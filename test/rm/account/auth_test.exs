defmodule RM.Account.AuthTest do
  use RM.DataCase, async: true

  alias RM.Account
  alias RM.Account.Auth
  alias RM.Account.User
  alias RM.FIRST
  alias RM.Local

  describe "email list and message access" do
    test "region admins can access region email lists and send messages" do
      region_id = id()
      user = user(regions: [%FIRST.Region{id: region_id}])
      region = %FIRST.Region{id: region_id}

      assert Auth.can?(user, :email_list_index, region)
      assert Auth.can?(user, :email_message_send, region)
      refute Auth.can?(user, :email_list_index, %FIRST.Region{id: id()})
      refute Auth.can?(user, :email_message_send, %FIRST.Region{id: id()})
    end

    test "league email permissions allow league email access" do
      league_id = id()
      league = %Local.League{id: league_id, region_id: id()}
      user = user(league_assignments: [league_assignment(league_id, email: true)])

      assert Auth.can?(user, :email_list_index, league)
      assert Auth.can?(user, :email_message_send, league)

      no_email_permission = user(league_assignments: [league_assignment(league_id)])
      refute Auth.can?(no_email_permission, :email_list_index, league)
      refute Auth.can?(no_email_permission, :email_message_send, league)
    end
  end

  describe "event settings access" do
    test "region admins and event-enabled league admins can update event settings" do
      region_id = id()
      league_id = id()
      event = %FIRST.Event{region_id: region_id, local_league_id: league_id}

      assert Auth.can?(
               user(regions: [%FIRST.Region{id: region_id}]),
               :event_settings_update,
               event
             )

      assert Auth.can?(
               user(league_assignments: [league_assignment(league_id, events: true)]),
               :event_settings_update,
               event
             )

      refute Auth.can?(user(), :event_settings_update, event)

      refute Auth.can?(
               user(league_assignments: [league_assignment(league_id)]),
               :event_settings_update,
               event
             )
    end

    test "region admins can sync events" do
      region_id = id()
      region = %FIRST.Region{id: region_id}

      assert Auth.can?(user(regions: [region]), :event_sync, region)
      refute Auth.can?(user(), :event_sync, region)
    end

    test "registration settings follow event settings permissions" do
      region_id = id()
      league_id = id()
      event = %FIRST.Event{region_id: region_id, local_league_id: league_id}

      assert Auth.can?(
               user(regions: [%FIRST.Region{id: region_id}]),
               :registration_settings_update,
               event
             )

      assert Auth.can?(
               user(league_assignments: [league_assignment(league_id, events: true)]),
               :registration_settings_update,
               event
             )

      refute Auth.can?(user(), :registration_settings_update, event)
    end
  end

  describe "event proposal access" do
    test "region admins can create proposals and access proposal indexes" do
      region_id = id()
      region = %FIRST.Region{id: region_id}
      user = user(regions: [region])

      assert Auth.can?(user, :proposal_create, region)
      assert Auth.can?(user, :proposal_index, region)
      assert Auth.can?(user, :proposal_submit, region)

      refute Auth.can?(user(), :proposal_create, region)
      refute Auth.can?(user(), :proposal_index, region)
      refute Auth.can?(user(), :proposal_submit, region)
    end

    test "event-enabled league admins can create proposals and access league indexes" do
      region_id = id()
      league_id = id()
      user = user(league_assignments: [league_assignment(league_id, events: true)])
      first_league = %FIRST.League{region_id: region_id, local_league_id: league_id}
      local_league = %Local.League{id: league_id, region_id: region_id}

      for action <- [:proposal_create, :proposal_index] do
        assert Auth.can?(user, action, first_league)
        assert Auth.can?(user, action, local_league)
        refute Auth.can?(user(), action, first_league)
        refute Auth.can?(user(), action, local_league)
      end

      assert Auth.can?(
               user(regions: [%FIRST.Region{id: region_id}]),
               :proposal_create,
               %FIRST.League{region_id: region_id}
             )

      refute Auth.can?(user(), :proposal_create, %FIRST.League{region_id: region_id})
      refute Auth.can?(user(), :proposal_index, %FIRST.League{region_id: region_id})
    end

    test "event or region assignments allow showing and updating proposals" do
      region_id = id()
      proposal_id = id()
      proposal = %Local.EventProposal{id: proposal_id, region_id: region_id}

      assert Auth.can?(user(regions: [%FIRST.Region{id: region_id}]), :proposal_show, proposal)
      assert Auth.can?(user(regions: [%FIRST.Region{id: region_id}]), :proposal_update, proposal)

      assert Auth.can?(
               user(event_assignments: [%Account.Event{proposal_id: proposal_id}]),
               :proposal_show,
               proposal
             )

      assert Auth.can?(
               user(event_assignments: [%Account.Event{proposal_id: proposal_id}]),
               :proposal_update,
               proposal
             )

      refute Auth.can?(user(), :proposal_show, proposal)
      refute Auth.can?(user(), :proposal_update, proposal)
    end

    test "event-enabled league admins can show and update proposals for their league" do
      league_id = id()
      proposal = %Local.EventProposal{league_id: league_id}
      user = user(league_assignments: [league_assignment(league_id, events: true)])

      assert Auth.can?(user, :proposal_show, proposal)
      assert Auth.can?(user, :proposal_update, proposal)
      refute Auth.can?(user(), :proposal_show, proposal)
      refute Auth.can?(user(), :proposal_update, proposal)
    end

    test "published events allow access through region or event-enabled league" do
      region_id = id()
      league_id = id()
      event = %FIRST.Event{region_id: region_id, local_league_id: league_id}
      region_user = user(regions: [%FIRST.Region{id: region_id}])
      league_user = user(league_assignments: [league_assignment(league_id, events: true)])

      for action <- [:proposal_show, :proposal_update] do
        assert Auth.can?(region_user, action, event)
        assert Auth.can?(league_user, action, event)
        refute Auth.can?(user(), action, event)
      end
    end

    test "assigned users can access their published proposals" do
      proposal_id = id()
      user = user(event_assignments: [%Account.Event{proposal_id: proposal_id}])
      proposal = %Local.EventProposal{id: proposal_id, first_event: %FIRST.Event{}}

      assert Auth.can?(user, :proposal_show, proposal)
      assert Auth.can?(user, :proposal_update, proposal)
    end
  end

  describe "league access" do
    test "region admins or league users with the users permission can add league users" do
      region_id = id()
      league_id = id()
      league = %Local.League{id: league_id, region_id: region_id}

      assert Auth.can?(user(regions: [%FIRST.Region{id: region_id}]), :league_add_user, league)

      assert Auth.can?(
               user(league_assignments: [league_assignment(league_id, users: true)]),
               :league_add_user,
               league
             )

      refute Auth.can?(
               user(league_assignments: [league_assignment(league_id)]),
               :league_add_user,
               league
             )
    end

    test "region admins can create and sync leagues" do
      region_id = id()
      region = %FIRST.Region{id: region_id}
      user = user(regions: [region])

      assert Auth.can?(user, :league_create, region)
      assert Auth.can?(user, :league_sync, region)
      refute Auth.can?(user(), :league_create, region)
      refute Auth.can?(user(), :league_sync, region)
    end

    test "region admins or event-enabled league admins can update league settings" do
      region_id = id()
      league_id = id()
      league = %Local.League{id: league_id, region_id: region_id}

      assert Auth.can?(
               user(regions: [%FIRST.Region{id: region_id}]),
               :league_settings_update,
               league
             )

      assert Auth.can?(
               user(league_assignments: [league_assignment(league_id, events: true)]),
               :league_settings_update,
               league
             )

      refute Auth.can?(user(), :league_settings_update, league)
    end

    test "region admins can update FIRST, region, and local league records" do
      region_id = id()
      user = user(regions: [%FIRST.Region{id: region_id}])
      first_league = %FIRST.League{region_id: region_id}
      region = %FIRST.Region{id: region_id}
      local_league = %Local.League{region_id: region_id}

      assert Auth.can?(user, :league_update, first_league)
      assert Auth.can?(user, :league_update, region)
      assert Auth.can?(user, :league_update, local_league)

      refute Auth.can?(user(), :league_update, first_league)
      refute Auth.can?(user(), :league_update, region)
      refute Auth.can?(user(), :league_update, local_league)
    end
  end

  describe "season access" do
    test "only admins can create a season" do
      assert Auth.can?(user(admin: %Account.Admin{}), :season_create, nil)
      refute Auth.can?(user(), :season_create, nil)
    end
  end

  describe "team access" do
    test "inactive team visibility is granted to region admins or direct league members" do
      region_id = id()
      league_id = id()
      region = %FIRST.Region{id: region_id}
      first_league = %FIRST.League{region_id: region_id, local_league_id: league_id}
      local_league = %Local.League{id: league_id, region_id: region_id}

      assert Auth.can?(user(regions: [region]), :team_inactive_show, region)
      assert Auth.can?(user(regions: [region]), :team_inactive_show, first_league)
      assert Auth.can?(user(regions: [region]), :team_inactive_show, local_league)

      assert Auth.can?(
               user(leagues: [%Local.League{id: league_id}]),
               :team_inactive_show,
               first_league
             )

      assert Auth.can?(
               user(leagues: [%Local.League{id: league_id}]),
               :team_inactive_show,
               local_league
             )

      refute Auth.can?(user(), :team_inactive_show, region)
      refute Auth.can?(user(), :team_inactive_show, first_league)
      refute Auth.can?(user(), :team_inactive_show, local_league)
    end

    test "team members can see their notices" do
      team_id = id()
      team = %Local.Team{id: team_id}

      assert Auth.can?(user(teams: [team]), :team_notices_show, team)
      refute Auth.can?(user(), :team_notices_show, team)
    end

    test "only region admins can update team league assignments or team records" do
      region_id = id()
      region = %FIRST.Region{id: region_id}
      team = %Local.Team{region_id: region_id}
      user = user(regions: [region])

      assert Auth.can?(user, :team_league_update, region)
      assert Auth.can?(user, :team_league_update, team)
      assert Auth.can?(user, :team_update, region)
      refute Auth.can?(user(), :team_league_update, region)
      refute Auth.can?(user(), :team_league_update, team)
      refute Auth.can?(user(), :team_update, region)
    end

    test "team PII is visible to region admins or league contacts" do
      region_id = id()
      league_id = id()
      team_id = id()
      event = %FIRST.Event{region_id: region_id, local_league_id: league_id}
      region = %FIRST.Region{id: region_id}
      first_league = %FIRST.League{region_id: region_id, local_league_id: league_id}
      local_league = %Local.League{id: league_id, region_id: region_id}

      team_with_league = %Local.Team{
        region_id: region_id,
        league: %Local.League{id: league_id}
      }

      team_without_league = %Local.Team{id: team_id, region_id: region_id}
      region_user = user(regions: [%FIRST.Region{id: region_id}])
      contact_user = user(league_assignments: [league_assignment(league_id, contact: true)])

      for data <- [
            event,
            region,
            first_league,
            local_league,
            team_with_league,
            team_without_league
          ] do
        assert Auth.can?(region_user, :team_pii_show, data)
      end

      for data <- [event, first_league, local_league, team_with_league] do
        assert Auth.can?(contact_user, :team_pii_show, data)
      end

      refute Auth.can?(user(), :team_pii_show, event)
      refute Auth.can?(user(), :team_pii_show, region)
      refute Auth.can?(user(), :team_pii_show, first_league)
      refute Auth.can?(user(), :team_pii_show, local_league)
      refute Auth.can?(user(), :team_pii_show, team_without_league)

      refute Auth.can?(
               user(league_assignments: [league_assignment(league_id)]),
               :team_pii_show,
               event
             )
    end
  end

  describe "venue access" do
    test "region admins and event-enabled league admins can create and list venues" do
      region_id = id()
      league_id = id()
      region = %FIRST.Region{id: region_id}
      local_league = %Local.League{id: league_id, region_id: region_id}
      region_user = user(regions: [region])
      league_user = user(league_assignments: [league_assignment(league_id, events: true)])

      for action <- [:venue_create, :venue_index] do
        assert Auth.can?(region_user, action, region)
        assert Auth.can?(region_user, action, local_league)
        assert Auth.can?(league_user, action, local_league)
        refute Auth.can?(user(), action, region)
        refute Auth.can?(user(), action, local_league)

        refute Auth.can?(
                 user(league_assignments: [league_assignment(league_id)]),
                 action,
                 local_league
               )
      end
    end

    test "region admins and event-enabled league admins can see and update venues" do
      region_id = id()
      league_id = id()
      venue = %Local.Venue{region_id: region_id, league_id: league_id}
      region_user = user(regions: [%FIRST.Region{id: region_id}])
      league_user = user(league_assignments: [league_assignment(league_id, events: true)])

      for action <- [:venue_show, :venue_update] do
        assert Auth.can?(region_user, action, venue)
        assert Auth.can?(league_user, action, venue)
        refute Auth.can?(user(), action, venue)
        refute Auth.can?(user(league_assignments: [league_assignment(league_id)]), action, venue)
      end
    end
  end

  describe "default access" do
    test "denies unknown actions, unsupported data, and nil users" do
      assert Auth.can?(nil, :unknown_action, nil) == false
      refute Auth.can?(user(), :unknown_action, nil)
      refute Auth.can?(user(), :event_sync, %Local.League{})
      refute Auth.can?(user(), :team_update, %Local.Team{})
    end
  end

  defp user(opts \\ []) do
    struct!(
      User,
      Keyword.merge(
        [
          admin: nil,
          event_assignments: [],
          league_assignments: [],
          leagues: [],
          regions: [],
          teams: []
        ],
        opts
      )
    )
  end

  defp league_assignment(league_id, permissions \\ []) do
    permissions =
      Keyword.merge([contact: false, email: false, events: false, users: false], permissions)
      |> Enum.into(%{})
      |> then(&struct!(Account.League.Permissions, &1))

    %Account.League{league_id: league_id, permissions: permissions}
  end

  defp id, do: Ecto.UUID.generate()
end
