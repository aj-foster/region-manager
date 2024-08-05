defmodule RM.Local.Query do
  @moduledoc """
  Query helpers for schemas in the Local namespace
  """
  import Ecto.Query

  alias RM.Local.EventProposal
  alias RM.Local.EventRegistration
  alias RM.Local.League
  alias RM.Local.Team

  @typedoc "Intermediate query"
  @type query :: Ecto.Query.t()

  #
  # Base
  #

  @doc "Start a query from the event proposals table"
  @spec from_proposal :: query
  def from_proposal do
    from(EventProposal, as: :proposal)
  end

  @doc "Start a query from the leagues table"
  @spec from_league :: query
  def from_league do
    from(League, as: :league)
  end

  @doc "Start a query from the event registration table"
  @spec from_registration :: query
  def from_registration do
    from(EventRegistration, as: :registration)
  end

  @doc "Start a query from the teams table"
  @spec from_team :: query
  def from_team do
    from(Team, as: :team)
  end

  #
  # Filters
  #

  @doc "Filter teams by active status"
  @spec active_team(query) :: query
  def active_team(query), do: where(query, [team: t], t.active)

  @doc "Filter by the associated league"
  @spec league(query, League.t() | nil) :: query
  def league(query, nil), do: query

  def league(query, %League{id: league_id}) do
    where(query, [any], any.league_id == ^league_id)
  end

  @doc "Find the league with the given code"
  @spec league_code(query, String.t()) :: query
  def league_code(query, code) do
    where(query, [league: l], l.code == ^code)
  end

  @doc "Find leagues related to the given region(s)"
  @spec league_region(query, RM.FIRST.Region.t()) :: query
  @spec league_region(query, [RM.FIRST.Region.t()]) :: query
  def league_region(query, %RM.FIRST.Region{id: region_id}) do
    where(query, [league: l], l.region_id == ^region_id)
  end

  @doc "Filter event proposals by region"
  @spec proposal_region(query, RM.FIRST.Region.t()) :: query
  def proposal_region(query, region), do: where(query, [proposal: p], p.region_id == ^region.id)

  @doc "Filter event proposals by season"
  @spec proposal_season(query, integer) :: query
  def proposal_season(query, season), do: where(query, [proposal: p], p.season == ^season)

  @doc "Filter by the `rescinded` attribute of a registration"
  @spec rescinded(query, boolean | nil) :: query
  def rescinded(query, nil), do: query
  def rescinded(query, true), do: where(query, [registration: r], r.rescinded)
  def rescinded(query, false), do: where(query, [registration: r], not r.rescinded)

  @doc "Filter by the `waitlisted` attribute of a registration"
  @spec waitlisted(query, boolean | nil) :: query
  def waitlisted(query, nil), do: query
  def waitlisted(query, true), do: where(query, [registration: r], r.waitlisted)
  def waitlisted(query, false), do: where(query, [registration: r], not r.waitlisted)

  #
  # Joins
  #

  @doc "Load the `first_event` association on an event proposal"
  @spec join_event_from_proposal(query) :: query
  def join_event_from_proposal(query) do
    with_named_binding(query, :event, fn query, binding ->
      join(query, :left, [proposal: p], e in assoc(p, :first_event), as: ^binding)
    end)
  end

  @doc "Load the `events` association on a league"
  @spec join_events_from_league(query) :: query
  def join_events_from_league(query) do
    with_named_binding(query, :events, fn query, binding ->
      join(query, :left, [league: l], e in assoc(l, :events), as: ^binding)
    end)
  end

  @doc "Load the `league` association on an event proposal"
  @spec join_league_from_proposal(query) :: query
  def join_league_from_proposal(query) do
    with_named_binding(query, :league, fn query, binding ->
      join(query, :left, [proposal: p], l in assoc(p, :league), as: ^binding)
    end)
  end

  @doc "Load the `venue` association on an event proposal"
  @spec join_venue_from_proposal(query) :: query
  def join_venue_from_proposal(query) do
    with_named_binding(query, :venue, fn query, binding ->
      join(query, :left, [proposal: p], v in assoc(p, :venue), as: ^binding)
    end)
  end

  @doc "Load the `event` association on an event registration"
  @spec join_event_from_registration(query) :: query
  def join_event_from_registration(query) do
    with_named_binding(query, :event, fn query, binding ->
      join(query, :inner, [registration: r], e in assoc(r, :event), as: ^binding)
    end)
  end

  @doc "Load the `team` association on an event registration"
  @spec join_team_from_registration(query) :: query
  def join_team_from_registration(query) do
    with_named_binding(query, :team, fn query, binding ->
      join(query, :inner, [registration: r], t in assoc(r, :team), as: ^binding)
    end)
  end

  @doc "Load the `league_assignment` and `league` associations on a team"
  @spec join_league_from_team(query) :: query
  def join_league_from_team(query) do
    with_named_binding(query, :league, fn query, binding ->
      query
      |> join(:left, [team: t], la in assoc(t, :league_assignment), as: :league_assignment)
      |> join(:left, [league_assignment: la], l in assoc(la, :league), as: ^binding)
    end)
  end

  @doc "Load the `region` association on a league"
  @spec join_region_from_league(query) :: query
  def join_region_from_league(query) do
    with_named_binding(query, :region, fn query, binding ->
      join(query, :left, [league: l], r in assoc(l, :region), as: ^binding)
    end)
  end

  @doc "Load the `league` association on an event proposal"
  @spec join_region_from_proposal(query) :: query
  def join_region_from_proposal(query) do
    with_named_binding(query, :region, fn query, binding ->
      join(query, :left, [proposal: p], r in assoc(p, :region), as: ^binding)
    end)
  end

  @doc "Load the `region` association on a team"
  @spec join_region_from_team(query) :: query
  def join_region_from_team(query) do
    with_named_binding(query, :region, fn query, binding ->
      join(query, :left, [team: t], r in assoc(t, :region), as: ^binding)
    end)
  end

  @doc "Load the `settings` association on a league"
  @spec join_settings_from_league(query) :: query
  def join_settings_from_league(query) do
    with_named_binding(query, :settings, fn query, binding ->
      join(query, :left, [league: l], s in assoc(l, :settings), as: ^binding)
    end)
  end

  @doc "Load the `teams` association on a league"
  @spec join_teams_from_league(query) :: query
  def join_teams_from_league(query) do
    with_named_binding(query, :teams, fn query, binding ->
      join(query, :left, [league: l], t in assoc(l, :teams), as: ^binding)
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

  With `proposal` as the base:

    * `event`: `first_event` on an event proposal
    * `league`: `league` on an event proposal
    * `region`: `region` on an event proposal
    * `venue`: `venue` on an event proposal

  With `registration` as the base:

    * `event`: `event` on an event registration
    * `team`: `team` on an event registration

  With `team` as the base:

    * `league`: `league_assignment` and `league` on a team
    * `region`: `region` on a team
    * `users`: `user_assignments` and `users` on a team

  """
  @spec preload_assoc(query, atom, [atom] | nil) :: query
  def preload_assoc(query, base, associations)
  def preload_assoc(query, _base, nil), do: query
  def preload_assoc(query, _base, []), do: query

  # League

  def preload_assoc(query, :league, [:active_teams | rest]) do
    query
    |> join_teams_from_league()
    |> where([teams: t], t.active)
    |> preload([teams: t], teams: t)
    |> preload_assoc(:league, rest)
  end

  def preload_assoc(query, :league, [:events | rest]) do
    query
    |> join_events_from_league()
    |> preload([events: t], events: t)
    |> preload_assoc(:league, rest)
  end

  def preload_assoc(query, :league, [:region | rest]) do
    query
    |> join_region_from_league()
    |> preload([region: r], region: r)
    |> preload_assoc(:league, rest)
  end

  def preload_assoc(query, :league, [:settings | rest]) do
    query
    |> join_settings_from_league()
    |> preload([settings: s], settings: s)
    |> preload_assoc(:league, rest)
  end

  def preload_assoc(query, :league, [:teams | rest]) do
    query
    |> join_teams_from_league()
    |> preload([teams: t], teams: t)
    |> preload_assoc(:league, rest)
  end

  # Event Proposal

  def preload_assoc(query, :proposal, [:event | rest]) do
    query
    |> join_event_from_proposal()
    |> preload([event: e], first_event: e)
    |> preload_assoc(:proposal, rest)
  end

  def preload_assoc(query, :proposal, [:league | rest]) do
    query
    |> join_league_from_proposal()
    |> preload([league: l], league: l)
    |> preload_assoc(:proposal, rest)
  end

  def preload_assoc(query, :proposal, [:region | rest]) do
    query
    |> join_region_from_proposal()
    |> preload([region: r], region: r)
    |> preload_assoc(:proposal, rest)
  end

  def preload_assoc(query, :proposal, [:venue | rest]) do
    query
    |> join_venue_from_proposal()
    |> preload([venue: v], venue: v)
    |> preload_assoc(:proposal, rest)
  end

  # Registration

  def preload_assoc(query, :registration, [:event | rest]) do
    query
    |> join_event_from_registration()
    |> preload([event: e], event: e)
    |> preload_assoc(:registration, rest)
  end

  def preload_assoc(query, :registration, [:team | rest]) do
    query
    |> join_team_from_registration()
    |> preload([team: t], team: t)
    |> preload_assoc(:registration, rest)
  end

  # Team

  def preload_assoc(query, :team, [:league | rest]) do
    query
    |> join_league_from_team()
    |> preload([league_assignment: la, league: l], league_assignment: {la, league: l}, league: l)
    |> preload_assoc(:team, rest)
  end

  def preload_assoc(query, :team, [:region | rest]) do
    query
    |> join_region_from_team()
    |> preload([region: r], region: r)
    |> preload_assoc(:team, rest)
  end

  def preload_assoc(query, :team, [:users | rest]) do
    query
    |> join_users_from_team()
    |> preload([user_assignments: ua, users: u],
      user_assignments: {ua, user: u},
      users: u
    )
    |> preload_assoc(:team, rest)
  end
end
