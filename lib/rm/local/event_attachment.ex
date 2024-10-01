defmodule RM.Local.EventAttachment do
  @moduledoc """
  Attached files for an event
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.Local.EventFile
  alias RM.Local.EventProposal

  @typedoc "Role of the attachment in the context of the event"
  @type type :: :program | :other
  @types [:program, :other]

  @typedoc "Upload record"
  @type t :: %__MODULE__{
          file: String.t(),
          proposal: Ecto.Schema.belongs_to(EventProposal.t()),
          proposal_id: Ecto.UUID.t(),
          name: String.t(),
          season: integer,
          type: type,
          uploaded_at: DateTime.t(),
          uploaded_by: Ecto.UUID.t()
        }

  @required_fields [:id, :name, :season, :type, :uploaded_at, :uploaded_by]

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "event_attachments" do
    field :file, EventFile.Type
    field :name, :string
    field :season, :integer
    field :type, Ecto.Enum, values: @types
    field :uploaded_at, :utc_datetime_usec
    field :uploaded_by, Ecto.UUID

    belongs_to :proposal, EventProposal
  end

  @spec new(EventProposal.t(), map) :: Changeset.t(t)
  def new(proposal, params) do
    params =
      Map.merge(params, %{
        "id" => Ecto.UUID.generate(),
        "season" => proposal.season,
        "uploaded_at" => DateTime.utc_now(),
        "uploaded_by" => params["user"].id
      })
      |> Map.put_new("name", slugify_name(proposal.name))

    %__MODULE__{}
    |> Changeset.cast(params, @required_fields)
    |> Changeset.put_assoc(:proposal, proposal)
    |> cast_file(params["path"])
    |> Changeset.validate_required(@required_fields)
  end

  @spec cast_file(Changeset.t(%__MODULE__{}), String.t()) :: Changeset.t(%__MODULE__{})
  defp cast_file(changeset, path) do
    scope = Changeset.apply_changes(changeset)
    Changeset.cast(changeset, %{file: {path, scope}}, [:file])
  end

  @spec slugify_name(String.t()) :: String.t()
  defp slugify_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\.+/, "")
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  @spec url(t) :: String.t()
  def url(attachment) do
    EventFile.url({attachment.file, attachment})
  end
end
