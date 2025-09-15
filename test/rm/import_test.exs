defmodule RM.ImportTest do
  use RM.DataCase, async: true

  alias RM.Import

  @fixture_import "test/fixture/import.csv"

  describe "import_from_team_info_tableau_export/2" do
    setup do
      Factory.insert(:user)
      |> Factory.with_region(name: "Florida")
    end

    test "imports teams", %{user: user} do
      Import.import_from_team_info_tableau_export(user, @fixture_import)
      |> assert_match(%{added: added, imported: imported, updated: [], upload: _})

      assert length(added) == 5
      assert length(imported) == 5

      assert_match_in added, %RM.Local.Team{active: true, event_ready: true, number: 1111}
      assert_match_in added, %RM.Local.Team{active: true, event_ready: false, number: 2222}
      assert_match_in added, %RM.Local.Team{active: false, event_ready: false, number: 3333}
      assert_match_in added, %RM.Local.Team{active: false, event_ready: false, number: 4444}
      assert_match_in added, %RM.Local.Team{active: false, event_ready: false, number: 5555}

      assert_match_in imported,
                      %RM.Import.Team{data: %{active: true, event_ready: true, number: 1111}}

      assert_match_in imported,
                      %RM.Import.Team{data: %{active: true, event_ready: false, number: 2222}}

      assert_match_in imported,
                      %RM.Import.Team{data: %{active: true, event_ready: false, number: 3333}}

      assert_match_in imported,
                      %RM.Import.Team{data: %{active: true, event_ready: false, number: 4444}}

      assert_match_in imported,
                      %RM.Import.Team{data: %{active: false, event_ready: false, number: 5555}}
    end

    test "updates teams", %{region: region, user: user} do
      team = Factory.insert(:team, region: region, number: 5555, team_id: 105_555)

      Import.import_from_team_info_tableau_export(user, @fixture_import)
      |> assert_match(%{added: added, imported: imported, updated: updated, upload: _})

      assert length(added) == 4
      assert length(imported) == 5
      assert length(updated) == 1

      assert %RM.Local.Team{active: false, event_ready: false, number: 5555} =
               RM.Repo.reload!(team)
    end

    test "updates active status across seasons", %{region: region, user: user} do
      Factory.insert(:team, active: false, region: region, number: 1111, team_id: 101_111)
      Factory.insert(:team, active: true, region: region, number: 4444, team_id: 104_444)
      Factory.insert(:team, active: true, region: region, number: 5555, team_id: 105_555)

      Import.import_from_team_info_tableau_export(user, @fixture_import)
      |> assert_match(%{added: added, imported: imported, updated: updated, upload: _})

      assert length(added) == 2
      assert length(imported) == 5
      assert length(updated) == 3

      assert_match_in updated, {%RM.Local.Team{active: true, event_ready: true, number: 1111}, _}

      assert_match_in updated,
                      {%RM.Local.Team{active: false, event_ready: false, number: 4444}, _}

      assert_match_in updated,
                      {%RM.Local.Team{active: false, event_ready: false, number: 5555}, _}
    end

    test "marks missing teams as inactive", %{region: region, user: user} do
      team = Factory.insert(:team, active: true, region: region, number: 6666, team_id: 106_666)

      Import.import_from_team_info_tableau_export(user, @fixture_import)

      Repo.reload!(team)
      |> assert_match(%RM.Local.Team{active: false, number: 6666, team_id: 106_666})
    end

    test "adds coach email addresses to list of known addresses", %{user: user} do
      Import.import_from_team_info_tableau_export(user, @fixture_import)

      Repo.all(RM.Email.Address)
      |> assert_match_in(%{email: "aaronson@example.com"})

      Import.import_from_team_info_tableau_export(user, @fixture_import)

      Repo.all(RM.Email.Address)
      |> assert_match_in(%{email: "aaronson@example.com"})
    end
  end
end
