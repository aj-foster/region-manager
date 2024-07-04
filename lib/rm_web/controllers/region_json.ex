defmodule RMWeb.RegionJSON do
  def show(%{region: region}) do
    %RM.FIRST.Region{
      abbreviation: abbreviation,
      description: description,
      has_leagues: has_leagues,
      name: name,
      stats: %RM.FIRST.Region.Stats{
        event_count: event_count,
        events_imported_at: events_imported_at,
        league_count: league_count,
        leagues_imported_at: leagues_imported_at,
        team_count: team_count,
        teams_imported_at: teams_imported_at
      }
    } = region

    %{
      success: true,
      data: %{
        abbreviation: abbreviation,
        description: description,
        has_leagues: has_leagues,
        name: name,
        stats: %{
          event_count: event_count,
          events_imported_at: events_imported_at,
          league_count: league_count,
          leagues_imported_at: leagues_imported_at,
          team_count: team_count,
          teams_imported_at: teams_imported_at
        }
      },
      errors: nil
    }
  end
end
