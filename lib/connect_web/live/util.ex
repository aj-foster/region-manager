defmodule ConnectWeb.Live.Util do
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
end
