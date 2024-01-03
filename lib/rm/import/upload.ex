defmodule RM.Import.Upload do
  use Ecto.Schema

  alias Identity.User

  @typedoc "Upload record"
  @type t :: %__MODULE__{
          file: term,
          imported_at: DateTime.t(),
          imported_by: Ecto.UUID.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "import_uploads" do
    field :file, :string
    field :imported_at, :utc_datetime_usec
    field :imported_by, Ecto.UUID
  end

  @spec new(User.t(), String.t()) :: %__MODULE__{}
  def new(user, path_to_file) do
    %__MODULE__{
      file: path_to_file,
      imported_at: DateTime.utc_now(),
      imported_by: user.id
    }
  end
end
