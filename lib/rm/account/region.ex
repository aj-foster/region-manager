defmodule RM.Account.Region do
  use Ecto.Schema

  alias RM.Account.User
  alias RM.FIRST.Region

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "user_regions" do
    belongs_to :region, Region
    belongs_to :user, User

    timestamps type: :utc_datetime_usec
  end
end
