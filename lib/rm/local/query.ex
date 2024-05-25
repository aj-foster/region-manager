defmodule RM.Local.Query do
  @moduledoc """
  Query helpers for schemas in the Local namespace
  """
  import Ecto.Query

  alias RM.Local.Team

  @typedoc "Intermediate query"
  @type query :: Ecto.Query.t()

  #
  # Base
  #

  @doc "Start a query from the teams table"
  @spec from_team :: query
  def from_team do
    from(Team, as: :team)
  end

  #
  # Joins
  #

  @doc "Load the `league_assignment` and `league` associations on a team"
  @spec join_league_from_team(query) :: query
  def join_league_from_team(query) do
    with_named_binding(query, :league, fn query, binding ->
      query
      |> join(:left, [team: t], la in assoc(t, :league_assignment), as: :league_assignment)
      |> join(:left, [league_assignment: la], l in assoc(la, :league), as: ^binding)
    end)
  end

  @doc "Load the `region` association on a team"
  @spec join_region_from_team(query) :: query
  def join_region_from_team(query) do
    with_named_binding(query, :region, fn query, binding ->
      join(query, :left, [team: t], r in assoc(t, :region), as: ^binding)
    end)
  end

  @doc "Load the `user_assignments` and `users` associations on a team"
  @spec join_users_from_team(query) :: query
  def join_users_from_team(query) do
    with_named_binding(query, :users, fn query, binding ->
      query
      |> join(:left, [team: t], ua in assoc(t, :user_assignments), as: :user_assignments)
      |> join(:left, [user_assignments: ua], u in assoc(ua, :user), as: ^binding)
    end)
  end

  #
  # Preloads
  #

  @doc """
  Preload data in a single query

  Data preloaded with this function will be joined and loaded in a single query, which can cause
  performance issues. The associations supported are:

    * `league`: `league_assignment` and `league` on a team
    * `region`: `region` on a team
    * `users`: `user_assignments` and `users` on a team

  """
  @spec preload_assoc(query, [atom] | nil) :: query
  def preload_assoc(query, associations)
  def preload_assoc(query, nil), do: query
  def preload_assoc(query, []), do: query

  def preload_assoc(query, [:league | rest]) do
    query
    |> join_league_from_team()
    |> preload([league_assignment: la, league: l], league_assignment: {la, league: l}, league: l)
    |> preload_assoc(rest)
  end

  def preload_assoc(query, [:region | rest]) do
    query
    |> join_region_from_team()
    |> preload([region: r], region: r)
    |> preload_assoc(rest)
  end

  def preload_assoc(query, [:users | rest]) do
    query
    |> join_users_from_team()
    |> preload([user_assignments: ua, users: u],
      user_assignments: {ua, user: u},
      users: u
    )
    |> preload_assoc(rest)
  end
end
