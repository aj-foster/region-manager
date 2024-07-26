defmodule RM.Local.League do
  @moduledoc """
  Season-independent league information

  While `RM.FIRST.League` mirrors the data available from the FTC Events API for a particular
  season, this data persists season-to-season. Maintaining both sets of data allows Region Manager
  to inform region administrators what data is missing from FIRST at the beginning of the season
  (when all league data must be re-entered in the FTC Cloud Scoring system).
  """
  use Ecto.Schema

  alias RM.Local.EventProposal
  alias RM.Local.LeagueSettings
  alias RM.Local.Log
  alias RM.Local.Venue

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "leagues" do
    field :code, :string
    field :current_season, :integer
    field :location, :string
    field :name, :string
    field :remote, :boolean
    field :removed_at, :utc_datetime_usec

    belongs_to :parent_league, __MODULE__, type: :binary_id
    belongs_to :region, RM.FIRST.Region, type: :binary_id
    has_one :settings, LeagueSettings

    has_many :events, RM.FIRST.Event
    has_many :event_proposals, EventProposal
    has_many :team_assignments, RM.FIRST.LeagueAssignment
    has_many :teams, through: [:team_assignments, :team]
    has_many :user_assignments, RM.Account.League
    has_many :users, through: [:user_assignments, :user]
    has_many :venues, Venue

    embeds_one :stats, Stats, on_replace: :delete, primary_key: false do
      field :event_count, :integer, default: 0
      field :league_count, :integer, default: 0
      field :team_count, :integer, default: 0
    end

    embeds_many :log, Log
    timestamps type: :utc_datetime_usec
  end
end
