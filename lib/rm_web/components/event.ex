defmodule RMWeb.Components.Event do
  use RMWeb, :html

  @doc """
  Venue information, incorporating both event and proposal data

  If the `editable` attribute is `true`, the calling view must handle an event
  `venue_virtual_toggle` by updating the event's settings to change the visibility of the venue
  address. The handler should check the same conditions that determine `editable`.
  """
  attr :editable, :boolean,
    default: false,
    doc: "whether the current user can toggle address visibility"

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
        <:row :if={@event.location.venue} title="Name">{@event.location.venue}</:row>
        <:row title="Address">
          <div :if={@event.settings.virtual}>
            <span class="italic">Virtual Event</span>
          </div>

          <div :if={not @event.settings.virtual}>
            <span :if={@event.location.address} class="block">{@event.location.address}</span>
            <span :if={@event.location.city}>{@event.location.city},</span>
            <span :if={@event.location.state_province}>
              {@event.location.state_province}<span :if={@postal_code}> <%= @postal_code %></span>,
            </span>
            <span>{@event.location.country || "Unknown Location"}</span>
          </div>

          <div :if={@editable}>
            <button
              class="text-orange-600 text-sm underline"
              phx-click={show_modal("venue-virtual-modal")}
            >
              <%= if @event.settings.virtual do %>
                Unhide Address
              <% else %>
                Hide Address
              <% end %>
            </button>
          </div>
        </:row>
        <:row :if={@event.proposal && @event.proposal.venue.notes} title="Notes">
          {@event.proposal.venue.notes}
        </:row>
        <:row :if={@event.proposal && @event.proposal.venue.website} title="Website">
          <a class="underline" href={@event.proposal.venue.website} target="blank">
            {@event.proposal.venue.website}
          </a>
        </:row>
      </.table>
    </.card>

    <.modal :if={@editable} id="venue-virtual-modal">
      <.title class="mb-4" flush>Hide Venue Address</.title>

      <p class="mb-4">
        If this event is virtual (meaning nobody besides event staff should show up at this address), you can hide the address from public view.
      </p>
      <p class="mb-4">
        The address is currently <strong :if={@event.settings.virtual}>hidden</strong>
        <strong :if={not @event.settings.virtual}>visible</strong>.
      </p>
      <p class="text-right">
        <.button phx-click="venue_virtual_toggle">Change Visibility</.button>
      </p>
    </.modal>
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
