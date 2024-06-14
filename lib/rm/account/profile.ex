defmodule RM.Account.Profile do
  use Ecto.Schema

  alias RM.Account.User

  @typedoc "User profile"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          user: Ecto.Schema.belongs_to(User.t()),
          user_id: Ecto.UUID.t()
        }

  schema "user_profiles" do
    field :name, :string

    embeds_one :metadata, Metadata, on_replace: :update, primary_key: false do
    end

    embeds_one :settings, Settings, on_replace: :update, primary_key: false do
    end

    belongs_to :user, User

    timestamps type: :utc_datetime_usec
  end
end
