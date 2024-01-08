defmodule RM.Account.Team do
  use Ecto.Schema
  import Ecto.Query

  alias RM.Account.User
  alias RM.Local.Team

  @typedoc "Supported relationships between users and teams"
  @type relationship :: :admin | :lc1 | :lc2
  @relationships [:admin, :lc1, :lc2]

  @typedoc "Association record between users and teams (ex. coaches)"
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_teams" do
    field :email, :string
    field :relationship, Ecto.Enum, values: @relationships
    timestamps type: :utc_datetime_usec

    belongs_to :team, Team
    belongs_to :user, User

    embeds_one :notices, Notices, on_replace: :delete, primary_key: false do
      field :agree_to_ypp, :boolean
      field :start_ypp, :boolean
    end
  end

  @spec from_import(RM.Import.Team.t(), %{integer => Ecto.UUID.t()}) :: [%__MODULE__{}]
  def from_import(import_team, team_id_map) do
    %RM.Import.Team{
      team_id: team_id,
      data: %RM.Import.Team.Data{
        lc1_email: lc1_email,
        lc1_ypp: lc1_ypp,
        lc1_ypp_reason: lc1_ypp_reason,
        lc2_email: lc2_email,
        lc2_ypp: lc2_ypp,
        lc2_ypp_reason: lc2_ypp_reason
      }
    } = import_team

    now = DateTime.utc_now()

    [
      %__MODULE__{
        email: lc1_email,
        inserted_at: now,
        notices: %__MODULE__.Notices{
          agree_to_ypp: not lc1_ypp and lc1_ypp_reason =~ "not yet agreed",
          start_ypp: not lc1_ypp and lc1_ypp_reason =~ "needs to log into"
        },
        relationship: :lc1,
        team_id: Map.fetch!(team_id_map, team_id),
        updated_at: now,
        user_id: nil
      },
      %__MODULE__{
        email: lc2_email,
        inserted_at: now,
        notices: %__MODULE__.Notices{
          agree_to_ypp: not lc2_ypp and lc2_ypp_reason =~ "not yet agreed",
          start_ypp: not lc2_ypp and lc2_ypp_reason =~ "needs to log into"
        },
        relationship: :lc2,
        team_id: Map.fetch!(team_id_map, team_id),
        updated_at: now,
        user_id: nil
      }
    ]
  end

  @doc """
  Create a query to update the `user_id` fields of team assignments with the given IDs

  The resulting query should be passed to `RM.Repo.update_all/3`.
  """
  @spec user_update_query([Ecto.UUID.t()]) :: Ecto.Query.t()
  def user_update_query(ids) do
    from(__MODULE__, as: :user_team)
    |> where([user_team: ut], ut.id in ^ids)
    |> join(:inner, [user_team: ut], e in Identity.Schema.Email,
      on: e.email == ut.email and not is_nil(e.confirmed_at),
      as: :email
    )
    |> update([user_team: ut, email: e], set: [user_id: e.user_id])
  end
end
