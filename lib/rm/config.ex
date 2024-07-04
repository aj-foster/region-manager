defmodule RM.Config do
  @moduledoc """
  Provides fast-lookup configuration for global app settings

  This module is intended for settings that are used frequently and therefore should not require
  a database or ETS table lookup every time they are needed. It is vitally important that these
  settings rarely change, as the change will require a "stop the world" global garbage collection
  on all running processes. If the only alternative is hard-coding (or something that requires a
  deploy to change) then this module is for you.

  ## Usage

  Include this module early in the top-level supervisor, after the database has loaded:

      children = [
        RM.Repo,
        RM.Config,
        # ...
      ]

  To add a new piece of configuration, add it to the `@configuration` attribute of this module.
  The entry should be a map that specifies a `key`, `description`, and `initial_value`. The entry
  only needs to be present for one startup of this module, then it only remains as documentation.

  To update a setting during runtime, call `set/2`.

  ## Transient Configuration

  This module also supports transient configuration that is neither persisted nor shared among
  nodes in the cluster. This would be appropriate for configuration like the features available
  based on the application's environment. Any such configuration must be set separately on each
  node for every startup of the application.

  It is not necessary for transient configuration to be included in the `@configuration` attribute
  of this module.
  """
  use GenServer
  require Logger

  alias RM.Config.Setting
  alias RM.Repo

  # Format:
  #
  # %{
  #   key: "configuration_key",
  #   description: "Human-readable description",
  #   initial_value: "any erlang term"
  # }
  @configuration [
    %{
      key: "current_season",
      description: "Current season served by default routes",
      initial_value: 2023
    }
  ]

  @typedoc "Key of a configuration entry (case-insensitive)"
  @type key :: String.t()

  #
  # Client API
  #

  @doc false
  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get a configuration value

  This performs a fast lookup of the configuration with the given `key` from `:persistent_term`.
  It returns `default` if no configuration has been created with the given key (for example, in
  the case of transient configuration).
  """
  @spec get(key, term) :: term
  def get(key, default \\ nil) do
    do_get(key, default)
  end

  @doc """
  Set a new value for an existing configuration record

  This function does not create new configuration records. For that, it is necessary to add the
  new record to the `@configuration` module attribute in this module.

  After persisting the new value to the database for future application starts, this function will
  block while every node in the cluster acknowledges the change in configuration. When this
  function returns, every node will have **started** a global garbage collection, which may
  impact performance for some amount of time.
  """
  @spec set(key, term) :: :ok
  def set(key, value) do
    Setting.update(key, value)
    GenServer.multi_call(__MODULE__, {:reload, key})

    :ok
  end

  @doc """
  Set a transient (non-persisted) configuration value

  This function does not create persisted configuration records, and it does not update the
  configuration of connected nodes in the cluster. The resulting configuration will only be
  available on the local node until the next restart of the application.
  """
  @spec set_transient(key, term) :: :ok
  def set_transient(key, value) do
    :persistent_term.put(key(key), value)
    :ok
  end

  #
  # Server API
  #

  @doc false
  @impl true
  def init(_opts) do
    {:ok, [], {:continue, :load}}
  end

  @doc false
  @impl true
  def handle_continue(:load, _state) do
    existing_keys = load()

    new_keys =
      @configuration
      |> Enum.reject(fn %{key: key} -> key in existing_keys end)
      |> Enum.map(fn %{key: key, description: description} = config ->
        Setting.create(key, description, config[:initial_value])
        |> put()

        key
      end)

    {:noreply, existing_keys ++ new_keys}
  end

  @doc false
  @impl true
  def handle_call({:reload, key}, _from, state) do
    reload(key)
    {:reply, :ok, state}
  end

  #
  # Local Persistent Term Management
  #

  @spec key(key) :: {module, key}
  defp key(key), do: {__MODULE__, key}

  @spec load :: [key]
  defp load do
    Setting.all()
    |> Enum.map(fn %Setting{key: key, value: value} ->
      term = :erlang.binary_to_term(value)
      :persistent_term.put(key(key), term)

      key
    end)
  rescue
    e in Postgrex.Error ->
      Logger.warning(
        "Failed to load persistent configuration. Trying again in 10 seconds. Error: #{Exception.message(e)}"
      )

      Process.sleep(10_000)
      load()
  end

  @spec reload(key) :: :ok
  defp reload(key) do
    Setting
    |> Repo.get_by(key: key)
    |> put()
  end

  @spec do_get(key, term) :: term
  defp do_get(key, default) do
    # The default argument to :persistent_term.get/2 does not affect the case when `nil` is
    # stored in the key, which is likely to happen for any key defined in @configuration.
    :persistent_term.get(key(key), default) || default
  end

  @spec put(Setting.t() | nil) :: :ok
  defp put(nil), do: :ok

  defp put(%Setting{key: key, value: value}) do
    term = :erlang.binary_to_term(value)
    :persistent_term.put(key(key), term)
  end
end
