defmodule RM.FIRST.Season do
  @moduledoc """
  Represents a season of FIRST Tech Challenge events, typically running from September to May

  Seasons are identified by their year, which corresponds to the year in which the season starts.
  For example, the 2023–2024 season is identified by the year 2023.
  """
  use Ecto.Schema

  alias Ecto.Changeset

  @typedoc "Season (September to May) of FIRST Tech Challenge events"
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
    field :logo_url, :string
    field :name, :string
    field :year, :integer

    timestamps type: :utc_datetime_usec
  end

  #
  # Changesets
  #

  @required_fields [:kickoff, :name, :year]
  @optional_fields [:logo_url]

  @doc "Create a changeset for inserting a new season"
  @spec create_changeset(map) :: Changeset.t(t)
  def create_changeset(attrs) do
    %__MODULE__{}
    |> Changeset.change()
    |> cast_and_validate(attrs)
  end

  @spec cast_and_validate(Changeset.t(t), map) :: Changeset.t(t)
  defp cast_and_validate(changeset, attrs) do
    changeset
    |> Changeset.cast(attrs, @required_fields ++ @optional_fields)
    |> put_year()
    |> Changeset.validate_format(:logo_url, ~r/^https?:\/\/.+/)
    |> Changeset.validate_length(:name, min: 1)
    |> Changeset.validate_required(@required_fields)
  end

  @spec put_year(Changeset.t(t)) :: Changeset.t(t)
  defp put_year(changeset) do
    year =
      if kickoff = Changeset.get_field(changeset, :kickoff) do
        Date.to_erl(kickoff) |> elem(0)
      end

    Changeset.put_change(changeset, :year, year)
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
