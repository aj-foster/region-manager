defmodule RM.Account.EventTest do
  use RM.DataCase

  alias RM.Account.Event

  describe "create_changeset/2" do
    test "associates the proposal and requires an email" do
      proposal = Factory.build(:event_proposal)

      changeset = Event.create_changeset(proposal, %{"email" => "host@example.com"})

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :email) == "host@example.com"
      assert Ecto.Changeset.get_field(changeset, :proposal) == proposal

      invalid_changeset = Event.create_changeset(proposal, %{})

      refute invalid_changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(invalid_changeset)
    end
  end

  describe "query builders" do
    test "user_update_query/1 updates matching IDs through confirmed email associations" do
      ids = [Ecto.UUID.generate()]

      query = Event.user_update_query(ids)

      assert query.updates != []
      assert length(query.wheres) == 1
      assert length(query.joins) == 1
    end

    test "user_update_by_email_query/1 updates assignments matching an email" do
      query = Event.user_update_by_email_query("user@example.com")

      assert query.updates != []
      assert length(query.wheres) == 1
      assert length(query.joins) == 1
    end

    test "user_remove_by_email_query/1 clears assignments matching an email" do
      query = Event.user_remove_by_email_query("user@example.com")

      assert query.updates != []
      assert length(query.wheres) == 1
    end
  end

  describe "compare/2" do
    test "compares assignments by their associated users" do
      alice = Factory.build(:user, profile: %RM.Account.Profile{name: "Alice"})
      bob = Factory.build(:user, profile: %RM.Account.Profile{name: "Bob"})
      alice_assignment = Factory.build(:user_event, user: alice)
      bob_assignment = Factory.build(:user_event, user: bob)

      assert Event.compare(alice_assignment, bob_assignment) == :lt
      assert Event.compare(bob_assignment, alice_assignment) == :gt
    end

    test "compares assignments by insertion time when users are not both present" do
      earlier = Factory.build(:user_event, user: nil, inserted_at: ~U[2026-01-01 00:00:00Z])
      later = Factory.build(:user_event, user: nil, inserted_at: ~U[2026-01-02 00:00:00Z])

      assert Event.compare(earlier, later) == :lt
      assert Event.compare(later, earlier) == :gt
    end
  end
end
