defmodule RM.Import.Upload do
  use Ecto.Schema

  alias Ecto.Changeset
  alias Identity.User
  alias RM.Import.File

  @typedoc "Upload record"
  @type t :: %__MODULE__{
          file: String.t(),
          imported_at: DateTime.t(),
          imported_by: Ecto.UUID.t()
        }

  @required_fields [:id, :imported_at, :imported_by]

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "import_uploads" do
    field :file, File.Type
    field :imported_at, :utc_datetime_usec
    field :imported_by, Ecto.UUID
  end

  @spec new(User.t(), String.t()) :: Changeset.t(t)
  def new(user, path_to_file) do
    params = %{
      id: Ecto.UUID.generate(),
      imported_at: DateTime.utc_now(),
      imported_by: user.id
    }

    %__MODULE__{}
    |> Changeset.cast(params, @required_fields)
    |> cast_file(path_to_file)
    |> Changeset.validate_required(@required_fields)
  end

  @spec cast_file(Changeset.t(%__MODULE__{}), String.t()) :: Changeset.t(%__MODULE__{})
  defp cast_file(changeset, path) do
    scope = Changeset.apply_changes(changeset)
    Changeset.cast(changeset, %{file: {path, scope}}, [:file])
  end
end
