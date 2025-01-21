defmodule RM.Local.EventVideo do
  @moduledoc """
  Video award submission for an event with judging
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.FIRST.Event
  alias RM.Local.Log
  alias RM.Local.Team

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
    cast_and_validate(%__MODULE__{}, params)
    |> Changeset.put_assoc(:event, event)
    |> Changeset.put_assoc(:team, team)
    |> Changeset.put_embed(:log, [Log.new("created", params)])
  end

  @doc "Create a changeset for updating an event video"
  @spec update_changeset(t, map) :: Changeset.t(t)
  def update_changeset(submission, params) do
    cast_and_validate(submission, params)
    |> Changeset.put_embed(:log, [Log.new("updated", params) | submission.log])
  end

  @spec cast_and_validate(%__MODULE__{}, map) :: Changeset.t(%__MODULE__{})
  defp cast_and_validate(struct, params) do
    struct
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> cast_url()
    |> Changeset.validate_required(@required_fields)
    |> Changeset.foreign_key_constraint(:event_id)
    |> Changeset.foreign_key_constraint(:team_id)
  end

  defp cast_url(changeset) do
    if url = Changeset.get_change(changeset, :url) do
      new_url =
        case URI.parse(url) do
          %URI{scheme: "https", host: <<_::binary>>} = uri ->
            URI.to_string(uri)

          %URI{scheme: "http", host: <<_::binary>>} = uri ->
            %URI{uri | scheme: "https"}
            |> URI.to_string()

          %URI{scheme: nil, host: <<_::binary>>} = uri ->
            %URI{uri | scheme: "https"}
            |> URI.to_string()

          %URI{scheme: nil, host: nil, path: <<_::binary>>} ->
            uri = URI.parse("//#{url}")

            %URI{uri | scheme: "https"}
            |> URI.to_string()

          %URI{} ->
            ""
        end

      Changeset.put_change(changeset, :url, new_url)
    else
      changeset
    end
  end

  #
  # Helpers
  #

  @doc """
  Returns a human-readable name for an award
  """
  @spec award_name(t) :: String.t()
  def award_name(%__MODULE__{award: :compass}), do: "Compass Award"
end
