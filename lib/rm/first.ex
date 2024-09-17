defmodule RM.FIRST do
  @moduledoc """
  Entrypoint for data managed by FIRST
  """
  import Ecto.Query

  alias Ecto.Changeset
  alias RM.FIRST.Event
  alias RM.FIRST.League
  alias RM.FIRST.LeagueAssignment
  alias RM.FIRST.Region
  alias RM.FIRST.Season
  alias RM.FIRST.Team
  alias RM.FIRST.Query
  alias RM.Local.EventSettings
  alias RM.Repo
  alias RM.Util

  #
  # Operations
  #

  @doc """
  Refresh all events for the given season or the given region's current season
  """
  @spec refresh_events(Region.t()) :: {:ok, [Event.t()]} | {:error, Exception.t()}
  @spec refresh_events(integer) :: {:ok, [Event.t()]} | {:error, Exception.t()}
  def refresh_events(region_or_season)

  def refresh_events(%Region{current_season: season}) do
    with {:ok, %{events: events}} <- External.FTCEvents.list_events(season) do
      {:ok, update_events_from_ftc_events(season, events)}
    end
  end

  def refresh_events(season) when is_integer(season) do
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
    leagues_by_code = list_leagues_by_code(season)
    local_leagues_by_code = RM.Local.list_leagues_by_code()
    regions_by_code = list_regions_by_code()
    open_proposals = RM.Local.list_open_event_proposals(season, preload: [:venue])

    event_data =
      Enum.map(
        api_events,
        &Event.from_ftc_events(&1, regions_by_code, leagues_by_code, local_leagues_by_code)
      )
      |> Enum.reject(&is_nil(&1.region_id))
      |> Enum.map(&Map.put(&1, :season, season))

    {_count, events} =
      Repo.insert_all(Event, event_data,
        on_conflict: {:replace_all_except, [:inserted_at, :local_league_id]},
        conflict_target: [:code, :season],
        returning: true
      )

    proposal_event_pairs =
      Enum.reduce(events, [], fn event, proposal_updates ->
        if proposal = Enum.find(open_proposals, &RM.Local.EventProposal.event_matches?(&1, event)) do
          [{proposal.id, event.id} | proposal_updates]
        else
          proposal_updates
        end
      end)

    RM.Local.update_event_proposal_events(proposal_event_pairs)
    update_event_leagues_from_proposals(proposal_event_pairs)

    event_settings_data =
      events
      |> Repo.preload([:proposal, local_league: :settings])
      |> Enum.map(&EventSettings.default_params/1)

    Repo.insert_all(EventSettings, event_settings_data,
      on_conflict: :nothing,
      conflict_target: :event_id
    )

    now = DateTime.utc_now()

    {_count, removed_events} =
      Query.from_event()
      |> Query.event_season(season)
      |> where([event: e], e.id not in ^Util.extract_ids(events))
      |> update(set: [removed_at: ^now])
      |> select([event: e], e)
      |> Repo.update_all([])

    Util.extract_ids(events ++ removed_events, :region_id)
    |> update_region_event_counts()

    Util.extract_ids(events ++ removed_events, :league_id)
    |> Enum.reject(&is_nil/1)
    |> update_league_event_counts()

    Util.extract_ids(events ++ removed_events, :local_league_id)
    |> Enum.reject(&is_nil/1)
    |> RM.Local.update_league_event_counts()

    events
  end

  @doc """
  Refresh the local league information for the given region

  This will refresh data for the region's "current season".
  """
  @spec refresh_leagues(Region.t()) :: {:ok, [League.t()]} | {:error, Exception.t()}
  @spec refresh_leagues(Region.t(), keyword) :: {:ok, [League.t()]} | {:error, Exception.t()}
  def refresh_leagues(region, opts \\ []) do
    season = opts[:season] || region.current_season

    with {:ok, %{leagues: leagues}} <- External.FTCEvents.list_leagues(season, region) do
      leagues = update_leagues_from_ftc_events(season, leagues, delete_region: region)

      for league <- leagues do
        # This is bad. But also... good.
        Process.sleep(1_000)

        with {:ok, members} <- External.FTCEvents.list_league_members(season, region, league) do
          update_league_assignments_from_ftc_events(season, league, members)
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
    local_leagues_by_code = RM.Local.list_leagues_by_code()

    league_data =
      Enum.map(api_leagues, &League.from_ftc_events(&1, regions_by_code, local_leagues_by_code))
      |> Enum.map(&Map.put(&1, :season, season))

    leagues =
      Repo.insert_all(League, league_data,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:code, :region_id, :season],
        returning: true
      )
      |> elem(1)

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
      Enum.map(
        api_leagues,
        &League.from_ftc_events(&1, regions_by_code, local_leagues_by_code, league_id_map)
      )
      |> Enum.map(&Map.put(&1, :season, season))

    leagues =
      Repo.insert_all(League, league_data,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:code, :region_id, :season],
        returning: true
      )
      |> elem(1)

    region_ids = Util.extract_ids(leagues, :region_id) ++ Util.extract_ids(opts[:delete_region])
    update_region_published_league_counts(region_ids)

    leagues
  end

  @doc """
  Save team/league assignments from an FTC Events API response
  """
  @spec update_league_assignments_from_ftc_events(integer, League.t(), [integer]) ::
          [LeagueAssignment.t()]
  def update_league_assignments_from_ftc_events(season, league, team_numbers) do
    Query.from_league_assignment()
    |> Query.assignment_league(league)
    |> Repo.delete_all()

    assignment_data =
      list_teams_by_number(season, team_numbers)
      |> Enum.map(&LeagueAssignment.new(league, &1))

    Repo.insert_all(LeagueAssignment, assignment_data,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:league_id, :team_id],
      returning: true
    )
    |> elem(1)
  end

  @doc """
  Refresh all season teams
  """
  @spec refresh_teams(Region.t()) :: {:ok, [RM.FIRST.Team.t()]} | {:error, Exception.t()}
  @spec refresh_teams(Region.t(), keyword) :: {:ok, [RM.FIRST.Team.t()]} | {:error, Exception.t()}
  def refresh_teams(region, opts \\ []) do
    season = opts[:season] || region.current_season
    do_refresh_teams(season, region, [], 1)
  end

  defp do_refresh_teams(season, region, team_acc, page) do
    case External.FTCEvents.list_teams(season, region, page: page) do
      {:ok, %{teams: api_teams, page_current: page_current, page_total: page_total}} ->
        teams = update_teams_from_ftc_events(season, region, api_teams)

        if page_current >= page_total do
          {:ok, teams ++ team_acc}
        else
          # This is bad. But also... good.
          Process.sleep(1_000)
          do_refresh_teams(season, region, teams ++ team_acc, page + 1)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_teams_from_ftc_events(season, region, api_teams) do
    %Region{code: code} = region
    regions_by_code = %{code => region}

    team_data =
      Enum.map(api_teams, &Team.from_ftc_events(&1, regions_by_code))
      |> Enum.reject(&is_nil(&1.region_id))
      |> Enum.map(&Map.put(&1, :season, season))

    {_count, teams} =
      Repo.insert_all(Team, team_data,
        on_conflict: {:replace_all_except, [:inserted_at]},
        conflict_target: [:team_number, :season],
        returning: true
      )

    teams
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
    |> Map.new(fn {code, region} ->
      {String.upcase(code), region}
    end)
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

  @spec update_region_event_counts(Repo.struct_or_id(Region.t())) :: :ok
  @spec update_region_event_counts([Repo.struct_or_id(Region.t())]) :: :ok
  def update_region_event_counts(region_or_id_or_list) do
    region_or_id_or_list
    |> Util.extract_ids()
    |> Enum.uniq()
    |> Region.event_stats_update_query()
    |> Repo.update_all([])

    :ok
  end

  @spec update_region_league_counts(Repo.struct_or_id(Region.t())) :: :ok
  @spec update_region_league_counts([Repo.struct_or_id(Region.t())]) :: :ok
  def update_region_league_counts(region_or_id_or_list) do
    region_or_id_or_list
    |> Util.extract_ids()
    |> Enum.uniq()
    |> Region.league_stats_update_query()
    |> Repo.update_all([])

    :ok
  end

  @spec update_region_published_league_counts(Repo.struct_or_id(Region.t())) :: :ok
  @spec update_region_published_league_counts([Repo.struct_or_id(Region.t())]) :: :ok
  def update_region_published_league_counts(region_or_id_or_list) do
    region_or_id_or_list
    |> Util.extract_ids()
    |> Enum.uniq()
    |> Region.published_league_stats_update_query()
    |> Repo.update_all([])

    :ok
  end

  @spec update_region_season(Region.t(), integer) ::
          {:ok, Region.t()} | {:error, Changeset.t(Region.t())}
  def update_region_season(region, season) do
    region
    |> Changeset.change(current_season: season)
    |> Repo.update()
  end

  @spec update_region_team_counts(Repo.struct_or_id(Region.t())) :: :ok
  @spec update_region_team_counts([Repo.struct_or_id(Region.t())]) :: :ok
  def update_region_team_counts(region_or_id_or_list) do
    region_or_id_or_list
    |> Util.extract_ids()
    |> Enum.uniq()
    |> Region.team_stats_update_query()
    |> Repo.update_all([])

    :ok
  end

  #
  # Leagues
  #

  @doc """
  List leagues for the given region

  ## Options

    * `season`: Season to get leagues for. Defaults to the region's current season.

  """
  @spec list_leagues_by_region(Region.t()) :: [League.t()]
  @spec list_leagues_by_region(Region.t(), keyword) :: [League.t()]
  def list_leagues_by_region(region, opts \\ []) do
    Query.from_league()
    |> Query.league_region(region)
    |> Query.league_season(opts[:season] || region.current_season)
    |> Query.preload_assoc(:league, opts[:preload])
    |> Repo.all()
    |> Enum.map(fn
      %League{region: %RM.FIRST.Region{}} = league -> league
      league -> %League{league | region: region}
    end)
  end

  @spec list_leagues_by_code(integer) :: %{{String.t(), String.t()} => League.t()}
  def list_leagues_by_code(season) do
    League.by_code_query(season)
    |> Repo.all()
    |> Map.new(fn {{region_code, league_code}, league} ->
      {{String.upcase(region_code), String.upcase(league_code)}, league}
    end)
  end

  @spec get_league_by_code(Region.t(), String.t()) :: League.t() | nil
  @spec get_league_by_code(Region.t(), String.t(), keyword) :: League.t() | nil
  def get_league_by_code(region, code, opts \\ []) do
    Query.from_league()
    |> Query.league_code(code)
    |> Query.league_region(region)
    |> Query.league_season(region.current_season)
    |> Query.preload_assoc(:league, opts[:preload])
    |> Repo.one()
  end

  @spec update_league_event_counts(Repo.struct_or_id(League.t())) :: :ok
  @spec update_league_event_counts([Repo.struct_or_id(League.t())]) :: :ok
  def update_league_event_counts(league_or_id_or_list) do
    league_or_id_or_list
    |> Util.extract_ids()
    |> Enum.uniq()
    |> League.event_stats_update_query()
    |> Repo.update_all([])

    :ok
  end

  @spec update_league_team_counts(Repo.struct_or_id(League.t())) :: :ok
  @spec update_league_team_counts([Repo.struct_or_id(League.t())]) :: :ok
  def update_league_team_counts(leagues) do
    leagues
    |> Util.extract_ids()
    |> Enum.uniq()
    |> League.team_stats_update_query()
    |> Repo.update_all([])

    :ok
  end

  #
  # Events
  #

  @spec list_events_by_region(Region.t()) :: [Event.t()]
  @spec list_events_by_region(Region.t(), keyword) :: [Event.t()]
  def list_events_by_region(region, opts \\ []) do
    Query.from_event()
    |> Query.event_region(region)
    |> Query.event_season(opts[:season] || region.current_season)
    |> Query.event_not_removed()
    |> Query.preload_assoc(:event, opts[:preload])
    |> Repo.all()
    |> Enum.filter(&is_nil(&1.division_code))
    |> Enum.sort(Event)
  end

  @spec list_eligible_events_by_team(RM.Local.Team.t()) :: [Event.t()]
  @spec list_eligible_events_by_team(RM.Local.Team.t(), keyword) :: [Event.t()]
  def list_eligible_events_by_team(team, opts \\ []) do
    Query.from_event()
    |> Query.event_not_removed()
    |> Query.event_season(opts[:season])
    |> Query.join_settings_from_event()
    |> filter_eligible_events_by_team(team)
    |> Query.preload_assoc(:event, opts[:preload])
    |> Repo.all()
    |> Enum.filter(&is_nil(&1.division_code))
    |> Enum.sort(Event)
  end

  @spec filter_eligible_events_by_team(Query.query(), RM.Local.Team.t()) :: Query.query()
  defp filter_eligible_events_by_team(
         query,
         %RM.Local.Team{league: %League{id: league_id}} = team
       ) do
    %RM.Local.Team{region_id: region_id} = team

    query
    |> filter_eligible_events_by_team(%RM.Local.Team{region_id: region_id})
    |> or_where(
      [event: e, settings: s],
      e.league_id == ^league_id and fragment("?->>'pool' = 'league'", s.registration)
    )
  end

  defp filter_eligible_events_by_team(query, team) do
    %RM.Local.Team{region_id: region_id} = team

    where(
      query,
      [event: e, settings: s],
      e.region_id == ^region_id and fragment("?->>'pool' = 'region'", s.registration)
    )
  end

  @spec fetch_event_by_code(integer, String.t()) ::
          {:ok, Event.t()} | {:error, :event, :not_found}
  @spec fetch_event_by_code(integer, String.t(), keyword) ::
          {:ok, Event.t()} | {:error, :event, :not_found}
  def fetch_event_by_code(season, code, opts \\ []) do
    Query.from_event()
    |> Query.event_code(code)
    |> Query.event_season(season)
    |> Query.event_not_removed()
    |> Query.preload_assoc(:event, opts[:preload])
    |> Repo.one()
    |> case do
      %Event{} = event -> {:ok, event}
      nil -> {:error, :event, :not_found}
    end
  end

  @doc """
  Update the FIRST event records with leagues from event proposals

  Data is given as a list of tuples containing the proposal ID and associated event ID.
  """
  @spec update_event_leagues_from_proposals([{Ecto.UUID.t(), Ecto.UUID.t()}]) :: :ok
  def update_event_leagues_from_proposals(updates) do
    {proposal_ids, first_event_ids} = Enum.unzip(updates)

    Query.from_event()
    |> join(
      :inner,
      [event: e],
      temp in fragment(
        "SELECT * FROM unnest(?::uuid[], ?::uuid[]) AS update_table(proposal_id, first_event_id)",
        type(^proposal_ids, {:array, Ecto.UUID}),
        type(^first_event_ids, {:array, Ecto.UUID})
      ),
      on: e.id == temp.first_event_id,
      as: :temp
    )
    |> join(:inner, [temp: t], p in RM.Local.EventProposal,
      on: p.id == t.proposal_id,
      as: :proposal
    )
    |> update([proposal: p], set: [local_league_id: p.league_id])
    |> Repo.update_all([])

    :ok
  end

  #
  # Teams
  #

  @spec list_teams_by_number(integer, [integer]) :: [Team.t()]
  @spec list_teams_by_number(integer, [integer], keyword) :: [Team.t()]
  def list_teams_by_number(season, numbers, opts \\ []) do
    Query.from_team()
    |> Query.team_season(season)
    |> where([team: t], t.team_number in ^numbers)
    |> Query.preload_assoc(:team, opts[:preload])
    |> Repo.all()
  end

  @doc """
  List teams for the given region

  ## Options

    * `season`: Season to get teams for. Defaults to the region's current season.

  """
  @spec list_teams_by_region(Region.t()) :: [Team.t()]
  @spec list_teams_by_region(Region.t(), keyword) :: [Team.t()]
  def list_teams_by_region(region, opts \\ []) do
    Query.from_team()
    |> Query.team_region(region)
    |> Query.team_season(opts[:season] || region.current_season)
    |> Query.preload_assoc(:team, opts[:preload])
    |> Repo.all()
    |> Enum.map(fn
      %Team{region: %RM.FIRST.Region{}} = team -> team
      team -> %Team{team | region: region}
    end)
  end
end
