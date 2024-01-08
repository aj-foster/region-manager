defmodule RM.Account.User do
  use Ecto.Schema
  import Identity.Schema

  alias RM.Account

  @typedoc "User record"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          region_assignments: Ecto.Schema.has_many(Account.Region.t()),
          regions: Ecto.Schema.has_many(RM.FIRST.Region.t())
        }

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    user_associations()

    has_many :region_assignments, Account.Region
    has_many :regions, through: [:region_assignments, :region]

    has_many :team_assignments, Account.Team
    has_many :teams, through: [:team_assignments, :team]
  end
end
