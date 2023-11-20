defmodule Connect.FIRST.Season do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "first_seasons" do
    field :name, :string
    field :year, :integer

    timestamps type: :utc_datetime_usec
  end
end
