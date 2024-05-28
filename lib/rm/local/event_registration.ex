defmodule RM.Local.EventRegistration do
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.Account.User
  alias RM.FIRST.Event
  alias RM.Local.Team

  @typedoc "Event registration record"
  @type t :: %__MODULE__{}

  @required_fields [:waitlisted]
  @optional_fields [:creator_id]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "event_registrations" do
    field :waitlisted, :boolean

    belongs_to :creator, User
    belongs_to :event, Event
    belongs_to :team, Team

    timestamps type: :utc_datetime_usec
  end

  @doc "Create a changeset for new event registrations"
  @spec create_changeset(Event.t(), Team.t(), map) :: Changeset.t(t)
  def create_changeset(event, team, params) do
    %__MODULE__{}
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.put_assoc(:event, event)
    |> Changeset.put_assoc(:team, team)
    |> Changeset.validate_required(@required_fields)
  end

  @doc "Create a changeset for modifying an event registration"
  @spec update_changeset(t, map) :: Changeset.t(t)
  def update_changeset(registration, params) do
    registration
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.validate_required(@required_fields)
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
