defmodule RM.Account.Query do
  @moduledoc """
  Query helpers for schemas in the Account namespace
  """
  import Ecto.Query

  alias RM.Account.User

  @typedoc "Intermediate query"
  @type query :: Ecto.Query.t()

  #
  # Base
  #

  @doc "Start a query from the users table"
  @spec from_user :: query
  def from_user do
    from(User, as: :user)
  end

  #
  # Joins
  #

  @doc "Load the `emails` association on a user"
  @spec join_emails_from_user(query) :: query
  def join_emails_from_user(query) do
    with_named_binding(query, :emails, fn query, binding ->
      query
      |> join(:left, [user: u], e in assoc(u, :emails), as: ^binding)
    end)
  end

  @doc "Load the `league_assignments` and `leagues` associations on a user"
  @spec join_leagues_from_user(query) :: query
  def join_leagues_from_user(query) do
    with_named_binding(query, :leagues, fn query, binding ->
      query
      |> join(:left, [user: u], la in assoc(u, :league_assignments), as: :league_assignments)
      |> join(:left, [league_assignments: la], r in assoc(la, :league), as: ^binding)
    end)
  end

  @doc "Load the `region_assignments` and `regions` associations on a user"
  @spec join_regions_from_user(query) :: query
  def join_regions_from_user(query) do
    with_named_binding(query, :regions, fn query, binding ->
      query
      |> join(:left, [user: u], ra in assoc(u, :region_assignments), as: :region_assignments)
      |> join(:left, [region_assignments: ra], r in assoc(ra, :region), as: ^binding)
    end)
  end

  @doc "Load the `team_assignments` and `teams` associations on a user"
  @spec join_teams_from_user(query) :: query
  def join_teams_from_user(query) do
    with_named_binding(query, :teams, fn query, binding ->
      query
      |> join(:left, [user: u], ta in assoc(u, :team_assignments), as: :team_assignments)
      |> join(:left, [team_assignments: ta], t in assoc(ta, :team), as: ^binding)
    end)
  end

  #
  # Preloads
  #

  @doc """
  Preload data in a single query

  Data preloaded with this function will be joined and loaded in a single query, which can cause
  performance issues. The associations supported are:

    * `emails`: confirmed and unconfirmed `emails` on a user
    * `regions`: `region_assignments` and `regions` on a user

  """
  @spec preload_assoc(query, [atom] | nil) :: query
  def preload_assoc(query, associations)
  def preload_assoc(query, nil), do: query
  def preload_assoc(query, []), do: query

  def preload_assoc(query, [:emails | rest]) do
    query
    |> join_emails_from_user()
    |> preload([emails: e], emails: e)
    |> preload_assoc(rest)
  end

  def preload_assoc(query, [:leagues | rest]) do
    query
    |> join_leagues_from_user()
    |> preload([league_assignments: la, leagues: r],
      league_assignments: {la, league: r},
      leagues: r
    )
    |> preload_assoc(rest)
  end

  def preload_assoc(query, [:regions | rest]) do
    query
    |> join_regions_from_user()
    |> preload([region_assignments: ra, regions: r],
      region_assignments: {ra, region: r},
      regions: r
    )
    |> preload_assoc(rest)
  end

  def preload_assoc(query, [:teams | rest]) do
    query
    |> join_teams_from_user()
    |> preload([team_assignments: ta, teams: t],
      team_assignments: {ta, team: t},
      teams: t
    )
    |> preload_assoc(rest)
  end
end
