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
end
