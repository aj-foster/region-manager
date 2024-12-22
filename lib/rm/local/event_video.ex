defmodule RM.Local.EventVideo do
  @moduledoc """
  Video award submission for an event with judging
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.FIRST.Event
  alias RM.FIRST.Team
  alias RM.Local.Log

  @typedoc "Video award"
  @type award :: :compass
  @awards [:compass]

  @typedoc "Video award submission"
  @type t :: %__MODULE__{
          award: award,
          event: Ecto.Schema.belongs_to(Event.t()),
          event_id: Ecto.UUID.t(),
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          log: Ecto.Schema.embeds_many(Log.t()),
          team: Ecto.Schema.belongs_to(Team.t()),
          team_id: Ecto.UUID.t(),
          updated_at: DateTime.t(),
          url: String.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "event_videos" do
    field :award, Ecto.Enum, values: @awards
    field :url, :string

    belongs_to :event, Event
    belongs_to :team, Team

    timestamps type: :utc_datetime_usec

    embeds_many :log, Log
  end

  #
  # Changesets
  #

  @required_fields [:award, :url]
  @optional_fields []

  @doc "Create a changeset for a new event video"
  @spec create_changeset(Event.t(), Team.t(), map) :: Changeset.t(t)
  def create_changeset(event, team, params) do
    %__MODULE__{}
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.put_assoc(:event, event)
    |> Changeset.put_assoc(:team, team)
    |> Changeset.validate_required(@required_fields)
    |> Changeset.put_embed(:log, [Log.new("created", params)])
  end
end
