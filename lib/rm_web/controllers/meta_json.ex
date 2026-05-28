defmodule RMWeb.MetaJSON do
  use RMWeb, :json

  def index(_assigns) do
    success(%{
      description: "Welcome to the Region Manager API",
      latest_version: RMWeb.Version.latest_version(),
      all_versions: RMWeb.Version.all_versions()
    })
  end

  def seasons(%{seasons: seasons}) do
    seasons = Enum.map(seasons, &season/1)
    success(%{season_count: length(seasons), seasons: seasons})
  end

  defp season(%RM.FIRST.Season{kickoff: kickoff, name: name, year: year}) do
    %{kickoff: kickoff, name: name, year: year}
  end

  def regions(%{regions: regions}) do
    success(%{region_count: length(regions), regions: Enum.map(regions, &region/1)})
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
