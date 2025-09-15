defmodule RM.Email.List do
  @moduledoc """
  Lists are groups of email addresses that can be sent to, subscribed to, and unsubscribed from
  """
  use Ecto.Schema

  alias Ecto.Changeset

  @typedoc "Auto-subscribe settings for an email list"
  @type auto_subscribe :: %__MODULE__.AutoSubscribe{
          admins: boolean,
          coaches: boolean,
          league_admins: boolean
        }

  @typedoc "Metadata about an email list"
  @type metadata :: %__MODULE__.Metadata{
          subscriber_count: integer
        }

  @typedoc "Group of email addresses"
  @type t :: %__MODULE__{
          auto_subscribe: auto_subscribe,
          description: String.t() | nil,
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          league: Ecto.Schema.belongs_to(RM.Local.League.t() | nil),
          league_id: Ecto.UUID.t() | nil,
          metadata: metadata,
          name: String.t(),
          region: Ecto.Schema.belongs_to(RM.FIRST.Region.t() | nil),
          region_id: Ecto.UUID.t() | nil,
          removed_at: DateTime.t() | nil,
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "email_lists" do
    field :name, :string
    field :description, :string

    embeds_one :auto_subscribe, AutoSubscribe do
      # Admins of the target league or region
      field :admins, :boolean, default: false

      # Coaches of teams in the target league or region
      field :coaches, :boolean, default: false

      # Admins of sub-leagues, if present
      field :league_admins, :boolean, default: false
    end

    embeds_one :metadata, Metadata do
      field :subscriber_count, :integer, default: 0
    end

    belongs_to :region, RM.FIRST.Region
    belongs_to :league, RM.Local.League

    timestamps(type: :utc_datetime_usec)
    field :removed_at, :utc_datetime_usec
  end

  #
  # Changesets
  #

  @required_fields [:name]
  @optional_fields [:description]

  @doc "Create a changeset for a new email list"
  @spec create_changeset(map) :: Changeset.t(t)
  def create_changeset(params) do
    %__MODULE__{}
    |> cast_and_validate(params)
    |> Changeset.put_assoc(:league, params["league"])
    |> Changeset.put_assoc(:region, params["region"])
  end

  @spec cast_and_validate(%__MODULE__{}, map) :: Changeset.t(t)
  defp cast_and_validate(struct, params) do
    struct
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.cast_embed(:auto_subscribe, with: &auto_subscribe_changeset/2)
    |> Changeset.cast_embed(:metadata, with: &metadata_changeset/2)
    |> Changeset.foreign_key_constraint(:league_id)
    |> Changeset.foreign_key_constraint(:region_id)
    |> Changeset.validate_required(@required_fields)
  end

  @spec auto_subscribe_changeset(%__MODULE__.AutoSubscribe{}, map) :: Changeset.t()
  defp auto_subscribe_changeset(settings, params) do
    Changeset.cast(settings, params, [:admins, :coaches, :league_admins])
  end

  @spec metadata_changeset(%__MODULE__.Metadata{}, map) :: Changeset.t()
  defp metadata_changeset(metadata, params) do
    Changeset.cast(metadata, params, [:subscriber_count])
  end
end
