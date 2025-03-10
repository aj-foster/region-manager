defmodule RMWeb.RegionJSON do
  use RMWeb, :json

  #
  # Region
  #

  @spec show(%{region: RM.FIRST.Region.t()}) :: RMWeb.JSON.success(map)
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

  #
  # Events
  #

  @spec events(%{events: [RM.FIRST.Event.t()]}) :: RMWeb.JSON.success(map)
  def events(%{events: events}) do
    success(%{event_count: length(events), events: Enum.map(events, &event/1)})
  end

  @spec event(RM.FIRST.Event.t()) :: map
  defp event(
         %RM.FIRST.Event{
           code: code,
           date_end: date_end,
           date_start: date_start,
           date_timezone: timezone,
           name: name,
           region: region,
           season: season,
           type: type,
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
      attachments: event_attachments(event),
      code: code,
      date_end: date_end,
      date_start: date_start,
      description: event_description(event),
      format: RM.FIRST.Event.format_name(event),
      live_stream_url: event_live_stream_url(event),
      name: name,
      season: season,
      type: RM.FIRST.Event.type_name(type),
      website: event_website(event),
      league: event_league(event.league || event.local_league),
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
      },
      registration: event_registration(event),
      url: url(~p"/s/#{event.season}/r/#{region}/e/#{event}"),
      virtual: event_virtual(event)
    }
  end

  @spec event_attachments(RM.FIRST.Event.t()) :: [%{name: String.t(), url: String.t()}]
  defp event_attachments(%RM.FIRST.Event{
         proposal: %RM.Local.EventProposal{attachments: attachments}
       }) do
    Enum.map(attachments, &%{name: &1.name, url: RM.Local.EventAttachment.url(&1)})
  end

  defp event_attachments(_event), do: []

  @spec event_description(RM.FIRST.Event.t()) :: String.t() | nil
  defp event_description(%RM.FIRST.Event{
         proposal: %RM.Local.EventProposal{description: description}
       }) do
    description
  end

  defp event_description(_event), do: nil

  @spec event_live_stream_url(RM.FIRST.Event.t()) :: String.t() | nil
  defp event_live_stream_url(%RM.FIRST.Event{
         proposal: %RM.Local.EventProposal{live_stream_url: live_stream_url}
       }) do
    live_stream_url
  end

  defp event_live_stream_url(%RM.FIRST.Event{live_stream_url: live_stream_url}) do
    live_stream_url
  end

  @spec event_website(RM.FIRST.Event.t()) :: String.t() | nil
  defp event_website(%RM.FIRST.Event{
         proposal: %RM.Local.EventProposal{website: website}
       }) do
    website
  end

  defp event_website(%RM.FIRST.Event{website: website}) do
    website
  end

  @spec event_virtual(RM.FIRST.Event.t()) :: boolean
  defp event_virtual(%RM.FIRST.Event{settings: %RM.Local.EventSettings{virtual: virtual}}) do
    virtual
  end

  defp event_virtual(_event), do: false

  @spec event_league(nil) :: nil
  @spec event_league(RM.FIRST.League.t()) :: map
  @spec event_league(RM.Local.League.t()) :: map
  defp event_league(nil), do: nil

  defp event_league(%RM.FIRST.League{code: code, name: name, remote: remote, location: location}) do
    %{code: code, name: name, remote: remote, location: location}
  end

  defp event_league(%RM.Local.League{code: code, name: name, remote: remote, location: location}) do
    %{code: code, name: name, remote: remote, location: location}
  end

  @spec event_registration(RM.FIRST.Event.t()) :: map | nil
  defp event_registration(
         %RM.FIRST.Event{
           region: region,
           settings: %RM.Local.EventSettings{
             registration: %RM.Local.RegistrationSettings{
               enabled: true,
               team_limit: team_limit,
               waitlist_limit: waitlist_limit
             }
           }
         } = event
       ) do
    {attending, waitlist} = event_registration_attending_waitlist(event)

    %{
      open: event_registration_open(event),
      opens_at: RM.FIRST.Event.registration_opens(event),
      closes_at: RM.FIRST.Event.registration_deadline(event),
      url: url(~p"/s/#{event.season}/r/#{region}/e/#{event}"),
      attending: Enum.map(attending, & &1.team.number),
      waitlist: Enum.map(waitlist, & &1.team.number),
      capacity: team_limit,
      waitlist_capacity: waitlist_limit
    }
  end

  defp event_registration(%RM.FIRST.Event{
         settings: %RM.Local.EventSettings{
           registration: %RM.Local.RegistrationSettings{enabled: false}
         }
       }) do
    nil
  end

  defp event_registration(%RM.FIRST.Event{settings: nil}) do
    nil
  end

  @spec event_registration_open(RM.FIRST.Event.t()) :: boolean
  defp event_registration_open(
         %RM.FIRST.Event{
           settings: %RM.Local.EventSettings{
             registration: %RM.Local.RegistrationSettings{enabled: true}
           }
         } = event
       ) do
    RM.FIRST.Event.registration_opening_passed?(event) and
      not RM.FIRST.Event.registration_deadline_passed?(event)
  end

  defp event_registration_open(_event), do: false

  @spec event_registration_attending_waitlist(RM.FIRST.Event.t()) ::
          {[RM.Local.EventRegistration.t()], [RM.Local.EventRegistration.t()]}
  defp event_registration_attending_waitlist(%RM.FIRST.Event{registrations: registrations}) do
    registrations
    |> Enum.reject(& &1.rescinded)
    |> Enum.split_with(&(not &1.waitlisted))
  end

  #
  # Leagues
  #

  @spec leagues(%{leagues: [RM.FIRST.League.t() | RM.Local.League.t()]}) ::
          RMWeb.JSON.success(map)
  def leagues(%{leagues: leagues}) do
    success(%{league_count: length(leagues), leagues: Enum.map(leagues, &league/1)})
  end

  @spec league(RM.FIRST.League.t()) :: map
  @spec league(RM.Local.League.t()) :: map
  defp league(%RM.FIRST.League{
         code: code,
         location: location,
         name: name,
         region: region,
         remote: remote,
         stats: %{event_count: event_count, league_count: league_count, team_count: team_count}
       }) do
    %{
      code: code,
      location: location,
      name: RM.Local.League.shorten_name(name, region),
      remote: remote,
      stats: %{event_count: event_count, league_count: league_count, team_count: team_count}
    }
  end

  defp league(%RM.Local.League{
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

  #
  # Teams
  #

  @spec teams(%{teams: [RM.FIRST.Team.t() | RM.Local.Team.t()], season: integer}) ::
          RMWeb.JSON.success(map)
  def teams(%{teams: teams, season: season}) do
    success(%{team_count: length(teams), teams: Enum.map(teams, &team(&1, season))})
  end

  @spec team(RM.FIRST.Team.t(), integer) :: map
  @spec team(RM.Local.Team.t(), integer) :: map
  defp team(
         %RM.Local.Team{
           event_ready: event_ready,
           name: name,
           number: number,
           rookie_year: rookie_year,
           website: website,
           location: %{
             city: city,
             country: country,
             county: county,
             state_province: state_province
           },
           league: league,
           region: region
         },
         season
       ) do
    %{
      event_ready: event_ready,
      name: name,
      number: number,
      rookie_year: rookie_year,
      website: website,
      location: %{city: city, country: country, county: county, state_province: state_province},
      league: team_league(league),
      url: url(~p"/s/#{season}/r/#{region}/t/#{number}")
    }
  end

  defp team(
         %RM.FIRST.Team{
           city: city,
           country: country,
           name_short: name,
           rookie_year: rookie_year,
           state_province: state_province,
           team_number: number,
           website: website,
           league: league,
           region: region
         },
         season
       ) do
    %{
      event_ready: nil,
      name: name,
      number: number,
      rookie_year: rookie_year,
      website: website,
      location: %{city: city, country: country, county: nil, state_province: state_province},
      league: team_league(league),
      url: url(~p"/s/#{season}/r/#{region}/t/#{number}")
    }
  end

  @spec team_league(nil) :: nil
  @spec team_league(RM.FIRST.League.t()) :: map
  @spec team_league(RM.Local.League.t()) :: map
  defp team_league(nil), do: nil

  defp team_league(%RM.FIRST.League{code: code, location: location, name: name, remote: remote}) do
    %{code: code, location: location, name: name, remote: remote}
  end

  defp team_league(%RM.Local.League{code: code, location: location, name: name, remote: remote}) do
    %{code: code, location: location, name: name, remote: remote}
  end

  #
  # Videos
  #

  @spec videos(%{videos: [RM.Local.EventVideo.t()]}) :: RMWeb.JSON.success(map)
  def videos(%{videos: videos}) do
    success(%{video_count: length(videos), videos: Enum.map(videos, &video/1)})
  end

  @spec video(RM.Local.EventVideo.t()) :: map
  defp video(
         %RM.Local.EventVideo{
           event:
             %RM.FIRST.Event{
               code: event_code,
               name: event_name
             } = event,
           team: %RM.Local.Team{number: number},
           url: url
         } = video
       ) do
    %{
      available_at: RM.FIRST.Event.video_submission_deadline(event),
      award: RM.Local.EventVideo.award_name(video),
      event_code: event_code,
      event_name: event_name,
      team: number,
      url: if(RM.FIRST.Event.video_submission_deadline_passed?(event), do: url, else: nil)
    }
  end
end
