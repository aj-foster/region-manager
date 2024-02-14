defmodule RM.FIRST.League do
  use Ecto.Schema
  import Ecto.Query

  alias RM.FIRST.LeagueAssignment
  alias RM.FIRST.Region
  alias RM.Local.LeagueSettings
  alias RM.Local.Team

  @type t :: %__MODULE__{
          code: String.t(),
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          location: String.t() | nil,
          name: String.t(),
          parent_league: Ecto.Schema.belongs_to(t | nil),
          parent_league_id: Ecto.UUID.t() | nil,
          region: Ecto.Schema.belongs_to(Region.t()),
          region_id: Ecto.UUID.t(),
          remote: boolean,
          settings: Ecto.Schema.has_one(LeagueSettings.t()),
          team_assignments: Ecto.Schema.has_many(LeagueAssignment.t()),
          teams: Ecto.Schema.has_many(Team.t()),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "first_leagues" do
    field :code, :string
    field :location, :string
    field :name, :string
    field :remote, :boolean

    belongs_to :parent_league, __MODULE__, type: :binary_id
    belongs_to :region, Region, type: :binary_id
    has_one :settings, LeagueSettings

    has_many :team_assignments, LeagueAssignment
    has_many :teams, through: [:team_assignments, :team]

    embeds_one :stats, Stats, on_replace: :delete, primary_key: false do
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
        region_id_map,
        league_id_map \\ %{}
      ) do
    now = DateTime.utc_now()

    %{
      code: code,
      inserted_at: now,
      location: location,
      name: name,
      parent_league_id: league_id_map[parent_league_code],
      region_id: region_id_map[region_code],
      remote: remote,
      updated_at: now
    }
  end

  def id_by_code_query do
    from(__MODULE__, as: :league)
    |> select([league: l], {l.code, l.id})
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

  defimpl Phoenix.Param do
    def to_param(%RM.FIRST.League{code: code}) do
      String.downcase(code)
    end
  end
end
