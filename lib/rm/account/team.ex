defmodule RM.Account.Team do
  use Ecto.Schema

  alias RM.Account.User
  alias RM.Local.Team

  @typedoc "Supported relationships between users and teams"
  @type relationship :: :admin | :lc1 | :lc2
  @relationships [:admin, :lc1, :lc2]

  @typedoc "Association record between users and teams (ex. coaches)"
  @type t :: %__MODULE__{}

  schema "user_teams" do
    field :email, :string
    field :relationship, Ecto.Enum, values: @relationships
    timestamps type: :utc_datetime_usec

    belongs_to :team, Team
    belongs_to :user, User

    embeds_one :notices, Notices do
      field :agree_to_ypp, :boolean
      field :start_ypp, :boolean
    end
  end
end
