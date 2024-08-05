defmodule RM.Local.League do
  @moduledoc """
  Season-independent league information

  While `RM.FIRST.League` mirrors the data available from the FTC Events API for a particular
  season, this data persists season-to-season. Maintaining both sets of data allows Region Manager
  to inform region administrators what data is missing from FIRST at the beginning of the season
  (when all league data must be re-entered in the FTC Cloud Scoring system).
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.Local.EventProposal
  alias RM.Local.LeagueAssignment
  alias RM.Local.LeagueSettings
  alias RM.Local.Log
  alias RM.Local.Venue

  @type t :: %__MODULE__{}

  @required_fields [:code, :current_season, :location, :name, :remote]

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "leagues" do
    field :code, :string
    field :current_season, :integer, autogenerate: {RM.Config, :get, ["current_season"]}
    field :location, :string
    field :name, :string
    field :remote, :boolean
    field :removed_at, :utc_datetime_usec

    belongs_to :parent_league, __MODULE__, type: :binary_id
    belongs_to :region, RM.FIRST.Region, type: :binary_id
    has_one :settings, LeagueSettings

    has_many :events, RM.FIRST.Event
    has_many :event_proposals, EventProposal
    has_many :team_assignments, LeagueAssignment
    has_many :teams, through: [:team_assignments, :team]
    has_many :user_assignments, RM.Account.League
    has_many :users, through: [:user_assignments, :user]
    has_many :venues, Venue

    embeds_one :stats, Stats, on_replace: :update, primary_key: false do
      field :event_count, :integer, default: 0
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

  @spec shorten_name(String.t(), RM.FIRST.Region.t() | nil) :: String.t()
  defp shorten_name(league_name, nil) do
    league_name
    |> String.replace(~r/\s+league\s*$/i, "")
  end

  defp shorten_name(league_name, %RM.FIRST.Region{code: region_code, name: region_name}) do
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
