defmodule RM.Account.Profile do
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.Account.User

  @typedoc "User profile"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          user: Ecto.Schema.belongs_to(User.t()),
          user_id: Ecto.UUID.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_profiles" do
    field :name, :string

    embeds_one :metadata, Metadata, on_replace: :update, primary_key: false do
    end

    embeds_one :settings, Settings, on_replace: :update, primary_key: false do
    end

    belongs_to :user, User

    timestamps type: :utc_datetime_usec
  end

  #
  # Changesets
  #

  @spec create_changeset(map, User.t()) :: Ecto.Changeset.t(t)
  def create_changeset(params, user) do
    %__MODULE__{}
    |> Changeset.cast(params, [:name])
    |> Changeset.put_assoc(:user, user)
    |> Changeset.validate_required([:name])
  end
end
