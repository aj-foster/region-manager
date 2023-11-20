defmodule ConnectWeb.RegionLive.Import do
  use ConnectWeb, :live_view

  alias Connect.Import

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> allow_upload(:team_data, accept: ["text/csv"], max_file_size: 1024 * 1024)

    {:ok, socket}
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("validate", _params, socket) do
    noreply(socket)
  end

  def handle_event("import", _params, socket) do
    consume_uploaded_entries(socket, :team_data, fn %{path: path}, _entry ->
      Import.parse("FL", path)
      {:ok, path}
    end)

    noreply(socket)
  end
end
