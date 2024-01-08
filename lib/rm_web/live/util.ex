defmodule RMWeb.Live.Util do
  import Phoenix.Component

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias RM.Account

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

  @spec on_mount(term, map, map, Socket.t()) :: {:cont, Socket.t()}
  def on_mount(:preload_user, _params, _session, socket) do
    case socket.assigns[:current_user] do
      %Identity.User{id: user_id} ->
        {:cont, assign(socket, current_user: get_user(user_id))}

      nil ->
        {:cont, socket}
    end
  end

  @spec get_user(Ecto.UUID.t()) :: Account.User.t()
  defp get_user(user_id) do
    Account.get_user_by_id!(user_id, preload: [:emails, :regions, :teams])
    |> Map.update!(:emails, &sort_emails/1)
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

  @spec sort_regions([RM.FIRST.Region.t()]) :: [RM.FIRST.Region.t()]
  defp sort_regions(regions) do
    Enum.sort_by(regions, & &1.name)
  end

  @spec sort_teams([RM.Local.Team.t()]) :: [RM.Local.Team.t()]
  defp sort_teams(teams) do
    Enum.sort_by(teams, & &1.number)
  end

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
end
