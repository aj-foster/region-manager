defmodule RM.AccountTest do
  use RM.DataCase, async: true

  alias RM.Account
  alias RM.Account.Event
  alias RM.Account.League
  alias RM.Account.Team

  describe "confirm_email/1" do
    test "links matching team, league, and event assignments to the user" do
      user = Factory.insert(:user)
      email = "director@example.com"
      assignments = insert_resource_assignments(email, nil)
      token = create_email_token(user, email)

      assert {:ok, confirmed_email} = Account.confirm_email(token)
      assert confirmed_email.email == email
      assert confirmed_email.confirmed_at

      assert_assignments_linked(assignments, user.id)
    end
  end

  describe "delete_email/2" do
    test "unlinks matching team, league, and event assignments from the user" do
      user = Factory.insert(:user)
      email = "director@example.com"
      assignments = insert_resource_assignments(email, user.id)
      token = create_email_token(user, email)
      assert {:ok, _confirmed_email} = Identity.confirm_email(token)

      assert :ok = Account.delete_email(user, email)

      assert Repo.get_by(Identity.Schema.Email, email: email) == nil
      assert_assignments_linked(assignments, nil)
    end
  end

  defp create_email_token(user, email) do
    token_ref = make_ref()

    assert :ok =
             Identity.create_email(user, email,
               token_url: fn token ->
                 send(self(), {token_ref, token})
                 token
               end
             )

    assert_receive {^token_ref, token}
    token
  end

  defp insert_resource_assignments(email, user_id) do
    team = Factory.insert(:team)

    team_assignment =
      Repo.insert!(%Team{
        email: email,
        name: "Event Director",
        relationship: :lc1,
        team_id: team.id,
        user_id: user_id
      })

    league = Factory.insert(:league)

    league_assignment =
      League.create_changeset(league, %{email: email})
      |> put_change(:user_id, user_id)
      |> Repo.insert!()

    proposal = Factory.insert(:event_proposal)

    event_assignment =
      Event.create_changeset(proposal, %{email: email})
      |> put_change(:user_id, user_id)
      |> Repo.insert!()

    %{team: team_assignment, league: league_assignment, event: event_assignment}
  end

  defp assert_assignments_linked(assignments, user_id) do
    assert Repo.get!(Team, assignments.team.id).user_id == user_id
    assert Repo.get!(League, assignments.league.id).user_id == user_id
    assert Repo.get!(Event, assignments.event.id).user_id == user_id
  end
end
