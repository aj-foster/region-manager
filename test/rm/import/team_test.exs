defmodule RM.Import.TeamTest do
  use RM.DataCase, async: true

  alias RM.Import.Team

  @fixture_import "test/fixture/import.csv"

  describe "from_csv/1" do
    test "parses Tableau values and normalizes imported contact data" do
      [header, row] =
        @fixture_import
        |> File.stream!([:trim_bom, encoding: {:utf16, :little}])
        |> RM.Import.TeamDataParser.parse_stream(skip_headers: false)
        |> Enum.take(2)

      team = Team.from_csv(Map.new(Enum.zip(header, row)))

      assert team.team_id == 101_111

      assert %DateTime{year: 2024, month: 7, day: 15, hour: 2, minute: 9, second: 22} =
               team.data_updated_at

      assert team.data.active
      assert team.data.event_ready
      assert team.data.intend_to_return
      assert team.data.secured
      assert team.data.secured_date == ~D[2024-06-01]
      assert team.data.temporary_number == 1111
      assert team.data.lc1_email == "aaronson@example.com"
      assert team.data.lc1_ypp
      assert is_nil(team.data.lc1_ypp_reason)
    end
  end

  test "metadata setters preserve the imported team while adding references" do
    team = %Team{team_id: 123}
    region_id = Ecto.UUID.generate()
    upload_id = Ecto.UUID.generate()

    team =
      team
      |> Team.put_region(region_id)
      |> Team.put_season(2025)
      |> Team.put_upload(upload_id)

    assert team.team_id == 123
    assert team.region_id == region_id
    assert team.season == 2025
    assert team.upload_id == upload_id
  end

  test "latest_by_team_id_query returns only requested teams' newest imports" do
    older = ~U[2024-01-01 00:00:00.000000Z]
    newer = ~U[2024-02-01 00:00:00.000000Z]

    for {team_id, imported_at} <- [{111, older}, {111, newer}, {222, older}, {333, newer}] do
      Repo.insert!(%Team{
        team_id: team_id,
        imported_at: imported_at,
        data_updated_at: older,
        region: "Florida",
        season: 2025
      })
    end

    results =
      Team.latest_by_team_id_query([111, 222])
      |> Repo.all()
      |> Enum.map(&{&1.team_id, &1.imported_at})
      |> Enum.sort()

    assert results == [{111, newer}, {222, older}]
  end
end
