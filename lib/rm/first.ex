defmodule RM.FIRST do
  @moduledoc """
  Entrypoint for data managed by FIRST
  """
  import Ecto.Query

  alias RM.FIRST.Event
  alias RM.FIRST.League
  alias RM.FIRST.LeagueAssignment
  alias RM.FIRST.Region
  alias RM.FIRST.Query
  alias RM.Local
  alias RM.Repo

  #
  # Operations
  #

  @doc """
  Refresh the local league information for the given region
  """
  @spec refresh_leagues(Region.t()) :: {:ok, [League.t()]} | {:error, Exception.t()}
  def refresh_leagues(region) do
    with {:ok, %{leagues: leagues}} <- External.FTCEvents.list_leagues(region) do
      {:ok, update_leagues_from_ftc_events(leagues)}
    end
  end

  #
  # Data
  #

  @spec list_league_ids_by_code :: %{String.t() => Ecto.UUID.t()}
  def list_league_ids_by_code do
    League.id_by_code_query()
    |> Repo.all()
    |> Map.new()
  end

  @spec list_region_ids_by_code :: %{String.t() => Ecto.UUID.t()}
  def list_region_ids_by_code do
    Region.id_by_code_query()
    |> Repo.all()
    |> Map.new()
  end

  @spec get_region_by_abbreviation(String.t(), keyword) :: Region.t() | nil
  def get_region_by_abbreviation(abbreviation, opts \\ []) do
    Query.from_region()
    |> Query.region_abbreviation(abbreviation)
    |> Query.preload_assoc(opts[:preload])
    |> Repo.one()
  end

  def update_events_from_ftc_events(api_events, opts \\ []) do
    league_id_map = list_league_ids_by_code()
    region_id_map = list_region_ids_by_code()

    event_data =
      Enum.map(api_events, &Event.from_ftc_events(&1, region_id_map, league_id_map))
      |> Enum.reject(&is_nil(&1.region_id))
      |> Enum.map(&Map.put(&1, :season, 2023))

    events =
      Repo.insert_all(Event, event_data,
        on_conflict: {:replace_all_except, [:inserted_at]},
        conflict_target: [:season, :code],
        returning: true
      )

    if region_or_regions = opts[:delete_region] do
      event_ids = Enum.map(events, & &1.id)

      Query.from_event()
      |> Query.event_region(region_or_regions)
      |> where([event: e], e.id not in ^event_ids)
      |> Repo.delete_all()
    end

    events
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
  @spec update_leagues_from_ftc_events([map], keyword) :: [League.t()]
  def update_leagues_from_ftc_events(api_leagues, opts \\ []) do
    # First round: Initial insertion of the records

    region_id_map = list_region_ids_by_code()
    league_data = Enum.map(api_leagues, &League.from_ftc_events(&1, region_id_map))

    leagues =
      Repo.insert_all(League, league_data,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: :code,
        returning: true
      )
      |> elem(1)

    if region_or_regions = opts[:delete_region] do
      league_codes = Enum.map(leagues, & &1.code)

      Query.from_league()
      |> Query.league_region(region_or_regions)
      |> where([league: l], l.code not in ^league_codes)
      |> Repo.delete_all()
    end

    # Second round: update parent/child relationships.

    league_id_map = Map.new(leagues, &{&1.code, &1.id})
    league_data = Enum.map(api_leagues, &League.from_ftc_events(&1, region_id_map, league_id_map))

    leagues =
      Repo.insert_all(League, league_data,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: :code,
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
end
