defmodule RM.Account.User do
  use Ecto.Schema
  import Identity.Schema

  alias RM.Account

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    user_associations()

    has_many :region_assignments, Account.Region
    has_many :regions, through: [:region_assignments, :region]
  end
end
