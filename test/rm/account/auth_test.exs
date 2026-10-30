defmodule RM.Account.AuthTest do
  use RM.DataCase, async: true

  alias RM.Account
  alias RM.Account.Auth
  alias RM.Account.User
  alias RM.FIRST.Event
  alias RM.Local.EventProposal

  describe "proposal access through event assignments" do
    test "grants show and update access to assigned event proposals" do
      proposal_id = Ecto.UUID.generate()
      user = user_with_event_assignment(proposal_id)
      proposal = %EventProposal{id: proposal_id}

      assert Auth.can?(user, :proposal_show, proposal)
      assert Auth.can?(user, :proposal_update, proposal)
    end

    test "does not grant access to unassigned event proposals" do
      user = user_with_event_assignment(Ecto.UUID.generate())
      proposal = %EventProposal{id: Ecto.UUID.generate()}

      refute Auth.can?(user, :proposal_show, proposal)
      refute Auth.can?(user, :proposal_update, proposal)
    end

    test "grants access to assigned published event proposals" do
      proposal_id = Ecto.UUID.generate()
      user = user_with_event_assignment(proposal_id)

      proposal = %EventProposal{
        id: proposal_id,
        first_event_id: Ecto.UUID.generate(),
        first_event: %Event{}
      }

      assert Auth.can?(user, :proposal_show, proposal)
      assert Auth.can?(user, :proposal_update, proposal)
    end
  end

  defp user_with_event_assignment(proposal_id) do
    %User{
      event_assignments: [%Account.Event{proposal_id: proposal_id}],
      league_assignments: [],
      leagues: [],
      regions: [],
      teams: []
    }
  end
end
