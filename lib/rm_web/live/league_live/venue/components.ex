defmodule RMWeb.LeagueLive.Venue.Components do
  use RMWeb, :html

  @doc """
  Render form to create or update a venue

  This form will emit the following events:

    * `venue_change` when inputs of the form are changed
    * `venue_submit` on submission
    * `venue_cancel` when the cancel button is pressed
  """
  attr :prompt, :string, doc: "text for the submit button of the form"
  attr :venue_form, Phoenix.HTML.Form, doc: "venue changeset passed through `to_form/1`"
  attr :rest, :global

  def venue_form(assigns) do
    ~H"""
    <div id="venue-form-component">
      <.form for={@venue_form} id="venue-form" phx-change="venue_change" phx-submit="venue_submit">
        <.input
          explanation="If there could be confusion, include the name of the specific campus or building."
          field={@venue_form[:name]}
          label="Venue Name"
          placeholder="Mountport High School, Tower Campus"
          required
          wrapper="mb-4"
        />
        <.input
          explanation="Optional website for general information about the venue, not a specific event."
          field={@venue_form[:website]}
          label="Website"
          placeholder="https://example.com"
          wrapper="mb-4"
        />

        <.input
          field={@venue_form[:country]}
          label="Country"
          options={country_options()}
          required
          type="select"
          wrapper="mb-4"
        />
        <.input field={@venue_form[:address]} label="Address Line 1" wrapper="mb-4" required />
        <.input field={@venue_form[:address_2]} label="Address Line 2" wrapper="mb-4" />
        <.input field={@venue_form[:city]} label="City" wrapper="mb-4" required />

        <div class="flex gap-4 mb-4">
          <.input
            field={@venue_form[:state_province]}
            label="State / Province"
            options={state_province_options(@venue_form[:country].value)}
            required={RM.Util.Location.state_province_required?(@venue_form[:country].value)}
            type="select"
            wrapper="basis-1/2 grow"
          />
          <.input field={@venue_form[:postal_code]} label="Postal Code" wrapper="basis-1/2 grow" />
        </div>

        <.input
          field={@venue_form[:timezone]}
          label="Timezone"
          options={timezone_options(@venue_form[:country].value)}
          required
          type="select"
          wrapper="mb-4"
        />
        <.input
          explanation="Helpful notes to visitors, such as entrance or parking instructions. Use this field for venue-specific details that don't change from event to event."
          field={@venue_form[:notes]}
          label="Additional Notes"
          type="textarea"
          wrapper="mb-4"
        />

        <p class="text-right">
          <button
            class="rounded border border-orange-500 font-semibold leading-6 py-1 px-2 text-orange-500"
            form=""
            phx-click="venue_cancel"
          >
            Cancel
          </button>
          <.button class="ml-4" type="submit"><%= @prompt %></.button>
        </p>
      </.form>
    </div>
    """
  end

  #
  # Template Helpers
  #

  @spec country_options :: [{String.t(), String.t()}]
  defp country_options do
    RM.Util.Location.countries()
    |> Enum.map(&{&1, &1})
  end

  @spec state_province_options(String.t()) :: [{String.t(), String.t()}]
  defp state_province_options(country_name) do
    RM.Util.Location.state_provinces(country_name)
    |> Enum.map(&{&1, &1})
  end

  @spec timezone_options(String.t()) :: [{String.t(), String.t()}]
  defp timezone_options(country_name) do
    RM.Util.Time.zones_for_country(country_name)
  end
end
