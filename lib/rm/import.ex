defmodule RM.Import do
  require NimbleCSV

  alias RM.Import.Team
  alias RM.Repo

  NimbleCSV.define(RM.TeamDataParser,
    separator: "\t",
    escape: "\"",
    encoding: :utf8,
    trim_bom: true,
    dump_bom: true
  )

  def parse(_region, path_to_file) do
    # filename = "import-#{region}-#{System.os_time()}.csv"

    stream =
      path_to_file
      |> File.stream!([:trim_bom, encoding: {:utf16, :little}])
      |> RM.TeamDataParser.parse_stream(skip_headers: false)

    [header] =
      stream
      |> Stream.take(1)
      |> Enum.to_list()

    stream
    |> Stream.drop(1)
    |> Stream.map(&Enum.zip(header, &1))
    |> Stream.map(&Map.new/1)
    |> Stream.filter(fn %{"Active Team" => status} -> status == "Active" end)
    |> Stream.map(&insert_team/1)
    |> Stream.map(&IO.inspect/1)
    |> Enum.to_list()
    |> Enum.count()
    |> IO.inspect(label: "Count")
  end

  def insert_team(team_data) do
    team_data
    |> Team.from_csv()
    |> Repo.insert!()
  end
end
