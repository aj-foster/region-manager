defmodule RM.Local.EventProposalTest do
  use RM.DataCase, async: true

  alias RM.Account.Event
  alias RM.Local

  describe "published event detail updates" do
    test "tracks the first proposal edit that differs from its published event" do
      region = Factory.insert(:region)
      date = Date.utc_today()

      venue =
        Factory.insert(:venue,
          name: "Published Venue",
          address: "123 Main St.",
          city: "Some City",
          country: "United States",
          state_province: "Florida",
          timezone: "Etc/UTC"
        )

      event =
        Factory.insert(:first_event,
          date_end: date,
          date_start: date,
          date_timezone: "Etc/UTC",
          hybrid: false,
          name: "Published Event",
          region: region,
          remote: false,
          type: :scrimmage,
          location: %RM.FIRST.Event.Location{
            address: venue.address,
            city: venue.city,
            country: "USA",
            state_province: "FL",
            venue: venue.name
          }
        )

      proposal =
        Factory.insert(:event_proposal,
          date_end: date,
          date_start: date,
          name: "Original Event",
          region: region,
          type: :scrimmage,
          venue: venue
        )

      assert is_nil(proposal.details_updated_at)

      assert :ok = Local.update_event_proposal_events([{proposal.id, event.id}])
      proposal = Repo.reload!(proposal) |> Repo.preload([:venue, :first_event])

      assert %DateTime{} = details_updated_at = proposal.details_updated_at
      assert proposal.first_event_id == event.id

      assert :ok = Local.update_event_proposal_events([{proposal.id, event.id}])
      assert Repo.reload!(proposal).details_updated_at == details_updated_at

      assert {:ok, updated_proposal} =
               Local.update_event(proposal, %{"name" => "Updated Event", "venue" => venue})

      assert updated_proposal.details_updated_at == details_updated_at

      assert {:ok, updated_proposal} =
               Local.update_event(updated_proposal, %{
                 "description" => "Additional details",
                 "name" => "Updated Event",
                 "venue" => venue
               })

      assert updated_proposal.details_updated_at == details_updated_at

      assert {:ok, updated_proposal} =
               Local.update_event(updated_proposal, %{"name" => event.name, "venue" => venue})

      assert is_nil(updated_proposal.details_updated_at)

      assert :ok = Local.update_event_proposal_events([{proposal.id, event.id}])
      assert is_nil(Repo.reload!(proposal).details_updated_at)
    end

    test "compares published country and state abbreviations without masking real changes" do
      date = ~D[2025-01-01]

      for {country, state, published_country, published_state, matches?} <- [
            {"United States", "Florida", "USA", "FL", true},
            {"United States", "Florida", "United States", "Florida", true},
            {"United States", "FL", "USA", "FL", true},
            {"Canada", "Québec", "Canada", "QC", true},
            {"Canada", "Ontario", "Canada", "ON", true},
            {"United States", "Florida", "USA", "CA", false},
            {"United States", "Florida", "Canada", "FL", false},
            {"Canada", "Ontario", "Canada", "CA", false},
            {"Canada", "Ontario", "USA", "ON", false},
            {"Mexico", "Unknown", "Mexico", "Unknown", true},
            {"Mexico", "Unknown", "Mexico", "XX", false},
            {"Mexico", "Unknown", "Mexico", nil, false},
            {"Mexico", "Unknown", nil, "Unknown", false},
            {nil, nil, nil, nil, true},
            {"United States", "Florida", "USA", nil, false}
          ] do
        venue = %RM.Local.Venue{
          name: "Venue",
          address: "Address",
          city: "City",
          country: country,
          state_province: state,
          timezone: "Etc/UTC"
        }

        event = %RM.FIRST.Event{
          date_end: date,
          date_start: date,
          date_timezone: venue.timezone,
          hybrid: false,
          remote: false,
          name: "Event",
          type: :scrimmage,
          location: %RM.FIRST.Event.Location{
            venue: venue.name,
            address: venue.address,
            city: venue.city,
            country: published_country,
            state_province: published_state
          }
        }

        proposal = %RM.Local.EventProposal{
          date_end: date,
          date_start: date,
          format: :traditional,
          name: event.name,
          type: event.type,
          venue: venue,
          first_event: event
        }

        changeset = RM.Local.EventProposal.details_updated_changeset(proposal)
        assert is_nil(Ecto.Changeset.get_field(changeset, :details_updated_at)) == matches?
      end
    end

    test "manual submission clears the detail update marker" do
      details_updated_at = DateTime.utc_now()

      proposal = Factory.insert(:event_proposal, details_updated_at: details_updated_at)

      assert :ok = Local.mark_event_proposal_submitted(proposal)

      assert %RM.Local.EventProposal{submitted_at: %DateTime{}, details_updated_at: nil} =
               Repo.reload!(proposal)
    end

    test "batch submission marking clears the detail update marker" do
      proposal = Factory.insert(:event_proposal, details_updated_at: DateTime.utc_now())

      RM.Local.EventProposal.mark_submitted_query([proposal])
      |> Repo.update_all([])

      assert %RM.Local.EventProposal{submitted_at: %DateTime{}, details_updated_at: nil} =
               Repo.reload!(proposal)
    end
  end

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
