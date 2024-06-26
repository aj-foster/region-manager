defmodule RM.Local.RegistrationSettings do
  use Ecto.Schema

  alias Ecto.Changeset

  @typedoc "Group of teams that can register for an event"
  @type pool :: :league | :region | :all
  @pools [:league, :region, :all]

  @typedoc "Settings for the registration process of an event"
  @type t :: %__MODULE__{
          enabled: boolean,
          deadline_days: integer,
          pool: pool,
          team_limit: integer | nil,
          waitlist_deadline_days: integer | nil,
          waitlist_limit: integer | nil
        }

  @required_fields [:deadline_days, :enabled, :pool]
  @optional_fields [:team_limit, :waitlist_deadline_days, :waitlist_limit]

  @primary_key false

  embedded_schema do
    field :enabled, :boolean
    field :deadline_days, :integer, default: 7
    field :pool, Ecto.Enum, values: @pools
    field :team_limit, :integer
    field :waitlist_deadline_days, :integer
    field :waitlist_limit, :integer
  end

  @doc """
  Create a changeset to insert or update registration settings
  """
  @spec changeset(map) :: Changeset.t(t)
  @spec changeset(%__MODULE__{}, map) :: Changeset.t(t)
  def changeset(settings \\ %__MODULE__{}, params) do
    settings
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.validate_required(@required_fields)
  end
end
