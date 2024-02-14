defmodule RMWeb.RegionLive.Util do
  use RMWeb, :html

  alias Phoenix.LiveView
  alias RM.Account.User
  alias RM.FIRST.Region

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

      <%= if @view == RMWeb.RegionLive.Show do %>
        <div
          class="border border-b-0 border-gray-400 px-4 py-2 rounded-t"
          style="background-image: linear-gradient(to bottom, white, transparent)"
        >
          Overview
        </div>
      <% else %>
        <.link
          class="border-b border-gray-400 px-4 py-2 transition-colors hover:text-gray-500"
          navigate={~p"/region/#{@region}"}
        >
          Overview
        </.link>
      <% end %>

      <%= if @region.has_leagues do %>
        <%= if @view == RMWeb.RegionLive.Leagues do %>
          <div
            class="border border-b-0 border-gray-400 px-4 py-2 rounded-t"
            style="background-image: linear-gradient(to bottom, white, transparent)"
          >
            Leagues
          </div>
        <% else %>
          <.link
            class="border-b border-gray-400 px-4 py-2 transition-colors hover:text-gray-500"
            navigate={~p"/region/#{@region}/leagues"}
          >
            Leagues
          </.link>
        <% end %>
      <% end %>

      <%= if @view == RMWeb.RegionLive.Teams do %>
        <div
          class="border border-b-0 border-gray-400 px-4 py-2 rounded-t"
          style="background-image: linear-gradient(to bottom, white, transparent)"
        >
          Teams
        </div>
      <% else %>
        <.link
          class="border-b border-gray-400 px-4 py-2 transition-colors hover:text-gray-500"
          navigate={~p"/region/#{@region}/teams"}
        >
          Teams
        </.link>
      <% end %>

      <%= if @view == RMWeb.RegionLive.Import do %>
        <div
          class="border border-b-0 border-gray-400 px-4 py-2 rounded-t"
          style="background-image: linear-gradient(to bottom, white, transparent)"
        >
          Import
        </div>
      <% else %>
        <.link
          class="border-b border-gray-400 px-4 py-2 transition-colors hover:text-gray-500"
          navigate={~p"/region/#{@region}/import"}
        >
          Import
        </.link>
      <% end %>

      <div class="border-b border-gray-400 grow"></div>
    </div>
    """
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

  def on_mount(:require_region_owner, _params, _session, socket) do
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
    case RM.FIRST.get_region_by_abbreviation(region_abbreviation, preload: [:leagues, :teams]) do
      nil -> {:error, :region, :not_found}
      region -> {:ok, Map.update!(region, :teams, &sort_teams/1)}
    end
  end

  @spec region_owner?(User.t(), Region.t()) :: boolean
  defp region_owner?(%User{regions: regions}, %Region{id: region_id}) do
    is_list(regions) and Enum.any?(regions, &(&1.id == region_id))
  end

  @spec sort_teams([RM.Local.Team.t()]) :: [RM.Local.Team.t()]
  defp sort_teams(teams) do
    Enum.sort_by(teams, & &1.number)
  end
end
