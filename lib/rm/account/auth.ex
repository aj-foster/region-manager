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

  #
  # Leagues
  #

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

  def can?(%User{} = user, :proposal_create, %Local.League{id: league_id, region_id: region_id}) do
    region_id in region_ids(user) or league_id in league_ids_with_events(user)
  end

  # List unpublished event proposals for a region or league
  def can?(%User{} = user, :proposal_index, %Region{id: region_id}) do
    region_id in region_ids(user)
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

  # See personally-identifiable information for registered teams
  def can?(%User{} = user, :team_pii_show, %Event{} = event) do
    event.region_id in region_ids(user) or
      (present?(event.local_league_id) and event.local_league_id in league_ids_with_contact(user))
  end

  #
  # Venues
  #

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

  # @spec league_ids(User.t()) :: [Ecto.UUID.t()]
  # defp league_ids(user), do: Enum.map(user.leagues, & &1.id)

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

  @spec present?(term) :: boolean
  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_data), do: true

  @spec region_ids(User.t()) :: [Ecto.UUID.t()]
  defp region_ids(user), do: Enum.map(user.regions, & &1.id)
end
