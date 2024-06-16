defmodule RM.Account.League do
  use Ecto.Schema

  alias RM.Account.User
  alias RM.FIRST.League

  @typedoc "Association record between users and leagues"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          league: Ecto.Schema.belongs_to(League.t()),
          league_id: Ecto.UUID.t(),
          permissions: %__MODULE__.Permission{},
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

    embeds_one :permissions, Permission, on_replace: :update, primary_key: false do
    end
  end
end
