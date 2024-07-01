defmodule RMWeb.MetaController do
  use RMWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end

  def seasons(conn, _params) do
    seasons = RM.FIRST.list_seasons()
    render(conn, :seasons, seasons: seasons)
  end
end
