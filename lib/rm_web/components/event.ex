defmodule RMWeb.Components.Event do
  use RMWeb, :html

  @doc """
  Venue information, incorporating both event and proposal data
  """
  attr :event, RM.FIRST.Event, required: true, doc: "event with proposal and settings preloaded"

  def unified_venue(assigns) do
    assigns = assign_new(assigns, :postal_code, fn -> venue_postal_code(assigns[:event]) end)

    ~H"""
    <.title>
      Venue Information
      <:action :if={not @event.settings.virtual}>
        <.link_button navigate={venue_map_link(@event)} style="tertiary" target="blank">
          Map <.icon class="bottom-0.5 h-4 relative w-4" name="hero-arrow-top-right-on-square" />
        </.link_button>
      </:action>
    </.title>

    <.card spaced>
      <.table>
        <:row :if={@event.location.venue} title="Name"><%= @event.location.venue %></:row>
        <:row title="Address">
          <%= if @event.settings.virtual do %>
            <span class="italic">Virtual Event</span>
          <% else %>
            <span :if={@event.location.address} class="block"><%= @event.location.address %></span>
            <span :if={@event.location.city}><%= @event.location.city %>,</span>
            <span :if={@event.location.state_province}>
              <%= @event.location.state_province %><span :if={@postal_code}> <%= @postal_code %></span>,
            </span>
            <span><%= @event.location.country || "Unknown Location" %></span>
          <% end %>
        </:row>
        <:row :if={@event.proposal && @event.proposal.venue.notes} title="Notes">
          <%= @event.proposal.venue.notes %>
        </:row>
        <:row :if={@event.proposal && @event.proposal.venue.website} title="Website">
          <a class="underline" href={@event.proposal.venue.website} target="blank">
            <%= @event.proposal.venue.website %>
          </a>
        </:row>
      </.table>
    </.card>
    """
  end

  @spec venue_map_link(RM.FIRST.Event.t()) :: String.t()
  defp venue_map_link(event) do
    %RM.FIRST.Event{
      location: %RM.FIRST.Event.Location{
        address: address,
        city: city,
        country: country,
        state_province: state_province,
        venue: venue
      }
    } = event

    query =
      [venue, address, city, state_province, country]
      |> Enum.reject(&(&1 in ["", nil]))
      |> Enum.join(", ")

    "https://www.google.com/maps/search/?api=1&#{URI.encode_query(query: query)}"
  end

  @spec venue_postal_code(RM.FIRST.Event.t()) :: String.t() | nil
  defp venue_postal_code(%RM.FIRST.Event{
         location: %{address: a},
         proposal: %RM.Local.EventProposal{
           venue: %RM.Local.Venue{address: a, postal_code: postal_code}
         }
       }) do
    postal_code
  end

  defp venue_postal_code(_event), do: nil
end
