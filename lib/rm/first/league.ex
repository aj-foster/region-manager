defmodule RM.FIRST.League do
  use Ecto.Schema

  alias RM.FIRST.Region

  @type t :: %__MODULE__{
          code: String.t(),
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          location: String.t() | nil,
          name: String.t(),
          parent_league: Ecto.Schema.belongs_to(t | nil),
          parent_league_id: Ecto.UUID.t(),
          region: Ecto.Schema.belongs_to(Region.t()),
          region_id: Ecto.UUID.t(),
          remote: boolean,
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "first_leagues" do
    field :code, :string
    field :location, :string
    field :name, :string
    field :remote, :boolean

    belongs_to :parent_league, __MODULE__, type: :binary_id
    belongs_to :region, Region, type: :binary_id

    timestamps type: :utc_datetime_usec
  end

  def from_ftc_events(
        %{
          "code" => code,
          "location" => location,
          "name" => name,
          "parentLeagueCode" => parent_league_code,
          "region" => region_code,
          "remote" => remote
        },
        region_id_map,
        league_id_map \\ %{}
      ) do
    %{
      code: code,
      inserted_at: DateTime.utc_now(),
      location: location,
      name: name,
      parent_league_id: league_id_map[parent_league_code],
      region_id: region_id_map[region_code],
      remote: remote,
      updated_at: DateTime.utc_now()
    }
  end
end
