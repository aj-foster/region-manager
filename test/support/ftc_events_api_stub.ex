defmodule External.FTCEvents.API.Stub do
  @moduledoc """
  Test environment stub of the FTC Events API
  """
  @behaviour External.FTCEvents.API

  @impl true
  def list_events(_season, _opts \\ []) do
    {:ok, %{count: 0, events: []}}
  end

  @impl true
  def list_leagues(_season, _opts \\ []) do
    {:ok, %{count: 0, leagues: []}}
  end

  @impl true
  def list_league_members(_season, _region, _league, _opts \\ []) do
    {:ok, []}
  end

  @impl true
  def list_teams(_season, _region, _opts \\ []) do
    {:ok,
     %{
       teams: [],
       team_count_total: 0,
       team_count_page: 0,
       page_current: 0,
       page_total: 0
     }}
  end
end
