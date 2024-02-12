defmodule RM.FIRST.LeagueAssignment do
  use Ecto.Schema

  alias RM.FIRST.League
  alias RM.Local.Team

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "first_league_assignments" do
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
