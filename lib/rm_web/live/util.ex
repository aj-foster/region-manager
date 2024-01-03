defmodule RMWeb.Live.Util do
  import Phoenix.Component

  alias Phoenix.LiveView.Socket
  alias RM.Account

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

  @spec on_mount(term, map, map, Socket.t()) :: {:cont, Socket.t()}
  def on_mount(:preload_user, _params, _session, socket) do
    case socket.assigns[:current_user] do
      %Identity.User{id: user_id} ->
        user = Account.get_user_by_id!(user_id, preload: [:regions])
        {:cont, assign(socket, current_user: user)}

      nil ->
        {:cont, socket}
    end
  end
end
