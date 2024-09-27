defmodule RMWeb.Live.Util do
  use RMWeb, :html
  import Phoenix.Component

  alias Phoenix.Component
  alias Phoenix.LiveView
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Socket
  alias RM.Account

  @doc """
  Copy data to the browser's clipboard

  This function allows an action (such as `phx-click`) to initiate copying data to the clipboard.
  The data can be simple text or rich data depending on the attributes of the element triggering
  the event.

  ```heex
  <span id="some-element"><%= @id %></span>
  <button phx-click={copy("#some-element")}>Copy ID</button>
  ```

  ## Data Sources

  The data to be copied will be retrieved from the `target` passed. In particular, it will come
  from the following sources, in order of priority:

  * `data-copy` attribute
  * `value`, if the element is an input element
  * Element's inner text

  By default, the data will be copied as plain text. A `data-copy-type` attribute can be added on
  the same element to modify the type of the data. Note that browser support for non-text
  clipboard data is limited.

  ## Integration

  Use of this utility requires the following event listener on the client (usually included in
  `app.js` after the setup of the live socket):

  ```javascript
  window.addEventListener("phx:copy", (event) => {
    let content;
    let copyAttribute = event.target.getAttribute("data-copy");
    let contentType = event.target.getAttribute("data-copy-type");

    if (copyAttribute != null) {
      content = copyAttribute;
    } else if (event.target instanceof HTMLInputElement) {
      content = event.target.value
    } else {
      content = event.target.innerText;
    }

    if (contentType != null) {
      const blob = new Blob([content], { contentType });
      const data = [new ClipboardItem({ [contentType]: blob })];

      navigator.clipboard.write(data)
    } else {
      navigator.clipboard.writeText(content)
    }
  })
  ```
  """
  @spec copy(%JS{}, String.t()) :: %JS{}
  def copy(js \\ %JS{}, target) do
    JS.dispatch(js, "phx:copy", to: target)
  end

  @doc """
  Send a `Phoenix.LiveView.JS.exec/1` call to the client

  This function allows `Phoenix.LiveView.JS` functions to be run from the server. Setup requires
  the JS function to be predefined as a `data-*` attribute on an HTML element with a name that
  matches the call:

  ```heex
  <div data-hide={JS.remove_class("opacity-100")} id="target-id" />
  ```

  With this data attribute, the server can call the JS command with:

      push_js(socket, "#target-id", "data-hide")

  The `target` can be any selector accepted by `querySelectorAll` on the client. The command will
  be dispatched to all matching elements.

  ## Integration

  Use of this utility requires the following event listener on the client (usually included in
  `app.js` after the setup of the live socket):

  ```javascript
  window.addEventListener("phx:js-exec", ({ detail: {to, attr} }) => {
    document.querySelectorAll(to).forEach(el => {
      liveSocket.execJS(el, el.getAttribute(attr))
    })
  })
  ```
  """
  @spec push_js(Socket.t(), String.t(), String.t()) :: Socket.t()
  def push_js(socket, target, command) do
    LiveView.push_event(socket, "js-exec", %{attr: command, to: target})
  end

  @doc """
  Merge the given params into the query params present on the socket's URI

  This function helps views ensure the URI state matches the state of the page. It is advisable
  to tie vital page state bidirectionally to the URI state in order to make deep links possible.

  Params with a value of `""`, `false`, or `nil` will be removed entirely.

  ## Setup

  In order for this helper to know the current state of the URI, the view must provide an assign
  `lvu_uri` with a parsed `%URI{}` of the current location. This integration can be set up
  automatically by calling:

      on_mount {#{inspect(__MODULE__)}, :setup_uri}

  Or by using this module (this will set up all of the hooks defined by this module):

      use #{inspect(__MODULE__)}

  """
  @spec push_query(Socket.t(), keyword | map) :: Socket.t()
  def push_query(socket, new_params) do
    current_params = URI.decode_query(socket.assigns.lvu_uri.query || "")
    new_params = for {key, value} <- new_params, into: %{}, do: {to_string(key), value}

    query =
      Map.merge(current_params, new_params)
      |> Enum.reject(fn {_key, value} -> value in ["", false, nil] end)
      |> URI.encode_query()

    suffix = if query != "", do: "?" <> query, else: ""
    LiveView.push_patch(socket, to: socket.assigns.lvu_uri.path <> suffix)
  end

  @doc """
  Wrap the socket in a `{:noreply, socket}` tuple

  This function is purely cosmetic, allowing most LiveView callbacks to be completed with a
  pipeline:

      socket
      |> do_work()
      |> noreply()

  """
  @spec noreply(Socket.t()) :: {:noreply, Socket.t()}
  def noreply(socket), do: {:noreply, socket}

  @doc """
  Wrap the socket in a `{:ok, socket}` tuple

  This function is purely cosmetic, allowing most LiveView mount callbacks to be completed with a
  pipeline:

      socket
      |> assign(...)
      |> ok()

  """
  @spec ok(Socket.t()) :: {:ok, Socket.t()}
  def ok(socket), do: {:ok, socket}

  @doc """
  Refresh the current user
  """
  @spec refresh_user(Socket.t()) :: Socket.t()
  def refresh_user(socket) do
    case socket.assigns[:current_user] do
      %{id: user_id} ->
        assign(socket, current_user: get_user(user_id))

      nil ->
        socket
    end
  end

  @spec get_user(Ecto.UUID.t()) :: Account.User.t()
  defp get_user(user_id) do
    Account.get_user_by_id!(user_id, preload: [:emails, :leagues, :profile, :regions, :teams])
    |> RM.Repo.preload(leagues: [:region], teams: [:league, :region])
    |> Map.update!(:emails, &sort_emails/1)
    |> Map.update!(:leagues, &sort_leagues/1)
    |> Map.update!(:regions, &sort_regions/1)
    |> Map.update!(:teams, &sort_teams/1)
  end

  @spec sort_emails([Identity.Schema.Email.t()]) :: [Identity.Schema.Email.t()]
  defp sort_emails(emails) do
    Enum.sort_by(emails, & &1, fn
      %{confirmed_at: %DateTime{}}, %{confirmed_at: nil} -> true
      %{confirmed_at: nil}, %{confirmed_at: %DateTime{}} -> false
      %{email: email_one}, %{email: email_two} -> email_one <= email_two
    end)
  end

  @spec sort_leagues([RM.FIRST.League.t()]) :: [RM.FIRST.League.t()]
  defp sort_leagues(leagues) do
    Enum.sort_by(leagues, & &1.name)
  end

  @spec sort_regions([RM.FIRST.Region.t()]) :: [RM.FIRST.Region.t()]
  defp sort_regions(regions) do
    Enum.sort_by(regions, & &1.name)
  end

  @spec sort_teams([RM.Local.Team.t()]) :: [RM.Local.Team.t()]
  defp sort_teams(teams) do
    Enum.sort_by(teams, & &1.number)
  end

  #
  # Hooks
  #

  @doc false
  defmacro __using__(_opt) do
    quote do
      LiveView.on_mount({RMWeb.Live.Util, :setup_season})
      LiveView.on_mount({RMWeb.Live.Util, :setup_timezone})
      LiveView.on_mount({RMWeb.Live.Util, :setup_uri})
    end
  end

  @doc false
  @spec on_mount(term, map, map, Socket.t()) :: {:cont, Socket.t()}
  def on_mount(name, params, session, socket)

  def on_mount(:preload_user, _params, _session, socket) do
    case socket.assigns[:current_user] do
      %RM.Account.User{id: user_id} ->
        {:cont, assign(socket, current_user: get_user(user_id))}

      nil ->
        {:cont, assign(socket, current_user: nil)}
    end
  end

  # Must be called after :setup_season has run
  def on_mount(:require_season, _params, _session, socket) do
    if socket.assigns[:season] do
      {:cont, socket}
    else
      socket =
        socket
        |> LiveView.put_flash(:error, "Invalid season in the URL")
        |> LiveView.redirect(to: ~p"/dashboard")

      {:halt, socket}
    end
  end

  def on_mount(:setup_season, params, _session, socket) do
    with {:ok, season_str} <- Map.fetch(params, "season"),
         {season, ""} <- Integer.parse(season_str) do
      {:cont, assign(socket, season: season)}
    else
      _ ->
        {:cont, socket}
    end
  end

  def on_mount(:setup_timezone, _params, _session, socket) do
    timezone = LiveView.get_connect_params(socket)["timezone"] || "Etc/UTC"

    canonical_timezone =
      if Tzdata.zone_alias?(timezone) do
        Tzdata.links()
        |> Map.get(timezone, "Etc/UTC")
      else
        timezone
      end

    Process.put(:client_timezone, canonical_timezone)
    {:cont, assign(socket, timezone: canonical_timezone)}
  end

  def on_mount(:setup_uri, _params, _session, socket) do
    socket =
      LiveView.attach_hook(socket, :setup_uri, :handle_params, fn _params, uri, socket ->
        {:cont, Component.assign(socket, lvu_uri: URI.parse(uri))}
      end)

    {:cont, socket}
  end
end
