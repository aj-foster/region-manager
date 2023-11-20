defmodule Connect.Import.Team do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "import_teams" do
    field :data_updated_at, :utc_datetime_usec
    field :imported_at, :utc_datetime_usec
    field :region, :string
    field :team_id, :integer

    embeds_one :data, Data do
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
      field :lc2_email, :string
      field :lc2_email_alt, :string
      field :lc2_name, :string
      field :lc2_phone, :string
      field :lc2_phone_alt, :string
      field :location_city, :string
      field :location_country, :string
      field :location_county, :string
      field :location_postal_code, :string
      field :location_state_province, :string
      field :name, :string
      field :number, :integer
      field :profile_id, :integer
      field :rookie_year, :integer
      field :sponsors, :string
      field :sponsor_types, :string
      field :team_id, :integer
      field :temporary_number, :integer
      field :youth_orgs, :string
      field :youth_org_types, :string
      field :website, :string
    end
  end

  @spec from_csv(map) :: %__MODULE__{}
  def from_csv(data) do
    %{
      "Date Last Updated" => date_last_updated_str,
      "Intent To Return" => intend_to_return_str,
      "LC1 Email" => lc1_email,
      "LC1 Email Alternate" => lc1_email_alt,
      "LC1 Name" => lc1_name,
      "LC1 Phone" => lc1_phone,
      "LC1 Phone Alternate" => lc1_phone_alt,
      "LC2 Email" => lc2_email,
      "LC2 Email Alternate" => lc2_email_alt,
      "LC2 Name" => lc2_name,
      "LC2 Phone" => lc2_phone,
      "LC2 Phone Alternate" => lc2_phone_alt,
      "Ready to Register for Events" => event_ready_str,
      "Ready to Register for Events Outstanding Issues" => event_ready_issues,
      "Region Name" => region,
      "School Youth Organizations" => youth_orgs,
      "School Youth Organizations Types" => youth_org_types,
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
        lc2_email: lc2_email,
        lc2_email_alt: lc2_email_alt,
        lc2_name: lc2_name,
        lc2_phone: lc2_phone,
        lc2_phone_alt: lc2_phone_alt,
        location_city: location_city,
        location_country: location_country,
        location_county: location_county,
        location_postal_code: location_postal_code,
        location_state_province: location_state_province,
        name: name,
        number: number,
        profile_id: profile_id,
        rookie_year: rookie_year,
        sponsors: sponsors,
        sponsor_types: sponsor_types,
        temporary_number: temporary_number,
        youth_orgs: youth_orgs,
        youth_org_types: youth_org_types,
        website: website
      }
    }
  end

  @datetime_re ~r"(?<month>\d+)/(?<day>\d+)/(?<year>\d+)\s+(?<hour>\d+):(?<minute>\d+):(?<second>\d+)\s(?<ampm>AM|PM)"

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
    second = String.to_integer(second)

    hour = if ampm == "AM", do: hour, else: hour + 12

    DateTime.new!(Date.new!(year, month, day), Time.new!(hour, minute, second, 0))
  end
end
