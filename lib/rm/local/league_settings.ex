defmodule RM.Local.LeagueSettings do
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.Local.League
  alias RM.Local.RegistrationSettings

  @typedoc "Settings for an event"
  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          league: League.t(),
          league_id: Ecto.UUID.t(),
          registration: RegistrationSettings.t()
        }

  @required_fields []
  @optional_fields []

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "league_settings" do
    embeds_one :registration, RegistrationSettings, on_replace: :update

    belongs_to :league, League
  end

  @doc """
  Default settings for a new league
  """
  @spec default_params(League.t()) :: map
  def default_params(league) do
    %{league_id: league.id, registration: %RegistrationSettings{enabled: true, pool: :league}}
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
