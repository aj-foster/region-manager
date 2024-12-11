defmodule RMWeb.Components.RegistrationSettings do
  use RMWeb, :live_component

  alias RM.FIRST.Event

  #
  # Lifecycle
  #

  @impl true
  def update(assigns, socket) do
    socket
    |> assign_event(assigns[:event])
    |> assign_form()
    |> ok()
  end

  #
  # Helpers
  #

  @spec assign_event(Socket.t(), Event.t() | nil) :: Socket.t()
  defp assign_event(socket, nil), do: socket

  defp assign_event(socket, event) do
    event = RM.Repo.preload(event, [:league, :local_league, :region, :settings])
    assign(socket, event: event, registration_settings: event.settings.registration)
  end

  @spec assign_form(Socket.t()) :: Socket.t()
  defp assign_form(socket) do
    event = socket.assigns[:event]
    registration_settings = socket.assigns[:registration_settings]

    form =
      to_form(%{
        "enabled" => registration_settings.enabled,
        "open_days_date" => Date.add(event.date_start, -1 * registration_settings.open_days),
        "deadline_days_date" =>
          Date.add(event.date_start, -1 * registration_settings.deadline_days)
      })

    assign(socket, form: form)
  end

  #
  # Template
  #

  attr :event, Event, doc: "event to modify"

  def render(assigns) do
    ~H"""
    <.form
      id="registration-settings-form"
      for={@registration_settings_form}
      phx-change="registration_settings_change"
      phx-target={@myself}
    >
      <.inputs_for :let={f} field={@registration_settings_form[:registration]}>
        <.switch
          explanation="When enabled, teams can register for this event here in Region Manager. If disabled, you will need to find another way to track event registration. Please check with your region's Program Delivery Partner before making changes."
          field={f[:enabled]}
          label="Teams can register for this event in Region Manager"
          wrapper="mb-4"
        />

        <div :if={f[:enabled].value}>
          <h3 class="font-semibold pl-10 text-sm text-zinc-800">Registration Window</h3>
          <p :if={Event.multi_day?(@event)} class="text-sm">
            For events with start dates before team activities begin, be sure to adjust this deadline based on the start date listed above.
          </p>

          <div class="flex gap-4 mb-6 pl-10">
            <.input
              field={f[:open_days_date]}
              label="Open"
              min={Date.add(@event.date_start, -90) |> Date.to_string()}
              max={Date.add(@event.date_start, -2) |> Date.to_string()}
              type="date"
              wrapper="basis-1/2"
            />
            <.input
              field={f[:deadline_days_date]}
              label="Close"
              max="60"
              min="0"
              step="1"
              type="date"
              wrapper="basis-1/2"
            />
          </div>

          <div class="mb-6">
            <.switch
              explanation="Use this only if the event or venue has restricted capacity. It is not necessary to use this setting to restrict non-league teams from signing up."
              id="league_registration_registration_team_limit_enable"
              label="Restrict the number of teams that can register for this event"
              name="event_settings[registration][team_limit_enable]"
              value={not is_nil(f[:team_limit].value)}
              wrapper="mb-2"
            />

            <.input
              :if={not is_nil(f[:team_limit].value)}
              field={f[:team_limit]}
              min="0"
              step="1"
              type="number"
              wrapper="pl-10"
            />
          </div>

          <.switch
            explanation="This enables registration for a waitlist after the event reaches capacity."
            id="league_registration_registration_waitlist_limit_enable"
            label="Teams can sign up for a waitlist"
            name="event_settings[registration][waitlist_limit_enable]"
            value={not is_nil(f[:waitlist_limit].value)}
            wrapper="mb-4"
          />

          <div :if={not is_nil(f[:waitlist_limit].value)}>
            <.input
              explanation={
                if Event.multi_day?(@event) do
                  "For events with start dates before team activities begin, be sure to adjust this deadline based on the official start date (#{format_date(@event.date_start, :date)})."
                end
              }
              field={f[:waitlist_deadline_days]}
              label={"How many days before #{format_date(@event.date_start, :date)} should the waitlist close?"}
              max="60"
              min="0"
              step="1"
              type="number"
              wrapper="pl-10 mb-6"
            />

            <.input
              explanation="Teams will be presented in the order in which they signed up."
              field={f[:waitlist_limit]}
              label="How many additional teams can sign up to the wailist?"
              min="0"
              step="1"
              type="number"
              wrapper="pl-10 mb-6"
            />
          </div>
        </div>
      </.inputs_for>
    </.form>
    """
  end
end
