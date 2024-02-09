defmodule External.FTCEvents.API.Stub do
  @moduledoc """
  Test environment stub of the FTC Events API
  """
  @behaviour External.FTCEvents.API

  @impl true
  def list_leagues(_season, _opts \\ []) do
    {:ok, %{count: 0, leagues: []}}
  end

  @impl true
  def list_league_members(_season, _region, _league, _opts \\ []) do
    {:ok, []}
  end
end
