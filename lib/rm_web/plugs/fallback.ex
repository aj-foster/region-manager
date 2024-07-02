defmodule RMWeb.Fallback do
  use RMWeb, :controller

  def call(conn, {:error, unknown_reason}) do
    conn
    |> put_status(:server_error)
    |> json(error(unknown_reason))
  end

  defp error(error) do
    %{success: false, data: nil, errors: [error]}
  end
end
