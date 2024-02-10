defmodule RM.Local do
  @moduledoc """
  Entrypoint for team and league data management
  """
  import Ecto.Query

  alias RM.Local.Query
  alias RM.Local.Team
  alias RM.Repo

  @spec list_teams_by_number([integer], keyword) :: [Team.t()]
  def list_teams_by_number(numbers, opts \\ []) do
    Query.from_team()
    |> where([team: t], t.number in ^numbers)
    |> Query.preload_assoc(opts[:preload])
    |> Repo.all()
  end

  @spec list_teams_by_team_id([integer], keyword) :: [Team.t()]
  def list_teams_by_team_id(team_ids, opts \\ []) do
    Query.from_team()
    |> where([team: t], t.team_id in ^team_ids)
    |> Query.preload_assoc(opts[:preload])
    |> Repo.all()
  end
end
