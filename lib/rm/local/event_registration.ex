defmodule RM.Local.EventRegistration do
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.FIRST.Event
  alias RM.Local.Log
  alias RM.Local.Team

  @typedoc "Event registration record"
  @type t :: %__MODULE__{}

  @required_fields [:rescinded, :waitlisted]
  @optional_fields []

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "event_registrations" do
    field :rescinded, :boolean
    field :waitlisted, :boolean

    belongs_to :event, Event
    belongs_to :team, Team

    timestamps type: :utc_datetime_usec

    embeds_many :log, Log
  end

  @doc "Create a changeset for new event registrations"
  @spec create_changeset(Event.t(), Team.t(), map) :: Changeset.t(t)
  def create_changeset(event, team, params) do
    %__MODULE__{}
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.put_change(:rescinded, false)
    |> Changeset.put_assoc(:event, event)
    |> Changeset.put_assoc(:team, team)
    |> Changeset.validate_required(@required_fields)
    |> Changeset.put_embed(:log, [Log.new("created", params)])
  end

  @doc "Create a map containing params for `insert_all`"
  @spec create_params(Event.t(), Team.t(), map) :: map
  def create_params(event, team, params) do
    now = DateTime.utc_now()

    create_changeset(event, team, params)
    |> Changeset.apply_changes()
    |> Map.take([:rescinded, :waitlisted, :event_id, :team_id, :log])
    |> Map.put(:id, Ecto.UUID.generate())
    |> Map.put(:inserted_at, now)
    |> Map.put(:updated_at, now)
  end

  @doc "Create a changeset for rescinding an event registration"
  @spec rescind_changeset(t, map) :: Changeset.t(t)
  def rescind_changeset(registration, params) do
    registration
    |> Changeset.change(rescinded: true)
    |> Changeset.put_embed(:log, [Log.new("rescinded", params) | registration.log])
  end

  #
  # Protocols
  #

  defimpl Phoenix.Param do
    def to_param(%RM.Local.EventRegistration{event: %RM.FIRST.Event{code: code}}) do
      String.downcase(code)
    end
  end

  @doc false
  def compare(a, b) do
    RM.FIRST.Event.compare(a.event, b.event)
  end
end
