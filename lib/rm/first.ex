defmodule RM.FIRST do
  @moduledoc """
  Entrypoint for data managed by FIRST
  """
  import Ecto.Query

  alias RM.FIRST.Event
  alias RM.FIRST.League
  alias RM.FIRST.LeagueAssignment
  alias RM.FIRST.Region
  alias RM.FIRST.Season
  alias RM.FIRST.Query
  alias RM.Local
  alias RM.Local.EventSettings
  alias RM.Local.LeagueSettings
  alias RM.Local.Team
  alias RM.Repo

  #
  # Operations
  #

  @doc """
  Refresh all season events
  """
  @spec refresh_events(Region.t()) :: {:ok, [Event.t()]} | {:error, Exception.t()}
  def refresh_events(region) do
    %Region{current_season: season} = region

    with {:ok, %{events: events}} <- External.FTCEvents.list_events(season) do
      {:ok, update_events_from_ftc_events(season, events)}
    end
  end

  @doc """
  Save event data from an FTC Events API response

  Because the events API covers all regions, any events not included in the response will be
  removed (regardless of region).
  """
  @spec update_events_from_ftc_events(integer, [map]) :: [Event.t()]
  def update_events_from_ftc_events(season, api_events) do
    league_id_map = list_league_ids_by_code(season)
    regions_by_code = list_regions_by_code()

    event_data =
      Enum.map(api_events, &Event.from_ftc_events(&1, regions_by_code, league_id_map))
      |> Enum.reject(&is_nil(&1.region_id))
      |> Enum.map(&Map.put(&1, :season, season))

    {_count, events} =
      Repo.insert_all(Event, event_data,
        on_conflict: {:replace_all_except, [:inserted_at]},
        conflict_target: [:season, :code],
        returning: true
      )

    event_settings_data =
      events
      |> Repo.preload(league: :settings)
      |> Enum.map(&EventSettings.default_params/1)

    Repo.insert_all(EventSettings, event_settings_data,
      on_conflict: :nothing,
      conflict_target: :event_id
    )

    event_ids = Enum.map(events, & &1.id)

    {_count, deleted_events} =
      Query.from_event()
      |> Query.event_season(season)
      |> where([event: e], e.id not in ^event_ids)
      |> select([event: e], e)
      |> Repo.delete_all()

    update_region_event_counts(events ++ deleted_events)
    update_league_event_counts(events ++ deleted_events, season)
    events
  end

  @spec update_region_event_counts([Event.t()]) :: {integer, nil}
  defp update_region_event_counts(events) do
    events
    |> Enum.map(& &1.region_id)
    |> Enum.uniq()
    |> Region.event_stats_update_query()
    |> Repo.update_all([])
  end

  @spec update_league_event_counts([Event.t()], integer) :: {integer, nil}
  defp update_league_event_counts(events, season) do
    events
    |> Enum.map(& &1.league_id)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
    |> League.event_stats_update_query(season)
    |> Repo.update_all([])
  end

  @doc """
  Refresh the local league information for the given region

  This will refresh data for the region's "current season".
  """
  @spec refresh_leagues(Region.t()) :: {:ok, [League.t()]} | {:error, Exception.t()}
  def refresh_leagues(region) do
    %Region{current_season: season} = region

    with {:ok, %{leagues: leagues}} <- External.FTCEvents.list_leagues(season, region) do
      leagues = update_leagues_from_ftc_events(season, leagues, delete_region: region)

      for league <- leagues do
        with {:ok, members} <- External.FTCEvents.list_league_members(season, region, league) do
          # This is bad. But also... good.
          Process.sleep(1_000)
          update_league_assignments_from_ftc_events(league, members)
        end
      end

      update_league_team_counts(leagues)

      {:ok, leagues}
    end
  end

  @doc """
  Save league data from an FTC Events API response

  This function assumes that for any league with a parent league, their parent is also included
  in the list of leagues to update (although not necessarily in a friendly order).

  TODO: Validate handling of parent leagues.

  ## Options

    * `delete_region`: If provided, leagues in the given region(s) will be deleted if not included
      in the updated data. This may be a `Region` or a list of regions. Defaults to not removing
      any existing records.

  """
  @spec update_leagues_from_ftc_events(integer, [map], keyword) :: [League.t()]
  def update_leagues_from_ftc_events(season, api_leagues, opts \\ []) do
    # First round: Initial insertion of the records

    regions_by_code = list_regions_by_code()

    league_data =
      Enum.map(api_leagues, &League.from_ftc_events(&1, regions_by_code))
      |> Enum.map(&Map.put(&1, :season, season))

    leagues =
      Repo.insert_all(League, league_data,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:code, :season],
        returning: true
      )
      |> elem(1)

    league_settings_data = Enum.map(leagues, &LeagueSettings.default_params/1)

    Repo.insert_all(LeagueSettings, league_settings_data,
      on_conflict: :nothing,
      conflict_target: :league_id
    )

    if region_or_regions = opts[:delete_region] do
      league_codes = Enum.map(leagues, & &1.code)

      Query.from_league()
      |> Query.league_season(season)
      |> Query.league_region(region_or_regions)
      |> where([league: l], l.code not in ^league_codes)
      |> Repo.delete_all()
    end

    # Second round: update parent/child relationships.

    league_id_map = Map.new(leagues, &{&1.code, &1.id})

    league_data =
      Enum.map(api_leagues, &League.from_ftc_events(&1, regions_by_code, league_id_map))
      |> Enum.map(&Map.put(&1, :season, season))

    leagues =
      Repo.insert_all(League, league_data,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:code, :season],
        returning: true
      )
      |> elem(1)

    update_region_league_counts(leagues)
    leagues
  end

  @spec update_region_league_counts([League.t()]) :: {integer, nil}
  defp update_region_league_counts(leagues) do
    leagues
    |> Enum.map(& &1.region_id)
    |> Enum.uniq()
    |> Region.league_stats_update_query()
    |> Repo.update_all([])
  end

  @doc """
  Save team/league assignments from an FTC Events API response
  """
  @spec update_league_assignments_from_ftc_events(League.t(), [integer]) :: [LeagueAssignment.t()]
  def update_league_assignments_from_ftc_events(league, team_numbers) do
    Query.from_league_assignment()
    |> Query.assignment_league(league)
    |> Repo.delete_all()

    assignment_data =
      Local.list_teams_by_number(team_numbers)
      |> Enum.map(&LeagueAssignment.new(league, &1))

    Repo.insert_all(LeagueAssignment, assignment_data,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:league_id, :team_id],
      returning: true
    )
    |> elem(1)
  end

  @spec update_league_team_counts([League.t()]) :: {integer, nil}
  defp update_league_team_counts(leagues) do
    leagues
    |> Enum.map(& &1.id)
    |> Enum.uniq()
    |> League.team_stats_update_query()
    |> Repo.update_all([])
  end

  #
  # Seasons
  #

  @spec list_seasons :: [Season.t()]
  def list_seasons do
    Query.from_season()
    |> order_by([season: s], s.year)
    |> Repo.all()
  end

  #
  # Regions
  #

  @spec list_regions :: [Region.t()]
  def list_regions do
    Query.from_region()
    |> order_by([region: r], r.name)
    |> Repo.all()
  end

  @spec list_regions_by_code :: %{String.t() => Region.t()}
  def list_regions_by_code do
    Region.by_code_query()
    |> Repo.all()
    |> Map.new()
  end

  @spec fetch_region_by_abbreviation(String.t(), keyword) ::
          {:ok, Region.t()} | {:error, :region, :not_found}
  def fetch_region_by_abbreviation(abbreviation, opts \\ []) do
    Query.from_region()
    |> Query.region_abbreviation(abbreviation)
    |> Query.preload_assoc(:region, opts[:preload])
    |> Repo.one()
    |> case do
      %Region{} = region -> {:ok, region}
      nil -> {:error, :region, :not_found}
    end
  end

  #
  # Leagues
  #

  @spec list_league_ids_by_code(integer) :: %{String.t() => Ecto.UUID.t()}
  def list_league_ids_by_code(season) do
    League.id_by_code_query(season)
    |> Repo.all()
    |> Map.new()
  end

  @spec fetch_league_by_code(String.t(), keyword) ::
          {:ok, League.t()} | {:error, :league, :not_found}
  def fetch_league_by_code(code, opts \\ []) do
    Query.from_league()
    |> Query.league_code(code)
    |> Query.preload_assoc(:league, opts[:preload])
    |> Repo.one()
    |> case do
      %League{} = league -> {:ok, league}
      nil -> {:error, :league, :not_found}
    end
  end

  #
  # Events
  #

  @spec list_events_by_region(Region.t()) :: [Event.t()]
  @spec list_events_by_region(Region.t(), keyword) :: [Event.t()]
  def list_events_by_region(region, opts \\ []) do
    Query.from_event()
    |> Query.event_region(region)
    |> Query.event_season(opts[:season])
    |> Query.preload_assoc(:event, opts[:preload])
    |> Repo.all()
    |> Enum.filter(&is_nil(&1.division_code))
    |> Enum.sort(Event)
  end

  @spec list_eligible_events_by_team(Team.t()) :: [Event.t()]
  @spec list_eligible_events_by_team(Team.t(), keyword) :: [Event.t()]
  def list_eligible_events_by_team(team, opts \\ []) do
    Query.from_event()
    |> Query.join_settings_from_event()
    |> filter_eligible_events_by_team(team)
    |> Query.preload_assoc(:event, opts[:preload])
    |> Repo.all()
    |> Enum.filter(&is_nil(&1.division_code))
    |> Enum.sort(Event)
  end

  @spec filter_eligible_events_by_team(Query.query(), Team.t()) :: Query.query()
  defp filter_eligible_events_by_team(query, %Team{league: %League{id: league_id}} = team) do
    %Team{region_id: region_id} = team

    query
    |> filter_eligible_events_by_team(%Team{region_id: region_id})
    |> or_where(
      [event: e, settings: s],
      e.league_id == ^league_id and fragment("?->>'pool' = 'league'", s.registration)
    )
  end

  defp filter_eligible_events_by_team(query, team) do
    %Team{region_id: region_id} = team

    where(
      query,
      [event: e, settings: s],
      e.region_id == ^region_id and fragment("?->>'pool' = 'region'", s.registration)
    )
  end

  @spec fetch_event_by_code(String.t()) :: {:ok, Event.t()} | {:error, :event, :not_found}
  @spec fetch_event_by_code(String.t(), keyword) ::
          {:ok, Event.t()} | {:error, :event, :not_found}
  def fetch_event_by_code(code, opts \\ []) do
    Query.from_event()
    |> Query.event_code(code)
    |> Query.preload_assoc(:event, opts[:preload])
    |> Repo.one()
    |> case do
      %Event{} = event -> {:ok, event}
      nil -> {:error, :event, :not_found}
    end
  end
end
