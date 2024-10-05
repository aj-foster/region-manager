defmodule RM.Account.Auth do
  @moduledoc """
  Authorization helpers for actions across the application
  """
  alias RM.Account.User
  alias RM.FIRST.Event

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

  def can?(%User{} = user, :proposal_create, _data) do
    length(user.regions) > 1 or length(user.leagues) > 1
  end

  def can?(%User{} = user, :registration_settings_update, %Event{} = event) do
    event.region_id in region_ids(user) or
      (present?(event.local_league_id) and event.local_league_id in league_ids_with_events(user))
  end

  def can?(%User{} = user, :venue_virtual_toggle, %Event{} = event) do
    event.region_id in region_ids(user) or
      (present?(event.local_league_id) and event.local_league_id in league_ids_with_events(user))
  end

  # Default: deny the action.
  def can?(_user, _action, _data), do: false

  #
  # Helpers
  #

  # @spec league_ids(User.t()) :: [Ecto.UUID.t()]
  # defp league_ids(user), do: Enum.map(user.leagues, & &1.id)

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
