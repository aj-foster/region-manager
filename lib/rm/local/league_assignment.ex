defmodule RM.Local.LeagueAssignment do
  @moduledoc """
  Season-independent league assignment for a team
  """
  use Ecto.Schema

  alias RM.Local.League
  alias RM.Local.Team

  @typedoc "League assignment record"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          league: Ecto.Schema.belongs_to(League.t()),
          league_id: Ecto.UUID.t(),
          team: Ecto.Schema.belongs_to(Team.t()),
          team_id: Ecto.UUID.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "league_assignments" do
    belongs_to :league, League
    belongs_to :team, Team
    timestamps type: :utc_datetime_usec
  end

  @spec new(League.t(), Team.t()) :: map
  def new(%League{id: league_id}, %Team{id: team_id}) do
    now = DateTime.utc_now()
    %{inserted_at: now, league_id: league_id, team_id: team_id, updated_at: now}
  end
end
