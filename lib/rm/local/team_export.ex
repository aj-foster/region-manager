defmodule RM.Local.TeamExport do
  @moduledoc """
  Export lists of teams in CSV or XLSX format

  The exported data may have varying fields depending on context (for example, list of teams
  registered for an event may have registration time).
  """
  use Waffle.Definition
  require Logger

  #
  # Export
  #

  @spec export(map) :: {:ok, url :: String.t()} | {:error, message :: String.t()}
  def export(params) do
    teams = params["teams"]

    imports_by_team_id =
      Enum.map(teams, fn %RM.Local.Team{team_id: team_id} -> team_id end)
      |> RM.Import.Team.latest_by_team_id_query()
      |> RM.Repo.all()
      |> Map.new(&{&1.team_id, &1})

    params =
      Map.update!(params, "teams", fn teams ->
        Enum.map(teams, fn team ->
          {team, Map.fetch!(imports_by_team_id, team.team_id)}
        end)
      end)

    case params["format"] do
      "csv" -> export_csv(params)
      "xlsx" -> export_xlsx(params)
      _else -> {:error, "Invalid format. Please choose CSV or XLSX."}
    end
  end

  @headers %{
    "name" => "Name",
    "number" => "Number",
    "rookie-status" => "Rookie Status",
    "rookie-year" => "Rookie Year",
    "school" => "School or Youth Org",
    "school-type" => "Organization Type",
    "sponsors" => "Sponsors",
    "sponsors-type" => "Sponsor Type",
    "website" => "Website",
    "country" => "Country",
    "state-province" => "State or Province",
    "city" => "City",
    "county" => "County",
    "postal-code" => "Postal Code",
    "region" => "Region",
    "league" => "League",
    "lc1-name" => "LC1 Name",
    "lc1-email" => "LC1 Email",
    "lc1-email-alt" => "LC1 Email Alt",
    "lc1-phone" => "LC1 Phone",
    "lc1-phone-alt" => "LC1 Phone Alt",
    "lc1-ypp-status" => "LC1 YPP Status",
    "lc2-name" => "LC2 Name",
    "lc2-email" => "LC2 Email",
    "lc2-email-alt" => "LC2 Email Alt",
    "lc2-phone" => "LC2 Phone",
    "lc2-phone-alt" => "LC2 Phone Alt",
    "lc2-ypp-status" => "LC2 YPP Status",
    "admin-name" => "Team Admin Name",
    "admin-email" => "Team Admin Email",
    "admin-phone" => "Team Admin Phone",
    "event-ready" => "Event Ready?",
    "missing-contacts" => "Missing Contacts",
    "secured-date" => "Secured Date"
  }

  @fields_in_order [
    "region",
    "league",
    "number",
    "name",
    "event-ready",
    "missing-contacts",
    "secured-date",
    "rookie-status",
    "rookie-year",
    "school",
    "school-type",
    "sponsors",
    "sponsors-type",
    "website",
    "country",
    "state-province",
    "city",
    "county",
    "postal-code",
    "lc1-name",
    "lc1-email",
    "lc1-email-alt",
    "lc1-phone",
    "lc1-phone-alt",
    "lc1-ypp-status",
    "lc2-name",
    "lc2-email",
    "lc2-email-alt",
    "lc2-phone",
    "lc2-phone-alt",
    "lc2-ypp-status",
    "admin-name",
    "admin-email",
    "admin-phone"
  ]

  #
  # CSV
  #

  NimbleCSV.define(RM.Local.TeamExport.CSV, [])

  @spec export_csv(map) :: {:ok, url :: String.t()} | {:error, message :: String.t()}
  defp export_csv(params) do
    fields = Enum.filter(@fields_in_order, &(&1 in params["fields"]))
    headers = Enum.map(fields, &Map.get(@headers, &1))
    body = Enum.map(params["teams"], &export_csv_team(fields, &1))

    file_io = RM.Local.TeamExport.CSV.dump_to_iodata([headers | body])
    file_bin = IO.iodata_to_binary(file_io)

    scope = %{date: Date.utc_today()}
    hash = :crypto.hash(:md5, file_io) |> Base.encode16(case: :lower) |> String.slice(0, 6)
    filename = "rm-teams-#{hash}.csv"

    case store({%{filename: filename, binary: file_bin}, scope}) do
      {:ok, filename} ->
        {:ok, url({filename, scope}, signed: true)}

      {:error, reason} ->
        Logger.error("Error while storing team export: #{inspect(reason)}")
        {:error, "An error occurred while storing the export"}
    end
  end

  @spec export_csv_team([String.t()], {RM.Local.Team.t(), RM.Import.Team.t()}) :: [String.t()]
  defp export_csv_team(fields, {team, import_team}) do
    %RM.Local.Team{
      event_ready: event_ready?,
      league: league_struct,
      location: %RM.Local.Team.Location{
        country: country,
        state_province: state_province,
        city: city,
        county: county,
        postal_code: postal_code
      },
      name: name,
      number: number,
      region: %RM.FIRST.Region{name: region},
      rookie_year: rookie_year,
      website: website
    } = RM.Repo.preload(team, [:league, :region])

    %RM.Import.Team{
      data: %RM.Import.Team.Data{
        admin_email: admin_email,
        admin_name: admin_name,
        admin_phone: admin_phone,
        lc1_email: lc1_email,
        lc1_email_alt: lc1_email_alt,
        lc1_name: lc1_name,
        lc1_phone: lc1_phone,
        lc1_phone_alt: lc1_phone_alt,
        lc1_ypp: lc1_ypp,
        lc1_ypp_reason: lc1_ypp_reason,
        lc2_email: lc2_email,
        lc2_email_alt: lc2_email_alt,
        lc2_name: lc2_name,
        lc2_phone: lc2_phone,
        lc2_phone_alt: lc2_phone_alt,
        lc2_ypp: lc2_ypp,
        lc2_ypp_reason: lc2_ypp_reason,
        missing_contacts: missing_contacts,
        secured_date: secured_date,
        sponsors: sponsors,
        sponsor_types: sponsor_types,
        youth_orgs: school,
        youth_org_types: school_type
      }
    } = import_team

    values = %{
      "region" => region,
      "league" => if(league_struct, do: league_struct.name, else: ""),
      "number" => to_string(number),
      "name" => name,
      "event-ready" => if(event_ready?, do: "Yes", else: "No"),
      "missing-contacts" => missing_contacts,
      "secured-date" => if(secured_date, do: Date.to_string(secured_date)),
      "rookie-status" =>
        if(rookie_year == RM.System.current_season(), do: "Rookie", else: "Veteran"),
      "rookie-year" => to_string(rookie_year),
      "school" => school || "",
      "school-type" => school_type || "",
      "sponsors" => sponsors || "",
      "sponsors-type" => sponsor_types || "",
      "website" => website || "",
      "country" => country || "",
      "state-province" => state_province || "",
      "city" => city || "",
      "county" => county || "",
      "postal-code" => postal_code || "",
      "lc1-name" => lc1_name || "",
      "lc1-email" => lc1_email || "",
      "lc1-email-alt" => lc1_email_alt || "",
      "lc1-phone" => lc1_phone || "",
      "lc1-phone-alt" => lc1_phone_alt || "",
      "lc1-ypp-status" => if(lc1_ypp, do: "Passed", else: lc1_ypp_reason),
      "lc2-name" => lc2_name || "",
      "lc2-email" => lc2_email || "",
      "lc2-email-alt" => lc2_email_alt || "",
      "lc2-phone" => lc2_phone || "",
      "lc2-phone-alt" => lc2_phone_alt || "",
      "lc2-ypp-status" => if(lc2_ypp, do: "Passed", else: lc2_ypp_reason),
      "admin-name" => admin_name || "",
      "admin-email" => admin_email || "",
      "admin-phone" => admin_phone || ""
    }

    Enum.map(fields, &Map.fetch!(values, &1))
  end

  #
  # XLSX
  #

  @spec export_xlsx(map) :: {:ok, url :: String.t()} | {:error, message :: String.t()}
  defp export_xlsx(_params), do: {:ok, ""}

  #
  # Waffle Callbacks
  #

  @versions [:original]

  @doc false
  def storage_dir(_version, {_, %{date: date}}) do
    "exports/#{Date.to_string(date)}/"
  end
end
