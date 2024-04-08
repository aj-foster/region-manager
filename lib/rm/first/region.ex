defmodule RM.FIRST.Region do
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
    field :description, :string
    field :has_leagues, :boolean, default: false
    field :name, :string
    timestamps type: :utc_datetime_usec

    has_many :events, Event
    has_many :leagues, League
    has_many :teams, Team

    embeds_one :stats, Stats, on_replace: :delete, primary_key: false do
      field :event_count, :integer, default: 0
      field :events_imported_at, :utc_datetime_usec
      field :league_count, :integer, default: 0
      field :leagues_imported_at, :utc_datetime_usec
      field :team_count, :integer, default: 0
      field :teams_imported_at, :utc_datetime_usec
    end
  end

  #
  # Queries
  #

  def id_by_code_query do
    from(__MODULE__, as: :region)
    |> select([region: r], {r.code, r.id})
  end

  @doc """
  Query to update cached event statistics for regions with the given IDs
  """
  @spec event_stats_update_query([Ecto.UUID.t()]) :: Ecto.Query.t()
  def event_stats_update_query(region_ids) do
    now = DateTime.utc_now()

    count_query =
      from(__MODULE__, as: :region)
      |> where([region: r], r.id in ^region_ids)
      |> join(:left, [region: r], e in assoc(r, :events), as: :event)
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
    now = DateTime.utc_now()

    count_query =
      from(__MODULE__, as: :region)
      |> where([region: r], r.id in ^region_ids)
      |> join(:left, [region: r], l in assoc(r, :leagues), as: :league)
      |> group_by([region: r], r.id)
      |> select([region: r, league: l], %{id: r.id, count: count(l.id)})

    from(__MODULE__, as: :region)
    |> join(:inner, [region: r], s in subquery(count_query), on: s.id == r.id, as: :counts)
    |> update([region: r, counts: c],
      set: [
        stats:
          fragment(
            "jsonb_set(jsonb_set(?, '{league_count}', ?::varchar::jsonb), '{leagues_imported_at}', ?)",
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
      |> join(:left, [region: r], t in assoc(r, :teams), as: :team)
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
