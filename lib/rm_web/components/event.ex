defmodule RMWeb.Components.Event do
  use RMWeb, :html
  import RMWeb.Live.Util

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

    <.card :if={@event.settings.virtual} spaced>
      <div>
        <span class="italic text-sm">This is a virtual event.</span>
      </div>
    </.card>

    <.card :if={not @event.settings.virtual} spaced>
      <.table>
        <:row :if={@event.location.venue} title="Name">{@event.location.venue}</:row>
        <:row title="Address">
          <div class="flex gap-4 items-center">
            <div class="grow">
              <a
                class="block no-underline hover:underline"
                href={venue_address_link(@event, @postal_code)}
              >
                <span :if={@event.location.address} class="block">{@event.location.address}</span>
                <span :if={@event.location.city}>{@event.location.city},</span>
                <span :if={@event.location.state_province}>
                  {@event.location.state_province}<span :if={@postal_code}> <%= @postal_code %></span>,
                </span>
                <span>{@event.location.country || "Unknown Location"}</span>
              </a>
            </div>

            <button
              class="leading-none p-1 rounded text-neutral-800 transition-colors hover:bg-neutral-200"
              id="copy-venue-address"
              data-copy={venue_address_string(@event, @postal_code)}
              phx-click={copy("#copy-venue-address")}
              title="Copy to Clipboard"
            >
              <.icon name="hero-document-duplicate" />
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

  @spec venue_address_string(RM.FIRST.Event.t(), String.t() | nil) :: String.t()
  defp venue_address_string(event, postal_code) do
    Enum.join([
      if(event.location.address, do: event.location.address <> ", "),
      if(event.location.city, do: event.location.city <> ", "),
      if(event.location.state_province, do: event.location.state_province <> " "),
      if(postal_code, do: postal_code <> ", "),
      if(event.location.country, do: event.location.country)
    ])
  end

  @spec venue_address_link(RM.FIRST.Event.t(), String.t() | nil) :: String.t()
  defp venue_address_link(event, postal_code) do
    query =
      venue_address_string(event, postal_code)
      |> URI.encode()

    "https://maps.apple.com/maps?q=#{query}"
  end
end
