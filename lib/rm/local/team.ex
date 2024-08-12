defmodule RM.Local.Team do
  use Ecto.Schema
  import Ecto.Query

  alias Ecto.Changeset
  alias RM.Account
  alias RM.FIRST.Region
  alias RM.Local.EventRegistration
  alias RM.Local.LeagueAssignment

  @typedoc "Team record"
  @type t :: %__MODULE__{}

  @required_fields [
    :active,
    :event_ready,
    :name,
    :number,
    :region_id,
    :rookie_year,
    :team_id
  ]

  @optional_fields [
    :hidden_at,
    :temporary_number,
    :website
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "teams" do
    field :active, :boolean
    field :event_ready, :boolean
    field :name, :string
    field :number, :integer
    field :rookie_year, :integer
    field :team_id, :integer
    field :temporary_number, :integer
    field :website, :string

    timestamps type: :utc_datetime_usec
    field :hidden_at, :utc_datetime_usec

    belongs_to :region, Region
    has_many :event_registrations, EventRegistration
    has_many :events, through: [:event_registrations, :event]
    has_one :league_assignment, LeagueAssignment
    has_one :league, through: [:league_assignment, :league]
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

    field :first_team, :any, virtual: true
  end

  @spec from_import(%__MODULE__{}, RM.Import.Team.t()) :: Changeset.t(t)
  def from_import(team, import_team) do
    %RM.Import.Team{
      region_id: region_id,
      team_id: team_id,
      data: %RM.Import.Team.Data{
        active: active,
        event_ready: event_ready,
        intend_to_return: intend_to_return,
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
        active: active && (intend_to_return || secured),
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

  #
  # Queries
  #

  @doc """
  Select teams with `active = true`
  """
  @spec active_query :: Ecto.Query.t()
  def active_query do
    from(__MODULE__, as: :team)
    |> where([team: t], t.active)
  end

  @doc "Update active status for teams with the given IDs"
  @spec update_active_status([integer], boolean) :: Ecto.Query.t()
  def update_active_status(ids, active?) do
    from(__MODULE__, as: :team)
    |> where([team: t], t.team_id in ^ids)
    |> update(set: [active: ^active?])
  end

  #
  # Protocols
  #

  defimpl Phoenix.Param do
    def to_param(%RM.Local.Team{number: number}) do
      Integer.to_string(number)
    end
  end

  @doc false
  def compare(a, b) do
    case {a.number || a.temporary_number, b.number || b.temporary_number} do
      {a, b} when a < b -> :lt
      {a, b} when a > b -> :gt
      _else -> :eq
    end
  end
end
