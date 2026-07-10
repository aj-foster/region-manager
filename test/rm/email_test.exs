defmodule RM.EmailTest do
  use RM.DataCase, async: true

  alias RM.Email
  alias RM.Email.Address
  alias RM.Email.List

  describe "known_address?/1" do
    test "returns true for a known address" do
      address = Factory.insert(:address)
      assert Email.known_address?(address.email)
      refute Email.known_address?("other-" <> address.email)
    end
  end

  describe "get_address/1" do
    test "returns the address for a known email" do
      address = Factory.insert(:address)
      assert Email.get_address(address.email).id == address.id
    end

    test "returns nil for an unknown email" do
      refute Email.get_address("unknown@example.com")
    end
  end

  describe "get_address_by_hashed_id/1" do
    test "returns the address for a known hashed_id" do
      address = Factory.insert(:address)
      assert Email.get_address_by_hashed_id(address.hashed_id).id == address.id
    end

    test "returns nil for an unknown hashed_id" do
      refute Email.get_address_by_hashed_id("unknownhashedid")
    end
  end

  describe "mark_email_undeliverable/2" do
    test "marks email as unreachable for complaint" do
      address = Factory.insert(:address)
      keila_project = create_keila_project()
      keila_contact = create_keila_contact(keila_project, address.email)

      assert {:ok, _} = Email.mark_email_undeliverable(address.email, :complaint)
      assert %Address{complained_at: %DateTime{}, sendable: false} = Repo.reload!(address)
      assert Keila.Repo.reload!(keila_contact).status == :unreachable
    end

    test "marks email as unreachable for permanent_bounce" do
      address = Factory.insert(:address)
      keila_project = create_keila_project()
      keila_contact = create_keila_contact(keila_project, address.email)

      assert {:ok, _} = Email.mark_email_undeliverable(address.email, :permanent_bounce)

      assert %Address{permanently_bounced_at: %DateTime{}, sendable: false} =
               Repo.reload!(address)

      assert Keila.Repo.reload!(keila_contact).status == :unreachable
    end

    test "marks email as unreachable after multiple bounces" do
      address = Factory.insert(:address)
      keila_project = create_keila_project()
      keila_contact = create_keila_contact(keila_project, address.email)

      # First bounce

      assert {:ok, _} = Email.mark_email_undeliverable(address.email, :temporary_bounce)

      assert %Address{bounce_count: 1, last_bounced_at: %DateTime{}, sendable: true} =
               Repo.reload!(address)

      assert Keila.Repo.reload!(keila_contact).status == :active

      # Second bounce

      assert {:ok, _} = Email.mark_email_undeliverable(address.email, :temporary_bounce)

      assert %Address{bounce_count: 2, sendable: false} = Repo.reload!(address)
      assert Keila.Repo.reload!(keila_contact).status == :unreachable
    end

    test "marks email as unsubscribed for unsubscribe" do
      address = Factory.insert(:address)
      keila_project = create_keila_project()
      keila_contact = create_keila_contact(keila_project, address.email)

      assert {:ok, _} = Email.mark_email_undeliverable(address.email, :unsubscribe)
      assert %Address{unsubscribed_at: %DateTime{}, sendable: false} = Repo.reload!(address)

      # Temporary: there is a bug that causes the contact to be marked as unreachable instead of unsubscribed.
      assert Keila.Repo.reload!(keila_contact).status == :unreachable
    end
  end

  describe "resubscribe_address/1" do
    test "resubscribes an unsubscribed address" do
      address = Factory.insert(:address, unsubscribed_at: DateTime.utc_now())
      keila_project = create_keila_project()
      keila_contact = create_keila_contact(keila_project, address.email)
      Keila.Contacts.downgrade_contact_status(keila_contact.id, :unsubscribed)

      assert {:ok, _} = Email.resubscribe_address(address)
      assert %Address{unsubscribed_at: nil, sendable: true} = Repo.reload!(address)
      assert Keila.Repo.reload!(keila_contact).status == :active
    end
  end

  describe "create_list/1" do
    test "creates a list with valid data" do
      params = %{
        "name" => "Test List",
        "description" => "A list for testing",
        "auto_subscribe" => %{
          "admins" => true,
          "coaches" => false,
          "league_admins" => true
        },
        "metadata" => %{
          "subscriber_count" => 10
        }
      }

      assert {:ok, %List{} = list} = Email.create_list(params)
      assert list.name == "Test List"
      assert list.description == "A list for testing"
      assert list.auto_subscribe.admins == true
      assert list.auto_subscribe.coaches == false
      assert list.auto_subscribe.league_admins == true
      assert list.metadata.subscriber_count == 10
    end

    test "fails to create a list with missing required fields" do
      params = %{
        "description" => "Missing name field"
      }

      assert {:error, changeset} = Email.create_list(params)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails to create a list with invalid auto_subscribe data" do
      params = %{
        "name" => "Invalid Auto Subscribe",
        "auto_subscribe" => %{
          # Invalid boolean value
          "admins" => "yes",
          "coaches" => false,
          "league_admins" => true
        }
      }

      assert {:error, changeset} = Email.create_list(params)
      assert %{auto_subscribe: %{admins: ["is invalid"]}} = errors_on(changeset)
    end
  end

  describe "sync_project_for_region/1" do
    test "syncs the project for a given region" do
      region = Factory.insert(:region)

      Email.sync_project_for_region(region)
      assert [project] = Keila.Repo.all(Keila.Projects.Project)
      assert project.name == "#{region.name} Region (#{region.code})"

      Ecto.Changeset.change(region, name: "Updated Name") |> Repo.update!()
      region = Repo.reload!(region)

      Email.sync_project_for_region(region)
      assert [project] = Keila.Repo.all(Keila.Projects.Project)
      assert project.name == "Updated Name Region (#{region.code})"
    end
  end

  describe "sync_segment_for_region/1" do
    test "syncs the segment for a given region" do
      keila_project = create_keila_project()
      region = Factory.insert(:region, metadata: %{keila_project_id: keila_project.id})

      Email.sync_segment_for_region(region)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)
      assert segment.name == "#{region.name} Region (#{region.code})"

      Ecto.Changeset.change(region, name: "Updated Name") |> Repo.update!()
      region = Repo.reload!(region)

      Email.sync_segment_for_region(region)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)
      assert segment.name == "Updated Name Region (#{region.code})"
    end
  end

  describe "sync_coach_segment_for_region/1" do
    test "syncs the coach segment for a given region" do
      keila_project = create_keila_project()
      region = Factory.insert(:region, metadata: %{keila_project_id: keila_project.id})

      Email.sync_coach_segment_for_region(region)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)
      assert segment.name == "#{region.name} Region Coaches (#{region.code})"

      Ecto.Changeset.change(region, name: "Updated Name") |> Repo.update!()
      region = Repo.reload!(region)

      Email.sync_coach_segment_for_region(region)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)
      assert segment.name == "Updated Name Region Coaches (#{region.code})"
    end
  end

  describe "sync_extended_coach_segment_for_region/1" do
    test "syncs the extended coach segment for a given region" do
      keila_project = create_keila_project()
      region = Factory.insert(:region, metadata: %{keila_project_id: keila_project.id})

      Email.sync_extended_coach_segment_for_region(region)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)
      assert segment.name == "#{region.name} Region Coaches Extended (#{region.code})"

      Ecto.Changeset.change(region, name: "Updated Name") |> Repo.update!()
      region = Repo.reload!(region)

      Email.sync_extended_coach_segment_for_region(region)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)
      assert segment.name == "Updated Name Region Coaches Extended (#{region.code})"
    end
  end

  describe "sync_segment_for_league/1" do
    test "syncs the segment for a given league" do
      keila_project = create_keila_project()
      region = Factory.insert(:region, metadata: %{keila_project_id: keila_project.id})
      league = Factory.insert(:league, region: region)

      Email.sync_segment_for_league(region, league)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)
      assert segment.name == "#{region.name} #{league.name} League (#{region.code}#{league.code})"

      Ecto.Changeset.change(league, name: "Updated Name") |> Repo.update!()
      league = Repo.reload!(league)

      Email.sync_segment_for_league(region, league)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)
      assert segment.name == "#{region.name} Updated Name League (#{region.code}#{league.code})"
    end
  end

  describe "sync_coach_segment_for_league/1" do
    test "syncs the coach segment for a given league" do
      keila_project = create_keila_project()
      region = Factory.insert(:region, metadata: %{keila_project_id: keila_project.id})
      league = Factory.insert(:league, region: region)

      Email.sync_coach_segment_for_league(region, league)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)

      assert segment.name ==
               "#{region.name} #{league.name} League Coaches (#{region.code}#{league.code})"

      Ecto.Changeset.change(league, name: "Updated Name") |> Repo.update!()
      league = Repo.reload!(league)

      Email.sync_coach_segment_for_league(region, league)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)

      assert segment.name ==
               "#{region.name} Updated Name League Coaches (#{region.code}#{league.code})"
    end
  end

  describe "sync_extended_coach_segment_for_league/1" do
    test "syncs the extended coach segment for a given league" do
      keila_project = create_keila_project()
      region = Factory.insert(:region, metadata: %{keila_project_id: keila_project.id})
      league = Factory.insert(:league, region: region)

      Email.sync_extended_coach_segment_for_league(region, league)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)

      assert segment.name ==
               "#{region.name} #{league.name} League Coaches Extended (#{region.code}#{league.code})"

      Ecto.Changeset.change(league, name: "Updated Name") |> Repo.update!()
      league = Repo.reload!(league)

      Email.sync_extended_coach_segment_for_league(region, league)
      assert [segment] = Keila.Repo.all(Keila.Contacts.Segment)

      assert segment.name ==
               "#{region.name} Updated Name League Coaches Extended (#{region.code}#{league.code})"
    end
  end

  describe "sync_coach_contacts_for_team/1" do
    test "syncs the coach contacts for a given team" do
      keila_project = create_keila_project()
      region = Factory.insert(:region, metadata: %{keila_project_id: keila_project.id})
      league = Factory.insert(:league, region: region)
      team = Factory.insert(:team, region: region)
      Factory.insert(:league_assignment, league: league, team: team)
      ut1 = Factory.insert(:user_team, team: team, relationship: :lc1)
      ut2 = Factory.insert(:user_team, team: team, relationship: :lc2)

      Email.sync_coach_contacts_for_team(team)

      assert [contact1, contact2] = Keila.Repo.all(Keila.Contacts.Contact)
      assert MapSet.new([contact1.email, contact2.email]) == MapSet.new([ut1.email, ut2.email])
    end
  end

  describe "list_contacts_by_email/1" do
    test "returns contacts with the given email across all projects" do
      email = "test-#{System.unique_integer()}@example.com"
      keila_project1 = create_keila_project()
      keila_project2 = create_keila_project()

      Keila.Contacts.create_contact(keila_project1.id, %{email: email})
      Keila.Contacts.create_contact(keila_project2.id, %{email: email})
      Keila.Contacts.create_contact(keila_project1.id, %{email: "other-#{email}"})

      assert Email.list_contacts_by_email(email) |> length() == 2
    end
  end

  defp create_keila_project do
    %{name: "Test Project", group_id: Keila.Auth.root_group().id}
    |> Keila.Projects.Project.creation_changeset()
    |> Keila.Repo.insert!()
  end

  defp create_keila_contact(project, email) do
    %{email: email}
    |> Keila.Contacts.Contact.creation_changeset(project.id)
    |> Keila.Repo.insert!()
  end
end
