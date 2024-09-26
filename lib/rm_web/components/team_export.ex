defmodule RMWeb.Components.TeamExport do
  use RMWeb, :live_component

  #
  # Lifecycle
  #

  @impl true
  def mount(socket) do
    socket
    |> assign(custom_fields: false)
    |> assign_form()
    |> ok()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, params, socket)

  def handle_event("export_change", params, socket) do
    socket
    |> assign_form(params)
    |> noreply()
  end

  def handle_event("export", _params, socket) do
    socket
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_form(Socket.t(), map) :: Socket.t()
  defp assign_form(socket, params \\ %{}) do
    form =
      Map.merge(
        %{"format" => "csv", "include" => "_all", "field" => "all", "fields" => []},
        params
      )
      |> to_form()

    assign(socket, form: form)
  end

  #
  # Template
  #

  attr :context, :string, default: "", doc: "Export ___ Teams"
  attr :pii, :boolean, default: false, doc: "whether the current user can see coach PII"

  attr :teams, :list,
    required: true,
    doc: "list of tuples containing a group label, count of teams, and the teams"

  def render(assigns) do
    ~H"""
    <div>
      <.modal id="team-export-modal" show>
        <.title flush class="mb-4">Export <%= @context %> Teams</.title>

        <.form
          for={@form}
          id="team-export-form"
          phx-change="export_change"
          phx-submit="export"
          phx-target={@myself}
        >
          <div id="team-export-format-inputs" phx-update="ignore">
            <h3 class="font-semibold mb-2">Format</h3>

            <div>
              <input checked id="export-format-csv" name="format" type="radio" value="csv" />
              <label class="ml-2" for="export-format-csv">CSV (comma-separated values)</label>
            </div>
            <div class="mb-4">
              <input id="export-format-xlsx" name="format" type="radio" value="xlsx" />
              <label class="ml-2" for="export-format-xlsx">XLSX (Microsoft Excel)</label>
            </div>
          </div>

          <div
            :if={length(@teams) > 1}
            class="mb-4"
            id="team-export-include-inputs"
            phx-update="ignore"
          >
            <h3 class="font-semibold mb-2">Teams to Include</h3>

            <div :for={{{label, count, _teams}, index} <- Enum.with_index(@teams)}>
              <input
                checked={index == 0}
                id={"export-include-#{index}"}
                name="include"
                type="radio"
                value={index}
              />
              <label class="ml-2" for={"export-include-#{index}"}>
                <%= label %> (<%= dumb_inflect("team", count) %>)
              </label>
            </div>
          </div>

          <input
            :if={length(@teams) == 1}
            id="export-include-all"
            name="include"
            type="hidden"
            value="_all"
          />

          <div id="team-export-field-inputs" phx-update="ignore">
            <h3 class="font-semibold mb-2">Fields to Include</h3>

            <div>
              <input checked id="export-field-all" name="field" type="radio" value="all" />
              <label class="ml-2" for="export-field-all">All fields</label>
            </div>
            <div>
              <input id="export-field-nn" name="field" type="radio" value="nn" />
              <label class="ml-2" for="export-field-nn">Name &amp; number</label>
            </div>
            <div>
              <input id="export-field-nns" name="field" type="radio" value="nns" />
              <label class="ml-2" for="export-field-nns">Name, number, &amp; school</label>
            </div>
            <div :if={@pii}>
              <input id="export-field-coaches" name="field" type="radio" value="coaches" />
              <label class="ml-2" for="export-field-coaches">Coach information</label>
            </div>
            <div class="mb-4">
              <input id="export-field-custom" name="field" type="radio" value="custom" />
              <label class="ml-2" for="export-field-custom">Custom...</label>
            </div>
          </div>

          <div :if={@custom_fields} class="mb-4">
            <h3 class="font-semibold mb-2">Field List</h3>

            <div class="grid grid-cols-2 gap-x-8 gap-y-4">
              <div class="">
                <div>
                  <input checked id="export-fields-name" name="fields[]" type="checkbox" value="name" />
                  <label class="ml-2" for="export-fields-name">Name</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-number"
                    name="fields[]"
                    type="checkbox"
                    value="number"
                  />
                  <label class="ml-2" for="export-fields-number">Number</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-rookie-status"
                    name="fields[]"
                    type="checkbox"
                    value="rookie-status"
                  />
                  <label class="ml-2" for="export-fields-rookie-status">Rookie Status</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-rookie-year"
                    name="fields[]"
                    type="checkbox"
                    value="rookie-year"
                  />
                  <label class="ml-2" for="export-fields-rookie-year">Rookie Year</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-school"
                    name="fields[]"
                    type="checkbox"
                    value="school"
                  />
                  <label class="ml-2" for="export-fields-school">School / Org</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-school-type"
                    name="fields[]"
                    type="checkbox"
                    value="school-type"
                  />
                  <label class="ml-2" for="export-fields-school-type">School / Org Type</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-sponsors"
                    name="fields[]"
                    type="checkbox"
                    value="sponsors"
                  />
                  <label class="ml-2" for="export-fields-sponsors">Sponsors</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-sponsors-type"
                    name="fields[]"
                    type="checkbox"
                    value="sponsors-type"
                  />
                  <label class="ml-2" for="export-fields-sponsors-type">Sponsor Type</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-website"
                    name="fields[]"
                    type="checkbox"
                    value="website"
                  />
                  <label class="ml-2" for="export-fields-website">Website</label>
                </div>
              </div>

              <div class="">
                <div>
                  <input
                    checked
                    id="export-fields-country"
                    name="fields[]"
                    type="checkbox"
                    value="country"
                  />
                  <label class="ml-2" for="export-fields-country">Country</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-state-province"
                    name="fields[]"
                    type="checkbox"
                    value="state-province"
                  />
                  <label class="ml-2" for="export-fields-state-province">State / Province</label>
                </div>
                <div>
                  <input checked id="export-fields-city" name="fields[]" type="checkbox" value="city" />
                  <label class="ml-2" for="export-fields-city">City</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-county"
                    name="fields[]"
                    type="checkbox"
                    value="county"
                  />
                  <label class="ml-2" for="export-fields-county">County</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-postal-code"
                    name="fields[]"
                    type="checkbox"
                    value="postal-code"
                  />
                  <label class="ml-2" for="export-fields-postal-code">Postal Code</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-region"
                    name="fields[]"
                    type="checkbox"
                    value="region"
                  />
                  <label class="ml-2" for="export-fields-region">Region</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-league"
                    name="fields[]"
                    type="checkbox"
                    value="league"
                  />
                  <label class="ml-2" for="export-fields-league">League</label>
                </div>
              </div>

              <div :if={@pii} class="">
                <div>
                  <input
                    checked
                    id="export-fields-lc1-name"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-name"
                  />
                  <label class="ml-2" for="export-fields-lc1-name">LC1 Name</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-lc1-email"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-email"
                  />
                  <label class="ml-2" for="export-fields-lc1-email">LC1 Email</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-lc1-email-alt"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-email-alt"
                  />
                  <label class="ml-2" for="export-fields-lc1-email-alt">LC1 Email Alternate</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-lc1-phone"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-phone"
                  />
                  <label class="ml-2" for="export-fields-lc1-phone">LC1 Phone</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-lc1-phone-alt"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-phone-alt"
                  />
                  <label class="ml-2" for="export-fields-lc1-phone-alt">LC1 Phone Alternate</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-lc1-ypp-status"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-ypp-status"
                  />
                  <label class="ml-2" for="export-fields-lc1-ypp-status">LC1 YPP Status</label>
                </div>
              </div>

              <div :if={@pii} class="">
                <div>
                  <input
                    checked
                    id="export-fields-lc2-name"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-name"
                  />
                  <label class="ml-2" for="export-fields-lc2-name">LC2 Name</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-lc2-email"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-email"
                  />
                  <label class="ml-2" for="export-fields-lc2-email">LC2 Email</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-lc2-email-alt"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-email-alt"
                  />
                  <label class="ml-2" for="export-fields-lc2-email-alt">LC2 Email Alternate</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-lc2-phone"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-phone"
                  />
                  <label class="ml-2" for="export-fields-lc2-phone">LC2 Phone</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-lc2-phone-alt"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-phone-alt"
                  />
                  <label class="ml-2" for="export-fields-lc2-phone-alt">LC2 Phone Alternate</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-lc2-ypp-status"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-ypp-status"
                  />
                  <label class="ml-2" for="export-fields-lc2-ypp-status">LC2 YPP Status</label>
                </div>
              </div>

              <div :if={@pii} class="">
                <div>
                  <input
                    checked
                    id="export-fields-admin-name"
                    name="fields[]"
                    type="checkbox"
                    value="admin-name"
                  />
                  <label class="ml-2" for="export-fields-admin-name">Team Admin Name</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-admin-email"
                    name="fields[]"
                    type="checkbox"
                    value="admin-email"
                  />
                  <label class="ml-2" for="export-fields-admin-email">Team Admin Email</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-admin-phone"
                    name="fields[]"
                    type="checkbox"
                    value="admin-phone"
                  />
                  <label class="ml-2" for="export-fields-admin-phone">Team Admin Phone</label>
                </div>
              </div>

              <div class="">
                <div>
                  <input
                    checked
                    id="export-fields-event-ready"
                    name="fields[]"
                    type="checkbox"
                    value="event-ready"
                  />
                  <label class="ml-2" for="export-fields-event-ready">Event Ready</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-missing-contacts"
                    name="fields[]"
                    type="checkbox"
                    value="missing-contacts"
                  />
                  <label class="ml-2" for="export-fields-missing-contacts">Missing Contacts</label>
                </div>
                <div>
                  <input
                    checked
                    id="export-fields-secured-date"
                    name="fields[]"
                    type="checkbox"
                    value="secured-date"
                  />
                  <label class="ml-2" for="export-fields-secured-date">Secured Date</label>
                </div>
              </div>
            </div>
          </div>

          <p class="text-right">
            <.button type="submit">Export Teams</.button>
          </p>
        </.form>
      </.modal>
    </div>
    """
  end
end
