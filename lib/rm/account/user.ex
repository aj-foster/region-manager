defmodule RM.Account.User do
  use Ecto.Schema
  import Identity.Schema

  alias Ecto.Changeset
  alias RM.Account

  @typedoc "User record"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          league_assignments: Ecto.Schema.has_many(Account.League.t()),
          leagues: Ecto.Schema.has_many(RM.Local.League.t()),
          region_assignments: Ecto.Schema.has_many(Account.Region.t()),
          regions: Ecto.Schema.has_many(RM.FIRST.Region.t()),
          team_assignments: Ecto.Schema.has_many(Account.Team.t()),
          teams: Ecto.Schema.has_many(RM.Local.Team.t())
        }

  @type create_data :: %{:email => String.t(), :password => String.t(), :name => String.t()}

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    user_associations()

    has_one :profile, Account.Profile

    has_many :league_assignments, Account.League
    has_many :leagues, through: [:league_assignments, :league]

    has_many :region_assignments, Account.Region
    has_many :regions, through: [:region_assignments, :region]

    has_many :team_assignments, Account.Team
    has_many :teams, through: [:team_assignments, :team]
  end

  #
  # Changesets
  #

  @doc """
  Changeset for inserting a new `Identity.Schema.Email`, `Identity.Schema.BasicLogin`, and
  `RM.Account.Profile` all at once

  See `Identity.Changeset.email_and_password/1` for the original implementation.
  """
  @spec create_changeset(map) :: Ecto.Changeset.t(create_data)
  def create_changeset(attrs \\ %{}) do
    {%{}, %{email: :string, password: :string, name: :string}}
    |> Changeset.cast(attrs, [:email, :password, :name])
    |> Identity.Schema.BasicLogin.validate_password(hash_password: false)
    |> Identity.Schema.Email.validate_email()
  end

  #
  # Protocols
  #

  @doc false
  def compare(%__MODULE__{profile: %Account.Profile{name: a_name}}, %__MODULE__{
        profile: %Account.Profile{name: b_name}
      }) do
    cond do
      a_name < b_name -> :lt
      a_name > b_name -> :gt
      :else -> :eq
    end
  end

  def compare(a, b) do
    cond do
      a.id < b.id -> :lt
      a.id > b.id -> :gt
      :else -> :eq
    end
  end

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
