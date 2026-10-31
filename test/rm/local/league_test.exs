defmodule RM.Local.LeagueTest do
  use RM.DataCase, async: true

  alias RM.Local
  alias RM.Local.LeagueSettings
  alias RM.Local.RegistrationSettings

  describe "create_league/2" do
    test "creates default league settings with the league" do
      region = Factory.insert(:region)

      assert {:ok, league} =
               Local.create_league(region, %{
                 "code" => "EX",
                 "location" => "Somewhere",
                 "name" => "Example"
               })

      assert %LeagueSettings{
               enable_email: false,
               registration: %RegistrationSettings{
                 deadline_days: 7,
                 enabled: true,
                 open_days: 21,
                 pool: :league
               }
             } = Repo.preload(league, :settings, force: true).settings
    end
  end

  describe "create_league_from_first/1" do
    test "creates default league settings with the league" do
      region = Factory.insert(:region)
      first_league = Factory.insert(:first_league, location: "Somewhere", region: region)

      assert {:ok, league} = Local.create_league_from_first(first_league)

      assert %LeagueSettings{
               enable_email: false,
               registration: %RegistrationSettings{
                 deadline_days: 7,
                 enabled: true,
                 open_days: 21,
                 pool: :league
               }
             } = Repo.preload(league, :settings, force: true).settings
    end
  end
end
