defmodule RM.FIRST.Query do
  @moduledoc """
  Query helpers for schemas in the FIRST namespace
  """
  import Ecto.Query

  alias RM.FIRST.Event
  alias RM.FIRST.League
  alias RM.FIRST.LeagueAssignment
  alias RM.FIRST.Region
  alias RM.FIRST.Season

  @typedoc "Intermediate query"
  @type query :: Ecto.Query.t()

  #
  # Base
  #

  @doc "Start a query from the events table"
  @spec from_event :: query
  def from_event do
    from(Event, as: :event)
  end

  @doc "Start a query from the leagues table"
  @spec from_league :: query
  def from_league do
    from(League, as: :league)
  end

  @doc "Start a query from the league assignments table"
  @spec from_league_assignment :: query
  def from_league_assignment do
    from(LeagueAssignment, as: :league_assignment)
  end

  @doc "Start a query from the regions table"
  @spec from_region :: query
  def from_region do
    from(Region, as: :region)
  end

  @doc "Start a query from the seasons table"
  @spec from_season :: query
  def from_season do
    from(Season, as: :season)
  end

  #
  # Filters
  #

  @doc "Find assignments related to the given league"
  @spec assignment_league(query, League.t()) :: query
  def assignment_league(query, %League{id: league_id}) do
    where(query, [league_assignment: a], a.league_id == ^league_id)
  end

  @doc "Find the event with the given code"
  @spec event_code(query, String.t()) :: query
  def event_code(query, code) do
    where(query, [event: e], e.code == ^code)
  end

  @doc "Find events related to the given region(s)"
  @spec event_region(query, Region.t()) :: query
  @spec event_region(query, [Region.t()]) :: query
  def event_region(query, %Region{id: region_id}) do
    where(query, [event: e], e.region_id == ^region_id)
  end

  def event_region(query, regions) when is_list(regions) do
    region_ids = Enum.map(regions, & &1.id)
    where(query, [event: e], e.region_id in ^region_ids)
  end

  @doc "Filter events by the season"
  @spec event_season(query, integer | nil) :: query
  def event_season(query, nil), do: query
  def event_season(query, season), do: where(query, [event: e], e.season == ^season)

  @doc "Find the league with the given code"
  @spec league_code(query, String.t()) :: query
  def league_code(query, code) do
    where(query, [league: l], l.code == ^code)
  end

  @doc "Find leagues related to the given region(s)"
  @spec league_region(query, Region.t()) :: query
  @spec league_region(query, [Region.t()]) :: query
  def league_region(query, %Region{id: region_id}) do
    where(query, [league: l], l.region_id == ^region_id)
  end

  def league_region(query, regions) when is_list(regions) do
    region_ids = Enum.map(regions, & &1.id)
    where(query, [league: l], l.region_id in ^region_ids)
  end

  @doc "Filter leagues by the season"
  @spec league_season(query, integer | nil) :: query
  def league_season(query, nil), do: query
  def league_season(query, season), do: where(query, [league: l], l.season == ^season)

  @doc "Find the region with a given abbreviation or code"
  @spec region_abbreviation(query, String.t()) :: query
  def region_abbreviation(query, abbreviation) do
    where(query, [region: r], r.abbreviation == ^abbreviation or r.code == ^abbreviation)
  end

  #
  # Joins
  #

  @doc "Load the `events` association on a league"
  @spec join_events_from_league(query) :: query
  def join_events_from_league(query) do
    with_named_binding(query, :events, fn query, binding ->
      join(query, :left, [league: l], e in assoc(l, :events), as: ^binding)
    end)
  end

  @doc "Load the `league` association on an event"
  @spec join_league_from_event(query) :: query
  def join_league_from_event(query) do
    with_named_binding(query, :league, fn query, binding ->
      join(query, :left, [event: e], l in assoc(e, :league), as: ^binding)
    end)
  end

  @doc "Load the `leagues` association on a region"
  @spec join_leagues_from_region(query) :: query
  def join_leagues_from_region(query) do
    with_named_binding(query, :leagues, fn query, binding ->
      join(query, :left, [region: r], l in assoc(r, :leagues), as: ^binding)
    end)
  end

  @doc "Load the `proposal` association on an event"
  @spec join_proposal_from_event(query) :: query
  def join_proposal_from_event(query) do
    with_named_binding(query, :proposal, fn query, binding ->
      join(query, :left, [event: e], p in assoc(e, :proposal), as: ^binding)
    end)
  end

  @doc "Load the `region` association on an event"
  @spec join_region_from_event(query) :: query
  def join_region_from_event(query) do
    with_named_binding(query, :region, fn query, binding ->
      join(query, :left, [event: e], r in assoc(e, :region), as: ^binding)
    end)
  end

  @doc "Load the `region` association on a league"
  @spec join_region_from_league(query) :: query
  def join_region_from_league(query) do
    with_named_binding(query, :region, fn query, binding ->
      join(query, :left, [league: l], r in assoc(l, :region), as: ^binding)
    end)
  end

  @doc "Load the `settings` association on an event"
  @spec join_settings_from_event(query) :: query
  def join_settings_from_event(query) do
    with_named_binding(query, :settings, fn query, binding ->
      join(query, :left, [event: e], s in assoc(e, :settings), as: ^binding)
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

  @doc "Load the `teams` association on a region"
  @spec join_teams_from_region(query) :: query
  def join_teams_from_region(query) do
    with_named_binding(query, :teams, fn query, binding ->
      join(query, :left, [region: r], t in assoc(r, :teams), as: ^binding)
    end)
  end

  @doc "Load the `venue` association on an event's proposal"
  @spec join_venue_from_event(query) :: query
  def join_venue_from_event(query) do
    query
    |> join_proposal_from_event()
    |> with_named_binding(:venue, fn query, binding ->
      join(query, :left, [proposal: p], v in assoc(p, :venue), as: ^binding)
    end)
  end

  #
  # Preloads
  #

  @doc """
  Preload data in a single query

  Data preloaded with this function will be joined and loaded in a single query, which can cause
  performance issues. The associations supported are:

  With `:event` as the base:

    * `league`: `league` associated with an event
    * `proposal`: `proposal` associated with an event
    * `region`: `region` associated with an event
    * `venue`: `venue` associated with an event's `proposal`

  With `:region` as the base:

    * `active_teams`: `teams` on a region with `active` set to `true`
    * `leagues`: `leagues` on a region
    * `teams`: `teams` on a region

  With `:league` as the base:

    * `teams`: `teams` assigned to a league

  """
  @spec preload_assoc(query, atom, [atom] | nil) :: query
  def preload_assoc(query, base, associations)
  def preload_assoc(query, _base, nil), do: query
  def preload_assoc(query, _base, []), do: query

  # Event

  def preload_assoc(query, :event, [:league | rest]) do
    query
    |> join_league_from_event()
    |> preload([league: l], league: l)
    |> preload_assoc(:event, rest)
  end

  def preload_assoc(query, :event, [:proposal | rest]) do
    query
    |> join_proposal_from_event()
    |> preload([proposal: p], proposal: p)
    |> preload_assoc(:event, rest)
  end

  def preload_assoc(query, :event, [:region | rest]) do
    query
    |> join_region_from_event()
    |> preload([region: r], region: r)
    |> preload_assoc(:event, rest)
  end

  def preload_assoc(query, :event, [:settings | rest]) do
    query
    |> join_settings_from_event()
    |> preload([settings: s], settings: s)
    |> preload_assoc(:event, rest)
  end

  def preload_assoc(query, :event, [:venue | rest]) do
    query
    |> join_proposal_from_event()
    |> join_venue_from_event()
    |> preload([proposal: p, venue: v], proposal: {p, venue: v})
    |> preload_assoc(:event, rest)
  end

  # Regions

  def preload_assoc(query, :region, [:active_teams | rest]) do
    query
    |> join_teams_from_region()
    |> where([teams: t], t.active)
    |> preload([teams: t], teams: t)
    |> preload_assoc(:region, rest)
  end

  def preload_assoc(query, :region, [:leagues | rest]) do
    query
    |> join_leagues_from_region()
    |> preload([leagues: l], leagues: l)
    |> preload_assoc(:region, rest)
  end

  def preload_assoc(query, :region, [:teams | rest]) do
    query
    |> join_teams_from_region()
    |> preload([teams: t], teams: t)
    |> preload_assoc(:region, rest)
  end

  # Leagues

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
end
