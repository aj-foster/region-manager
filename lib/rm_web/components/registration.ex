defmodule RMWeb.Components.Registration do
  use RMWeb, :html

  alias RM.FIRST.Event

  @doc """
  Show the current registration settings for an event
  """
  attr :event, RM.FIRST.Event, required: true, doc: "event to display"
  attr :teams, :list, required: true, doc: "list of registered teams"

  def show(assigns) do
    assigns = assign(assigns, teams_count: length(assigns[:teams]))

    ~H"""
    <.card :if={@event.settings.registration.enabled} spaced>
      <.table>
        <:row title="Registration">
          <%= cond do %>
            <% Event.registration_deadline_passed?(@event) -> %>
              <span class="text-orange-600">
                Closed on <%= format_date(Event.registration_deadline(@event), :date) %>
              </span>
            <% Event.registration_opening_passed?(@event) -> %>
              <span class="text-green-600">Open</span>
            <% :else -> %>
              <span class="text-orange-600">
                Opens on <%= format_date(Event.registration_opens(@event), :date) %>
              </span>
          <% end %>
        </:row>
        <:row :if={not Event.registration_deadline_passed?(@event)} title="Deadline">
          <%= format_date(Event.registration_deadline(@event), :full) %>
        </:row>
        <:row title="Available For">
          <%= case @event.settings.registration.pool do %>
            <% :all -> %>
              All Teams
            <% :league -> %>
              Teams in <%= if(@event.league, do: @event.league.name <> " League", else: "league") %>
            <% :region -> %>
              Teams in <%= @event.region.name %>
          <% end %>
        </:row>
        <:row :if={@event.settings.registration.team_limit} title="Capacity">
          <span class="font-mono text-sm">
            <%= @teams_count %> / <%= @event.settings.registration.team_limit %>
          </span>
          filled
        </:row>
        <:row :if={is_nil(@event.settings.registration.team_limit)} title="Registered Count">
          <%= dumb_inflect("team", @teams_count) %>
        </:row>
        <:row title="Registered Teams">
          <ul :if={@teams_count > 0}>
            <li :for={team <- @teams}>
              <strong><%= team.number %></strong> <%= team.name %>
            </li>
          </ul>
          <p :if={@teams_count == 0} class="italic">None</p>
        </:row>
      </.table>
    </.card>

    <.card :if={not @event.settings.registration.enabled} spaced>
      <p class="text-sm">
        Registration for this event is not available in <strong>Region Manager</strong>.
      </p>
    </.card>
    """
  end
end
