defmodule RM.Local.League do
  @moduledoc """
  Season-independent league information

  While `RM.FIRST.League` mirrors the data available from the FTC Events API for a particular
  season, this data persists season-to-season. Maintaining both sets of data allows Region Manager
  to inform region administrators what data is missing from FIRST at the beginning of the season
  (when all league data must be re-entered in the FTC Cloud Scoring system).
  """
  use Ecto.Schema
  import Ecto.Query

  alias Ecto.Changeset
  alias RM.Local.EventProposal
  alias RM.Local.LeagueAssignment
  alias RM.Local.LeagueSettings
  alias RM.Local.Log
  alias RM.Local.Query
  alias RM.Local.Venue

  @type t :: %__MODULE__{}

  @required_fields [:code, :current_season, :location, :name, :remote]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "leagues" do
    field :code, :string
    field :current_season, :integer, autogenerate: {RM.System, :current_season, []}
    field :location, :string
    field :name, :string
    field :remote, :boolean
    field :removed_at, :utc_datetime_usec

    belongs_to :parent_league, __MODULE__
    belongs_to :region, RM.FIRST.Region
    has_one :settings, LeagueSettings
    has_one :first_league, RM.FIRST.League, foreign_key: :local_league_id

    has_many :events, RM.FIRST.Event, foreign_key: :local_league_id
    has_many :event_proposals, EventProposal
    has_many :team_assignments, LeagueAssignment
    has_many :teams, through: [:team_assignments, :team]
    has_many :user_assignments, RM.Account.League
    has_many :users, through: [:user_assignments, :user]
    has_many :venues, Venue

    embeds_one :stats, Stats, on_replace: :update, primary_key: false do
      field :event_count, :integer, default: 0
      field :events_imported_at, :utc_datetime_usec
      field :league_count, :integer, default: 0
      field :team_count, :integer, default: 0
    end

    embeds_many :log, Log
    timestamps type: :utc_datetime_usec
  end

  #
  # Changesets
  #

  @doc """
  Create a changeset for editing league details
  """
  @spec update_changeset(t, map) :: Changeset.t(t)
  def update_changeset(league, params) do
    league
    |> Changeset.cast(params, [:code, :location, :name, :remote])
    |> Changeset.validate_required(@required_fields)
    |> Changeset.unique_constraint([:code, :region_id])
  end

  @doc """
  Create a new local representation of a league from FIRST's representation

  This is useful when creating local data for the first time.
  """
  @spec from_first_league(RM.FIRST.League.t()) :: map
  def from_first_league(
        %RM.FIRST.League{
          code: code,
          location: location,
          name: name,
          parent_league_id: parent_league_id,
          region: region,
          remote: remote,
          season: season
        },
        league_id_map \\ %{}
      ) do
    now = DateTime.utc_now()

    %{
      code: code,
      current_season: season,
      inserted_at: now,
      location: location,
      log: [Log.new("copied", %{})],
      name: shorten_name(name, region),
      parent_league_id: league_id_map[parent_league_id],
      remote: remote,
      region_id: region.id,
      updated_at: now
    }
  end

  #
  # Queries
  #

  @doc """
  Query to construct a map of leagues keyed by their region and league codes
  """
  @spec by_code_query :: Ecto.Query.t()
  def by_code_query do
    Query.from_league()
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
      |> join(:inner, [league: l], r in assoc(l, :region), as: :region)
      |> join(:left, [league: l, region: r], e in assoc(l, :events),
        on: e.season == r.current_season and is_nil(e.removed_at),
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

  ## Options

    * `import`: When `true`, update the `teams_imported_at` timestamp to the current time.
      Defaults to `false`.

  """
  @spec team_stats_update_query([Ecto.UUID.t()]) :: Ecto.Query.t()
  @spec team_stats_update_query([Ecto.UUID.t()], keyword) :: Ecto.Query.t()
  def team_stats_update_query(league_ids, opts \\ []) do
    count_query =
      from(__MODULE__, as: :league)
      |> where([league: l], l.id in ^league_ids)
      |> join(:left, [league: l], t in assoc(l, :teams), on: t.active, as: :team)
      |> group_by([league: l], l.id)
      |> select([league: l, team: t], %{id: l.id, count: count(t.id)})

    if opts[:import] do
      team_stats_update_count_and_time(count_query)
    else
      team_status_update_count_only(count_query)
    end
  end

  @spec team_stats_update_count_and_time(Ecto.Query.t()) :: Ecto.Query.t()
  defp team_stats_update_count_and_time(count_query) do
    now = DateTime.utc_now()

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

  @spec team_status_update_count_only(Ecto.Query.t()) :: Ecto.Query.t()
  defp team_status_update_count_only(count_query) do
    from(__MODULE__, as: :league)
    |> join(:inner, [league: l], s in subquery(count_query), on: s.id == l.id, as: :counts)
    |> update([league: l, counts: c],
      set: [
        stats:
          fragment(
            "jsonb_set(?, '{team_count}', ?::varchar::jsonb)",
            l.stats,
            c.count
          )
      ]
    )
  end

  #
  # Helpers
  #

  @doc """
  Report differences between the FIRST record for the current season and this league's saved data
  """
  @spec compare_with_first(t) :: :unpublished | :match | {:different, [atom]}
  def compare_with_first(%__MODULE__{first_league: nil}), do: :unpublished

  def compare_with_first(league) do
    %RM.Local.League{
      code: code,
      name: name,
      location: location,
      region: region,
      remote: remote,
      first_league: %RM.FIRST.League{
        code: first_code,
        name: first_name,
        location: first_location,
        remote: first_remote
      }
    } = league

    differences =
      Enum.reject(
        [
          unless(code == first_code, do: :code),
          unless(name == shorten_name(first_name, region), do: :name),
          unless(location == first_location, do: :location),
          unless(remote == first_remote, do: :remote)
        ],
        &is_nil/1
      )

    if differences == [] do
      :match
    else
      {:different, differences}
    end
  end

  @doc """
  Report whether the FIRST record for the current season matches this league's saved data
  """
  @spec matches_public_data?(t) :: boolean
  def matches_public_data?(league) do
    case compare_with_first(league) do
      :unpublished -> false
      :match -> true
      {:different, _} -> false
    end
  end

  @doc "Removes region name or code from beginning, and `\"League\"` from the end"
  @spec shorten_name(String.t(), RM.FIRST.Region.t() | nil) :: String.t()
  def shorten_name(league_name, nil) do
    league_name
    |> String.replace(~r/\s+league\s*$/i, "")
  end

  def shorten_name(league_name, %RM.FIRST.Region{code: region_code, name: region_name}) do
    league_name
    |> String.replace(~r/^\s*(#{region_code}|#{region_name})\s+/i, "")
    |> String.replace(~r/\s+league\s*$/i, "")
  end

  #
  # Protocols
  #

  defimpl Phoenix.Param do
    def to_param(%RM.Local.League{code: code}) do
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
