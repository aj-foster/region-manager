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

  defp event(
         %RM.FIRST.Event{
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
         } = event
       ) do
    %{
      code: code,
      date_end: date_end,
      date_start: date_start,
      hybrid: hybrid,
      live_stream_url: live_stream_url,
      name: name,
      remote: remote,
      season: season,
      type: type,
      website: website,
      location: %{
        name: venue,
        address: address,
        city: city,
        country: country,
        state_province: state_province,
        postal_code: get_in(event.proposal.venue.postal_code),
        timezone: timezone,
        website: get_in(event.proposal.venue.website),
        notes: get_in(event.proposal.venue.notes)
      }
    }
  end

  def leagues(%{leagues: leagues}) do
    success(%{league_count: length(leagues), leagues: Enum.map(leagues, &league/1)})
  end

  defp league(%RM.FIRST.League{
         code: code,
         location: location,
         name: name,
         remote: remote,
         stats: %{event_count: event_count, league_count: league_count, team_count: team_count}
       }) do
    %{
      code: code,
      location: location,
      name: name,
      remote: remote,
      stats: %{event_count: event_count, league_count: league_count, team_count: team_count}
    }
  end

  def teams(%{teams: teams}) do
    success(%{team_count: length(teams), teams: Enum.map(teams, &team/1)})
  end

  defp team(%RM.Local.Team{
         name: name,
         number: number,
         rookie_year: rookie_year,
         website: website,
         location: %{city: city, country: country, county: county, state_province: state_province},
         league: league
       }) do
    %{
      name: name,
      number: number,
      rookie_year: rookie_year,
      website: website,
      location: %{city: city, country: country, county: county, state_province: state_province},
      league: team_league(league)
    }
  end

  defp team_league(nil), do: nil

  defp team_league(%RM.FIRST.League{code: code, location: location, name: name, remote: remote}) do
    %{code: code, location: location, name: name, remote: remote}
  end
end
