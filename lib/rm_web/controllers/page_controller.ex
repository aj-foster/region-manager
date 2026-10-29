defmodule RMWeb.PageController do
  use RMWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def redirect_to_current_season(conn, %{"region" => abbreviation, "rest" => rest}) do
    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation) do
      target =
        "/s/#{region.current_season}/r/#{Phoenix.Param.to_param(region)}/#{Enum.join(rest, "/")}"

      redirect(conn, to: target)
    end
  end
end
