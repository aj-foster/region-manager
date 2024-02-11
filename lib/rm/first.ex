defmodule RM.FIRST do
  @moduledoc """
  Entrypoint for data managed by FIRST
  """
  import Ecto.Query

  alias RM.FIRST.League
  alias RM.FIRST.LeagueAssignment
  alias RM.FIRST.Region
  alias RM.FIRST.Query
  alias RM.Local
  alias RM.Repo

  @spec list_region_ids_by_code :: %{String.t() => Ecto.UUID.t()}
  def list_region_ids_by_code do
    Region.id_by_code_query()
    |> Repo.all()
    |> Map.new()
  end

  @spec get_region_by_name(String.t(), keyword) :: Region.t() | nil
  def get_region_by_name(name, opts \\ []) do
    Query.from_region()
    |> Query.region_name(name)
    |> Query.preload_assoc(opts[:preload])
    |> Repo.one()
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

    league_id_map = Map.new(leagues, &{&1.code, &1.id})
    league_data = Enum.map(api_leagues, &League.from_ftc_events(&1, region_id_map, league_id_map))

    Repo.insert_all(League, league_data,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :code,
      returning: true
    )
    |> elem(1)
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
