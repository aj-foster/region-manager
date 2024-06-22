defmodule RM.Local.Log do
  use Ecto.Schema

  alias RM.Account.User

  @typedoc "Audit log entry"
  @type t :: %__MODULE__{
          at: DateTime.t(),
          by: Ecto.UUID.t() | nil,
          event: String.t()
        }

  embedded_schema do
    field :event, :string
    field :at, :utc_datetime_usec
    field :by, Ecto.UUID
  end

  @doc """
  Create a new log entry for the given `event`

  If a param of `:by` or `"by"` is passed, the corresponding user ID will be logged.
  """
  @spec new(String.t(), map) :: t
  def new(event, params) do
    %__MODULE__{
      at: DateTime.utc_now(),
      by: by(params),
      event: event
    }
  end

  @spec by(map) :: Ecto.UUID.t() | nil
  defp by(params) do
    cond do
      is_struct(params[:by], User) -> params[:by].id
      is_struct(params["by"], User) -> params["by"].id
      :else -> nil
    end
  end
end
