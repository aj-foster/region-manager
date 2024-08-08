defmodule RM.FIRST.RefreshJob do
  @moduledoc """
  Oban Job that periodically refreshes leagues and events for all regions
  """
  use Oban.Worker

  alias RM.FIRST

  def perform(_job) do
    regions = FIRST.list_regions()

    seasons =
      Enum.map(regions, & &1.current_season)
      |> Enum.uniq()
      |> Enum.sort()

    # Events

    Enum.each(seasons, fn season ->
      FIRST.refresh_events(season)
      Process.sleep(1_000)
    end)

    # Leagues & Assignments

    Enum.each(regions, fn region ->
      FIRST.refresh_leagues(region)
      Process.sleep(1_000)
    end)

    :ok
  end
end
