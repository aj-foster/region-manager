defmodule RM.FIRST.Region do
  @moduledoc """
  _FIRST_ Tech Challenge region

  Regions often represent North American states/provinces or non-American countries. Because
  regions do not have any endpoints in the FTC Events API, this schema represents both local
  data and how it is represented elsewhere (ex. `code` for the FTC Events API).

  Regions have a "current season" that should propagate to all related queries. Region admins
  must choose when to transition to a new season (usually after any off-season events).

  Most other pieces of data have a local representation that is separate from the FIRST namespace
  representation. Regions do not, because it is expected that they will not change from season
  to season. This may present an issue in the future if, for example, the region's code in the
  FTC Events API changes — getting previous-season data will not be possible once changed. This
  is an acceptable trade-off for now.
  """
  use Ecto.Schema
  import Ecto.Query

  alias RM.FIRST.Event
  alias RM.FIRST.League
  alias RM.Local.Team

  @type t :: %__MODULE__{
          abbreviation: String.t(),
          code: String.t(),
          description: String.t() | nil,
          events: Ecto.Schema.has_many(Event.t()),
          has_leagues: boolean,
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          name: String.t(),
          stats: %__MODULE__.Stats{
            event_count: integer,
            events_imported_at: DateTime.t(),
            league_count: integer,
            leagues_imported_at: DateTime.t(),
            published_league_count: integer,
            team_count: integer,
            teams_imported_at: DateTime.t()
          },
          teams: Ecto.Schema.has_many(Team.t()),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "first_regions" do
    field :abbreviation, :string
    field :code, :string
    field :current_season, :integer, autogenerate: {RM.Config, :get, ["current_season"]}
    field :description, :string
    field :has_leagues, :boolean, default: false
    field :name, :string
    timestamps type: :utc_datetime_usec

    has_many :events, Event
    has_many :first_leagues, League
    has_many :leagues, RM.Local.League
    has_many :teams, Team

    embeds_one :metadata, Metadata, on_replace: :update, primary_key: false do
      # Region's country as it appears in Batch Create spreadsheets for events
      field :code_batch_country, :string

      # Special code for `c:External.FTCEvents.API.list_teams/3`
      # May return more teams than expected (ex. "FL" returns Adventist teams in Florida)
      # May need to become an array of codes for some regions in the future.
      field :code_list_teams, :string

      # Default country for event proposals in this region
      field :default_country, :string

      # Default state/province, if any, for event proposals in this region
      field :default_state_province, :string
    end

    embeds_one :stats, Stats, on_replace: :update, primary_key: false do
      field :event_count, :integer, default: 0
      field :events_imported_at, :utc_datetime_usec
      field :league_count, :integer, default: 0
      field :leagues_imported_at, :utc_datetime_usec
      field :published_league_count, :integer, default: 0
      field :team_count, :integer, default: 0
      field :teams_imported_at, :utc_datetime_usec
    end
  end

  #
  # Queries
  #

  @doc """
  Get all regions with their code as a key-value tuple
  """
  @spec by_code_query :: Ecto.Query.t()
  def by_code_query do
    from(__MODULE__, as: :region)
    |> select([region: r], {r.code, r})
  end

  @doc """
  Query to update cached event statistics for regions with the given IDs

  Because regions do not have season-specific records, statistics will always be updated based
  on the region's `current_season`.
  """
  @spec event_stats_update_query([Ecto.UUID.t()]) :: Ecto.Query.t()
  def event_stats_update_query(region_ids) do
    now = DateTime.utc_now()

    count_query =
      from(__MODULE__, as: :region)
      |> where([region: r], r.id in ^region_ids)
      |> join(:left, [region: r], e in assoc(r, :events),
        on: e.season == r.current_season and is_nil(e.removed_at),
        as: :event
      )
      |> group_by([region: r], r.id)
      |> select([region: r, event: e], %{id: r.id, count: count(e.id)})

    from(__MODULE__, as: :region)
    |> join(:inner, [region: r], s in subquery(count_query), on: s.id == r.id, as: :counts)
    |> update([region: r, counts: c],
      set: [
        stats:
          fragment(
            "jsonb_set(jsonb_set(?, '{event_count}', ?::varchar::jsonb), '{events_imported_at}', ?)",
            r.stats,
            c.count,
            ^now
          )
      ]
    )
  end

  @doc """
  Query to update cached league statistics for regions with the given IDs
  """
  @spec league_stats_update_query([Ecto.UUID.t()]) :: Ecto.Query.t()
  def league_stats_update_query(region_ids) do
    count_query =
      from(__MODULE__, as: :region)
      |> where([region: r], r.id in ^region_ids)
      |> join(:left, [region: r], l in assoc(r, :leagues),
        on: is_nil(l.removed_at),
        as: :league
      )
      |> group_by([region: r], r.id)
      |> select([region: r, league: l], %{id: r.id, count: count(l.id)})

    from(__MODULE__, as: :region)
    |> join(:inner, [region: r], s in subquery(count_query), on: s.id == r.id, as: :counts)
    |> update([region: r, counts: c],
      set: [
        stats: fragment("jsonb_set(?, '{league_count}', ?::varchar::jsonb)", r.stats, c.count)
      ]
    )
  end

  @doc """
  Query to update cached published league statistics for regions with the given IDs

  Because regions do not have season-specific records, statistics will always be updated based
  on the region's `current_season`.
  """
  @spec published_league_stats_update_query([Ecto.UUID.t()]) :: Ecto.Query.t()
  def published_league_stats_update_query(region_ids) do
    now = DateTime.utc_now()

    count_query =
      from(__MODULE__, as: :region)
      |> where([region: r], r.id in ^region_ids)
      |> join(:left, [region: r], l in assoc(r, :first_leagues),
        on: l.season == r.current_season,
        as: :league
      )
      |> group_by([region: r], r.id)
      |> select([region: r, league: l], %{id: r.id, count: count(l.id)})

    from(__MODULE__, as: :region)
    |> join(:inner, [region: r], s in subquery(count_query), on: s.id == r.id, as: :counts)
    |> update([region: r, counts: c],
      set: [
        stats:
          fragment(
            "jsonb_set(jsonb_set(?, '{published_league_count}', ?::varchar::jsonb), '{leagues_imported_at}', ?)",
            r.stats,
            c.count,
            ^now
          )
      ]
    )
  end

  @doc """
  Query to update cached team statistics for regions with the given IDs
  """
  @spec team_stats_update_query([Ecto.UUID.t()]) :: Ecto.Query.t()
  def team_stats_update_query(region_ids) do
    now = DateTime.utc_now()

    count_query =
      from(__MODULE__, as: :region)
      |> where([region: r], r.id in ^region_ids)
      |> join(:left, [region: r], t in assoc(r, :teams),
        on: t.active and is_nil(t.hidden_at),
        as: :team
      )
      |> group_by([region: r], r.id)
      |> select([region: r, team: t], %{id: r.id, count: count(t.id)})

    from(__MODULE__, as: :region)
    |> join(:inner, [region: r], s in subquery(count_query), on: s.id == r.id, as: :counts)
    |> update([region: r, counts: c],
      set: [
        stats:
          fragment(
            "jsonb_set(jsonb_set(?, '{team_count}', ?::varchar::jsonb), '{teams_imported_at}', ?)",
            r.stats,
            c.count,
            ^now
          )
      ]
    )
  end

  #
  # Protocols
  #

  defimpl Phoenix.Param do
    def to_param(%RM.FIRST.Region{abbreviation: abbreviation}) do
      String.downcase(abbreviation)
    end
  end
end
