defmodule RMWeb.MetaJSON do
  use RMWeb, :json

  def index(_assigns) do
    success(%{
      description: "Welcome to the Region Manager API",
      latest_version: RMWeb.Version.latest_version(),
      all_versions: RMWeb.Version.all_versions()
    })
  end

  def seasons(%{seasons: seasons, current: current}) do
    seasons = Enum.map(seasons, fn s -> season(s, s.year == current) end)
    success(%{current_season: current, seasons: seasons})
  end

  defp season(%RM.FIRST.Season{name: name, year: year}, current?) do
    %{name: name, year: year, current: current?}
  end

  def regions(%{regions: regions}) do
    Enum.map(regions, &region/1)
    |> success()
  end

  defp region(%RM.FIRST.Region{
         abbreviation: abbreviation,
         code: code,
         has_leagues: has_leagues,
         name: name
       }) do
    %{abbreviation: abbreviation, code: code, has_leagues: has_leagues, name: name}
  end
end
