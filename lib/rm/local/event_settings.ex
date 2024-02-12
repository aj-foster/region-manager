defmodule RM.Local.EventSettings do
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.FIRST.Event
  alias RM.Local.RegistrationSettings

  @typedoc "Settings for an event"
  @type t :: %__MODULE__{
          event: Event.t(),
          event_id: Ecto.UUID.t(),
          id: Ecto.UUID.t(),
          registration: RegistrationSettings.t()
        }

  @required_fields [:event_id]
  @optional_fields []

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "event_settings" do
    embeds_one :registration, RegistrationSettings, on_replace: :update

    belongs_to :event, Event
  end

  @doc """
  Create a changeset to insert or update event settings
  """
  @spec changeset(map) :: Changeset.t(t)
  @spec changeset(%__MODULE__{}, map) :: Changeset.t(t)
  def changeset(settings \\ %__MODULE__{}, params) do
    settings
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.validate_required(@required_fields)
    |> Changeset.cast_embed(:registration)
  end
end
