defmodule RM.FIRST.League do
  use Ecto.Schema
  import Ecto.Query

  alias RM.FIRST.Event
  alias RM.FIRST.LeagueAssignment
  alias RM.FIRST.Region
  alias RM.FIRST.Query

  alias RM.Local.Team

  @type t :: %__MODULE__{
          code: String.t(),
          events: Ecto.Schema.has_many(Event.t()),
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          location: String.t() | nil,
          name: String.t(),
          parent_league: Ecto.Schema.belongs_to(t | nil),
          parent_league_id: Ecto.UUID.t() | nil,
          region: Ecto.Schema.belongs_to(Region.t()),
          region_id: Ecto.UUID.t(),
          remote: boolean,
          stats: %__MODULE__.Stats{
            event_count: integer,
            league_count: integer,
            team_count: integer
          },
          team_assignments: Ecto.Schema.has_many(LeagueAssignment.t()),
          teams: Ecto.Schema.has_many(Team.t()),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "first_leagues" do
    field :code, :string
    field :location, :string
    field :name, :string
    field :remote, :boolean
    field :season, :integer

    belongs_to :local_league, RM.Local.League
    belongs_to :parent_league, __MODULE__
    belongs_to :region, Region

    has_many :events, Event
    has_many :team_assignments, LeagueAssignment
    has_many :teams, through: [:team_assignments, :team]

    embeds_one :stats, Stats, on_replace: :delete, primary_key: false do
      field :event_count, :integer, default: 0
      field :league_count, :integer, default: 0
      field :team_count, :integer, default: 0
    end

    timestamps type: :utc_datetime_usec
  end

  def from_ftc_events(
        %{
          "code" => code,
          "location" => location,
          "name" => name,
          "parentLeagueCode" => parent_league_code,
          "region" => region_code,
          "remote" => remote
        },
        regions_by_code,
        local_leagues_by_code,
        league_id_map \\ %{}
      ) do
    now = DateTime.utc_now()
    region = regions_by_code[region_code]
    local_league = local_leagues_by_code[{region_code, code}]

    %{
      code: code,
      inserted_at: now,
      local_league_id: local_league && local_league.id,
      location: location,
      name: name,
      parent_league_id: league_id_map[parent_league_code],
      region_id: region && region.id,
      remote: remote || false,
      updated_at: now
    }
  end

  @doc """
  Query to construct a map of leagues keyed by their region and league codes
  """
  @spec by_code_query(integer) :: Ecto.Query.t()
  def by_code_query(season) do
    Query.from_league()
    |> Query.league_season(season)
    |> Query.join_region_from_league()
    |> select([league: l, region: r], {{r.code, l.code}, l})
  end

  @doc """
  Query to update cached event statistics for leagues with the given IDs
  """
  @spec event_stats_update_query([Ecto.UUID.t()]) :: Ecto.Query.t()
  def event_stats_update_query(league_ids) do
    now = DateTime.utc_now()

    count_query =
      from(__MODULE__, as: :league)
      |> where([league: l], l.id in ^league_ids)
      |> join(:left, [league: l], e in assoc(l, :events),
        on: e.season == l.season and is_nil(e.removed_at),
        as: :event
      )
      |> group_by([league: l], l.id)
      |> select([league: l, event: e], %{id: l.id, count: count(e.id)})

    from(__MODULE__, as: :league)
    |> join(:inner, [league: l], s in subquery(count_query), on: s.id == l.id, as: :counts)
    |> update([league: l, counts: c],
      set: [
        stats:
          fragment(
            "jsonb_set(jsonb_set(?, '{event_count}', ?::varchar::jsonb), '{events_imported_at}', ?)",
            l.stats,
            c.count,
            ^now
          )
      ]
    )
  end

  @doc """
  Query to update cached team statistics for leagues with the given IDs
  """
  @spec team_stats_update_query([Ecto.UUID.t()]) :: Ecto.Query.t()
  def team_stats_update_query(league_ids) do
    now = DateTime.utc_now()

    count_query =
      from(__MODULE__, as: :league)
      |> where([league: l], l.id in ^league_ids)
      |> join(:left, [league: l], t in assoc(l, :teams), as: :team)
      |> group_by([league: l], l.id)
      |> select([league: l, team: t], %{id: l.id, count: count(t.id)})

    from(__MODULE__, as: :league)
    |> join(:inner, [league: l], s in subquery(count_query), on: s.id == l.id, as: :counts)
    |> update([league: l, counts: c],
      set: [
        stats:
          fragment(
            "jsonb_set(jsonb_set(?, '{team_count}', ?::varchar::jsonb), '{teams_imported_at}', ?)",
            l.stats,
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
    def to_param(%RM.FIRST.League{code: code}) do
      String.downcase(code)
    end
  end

  @doc false
  def compare(a, b) do
    case {a.name, b.name} do
      {a, b} when a < b -> :lt
      {a, b} when a > b -> :gt
      _else -> :eq
    end
  end
end
