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
      season: RM.Config.get("current_season"),
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
      season: RM.Config.get("current_season")
    }
  end

  @doc false
  def region_factory do
    code = sequence("region", &"R#{&1}")

    %RM.FIRST.Region{
      abbreviation: code,
      code: code,
      current_season: RM.Config.get("current_season"),
      description: "Region #{code}",
      has_leagues: true,
      name: "Region #{code}",
      metadata: %{code_list_teams: code}
    }
  end

  #
  # Local
  #

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
  def team_factory do
    number = sequence("team", & &1)

    %RM.Local.Team{
      active: true,
      event_ready: true,
      name: "Team #{number}",
      number: number,
      region: fn -> build(:region) end,
      rookie_year: RM.Config.get("current_season"),
      team_id: number,
      temporary_number: number,
      website: nil
    }
  end
end
