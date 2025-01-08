defmodule RM.Import.Team do
  use Ecto.Schema
  import Ecto.Query

  @typedoc "Imported team record"
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "import_teams" do
    field :data_updated_at, :utc_datetime_usec
    field :imported_at, :utc_datetime_usec
    field :region, :string
    field :region_id, Ecto.UUID
    field :team_id, :integer
    field :upload_id, Ecto.UUID

    embeds_one :data, Data do
      field :active, :boolean
      field :admin_email, :string
      field :admin_name, :string
      field :admin_phone, :string
      field :event_ready, :boolean
      field :event_ready_issues, :string
      field :intend_to_return, :boolean
      field :lc1_email, :string
      field :lc1_email_alt, :string
      field :lc1_name, :string
      field :lc1_phone, :string
      field :lc1_phone_alt, :string
      field :lc1_ypp, :boolean
      field :lc1_ypp_reason, :string
      field :lc2_email, :string
      field :lc2_email_alt, :string
      field :lc2_name, :string
      field :lc2_phone, :string
      field :lc2_phone_alt, :string
      field :lc2_ypp, :boolean
      field :lc2_ypp_reason, :string
      field :location_city, :string
      field :location_country, :string
      field :location_county, :string
      field :location_postal_code, :string
      field :location_state_province, :string
      field :missing_contacts, :string
      field :name, :string
      field :number, :integer
      field :profile_id, :integer
      field :rookie_year, :integer
      field :secured, :boolean
      field :secured_date, :date
      field :sponsors, :string
      field :sponsor_types, :string
      field :team_id, :integer
      field :temporary_number, :integer
      field :youth_orgs, :string
      field :youth_org_types, :string
      field :website, :string
    end
  end

  @doc """
  Create a team struct from a Tableau export
  """
  @spec from_csv(map) :: %__MODULE__{}
  def from_csv(data) do
    %{
      "Active Team" => active_team_str,
      "Date Last Updated" => date_last_updated_str,
      "Intent To Return" => intend_to_return_str,
      "LC1 Email" => lc1_email,
      "LC1 Email Alternate" => lc1_email_alt,
      "LC1 Name" => lc1_name,
      "LC1 Phone" => lc1_phone,
      "LC1 Phone Alternate" => lc1_phone_alt,
      "LC1 YPP Screening Requirements Met" => lc1_ypp,
      "LC1 YPP Screening Requirements Details" => lc1_ypp_reason,
      "LC2 Email" => lc2_email,
      "LC2 Email Alternate" => lc2_email_alt,
      "LC2 Name" => lc2_name,
      "LC2 Phone" => lc2_phone,
      "LC2 Phone Alternate" => lc2_phone_alt,
      "LC2 YPP Screening Requirements Met" => lc2_ypp,
      "LC2 YPP Screening Requirements Details" => lc2_ypp_reason,
      "Missing Contacts" => missing_contacts,
      "Ready to Register for Events" => event_ready_str,
      "Ready to Register for Events Outstanding Issues" => event_ready_issues,
      "Region Name" => region,
      "School Youth Organizations" => youth_orgs,
      "School Youth Organizations Types" => youth_org_types,
      "Secured Date" => secured_date,
      "Secured Status" => secured_status,
      "Sponsors" => sponsors,
      "Sponsor Types" => sponsor_types,
      "Team Admin Email" => admin_email,
      "Team Admin Name" => admin_name,
      "Team Admin Phone" => admin_phone,
      "Team Id" => team_id,
      "Team City" => location_city,
      "Team Country" => location_country,
      "Team County" => location_county,
      "Team Postal Code" => location_postal_code,
      "Team State Province" => location_state_province,
      "Team Nickname" => name,
      "Team Number" => number,
      "Team Number Temp" => temporary_number,
      "Team Profile Id" => profile_id,
      "Team Rookie Year" => rookie_year,
      "Team Website" => website
    } = data

    %__MODULE__{
      data_updated_at: parse_datetime(date_last_updated_str),
      imported_at: DateTime.utc_now(),
      region: region,
      team_id: String.to_integer(team_id),
      data: %__MODULE__.Data{
        active: active_team_str == "Active",
        admin_email: admin_email,
        admin_name: admin_name,
        admin_phone: admin_phone,
        event_ready: event_ready_str == "Event Ready",
        event_ready_issues: event_ready_issues,
        intend_to_return: intend_to_return_str == "1",
        lc1_email: lc1_email,
        lc1_email_alt: lc1_email_alt,
        lc1_name: lc1_name,
        lc1_phone: lc1_phone,
        lc1_phone_alt: lc1_phone_alt,
        lc1_ypp: lc1_ypp =~ "Satisfies",
        lc1_ypp_reason: if(lc1_ypp =~ "Does Not Satisfy", do: lc1_ypp_reason),
        lc2_email: lc2_email,
        lc2_email_alt: lc2_email_alt,
        lc2_name: lc2_name,
        lc2_phone: lc2_phone,
        lc2_phone_alt: lc2_phone_alt,
        lc2_ypp: lc2_ypp =~ "Satisfies",
        lc2_ypp_reason: if(lc2_ypp =~ "Does Not Satisfy", do: lc2_ypp_reason),
        location_city: location_city,
        location_country: location_country,
        location_county: location_county,
        location_postal_code: location_postal_code,
        location_state_province: location_state_province,
        missing_contacts: missing_contacts,
        name: name,
        number: number,
        profile_id: profile_id,
        rookie_year: rookie_year,
        secured: secured_status == "Secured",
        secured_date: if(secured_date != "", do: parse_date(secured_date)),
        sponsors: sponsors,
        sponsor_types: sponsor_types,
        temporary_number: if(temporary_number != "", do: String.to_integer(temporary_number)),
        youth_orgs: youth_orgs,
        youth_org_types: youth_org_types,
        website: website
      }
    }
  end

  @date_re ~r"(?<month>\d+)/(?<day>\d+)/(?<year>\d+)"
  @datetime_re ~r"(?<month>\d+)/(?<day>\d+)/(?<year>\d+)\s+(?<hour>\d+):(?<minute>\d+)(:(?<second>\d+)(\s*(?<ampm>AM|PM|am|pm))?)?"

  defp parse_date(datetime_str) do
    %{
      "month" => month,
      "day" => day,
      "year" => year
    } = Regex.named_captures(@date_re, datetime_str)

    month = String.to_integer(month)
    day = String.to_integer(day)
    year = String.to_integer(year)

    Date.new!(year, month, day)
  end

  defp parse_datetime(datetime_str) do
    %{
      "month" => month,
      "day" => day,
      "year" => year,
      "hour" => hour,
      "minute" => minute,
      "second" => second,
      "ampm" => ampm
    } = Regex.named_captures(@datetime_re, datetime_str)

    month = String.to_integer(month)
    day = String.to_integer(day)
    year = String.to_integer(year)
    hour = String.to_integer(hour)
    minute = String.to_integer(minute)

    second =
      case Integer.parse(second) do
        {second, ""} -> second
        _else -> 0
      end

    hour = if ampm in ["PM", "pm"], do: hour + 12, else: hour

    DateTime.new!(Date.new!(year, month, day), Time.new!(hour, minute, second, 0))
  end

  @doc """
  Add a region ID to an existing team struct
  """
  @spec put_region(%__MODULE__{}, Ecto.UUID.t()) :: %__MODULE__{}
  def put_region(team, region_id), do: %__MODULE__{team | region_id: region_id}

  @doc """
  Add an upload ID to an existing team struct
  """
  @spec put_upload(%__MODULE__{}, Ecto.UUID.t()) :: %__MODULE__{}
  def put_upload(team, upload_id), do: %__MODULE__{team | upload_id: upload_id}

  #
  # Queries
  #

  @doc """
  List the latest import record for each team with one of the given team IDs
  """
  @spec latest_by_team_id_query([integer]) :: Ecto.Query.t()
  def latest_by_team_id_query(team_ids) do
    subquery =
      from(__MODULE__, as: :import)
      |> where([import: i], i.team_id in ^team_ids)
      |> select([import: i], %{team_id: i.team_id, imported_at: max(i.imported_at)})
      |> group_by([import: i], i.team_id)

    from(__MODULE__, as: :import)
    |> join(
      :inner,
      [import: i],
      s in subquery(subquery),
      on: i.team_id == s.team_id and i.imported_at == s.imported_at
    )
  end
end
