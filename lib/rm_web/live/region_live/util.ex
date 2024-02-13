defmodule RMWeb.RegionLive.Util do
  use RMWeb, :html

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
          navigate={~p"/region/#{String.downcase(@region.name)}"}
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
            navigate={~p"/region/#{String.downcase(@region.name)}/leagues"}
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
          navigate={~p"/region/#{String.downcase(@region.name)}/teams"}
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
          navigate={~p"/region/#{String.downcase(@region.name)}/import"}
        >
          Import
        </.link>
      <% end %>

      <div class="border-b border-gray-400 grow"></div>
    </div>
    """
  end
end
