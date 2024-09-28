defmodule RM.Factory do
  use ExMachina.Ecto, repo: RM.Repo

  #
  # Accounts
  #

  @doc false
  def user_factory do
    %RM.Account.User{
      emails: fn -> [build(:user_email)] end
    }
  end

  @doc false
  def user_email_factory do
    now = DateTime.utc_now()

    %Identity.Schema.Email{
      confirmed_at: now,
      email: sequence("email", &"user-#{&1}@example.com"),
      generated_at: now
    }
  end

  @doc false
  def user_region_factory do
    %RM.Account.Region{
      region: fn -> build(:region) end,
      user: fn -> build(:user) end
    }
  end

  @doc false
  def with_region(%RM.Account.User{} = user, overrides \\ %{}) do
    %{region: region, user: user} =
      insert(:user_region, region: build(:region, overrides), user: user)

    user = RM.Repo.preload(user, [:region_assignments, :regions], force: true)

    %{region: region, user: user}
  end

  #
  # FIRST
  #

  @doc false
  def first_event_factory do
    code = sequence("event", &"E#{&1}")
    today = Date.utc_today()

    %RM.FIRST.Event{
      code: code,
      date_end: today,
      date_start: today,
      date_timezone: "Etc/UTC",
      field_count: 1,
      hybrid: false,
      name: "Event #{code}",
      published: false,
      region: fn -> build(:region) end,
      remote: false,
      season: RM.System.current_season(),
      type: :scrimmage
    }
  end

  @doc false
  def first_league_factory do
    code = sequence("league", &"L#{&1}")

    %RM.FIRST.League{
      code: code,
      name: "League #{code}",
      region: fn -> build(:region) end,
      remote: false,
      season: RM.System.current_season()
    }
  end

  @doc false
  def first_league_assignment_factory do
    %RM.FIRST.LeagueAssignment{
      league: fn -> build(:first_league) end,
      team: fn -> build(:first_team) end
    }
  end

  @doc false
  def first_team_factory do
    number = sequence("team", & &1)

    %RM.FIRST.Team{
      city: "City #{number}",
      country: "United States",
      display_location: "City #{number}",
      display_team_number: to_string(number),
      name_full: "Team #{number}",
      name_short: "Team #{number}",
      region: fn -> build(:region) end,
      rookie_year: RM.System.current_season(),
      season: RM.System.current_season(),
      state_province: "Florida",
      team_number: number
    }
  end

  @doc false
  def region_factory do
    code = sequence("region", &"R#{&1}")

    %RM.FIRST.Region{
      abbreviation: code,
      code: code,
      current_season: RM.System.current_season(),
      description: "Region #{code}",
      has_leagues: true,
      name: "Region #{code}",
      metadata: %{code_list_teams: code}
    }
  end

  @doc false
  def season_factory do
    year = sequence("season", & &1)

    %RM.FIRST.Season{
      name: "Season #{year}",
      year: year
    }
  end

  #
  # Local
  #

  @doc false
  def event_proposal_factory do
    code = sequence("event", &"E#{&1}")
    today = Date.utc_today()

    %RM.Local.EventProposal{
      contact: %RM.Local.EventProposal.Contact{
        email: "host-#{code}@example.com",
        name: "Host #{code}",
        phone: "123-456-7890"
      },
      date_end: today,
      date_start: today,
      format: :traditional,
      name: "Event #{code}",
      region: fn -> build(:region) end,
      season: RM.System.current_season(),
      type: :scrimmage,
      venue: fn -> build(:venue) end
    }
  end

  @doc false
  def with_event_settings(event) do
    insert(:event_settings, event: event)
    event
  end

  @doc false
  def event_settings_factory do
    %RM.Local.EventSettings{
      event: fn -> build(:first_event) end,
      registration: %RM.Local.RegistrationSettings{
        enabled: true,
        deadline_days: 7,
        open_days: 21,
        pool: :region
      }
    }
  end

  @doc false
  def league_factory do
    code = sequence("league", &"L#{&1}")

    %RM.Local.League{
      code: code,
      current_season: RM.System.current_season(),
      location: "Somewhere",
      name: "League #{code}",
      region: fn -> build(:region) end,
      remote: false
    }
  end

  @doc false
  def with_league_settings(league, overrides \\ []) do
    insert(:league_settings, [league: league] ++ overrides)
    league
  end

  @doc false
  def league_assignment_factory do
    %RM.Local.LeagueAssignment{
      league: fn -> build(:league) end,
      team: fn -> build(:team) end
    }
  end

  @doc false
  def league_settings_factory do
    %RM.Local.LeagueSettings{
      league: fn -> build(:league) end,
      registration: %RM.Local.RegistrationSettings{
        enabled: true,
        deadline_days: 7,
        open_days: 21,
        pool: :league
      }
    }
  end

  @doc false
  def team_factory do
    number = sequence("team", & &1)

    %RM.Local.Team{
      active: true,
      event_ready: true,
      name: "Team #{number}",
      number: number,
      region: fn -> build(:region) end,
      rookie_year: RM.System.current_season(),
      team_id: number,
      temporary_number: number,
      website: nil
    }
  end

  @doc false
  def venue_factory do
    code = sequence("venue", &"V#{&1}")

    %RM.Local.Venue{
      address: "123 Main St.",
      address_2: "",
      city: "Some City",
      country: "United States",
      league: fn -> build(:league) end,
      name: "Venue #{code}",
      postal_code: "11111",
      state_province: "New State",
      timezone: "Etc/UTC"
    }
  end
end
