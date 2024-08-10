defmodule RM.FIRST.RefreshJob do
  @moduledoc """
  Oban Job that periodically refreshes leagues and events for all regions
  """
  use Oban.Worker

  alias RM.FIRST

  @delay_between_calls_ms 1_000

  def perform(_job) do
    regions = FIRST.list_regions()

    seasons =
      Enum.map(regions, & &1.current_season)
      |> Enum.uniq()
      |> Enum.sort()

    # Teams

    Enum.each(regions, fn region ->
      FIRST.refresh_teams(region)
      Process.sleep(@delay_between_calls_ms)
    end)

    # Events

    Enum.each(seasons, fn season ->
      FIRST.refresh_events(season)
      Process.sleep(@delay_between_calls_ms)
    end)

    # Leagues & Assignments

    Enum.each(regions, fn region ->
      FIRST.refresh_leagues(region)
      Process.sleep(@delay_between_calls_ms)
    end)

    :ok
  end
end
