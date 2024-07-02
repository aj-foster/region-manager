defmodule RMWeb.MetaJSON do
  def index(_assigns) do
    %{success: true, data: "Welcome to the Region Manager API", errors: nil}
  end

  def seasons(%{seasons: seasons}) do
    seasons = Enum.map(seasons, &season/1)
    %{success: true, data: seasons, errors: nil}
  end

  defp season(%RM.FIRST.Season{name: name, year: year}) do
    %{name: name, year: year}
  end

  def regions(%{regions: regions}) do
    regions = Enum.map(regions, &region/1)
    %{success: true, data: regions, errors: nil}
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
