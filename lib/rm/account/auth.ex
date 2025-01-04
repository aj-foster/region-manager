defmodule RM.Account.Auth do
  @moduledoc """
  Authorization helpers for actions across the application
  """
  alias RM.Account.User
  alias RM.FIRST
  alias RM.FIRST.Event
  alias RM.FIRST.Region
  alias RM.Local
  alias RM.Local.EventProposal
  alias RM.Local.Venue

  @doc """
  Returns whether the given `user` can perform the given `action`

  The user struct must have region, league, and team associations preloaded.

  Actions are represented as atoms, such as `:event_update`. If the action has a recipient piece
  of `data` (or other important context), it may also be included in the decision. By default, no
  action is allowed.
  """
  @spec can?(User.t() | nil, atom) :: boolean
  @spec can?(User.t() | nil, atom, term) :: boolean
  def can?(user, action, data \\ nil)

  #
  # Event Settings
  #

  # Update event settings for a published event
  def can?(%User{} = user, :event_settings_update, %Event{} = event) do
    event.region_id in region_ids(user) or
      (present?(event.local_league_id) and event.local_league_id in league_ids_with_events(user))
  end

  # Sync events with FTC Events API
  def can?(%User{} = user, :event_sync, %Region{id: region_id}) do
    region_id in region_ids(user)
  end

  #
  # Leagues
  #

  # Add league administrations
  def can?(%User{} = user, :league_add_user, %Local.League{} = league) do
    league.region_id in region_ids(user) or league.id in league_ids_with_users(user)
  end

  # Update default registration settings for a league
  def can?(%User{} = user, :league_settings_update, %Local.League{} = league) do
    league.region_id in region_ids(user) or league.id in league_ids_with_events(user)
  end

  # Sync leagues with FTC Events API
  def can?(%User{} = user, :league_sync, %Region{id: region_id}) do
    region_id in region_ids(user)
  end

  # Update information about published and unpublished leagues
  def can?(%User{} = user, :league_update, %FIRST.League{} = league) do
    league.region_id in region_ids(user)
  end

  def can?(%User{} = user, :league_update, %Region{} = region) do
    region.id in region_ids(user)
  end

  def can?(%User{} = user, :league_update, %Local.League{} = league) do
    league.region_id in region_ids(user)
  end

  #
  # Event Proposals
  #

  # Create a new event proposal
  def can?(%User{} = user, :proposal_create, %Region{id: region_id}) do
    region_id in region_ids(user)
  end

  def can?(%User{} = user, :proposal_create, %FIRST.League{
        local_league_id: league_id,
        region_id: region_id
      }) do
    region_id in region_ids(user) or
      (present?(league_id) and league_id in league_ids_with_events(user))
  end

  def can?(%User{} = user, :proposal_create, %Local.League{id: league_id, region_id: region_id}) do
    region_id in region_ids(user) or league_id in league_ids_with_events(user)
  end

  # List unpublished event proposals for a region or league
  def can?(%User{} = user, :proposal_index, %Region{id: region_id}) do
    region_id in region_ids(user)
  end

  def can?(%User{} = user, :proposal_index, %FIRST.League{
        local_league_id: league_id,
        region_id: region_id
      }) do
    region_id in region_ids(user) or
      (present?(league_id) and league_id in league_ids_with_events(user))
  end

  def can?(%User{} = user, :proposal_index, %Local.League{id: league_id, region_id: region_id}) do
    region_id in region_ids(user) or league_id in league_ids_with_events(user)
  end

  # See the original event proposal for a published event
  def can?(%User{} = user, :proposal_show, %Event{} = event) do
    event.region_id in region_ids(user) or
      (present?(event.local_league_id) and event.local_league_id in league_ids_with_events(user))
  end

  # See an unpublished event proposal
  def can?(%User{} = user, :proposal_show, %EventProposal{first_event_id: nil} = proposal) do
    proposal.region_id in region_ids(user) or
      (present?(proposal.league_id) and proposal.league_id in league_ids_with_events(user))
  end

  # See the original event proposal for a published event
  def can?(%User{} = user, :proposal_show, %EventProposal{first_event: event}) do
    can?(%User{} = user, :proposal_show, event)
  end

  # Submit Batch Create events in FTC Scoring
  def can?(%User{} = user, :proposal_submit, %Region{id: region_id}) do
    region_id in region_ids(user)
  end

  # Update the original event proposal for a published event
  def can?(%User{} = user, :proposal_update, %Event{} = event) do
    event.region_id in region_ids(user) or
      (present?(event.local_league_id) and event.local_league_id in league_ids_with_events(user))
  end

  # Update a proposal for an unpublished event
  def can?(%User{} = user, :proposal_update, %EventProposal{first_event_id: nil} = proposal) do
    proposal.region_id in region_ids(user) or
      (present?(proposal.league_id) and proposal.league_id in league_ids_with_events(user))
  end

  # Update the original event proposal for a published event
  def can?(%User{} = user, :proposal_update, %EventProposal{first_event: event}) do
    can?(%User{} = user, :proposal_update, event)
  end

  #
  # Registration Settings
  #

  # Update registration settings for a published event
  def can?(%User{} = user, :registration_settings_update, %Event{} = event) do
    event.region_id in region_ids(user) or
      (present?(event.local_league_id) and event.local_league_id in league_ids_with_events(user))
  end

  #
  # Teams
  #

  # See information about inactive teams
  def can?(%User{} = user, :team_inactive_show, %Region{id: region_id}) do
    region_id in region_ids(user)
  end

  def can?(%User{} = user, :team_inactive_show, %FIRST.League{
        region_id: region_id,
        local_league_id: league_id
      }) do
    region_id in region_ids(user) or (present?(league_id) and league_id in league_ids(user))
  end

  def can?(%User{} = user, :team_inactive_show, %Local.League{id: league_id, region_id: region_id}) do
    region_id in region_ids(user) or league_id in league_ids(user)
  end

  def can?(%User{} = user, :team_notices_show, %Local.Team{id: team_id}) do
    team_id in team_ids(user)
  end

  # Update league assignments
  def can?(%User{} = user, :team_league_update, %Region{} = region) do
    region.id in region_ids(user)
  end

  def can?(%User{} = user, :team_league_update, %Local.Team{} = team) do
    team.region_id in region_ids(user)
  end

  # See personally-identifiable information for teams
  def can?(%User{} = user, :team_pii_show, %Event{} = event) do
    event.region_id in region_ids(user) or
      (present?(event.local_league_id) and event.local_league_id in league_ids_with_contact(user))
  end

  def can?(%User{} = user, :team_pii_show, %Region{} = region) do
    region.id in region_ids(user)
  end

  def can?(%User{} = user, :team_pii_show, %FIRST.League{
        region_id: region_id,
        local_league_id: league_id
      }) do
    region_id in region_ids(user) or
      (present?(league_id) and league_id in league_ids_with_contact(user))
  end

  def can?(%User{} = user, :team_pii_show, %Local.League{id: league_id, region_id: region_id}) do
    region_id in region_ids(user) or league_id in league_ids_with_contact(user)
  end

  def can?(%User{} = user, :team_pii_show, %Local.Team{
        region_id: region_id,
        league: %Local.League{id: league_id}
      }) do
    region_id in region_ids(user) or league_id in league_ids_with_contact(user)
  end

  def can?(%User{} = user, :team_pii_show, %Local.Team{} = team) do
    team.region_id in region_ids(user)
  end

  def can?(%User{} = user, :team_update, %Region{} = region) do
    region.id in region_ids(user)
  end

  #
  # Venues
  #

  # Create new event venues for a region or league
  def can?(%User{} = user, :venue_create, %Region{id: region_id}) do
    region_id in region_ids(user)
  end

  def can?(%User{} = user, :venue_create, %Local.League{id: league_id, region_id: region_id}) do
    region_id in region_ids(user) or league_id in league_ids_with_events(user)
  end

  # List event venues for a region or league
  def can?(%User{} = user, :venue_index, %Region{id: region_id}) do
    region_id in region_ids(user)
  end

  def can?(%User{} = user, :venue_index, %Local.League{id: league_id, region_id: region_id}) do
    region_id in region_ids(user) or league_id in league_ids_with_events(user)
  end

  # See an event venue
  def can?(%User{} = user, :venue_show, %Venue{} = venue) do
    venue.region_id in region_ids(user) or
      (present?(venue.league_id) and venue.league_id in league_ids_with_events(user))
  end

  # Update an event venue
  def can?(%User{} = user, :venue_update, %Venue{} = venue) do
    venue.region_id in region_ids(user) or
      (present?(venue.league_id) and venue.league_id in league_ids_with_events(user))
  end

  # Change whether the venue address is visible for a published event
  def can?(%User{} = user, :venue_virtual_toggle, %Event{} = event) do
    event.region_id in region_ids(user) or
      (present?(event.local_league_id) and event.local_league_id in league_ids_with_events(user))
  end

  #
  # Default
  #

  # Default: deny the action.
  def can?(_user, _action, _data), do: false

  #
  # Helpers
  #

  @spec league_ids(User.t()) :: [Ecto.UUID.t()]
  defp league_ids(user), do: Enum.map(user.leagues, & &1.id)

  @spec league_ids_with_contact(User.t()) :: [Ecto.UUID.t()]
  defp league_ids_with_contact(user) do
    user.league_assignments
    |> Enum.filter(& &1.permissions.contact)
    |> Enum.map(& &1.league_id)
  end

  @spec league_ids_with_events(User.t()) :: [Ecto.UUID.t()]
  defp league_ids_with_events(user) do
    user.league_assignments
    |> Enum.filter(& &1.permissions.events)
    |> Enum.map(& &1.league_id)
  end

  @spec league_ids_with_users(User.t()) :: [Ecto.UUID.t()]
  defp league_ids_with_users(user) do
    user.league_assignments
    |> Enum.filter(& &1.permissions.users)
    |> Enum.map(& &1.league_id)
  end

  @spec present?(term) :: boolean
  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_data), do: true

  @spec region_ids(User.t()) :: [Ecto.UUID.t()]
  defp region_ids(user), do: Enum.map(user.regions, & &1.id)

  @spec team_ids(User.t()) :: [Ecto.UUID.t()]
  defp team_ids(user), do: Enum.map(user.teams, & &1.id)
end
