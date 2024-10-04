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
          waitlist_limit: integer | nil,
          waitlist_pool: pool | nil
        }

  @required_fields [:deadline_days, :enabled, :open_days, :pool]
  @optional_fields [:team_limit, :waitlist_deadline_days, :waitlist_limit, :waitlist_pool]

  @primary_key false

  embedded_schema do
    field :enabled, :boolean
    field :deadline_days, :integer, default: 7
    field :open_days, :integer, default: 21
    field :pool, Ecto.Enum, values: @pools
    field :team_limit, :integer
    field :waitlist_deadline_days, :integer
    field :waitlist_limit, :integer
    field :waitlist_pool, Ecto.Enum, values: @pools
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
    |> validate_open_before_deadline()
    |> validate_cascading_pool()
  end

  @spec validate_open_before_deadline(Changeset.t(%__MODULE__{})) :: Changeset.t(%__MODULE__{})
  defp validate_open_before_deadline(changeset) do
    if Changeset.get_field(changeset, :enabled) do
      close = Changeset.get_field(changeset, :deadline_days)
      open = Changeset.get_field(changeset, :open_days)

      if open - close < 2 do
        Changeset.add_error(changeset, :open_days, "must allow at least two days to register")
      else
        changeset
      end
    else
      changeset
    end
  end

  @spec validate_cascading_pool(Changeset.t(%__MODULE__{})) :: Changeset.t(%__MODULE__{})
  defp validate_cascading_pool(changeset) do
    if waitlist_pool = Changeset.get_field(changeset, :waitlist_pool) do
      pool = Changeset.get_field(changeset, :pool)
      message = "waitlist eligibility must be at least as broad as priority registration"

      case {pool, waitlist_pool} do
        {:all, :region} -> Changeset.add_error(changeset, :waitlist_pool, message)
        {:all, :league} -> Changeset.add_error(changeset, :waitlist_pool, message)
        {:region, :league} -> Changeset.add_error(changeset, :waitlist_pool, message)
        _else -> changeset
      end
    else
      changeset
    end
  end
end
