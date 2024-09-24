defmodule RMWeb.RegionLive.Util do
  use RMWeb, :html

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias RM.Account.User
  alias RM.FIRST.Region
  alias RMWeb.RegionLive

  @doc """
  Navigation component for region views
  """
  attr :class, :string, default: nil, doc: "Additional classes for the navigation wrapper"
  attr :region, :any, required: true, doc: "`@region`"
  attr :view, :any, required: true, doc: "`@socket.view`"

  def nav(assigns) do
    ~H"""
    <div class={["flex font-title italic small-caps", @class]}>
      <div class="border-b border-gray-400 w-4"></div>

      <%= if @view == RegionLive.Show do %>
        <div
          class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
          style="background-image: linear-gradient(to bottom, white, transparent)"
        >
          Overview
        </div>
      <% else %>
        <.link
          class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
          navigate={~p"/region/#{@region}"}
        >
          Overview
        </.link>
      <% end %>

      <%= cond do %>
        <% @view == RegionLive.Event.Index -> %>
          <div
            class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
            style="background-image: linear-gradient(to bottom, white, transparent)"
          >
            Events
          </div>
        <% @view in [RegionLive.Event.Show] -> %>
          <.link
            class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
            style="background-image: linear-gradient(to bottom, white, transparent)"
            navigate={~p"/region/#{@region}/events"}
          >
            Events
          </.link>
        <% :else -> %>
          <.link
            class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
            navigate={~p"/region/#{@region}/events"}
          >
            Events
          </.link>
      <% end %>

      <%= if @region.has_leagues do %>
        <%= cond do %>
          <% @view == RegionLive.League.Index -> %>
            <div
              class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
              style="background-image: linear-gradient(to bottom, white, transparent)"
            >
              Leagues
            </div>
          <% @view in [RegionLive.League.Show] -> %>
            <.link
              class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
              navigate={~p"/region/#{@region}/leagues"}
              style="background-image: linear-gradient(to bottom, white, transparent)"
            >
              Leagues
            </.link>
          <% :else -> %>
            <.link
              class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
              navigate={~p"/region/#{@region}/leagues"}
            >
              Leagues
            </.link>
        <% end %>
      <% end %>

      <%= cond do %>
        <% @view == RegionLive.Team.Index -> %>
          <div
            class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
            style="background-image: linear-gradient(to bottom, white, transparent)"
          >
            Teams
          </div>
        <% @view in [RegionLive.Team.Show] -> %>
          <.link
            class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
            navigate={~p"/region/#{@region}/teams"}
            style="background-image: linear-gradient(to bottom, white, transparent)"
          >
            Teams
          </.link>
        <% :else -> %>
          <.link
            class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
            navigate={~p"/region/#{@region}/teams"}
          >
            Teams
          </.link>
      <% end %>

      <%!-- <%= if @view == RegionLive.Setup do %>
        <div
          class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
          style="background-image: linear-gradient(to bottom, white, transparent)"
        >
          Setup
        </div>
      <% else %>
        <.link
          class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
          navigate={~p"/region/#{@region}/setup"}
        >
          Setup
        </.link>
      <% end %> --%>

      <div class="border-b border-gray-400 grow"></div>
    </div>
    """
  end

  @doc """
  Refresh the current region
  """
  @spec refresh_region(Socket.t()) :: Socket.t()
  def refresh_region(socket) do
    case socket.assigns[:region] do
      %RM.FIRST.Region{abbreviation: region_abbreviation} ->
        case get_region(region_abbreviation) do
          {:ok, region} ->
            assign(socket, region: region)

          {:error, :region, :not_found} ->
            socket
        end

      nil ->
        socket
    end
  end

  @doc false
  @spec on_mount(term, map, map, Socket.t()) :: {:cont, Socket.t()}
  def on_mount(name, params, session, socket)

  def on_mount(:preload_region, %{"region" => region_abbreviation}, _session, socket) do
    case get_region(region_abbreviation) do
      {:ok, region} ->
        {:cont, assign(socket, region: region)}

      {:error, :region, :not_found} ->
        socket =
          socket
          |> LiveView.put_flash(:error, "Region not found")
          |> LiveView.redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end

  def on_mount(:require_region_manager, _params, _session, socket) do
    region = socket.assigns[:region]
    user = socket.assigns[:current_user]

    if is_nil(region) or is_nil(user) or not region_owner?(user, region) do
      socket =
        socket
        |> LiveView.put_flash(:error, "You do not have permission to perform this action")
        |> LiveView.redirect(to: ~p"/dashboard")

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  @spec get_region(Ecto.UUID.t()) :: {:ok, Region.t()} | {:error, :region, :not_found}
  defp get_region(region_abbreviation) do
    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(region_abbreviation) do
      region =
        region
        |> RM.Repo.preload([:leagues, :teams])
        |> Map.update!(:leagues, &Enum.sort(&1, RM.Local.League))
        |> Map.update!(:teams, &Enum.sort(&1, RM.Local.Team))

      {:ok, region}
    end
  end

  @spec region_owner?(User.t(), Region.t()) :: boolean
  defp region_owner?(%User{regions: regions}, %Region{id: region_id}) do
    is_list(regions) and Enum.any?(regions, &(&1.id == region_id))
  end
end
