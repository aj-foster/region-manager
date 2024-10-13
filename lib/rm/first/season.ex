defmodule RM.FIRST.Season do
  use Ecto.Schema

  @type t :: %__MODULE__{
          inserted_at: DateTime.t(),
          kickoff: Date.t(),
          name: String.t(),
          updated_at: DateTime.t(),
          year: integer
        }

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "first_seasons" do
    field :kickoff, :date
    field :name, :string
    field :year, :integer

    timestamps type: :utc_datetime_usec
  end

  #
  # Protocols
  #

  defimpl Phoenix.Param do
    def to_param(%RM.FIRST.Season{year: year}) do
      to_string(year)
    end
  end
end
