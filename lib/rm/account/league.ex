defmodule RM.Account.League do
  use Ecto.Schema
  import Ecto.Query

  alias Ecto.Changeset
  alias RM.Account.User
  alias RM.Local.League

  @typedoc "Association record between users and leagues"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          league: Ecto.Schema.belongs_to(League.t()),
          league_id: Ecto.UUID.t(),
          permissions: %__MODULE__.Permissions{},
          updated_at: DateTime.t(),
          user: Ecto.Schema.belongs_to(User.t()),
          user_id: Ecto.UUID.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_leagues" do
    field :email, :string
    timestamps type: :utc_datetime_usec

    belongs_to :league, League
    belongs_to :user, User

    embeds_one :permissions, Permissions, on_replace: :update, primary_key: false do
      field :contact, :boolean, default: false
      field :events, :boolean, default: false
      field :users, :boolean, default: false
    end
  end

  #
  # Changesets
  #

  @doc """
  Changeset for creating a new user-league assignment
  """
  @spec create_changeset(League.t(), map) :: Changeset.t(t)
  def create_changeset(league, params) do
    %__MODULE__{}
    |> Changeset.cast(params, [:email])
    |> Changeset.cast_embed(:permissions, with: &permissions_changeset/2)
    |> Changeset.put_assoc(:league, league)
    |> Changeset.validate_required([:email])
  end

  @spec permissions_changeset(%__MODULE__.Permissions{}, map) ::
          Changeset.t(%__MODULE__.Permissions{})
  defp permissions_changeset(permissions, params) do
    permissions
    |> Changeset.cast(params, [:contact, :events, :users])
    |> cascade_permissions()
  end

  @spec cascade_permissions(Changeset.t(%__MODULE__.Permissions{})) ::
          Changeset.t(%__MODULE__.Permissions{})
  defp cascade_permissions(changeset) do
    if Changeset.get_field(changeset, :users) do
      changeset
      |> Changeset.put_change(:contact, true)
      |> Changeset.put_change(:events, true)
    else
      changeset
    end
  end

  #
  # Queries
  #

  @doc """
  Create a query to update the `user_id` fields of league assignments with the given email address

  The resulting query should be passed to `RM.Repo.update_all/3`.
  """
  @spec user_update_by_email_query(String.t()) :: Ecto.Query.t()
  def user_update_by_email_query(email) do
    from(__MODULE__, as: :user_league)
    |> where([user_league: ul], ul.email == ^email)
    |> join(:inner, [user_league: ul], e in Identity.Schema.Email,
      on: e.email == ul.email and not is_nil(e.confirmed_at),
      as: :email
    )
    |> update([user_league: ul, email: e], set: [user_id: e.user_id])
  end

  #
  # Protocols
  #

  @doc false
  def compare(%__MODULE__{user: %User{} = a}, %__MODULE__{user: %User{} = b}) do
    User.compare(a, b)
  end

  def compare(a, b) do
    cond do
      a.inserted_at < b.inserted_at -> :lt
      a.inserted_at > b.inserted_at -> :gt
      :else -> :eq
    end
  end
end
