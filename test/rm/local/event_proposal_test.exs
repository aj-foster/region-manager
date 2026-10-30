defmodule RM.Local.EventProposalTest do
  use RM.DataCase, async: true

  alias RM.Account.Event
  alias RM.Local

  describe "director association" do
    test "links a confirmed user when a proposal is created" do
      email = "director@example.com"
      user = insert_user_with_email(email)
      region = Factory.insert(:region)
      venue = Factory.insert(:venue, region: region, league: nil)

      assert {:ok, proposal} = Local.create_event(proposal_params(region, venue, email))

      assert %Event{email: ^email, proposal_id: proposal_id, user_id: user_id} =
               Repo.get_by!(Event, proposal_id: proposal.id)

      assert proposal_id == proposal.id
      assert user_id == user.id
      assert RM.Email.known_address?(email)
    end

    test "stores a director email without a matching account" do
      email = "unregistered-director@example.com"
      region = Factory.insert(:region)
      venue = Factory.insert(:venue, region: region, league: nil)

      assert {:ok, proposal} = Local.create_event(proposal_params(region, venue, email))

      assert %Event{email: ^email, user_id: nil} =
               Repo.get_by!(Event, proposal_id: proposal.id)

      assert RM.Email.known_address?(email)
    end

    test "does not link or recognize an invalid director email" do
      email = "invalid-email"
      region = Factory.insert(:region)
      venue = Factory.insert(:venue, region: region, league: nil)

      assert {:ok, proposal} = Local.create_event(proposal_params(region, venue, email))

      assert Repo.get_by(Event, proposal_id: proposal.id) == nil
      refute RM.Email.known_address?(email)
    end

    test "updates the director association when a proposal is updated" do
      email = "new-director@example.com"
      user = insert_user_with_email(email)
      proposal = Factory.insert(:event_proposal)

      assert {:ok, updated_proposal} =
               Local.update_event(proposal, %{
                 "contact" => %{
                   "email" => email,
                   "name" => "Event Director",
                   "phone" => "123-456-7890"
                 },
                 "venue" => proposal.venue
               })

      assert %Event{email: ^email, user_id: user_id} =
               Repo.get_by!(Event, proposal_id: updated_proposal.id)

      assert user_id == user.id
      assert Repo.aggregate(Event, :count, :id) == 1
      assert RM.Email.known_address?(email)
    end

    test "removes an existing association when the director email becomes invalid" do
      email = "invalid-email"
      region = Factory.insert(:region)
      venue = Factory.insert(:venue, region: region, league: nil)

      assert {:ok, proposal} =
               Local.create_event(proposal_params(region, venue, "director@example.com"))

      assert {:ok, updated_proposal} =
               Local.update_event(proposal, %{
                 "contact" => %{
                   "email" => email,
                   "name" => "Event Director",
                   "phone" => "123-456-7890"
                 },
                 "venue" => proposal.venue
               })

      assert Repo.get_by(Event, proposal_id: updated_proposal.id) == nil
      refute RM.Email.known_address?(email)
    end
  end

  defp insert_user_with_email(email) do
    Factory.insert(:user, emails: [Factory.build(:user_email, email: email)])
  end

  defp proposal_params(region, venue, email) do
    %{
      "contact" => %{
        "email" => email,
        "name" => "Event Director",
        "phone" => "123-456-7890"
      },
      "date_end" => Date.utc_today(),
      "date_start" => Date.utc_today(),
      "format" => "traditional",
      "name" => "Proposed Event",
      "region" => region,
      "season" => region.current_season,
      "type" => "scrimmage",
      "venue" => venue
    }
  end
end
