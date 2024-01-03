defmodule RM.Account.Region do
  use Ecto.Schema

  alias RM.Account.User
  alias RM.FIRST.Region

  @typedoc "Association record between users and regions"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          region: Ecto.Schema.belongs_to(Region.t()),
          region_id: Ecto.UUID.t(),
          updated_at: DateTime.t(),
          user: Ecto.Schema.belongs_to(User.t()),
          user_id: Ecto.UUID.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_regions" do
    belongs_to :region, Region
    belongs_to :user, User

    timestamps type: :utc_datetime_usec
  end
end
