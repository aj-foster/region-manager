defmodule RM.Import do
  require NimbleCSV

  alias RM.Account
  alias RM.Import.Team
  alias RM.Import.Upload
  alias RM.Repo

  NimbleCSV.define(RM.Import.TeamDataParser,
    separator: "\t",
    escape: "\"",
    encoding: :utf8,
    trim_bom: true,
    dump_bom: true
  )

  @spec import_from_team_info_tableau_export(Account.User.t(), String.t()) :: term
  def import_from_team_info_tableau_export(user, path_to_file) do
    %Upload{id: upload_id} = upload = insert_upload(user, path_to_file)

    allowed_regions = Account.get_regions_for_user(user)
    allowed_region_names = Enum.map(allowed_regions, & &1.name)
    allowed_regions_by_name = Map.new(allowed_regions, fn region -> {region.name, region} end)

    stream =
      path_to_file
      |> File.stream!([:trim_bom, encoding: {:utf16, :little}])
      |> RM.Import.TeamDataParser.parse_stream(skip_headers: false)

    [header] =
      stream
      |> Stream.take(1)
      |> Enum.to_list()

    {_count, teams} =
      stream
      |> Stream.drop(1)
      |> Stream.map(&Enum.zip(header, &1))
      |> Stream.map(&Map.new/1)
      |> Stream.filter(fn %{"Active Team" => status} -> status == "Active" end)
      |> Stream.filter(fn %{"Region" => region} -> region in allowed_region_names end)
      |> Stream.map(&Team.from_csv/1)
      |> Stream.map(&Team.put_region(&1, allowed_regions_by_name[&1.region].id))
      |> Stream.map(&Team.put_upload(&1, upload_id))
      |> Enum.to_list()
      |> insert_teams()

    %{teams: teams, upload: upload}
  end

  @spec insert_upload(Account.User.t(), String.t()) :: Upload.t()
  defp insert_upload(user, path_to_file) do
    Upload.new(user, path_to_file)
    |> Repo.insert!()
  end

  @spec insert_teams([Team.t()]) :: {integer, [Team.t()]}
  defp insert_teams(teams) do
    teams = Enum.map(teams, &Map.from_struct/1)
    Repo.insert_all(Team, teams, returning: true)
  end
end
