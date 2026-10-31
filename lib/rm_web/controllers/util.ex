defmodule RMWeb.Controller.Util do
  @moduledoc """
  Common controller plugs.
  """
  import Plug.Conn

  alias Plug.Conn

  @region_key :rm_preloaded_region

  @doc """
  Assign the current season based on path parameters or using the region's current season
  """
  @spec assign_season(Conn.t(), keyword) :: Conn.t()
  def assign_season(%Conn{path_params: %{"season" => season}} = conn, _opts) do
    case Integer.parse(season) do
      {season, ""} ->
        assign(conn, :season, season)

      _error ->
        conn
        |> send_resp(:not_found, "Invalid season")
        |> halt()
    end
  end

  def assign_season(conn, _opts) do
    if region = get_region(conn, []) do
      assign(conn, :season, region.current_season)
    else
      conn
      |> send_resp(:not_found, "Invalid season")
      |> halt()
    end
  end

  @doc """
  Assign a region context based on path parameters, possibly using pre-loaded data
  """
  @spec assign_region(Conn.t(), keyword) :: Conn.t()
  def assign_region(conn, opts) do
    if region = get_region(conn, opts) do
      assign(conn, :region, region)
    else
      conn
      |> send_resp(:not_found, "Region not found")
      |> halt()
    end
  end

  @spec get_region(Conn.t(), keyword) :: RM.FIRST.Region.t() | nil
  defp get_region(%Conn{assigns: %{region: %RM.FIRST.Region{} = region}}, opts) do
    RM.Repo.preload(region, opts[:preload] || [])
  end

  defp get_region(%Conn{private: %{@region_key => %RM.FIRST.Region{} = region}}, opts) do
    RM.Repo.preload(region, opts[:preload] || [])
  end

  defp get_region(%Conn{path_params: %{"region" => abbreviation}}, opts) do
    RM.FIRST.get_region_by_abbreviation(abbreviation, opts)
  end

  @doc """
  Assign an event context based on path parameters, using the current season from the connection
  """
  @spec assign_event(Conn.t(), keyword) :: Conn.t()
  def assign_event(%Conn{path_params: %{"event" => event_code}} = conn, opts) do
    season = conn.assigns.season
    region = get_region(conn, [])

    case RM.FIRST.fetch_event_by_code(season, event_code, opts) do
      {:ok, event} ->
        if region && region.id == event.region_id do
          assign(conn, :event, event)
        else
          conn
          |> send_resp(:not_found, "Event not found")
          |> halt()
        end

      _error ->
        conn
        |> send_resp(:not_found, "Event not found")
        |> halt()
    end
  end
end
