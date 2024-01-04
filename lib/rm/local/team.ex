defmodule RM.Local.Team do
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.Account
  alias RM.FIRST.Region

  @typedoc "Team record"
  @type t :: %__MODULE__{}

  @required_fields [
    :event_ready,
    :name,
    :number,
    :region_id,
    :rookie_year,
    :team_id
  ]

  @optional_fields [
    :temporary_number,
    :website
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "teams" do
    field :event_ready, :boolean
    field :name, :string
    field :number, :integer
    field :rookie_year, :integer
    field :team_id, :integer
    field :temporary_number, :integer
    field :website, :string
    timestamps type: :utc_datetime_usec

    belongs_to :region, Region
    has_many :user_assignments, Account.Team
    has_many :users, through: [:user_assignments, :user]

    embeds_one :location, Location, on_replace: :update, primary_key: false do
      field :city, :string
      field :country, :string
      field :county, :string
      field :postal_code, :string
      field :state_province, :string
    end

    embeds_one :notices, Notices, on_replace: :update, primary_key: false do
      field :lc1_missing, :boolean
      field :lc1_ypp, :boolean
      field :lc2_missing, :boolean
      field :lc2_ypp, :boolean
      field :unsecured, :boolean
    end
  end

  @spec from_import(%__MODULE__{}, RM.Import.Team.t()) :: Changeset.t(t)
  def from_import(team, import_team) do
    %RM.Import.Team{
      region_id: region_id,
      team_id: team_id,
      data: %RM.Import.Team.Data{
        event_ready: event_ready,
        lc1_name: lc1_name,
        lc2_name: lc2_name,
        location_city: city,
        location_country: country,
        location_county: county,
        location_postal_code: postal_code,
        location_state_province: state_province,
        name: name,
        number: number,
        rookie_year: rookie_year,
        secured: secured,
        temporary_number: temporary_number,
        website: website
      }
    } = import_team

    team
    |> Changeset.cast(
      %{
        event_ready: event_ready,
        name: name,
        number: number,
        region_id: region_id,
        rookie_year: rookie_year,
        team_id: team_id,
        temporary_number: temporary_number,
        website: website,
        location: %{
          city: city,
          country: country,
          county: county,
          postal_code: postal_code,
          state_province: state_province
        },
        notices: %{
          lc1_missing: lc1_name in ["", nil],
          lc1_ypp: false,
          lc2_missing: lc2_name in ["", nil],
          lc2_ypp: false,
          unsecured: !secured
        }
      },
      @required_fields ++ @optional_fields
    )
    |> Changeset.cast_embed(:location, with: &cast_location/2)
    |> Changeset.cast_embed(:notices, with: &cast_notices/2)
    |> Changeset.validate_required(@required_fields)
  end

  @spec cast_location(%__MODULE__.Location{}, map) :: Changeset.t(%__MODULE__.Location{})
  defp cast_location(location, params) do
    Changeset.cast(location, params, [:city, :country, :county, :postal_code, :state_province])
  end

  @spec cast_notices(%__MODULE__.Notices{}, map) :: Changeset.t(%__MODULE__.Notices{})
  defp cast_notices(notices, params) do
    Changeset.cast(notices, params, [:lc1_missing, :lc1_ypp, :lc2_missing, :lc2_ypp, :unsecured])
  end
end
