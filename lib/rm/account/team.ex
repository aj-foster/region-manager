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
    field :name, :string
    field :email, :string
    field :email_alt, :string
    field :phone, :string
    field :phone_alt, :string
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
        lc1_email_alt: lc1_email_alt,
        lc1_name: lc1_name,
        lc1_phone: lc1_phone,
        lc1_phone_alt: lc1_phone_alt,
        lc1_ypp: lc1_ypp,
        lc1_ypp_reason: lc1_ypp_reason,
        lc2_email: lc2_email,
        lc2_email_alt: lc2_email_alt,
        lc2_name: lc2_name,
        lc2_phone: lc2_phone,
        lc2_phone_alt: lc2_phone_alt,
        lc2_ypp: lc2_ypp,
        lc2_ypp_reason: lc2_ypp_reason
      }
    } = import_team

    now = DateTime.utc_now()

    [
      %__MODULE__{
        email: if(lc1_email != "", do: lc1_email),
        email_alt: if(lc1_email_alt != "", do: lc1_email_alt),
        inserted_at: now,
        name: if(lc1_name != "", do: lc1_name),
        notices: %__MODULE__.Notices{
          agree_to_ypp: not lc1_ypp and lc1_ypp_reason =~ "not yet agreed",
          start_ypp: not lc1_ypp and lc1_ypp_reason =~ "needs to log into"
        },
        phone: if(lc1_phone != "", do: lc1_phone),
        phone_alt: if(lc1_phone_alt != "", do: lc1_phone_alt),
        relationship: :lc1,
        team_id: Map.fetch!(team_id_map, team_id),
        updated_at: now,
        user_id: nil
      },
      %__MODULE__{
        email: if(lc2_email != "", do: lc2_email),
        email_alt: if(lc2_email_alt != "", do: lc2_email_alt),
        inserted_at: now,
        name: if(lc2_name != "", do: lc2_name),
        notices: %__MODULE__.Notices{
          agree_to_ypp: not lc2_ypp and lc2_ypp_reason =~ "not yet agreed",
          start_ypp: not lc2_ypp and lc2_ypp_reason =~ "needs to log into"
        },
        phone: if(lc2_phone != "", do: lc2_phone),
        phone_alt: if(lc2_phone_alt != "", do: lc2_phone_alt),
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

  @doc """
  Create a query to update the `user_id` fields of team assignments with the given email address

  The resulting query should be passed to `RM.Repo.update_all/3`.
  """
  @spec user_update_by_email_query(String.t()) :: Ecto.Query.t()
  def user_update_by_email_query(email) do
    from(__MODULE__, as: :user_team)
    |> where([user_team: ut], ut.email == ^email)
    |> join(:inner, [user_team: ut], e in Identity.Schema.Email,
      on: e.email == ut.email and not is_nil(e.confirmed_at),
      as: :email
    )
    |> update([user_team: ut, email: e], set: [user_id: e.user_id])
  end

  @doc """
  Create a query to remove the `user_id` fields of team assignments with the given email address

  The resulting query should be passed to `RM.Repo.update_all/3`.
  """
  @spec user_remove_by_email_query(String.t()) :: Ecto.Query.t()
  def user_remove_by_email_query(email) do
    from(__MODULE__, as: :user_team)
    |> where([user_team: ut], ut.email == ^email)
    |> update(set: [user_id: nil])
  end
end
