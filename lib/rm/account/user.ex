defmodule RM.Account.User do
  use Ecto.Schema
  import Identity.Schema

  alias RM.Account

  @typedoc "User record"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          league_assignments: Ecto.Schema.has_many(Account.League.t()),
          leagues: Ecto.Schema.has_many(RM.FIRST.League.t()),
          region_assignments: Ecto.Schema.has_many(Account.Region.t()),
          regions: Ecto.Schema.has_many(RM.FIRST.Region.t()),
          team_assignments: Ecto.Schema.has_many(Account.Team.t()),
          teams: Ecto.Schema.has_many(RM.Local.Team.t())
        }

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    user_associations()

    has_many :league_assignments, Account.League
    has_many :leagues, through: [:league_assignments, :league]

    has_many :region_assignments, Account.Region
    has_many :regions, through: [:region_assignments, :region]

    has_many :team_assignments, Account.Team
    has_many :teams, through: [:team_assignments, :team]
  end

  #
  # Protocols
  #

  defimpl String.Chars do
    def to_string(%RM.Account.User{id: id}) do
      id
    end
  end

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%RM.Account.User{id: id}) do
      id
    end
  end
end
