defmodule RM.FIRST.Region do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "first_regions" do
    field :abbreviation, :string
    field :description, :string
    field :has_leagues, :boolean, default: false
    field :name, :string

    timestamps type: :utc_datetime_usec
  end
end
