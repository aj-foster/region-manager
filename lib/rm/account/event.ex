defmodule RM.Account.Event do
  use Ecto.Schema
  import Ecto.Query

  alias Ecto.Changeset
  alias RM.Account.User
  alias RM.Local.EventProposal

  @typedoc "Association record between users and event proposals"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          permissions: %__MODULE__.Permissions{},
          proposal: Ecto.Schema.belongs_to(EventProposal.t()),
          proposal_id: Ecto.UUID.t(),
          updated_at: DateTime.t(),
          user: Ecto.Schema.belongs_to(User.t()),
          user_id: Ecto.UUID.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_events" do
    field :email, :string
    timestamps type: :utc_datetime_usec

    belongs_to :proposal, EventProposal
    belongs_to :user, User

    embeds_one :permissions, Permissions, on_replace: :update, primary_key: false do
    end
  end

  #
  # Changesets
  #

  @doc """
  Changeset for creating a new user-event assignment
  """
  @spec create_changeset(EventProposal.t(), map) :: Changeset.t(t)
  def create_changeset(event_proposal, params) do
    %__MODULE__{}
    |> Changeset.cast(params, [:email])
    |> Changeset.cast_embed(:permissions, with: &permissions_changeset/2)
    |> Changeset.put_assoc(:proposal, event_proposal)
    |> Changeset.validate_required([:email])
  end

  @spec permissions_changeset(%__MODULE__.Permissions{}, map) ::
          Changeset.t(%__MODULE__.Permissions{})
  defp permissions_changeset(permissions, params) do
    permissions
    |> Changeset.cast(params, [])
    |> cascade_permissions()
  end

  @spec cascade_permissions(Changeset.t(%__MODULE__.Permissions{})) ::
          Changeset.t(%__MODULE__.Permissions{})
  defp cascade_permissions(changeset) do
    changeset
  end

  #
  # Queries
  #

  @doc """
  Create a query to update the `user_id` fields of event assignments with the given IDs

  The resulting query should be passed to `RM.Repo.update_all/3`.
  """
  @spec user_update_query([Ecto.UUID.t()]) :: Ecto.Query.t()
  def user_update_query(ids) do
    from(__MODULE__, as: :user_event)
    |> where([user_event: ue], ue.id in ^ids)
    |> join(:inner, [user_event: ue], e in Identity.Schema.Email,
      on: e.email == ue.email and not is_nil(e.confirmed_at),
      as: :email
    )
    |> update([user_event: ue, email: e], set: [user_id: e.user_id])
  end

  @doc """
  Create a query to update the `user_id` fields of event assignments with the given email address

  The resulting query should be passed to `RM.Repo.update_all/3`.
  """
  @spec user_update_by_email_query(String.t()) :: Ecto.Query.t()
  def user_update_by_email_query(email) do
    from(__MODULE__, as: :user_event)
    |> where([user_event: ue], ue.email == ^email)
    |> join(:inner, [user_event: ue], e in Identity.Schema.Email,
      on: e.email == ue.email and not is_nil(e.confirmed_at),
      as: :email
    )
    |> update([user_event: ue, email: e], set: [user_id: e.user_id])
  end

  @doc """
  Create a query to remove the `user_id` fields of event assignments with the given email address

  The resulting query should be passed to `RM.Repo.update_all/3`.
  """
  @spec user_remove_by_email_query(String.t()) :: Ecto.Query.t()
  def user_remove_by_email_query(email) do
    from(__MODULE__, as: :user_event)
    |> where([user_event: ue], ue.email == ^email)
    |> update(set: [user_id: nil])
  end

  #
  # Protocols
  #

  @doc false
  def compare(%__MODULE__{user: %User{} = a}, %__MODULE__{user: %User{} = b}) do
    User.compare(a, b)
  end

  def compare(a, b) do
    DateTime.compare(a.inserted_at, b.inserted_at)
  end
end
