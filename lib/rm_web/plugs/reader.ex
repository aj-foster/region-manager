defmodule RMWeb.Reader do
  @moduledoc """
  Plug that reads and optionally caches the request body on the connection

  Certain routes in the application, such as webhooks processors, need access to the raw,
  unprocessed request body in order to perform tasks like signature checking. For these routes, we
  save the original data to the connection as a `raw_body` assign. For all other routes, we call
  the default body reader.

  ## Usage

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Phoenix.json_library(),
        body_reader: {RMWeb.Reader, :read_body, []}

  ## Adding Routes

  To enable cached body reading for a new route, add the route to `@cache_routes` in this module.
  """

  @cache_routes [
    "/hook/ses-delivery"
  ]

  @cache_routes_split Enum.map(@cache_routes, &String.split(&1, "/", trim: true))

  @doc false
  def read_body(%Plug.Conn{path_info: path_info} = conn, opts)
      when path_info in @cache_routes_split do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
        {:ok, body, conn}

      {:more, _, _} ->
        {:error, "Uploaded file is too big (over 8MB)"}

      {:error, _} = err ->
        err
    end
  end

  def read_body(conn, opts) do
    Plug.Conn.read_body(conn, opts)
  end
end
