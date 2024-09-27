defmodule RMWeb.Components.TeamExport do
  use RMWeb, :live_component

  #
  # Lifecycle
  #

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
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

  def handle_event("export", params, socket) do
    socket
    |> export_teams(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_form(Socket.t(), map) :: Socket.t()
  defp assign_form(socket, params \\ %{}) do
    include = if length(socket.assigns[:teams]) > 1, do: "0", else: "_all"

    form =
      Map.merge(
        %{"format" => "csv", "include" => include, "field" => "all", "fields" => []},
        params
      )
      |> to_form()

    assign(socket, form: form)
  end

  @spec export_teams(Socket.t(), map) :: Socket.t()
  defp export_teams(socket, params) do
    params =
      Map.merge(params, %{
        "fields" => select_fields(socket, params),
        "teams" => select_teams(socket, params)
      })

    case RM.Local.TeamExport.export(params) do
      {:ok, url} ->
        socket
        |> push_event("window-open", %{url: url})
        |> put_flash(
          :info,
          "Export generated successfully. If a download doesn't start immediately, please allow popups."
        )
        |> push_js("#team-export-modal", "data-cancel")

      {:error, reason} ->
        socket
        |> put_flash(:error, "An error occurred while generating export: #{reason}")
        |> push_js("#team-export-modal", "data-cancel")
    end
  end

  @fields_all [
    "name",
    "number",
    "rookie-status",
    "rookie-year",
    "school",
    "school-type",
    "sponsors",
    "sponsors-type",
    "website",
    "country",
    "state-province",
    "city",
    "county",
    "postal-code",
    "region",
    "league",
    "lc1-name",
    "lc1-email",
    "lc1-email-alt",
    "lc1-phone",
    "lc1-phone-alt",
    "lc1-ypp-status",
    "lc2-name",
    "lc2-email",
    "lc2-email-alt",
    "lc2-phone",
    "lc2-phone-alt",
    "lc2-ypp-status",
    "admin-name",
    "admin-email",
    "admin-phone",
    "event-ready",
    "missing-contacts",
    "secured-date"
  ]
  @fields_nn ["name", "number"]
  @fields_nns ["name", "number", "school", "school-type"]
  @fields_coach_information [
    "lc1-name",
    "lc1-email",
    "lc1-email-alt",
    "lc1-phone",
    "lc1-phone-alt",
    "lc1-ypp-status",
    "lc2-name",
    "lc2-email",
    "lc2-email-alt",
    "lc2-phone",
    "lc2-phone-alt",
    "lc2-ypp-status",
    "admin-name",
    "admin-email",
    "admin-phone"
  ]

  @spec select_fields(Socket.t(), map) :: [String.t()]
  defp select_fields(socket, params) do
    pii? = socket.assigns[:pii]

    case params["field"] do
      "all" ->
        if pii? do
          @fields_all
        else
          @fields_all -- @fields_coach_information
        end

      "nn" ->
        @fields_nn

      "nns" ->
        @fields_nns

      "coaches" ->
        if pii? do
          @fields_nn ++ @fields_coach_information
        else
          @fields_nn
        end

      "custom" ->
        if pii? do
          params["fields"]
        else
          params["fields"] -- @fields_coach_information
        end
    end
  end

  @spec select_teams(Socket.t(), map) :: [RM.Local.Team.t()]
  defp select_teams(socket, params) do
    index =
      case Integer.parse(params["include"]) do
        {x, ""} -> x
        _else -> 0
      end

    socket.assigns[:teams]
    |> Enum.at(index)
    |> elem(2)
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
      <.modal id="team-export-modal">
        <.title flush class="mb-4">Export <%= @context %> Teams</.title>

        <.form
          for={@form}
          id="team-export-form"
          phx-change="export_change"
          phx-submit="export"
          phx-target={@myself}
        >
          <input name={@form[:format].name} type="hidden" value="csv" />
          <%!-- <div class="mb-4" id="team-export-format-inputs">
            <h3 class="font-semibold mb-2">Format</h3>

            <.radio_group field={@form[:format]}>
              <:radio value="csv">CSV (comma-separated values)</:radio>
              <:radio value="xlsx">XLSX (Microsoft Excel)</:radio>
            </.radio_group>
          </div> --%>

          <div :if={length(@teams) > 1} class="mb-4" id="team-export-include-inputs">
            <h3 class="font-semibold mb-2">Teams to Include</h3>

            <.radio_group field={@form[:include]}>
              <:radio :for={{{label, count, _teams}, index} <- Enum.with_index(@teams)} value={index}>
                <%= label %> (<%= dumb_inflect("team", count) %>)
              </:radio>
            </.radio_group>
          </div>

          <input :if={length(@teams) == 1} field={@form[:include]} type="hidden" value="_all" />

          <div class="mb-4" id="team-export-field-inputs">
            <h3 class="font-semibold mb-2">Fields to Include</h3>

            <.radio_group field={@form[:field]}>
              <:radio value="all">All fields</:radio>
              <:radio value="nn">Name &amp; number</:radio>
              <:radio value="nns">Name, number, &amp; school or organization</:radio>
              <:radio value="coaches">Coach information</:radio>
              <:radio value="custom">Custom...</:radio>
            </.radio_group>
          </div>

          <div :if={@form[:field].value == "custom"} class="mb-4">
            <h3 class="font-semibold mb-2">Field List</h3>

            <div class="grid grid-cols-2 gap-x-8 gap-y-4">
              <div class="">
                <div>
                  <input
                    checked={"name" in @form[:fields].value}
                    id="export-fields-name"
                    name="fields[]"
                    type="checkbox"
                    value="name"
                  />
                  <label class="ml-2" for="export-fields-name">Name</label>
                </div>
                <div>
                  <input
                    checked={"number" in @form[:fields].value}
                    id="export-fields-number"
                    name="fields[]"
                    type="checkbox"
                    value="number"
                  />
                  <label class="ml-2" for="export-fields-number">Number</label>
                </div>
                <div>
                  <input
                    checked={"rookie-status" in @form[:fields].value}
                    id="export-fields-rookie-status"
                    name="fields[]"
                    type="checkbox"
                    value="rookie-status"
                  />
                  <label class="ml-2" for="export-fields-rookie-status">Rookie Status</label>
                </div>
                <div>
                  <input
                    checked={"rookie-year" in @form[:fields].value}
                    id="export-fields-rookie-year"
                    name="fields[]"
                    type="checkbox"
                    value="rookie-year"
                  />
                  <label class="ml-2" for="export-fields-rookie-year">Rookie Year</label>
                </div>
                <div>
                  <input
                    checked={"school" in @form[:fields].value}
                    id="export-fields-school"
                    name="fields[]"
                    type="checkbox"
                    value="school"
                  />
                  <label class="ml-2" for="export-fields-school">School / Org</label>
                </div>
                <div>
                  <input
                    checked={"school-type" in @form[:fields].value}
                    id="export-fields-school-type"
                    name="fields[]"
                    type="checkbox"
                    value="school-type"
                  />
                  <label class="ml-2" for="export-fields-school-type">School / Org Type</label>
                </div>
                <div>
                  <input
                    checked={"sponsors" in @form[:fields].value}
                    id="export-fields-sponsors"
                    name="fields[]"
                    type="checkbox"
                    value="sponsors"
                  />
                  <label class="ml-2" for="export-fields-sponsors">Sponsors</label>
                </div>
                <div>
                  <input
                    checked={"sponsors-type" in @form[:fields].value}
                    id="export-fields-sponsors-type"
                    name="fields[]"
                    type="checkbox"
                    value="sponsors-type"
                  />
                  <label class="ml-2" for="export-fields-sponsors-type">Sponsor Type</label>
                </div>
                <div>
                  <input
                    checked={"website" in @form[:fields].value}
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
                    checked={"country" in @form[:fields].value}
                    id="export-fields-country"
                    name="fields[]"
                    type="checkbox"
                    value="country"
                  />
                  <label class="ml-2" for="export-fields-country">Country</label>
                </div>
                <div>
                  <input
                    checked={"state-province" in @form[:fields].value}
                    id="export-fields-state-province"
                    name="fields[]"
                    type="checkbox"
                    value="state-province"
                  />
                  <label class="ml-2" for="export-fields-state-province">State / Province</label>
                </div>
                <div>
                  <input
                    checked={"city" in @form[:fields].value}
                    id="export-fields-city"
                    name="fields[]"
                    type="checkbox"
                    value="city"
                  />
                  <label class="ml-2" for="export-fields-city">City</label>
                </div>
                <div>
                  <input
                    checked={"county" in @form[:fields].value}
                    id="export-fields-county"
                    name="fields[]"
                    type="checkbox"
                    value="county"
                  />
                  <label class="ml-2" for="export-fields-county">County</label>
                </div>
                <div>
                  <input
                    checked={"postal-code" in @form[:fields].value}
                    id="export-fields-postal-code"
                    name="fields[]"
                    type="checkbox"
                    value="postal-code"
                  />
                  <label class="ml-2" for="export-fields-postal-code">Postal Code</label>
                </div>
                <div>
                  <input
                    checked={"region" in @form[:fields].value}
                    id="export-fields-region"
                    name="fields[]"
                    type="checkbox"
                    value="region"
                  />
                  <label class="ml-2" for="export-fields-region">Region</label>
                </div>
                <div>
                  <input
                    checked={"league" in @form[:fields].value}
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
                    checked={"lc1-name" in @form[:fields].value}
                    id="export-fields-lc1-name"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-name"
                  />
                  <label class="ml-2" for="export-fields-lc1-name">LC1 Name</label>
                </div>
                <div>
                  <input
                    checked={"lc1-email" in @form[:fields].value}
                    id="export-fields-lc1-email"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-email"
                  />
                  <label class="ml-2" for="export-fields-lc1-email">LC1 Email</label>
                </div>
                <div>
                  <input
                    checked={"lc1-email-alt" in @form[:fields].value}
                    id="export-fields-lc1-email-alt"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-email-alt"
                  />
                  <label class="ml-2" for="export-fields-lc1-email-alt">LC1 Email Alternate</label>
                </div>
                <div>
                  <input
                    checked={"lc1-phone" in @form[:fields].value}
                    id="export-fields-lc1-phone"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-phone"
                  />
                  <label class="ml-2" for="export-fields-lc1-phone">LC1 Phone</label>
                </div>
                <div>
                  <input
                    checked={"lc1-phone-alt" in @form[:fields].value}
                    id="export-fields-lc1-phone-alt"
                    name="fields[]"
                    type="checkbox"
                    value="lc1-phone-alt"
                  />
                  <label class="ml-2" for="export-fields-lc1-phone-alt">LC1 Phone Alternate</label>
                </div>
                <div>
                  <input
                    checked={"lc1-ypp-status" in @form[:fields].value}
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
                    checked={"lc2-name" in @form[:fields].value}
                    id="export-fields-lc2-name"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-name"
                  />
                  <label class="ml-2" for="export-fields-lc2-name">LC2 Name</label>
                </div>
                <div>
                  <input
                    checked={"lc2-email" in @form[:fields].value}
                    id="export-fields-lc2-email"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-email"
                  />
                  <label class="ml-2" for="export-fields-lc2-email">LC2 Email</label>
                </div>
                <div>
                  <input
                    checked={"lc2-email-alt" in @form[:fields].value}
                    id="export-fields-lc2-email-alt"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-email-alt"
                  />
                  <label class="ml-2" for="export-fields-lc2-email-alt">LC2 Email Alternate</label>
                </div>
                <div>
                  <input
                    checked={"lc2-phone" in @form[:fields].value}
                    id="export-fields-lc2-phone"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-phone"
                  />
                  <label class="ml-2" for="export-fields-lc2-phone">LC2 Phone</label>
                </div>
                <div>
                  <input
                    checked={"lc2-phone-alt" in @form[:fields].value}
                    id="export-fields-lc2-phone-alt"
                    name="fields[]"
                    type="checkbox"
                    value="lc2-phone-alt"
                  />
                  <label class="ml-2" for="export-fields-lc2-phone-alt">LC2 Phone Alternate</label>
                </div>
                <div>
                  <input
                    checked={"lc2-ypp-status" in @form[:fields].value}
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
                    checked={"admin-name" in @form[:fields].value}
                    id="export-fields-admin-name"
                    name="fields[]"
                    type="checkbox"
                    value="admin-name"
                  />
                  <label class="ml-2" for="export-fields-admin-name">Team Admin Name</label>
                </div>
                <div>
                  <input
                    checked={"admin-email" in @form[:fields].value}
                    id="export-fields-admin-email"
                    name="fields[]"
                    type="checkbox"
                    value="admin-email"
                  />
                  <label class="ml-2" for="export-fields-admin-email">Team Admin Email</label>
                </div>
                <div>
                  <input
                    checked={"admin-phone" in @form[:fields].value}
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
                    checked={"event-ready" in @form[:fields].value}
                    id="export-fields-event-ready"
                    name="fields[]"
                    type="checkbox"
                    value="event-ready"
                  />
                  <label class="ml-2" for="export-fields-event-ready">Event Ready</label>
                </div>
                <div>
                  <input
                    checked={"missing-contacts" in @form[:fields].value}
                    id="export-fields-missing-contacts"
                    name="fields[]"
                    type="checkbox"
                    value="missing-contacts"
                  />
                  <label class="ml-2" for="export-fields-missing-contacts">Missing Contacts</label>
                </div>
                <div>
                  <input
                    checked={"secured-date" in @form[:fields].value}
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
