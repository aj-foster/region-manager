defmodule RMWeb.RegionJSON do
  use RMWeb, :json

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

    success(%{
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
    })
  end

  def events(%{events: events}) do
    success(%{event_count: length(events), events: Enum.map(events, &event/1)})
  end

  defp event(%RM.FIRST.Event{
         code: code,
         date_end: date_end,
         date_start: date_start,
         date_timezone: timezone,
         hybrid: hybrid,
         live_stream_url: live_stream_url,
         name: name,
         remote: remote,
         season: season,
         type: type,
         website: website,
         location: %{
           address: address,
           city: city,
           country: country,
           state_province: state_province,
           venue: venue
         }
       }) do
    %{
      code: code,
      date_end: date_end,
      date_start: date_start,
      date_timezone: timezone,
      hybrid: hybrid,
      live_stream_url: live_stream_url,
      name: name,
      remote: remote,
      season: season,
      type: type,
      website: website,
      location: %{
        address: address,
        city: city,
        country: country,
        state_province: state_province,
        venue: venue
      }
    }
  end
end
