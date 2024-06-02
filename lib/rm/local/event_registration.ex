defmodule RM.Local.EventRegistration do
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.Account.User
  alias RM.FIRST.Event
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

    embeds_many :log, Log do
      field :event, :string
      field :at, :utc_datetime_usec
      field :by, Ecto.UUID
    end
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
    |> Changeset.put_embed(:log, [
      %__MODULE__.Log{event: "created", at: DateTime.utc_now(), by: by(params)}
    ])
  end

  @doc "Create a changeset for rescinding an event registration"
  @spec rescind_changeset(t, map) :: Changeset.t(t)
  def rescind_changeset(registration, params) do
    registration
    |> Changeset.change(rescinded: true)
    |> Changeset.put_embed(:log, [
      %__MODULE__.Log{event: "rescinded", at: DateTime.utc_now(), by: by(params)}
      | registration.log
    ])
  end

  @spec by(map) :: Ecto.UUID | nil
  defp by(params) do
    cond do
      is_struct(params[:by], User) -> params[:by].id
      is_struct(params["by"], User) -> params["by"].id
      :else -> nil
    end
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
