defmodule RMWeb.Fallback do
  use RMWeb, :controller
  use RMWeb, :json

  def call(conn, {:error, data, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(error("#{data} not found"))
  end

  def call(conn, {:error, unknown_reason}) do
    conn
    |> put_status(:server_error)
    |> json(error(unknown_reason))
  end
end
