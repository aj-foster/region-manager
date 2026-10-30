defmodule RMWeb.Live.UtilTest do
  use RM.DataCase, async: true

  alias Phoenix.Component
  alias Phoenix.LiveView.Socket
  alias RM.Account.Admin
  alias RM.Account.Event
  alias RM.Account.League, as: UserLeague
  alias RM.Account.Region, as: UserRegion
  alias RM.Local.LeagueAssignment
  alias RMWeb.Live.Util

  describe "refresh_user/1" do
    test "reloads user associations and applies their existing sorting and filtering" do
      season = 2025

      user =
        Factory.insert(:user,
          emails: [
            Factory.build(:user_email, email: "z@example.com", confirmed_at: nil),
            Factory.build(:user_email, email: "b@example.com"),
            Factory.build(:user_email, email: "a@example.com")
          ]
        )

      admin = Repo.insert!(%Admin{user_id: user.id})

      region_b = Factory.insert(:region, name: "Region B", current_season: season)
      region_a = Factory.insert(:region, name: "Region A", current_season: season)
      Repo.insert!(%UserRegion{user_id: user.id, region_id: region_b.id})
      Repo.insert!(%UserRegion{user_id: user.id, region_id: region_a.id})

      league_b = Factory.insert(:league, name: "League B", region: region_b)
      league_a = Factory.insert(:league, name: "League A", region: region_a)

      Repo.insert!(%UserLeague{
        email: "user@example.com",
        user_id: user.id,
        league_id: league_b.id
      })

      Repo.insert!(%UserLeague{
        email: "user@example.com",
        user_id: user.id,
        league_id: league_a.id
      })

      current_team_b =
        Factory.insert(:team, region: region_a, season: season, number: 20)
        |> assign_to_league(league_a)

      current_team_a =
        Factory.insert(:team, region: region_a, season: season, number: 10)
        |> assign_to_league(league_a)

      old_team = Factory.insert(:team, region: region_a, season: season - 1, number: 5)

      Enum.each([current_team_b, current_team_a, old_team], fn team ->
        Factory.insert(:user_team, user: user, team: team)
      end)

      current_proposal = Factory.insert(:event_proposal, region: region_a, season: season)
      old_proposal = Factory.insert(:event_proposal, region: region_a, season: season - 1)

      current_assignment = insert_event_assignment(user, current_proposal)
      insert_event_assignment(user, old_proposal)

      refreshed_user =
        %Socket{}
        |> Component.assign(:current_user, user)
        |> Util.refresh_user()
        |> then(& &1.assigns.current_user)

      assert refreshed_user.id == user.id
      assert refreshed_user.admin.id == admin.id
      assert refreshed_user.profile.id == user.profile.id

      assert Enum.map(refreshed_user.emails, & &1.email) ==
               ["a@example.com", "b@example.com", "z@example.com"]

      assert Enum.map(refreshed_user.regions, & &1.name) == ["Region A", "Region B"]
      assert Enum.map(refreshed_user.leagues, & &1.name) == ["League A", "League B"]

      assert Enum.all?(refreshed_user.leagues, &Ecto.assoc_loaded?(&1.region))
      assert Enum.map(refreshed_user.teams, & &1.number) == [10, 20]
      assert Enum.all?(refreshed_user.teams, &Ecto.assoc_loaded?(&1.region))
      assert Enum.all?(refreshed_user.teams, &Ecto.assoc_loaded?(&1.league))

      [assignment] = refreshed_user.event_assignments
      assert assignment.id == current_assignment.id
      refute Ecto.assoc_loaded?(assignment.proposal)
    end

    test "leaves the socket unchanged when no user is assigned" do
      socket = %Socket{}

      assert Util.refresh_user(socket) == socket
    end
  end

  defp assign_to_league(team, league) do
    Repo.insert!(%LeagueAssignment{team_id: team.id, league_id: league.id})
    team
  end

  defp insert_event_assignment(user, proposal) do
    Event.create_changeset(proposal, %{email: "director@example.com"})
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert!()
  end
end
