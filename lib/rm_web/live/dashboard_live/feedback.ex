defmodule RMWeb.DashboardLive.Feedback do
  use RMWeb, :live_view

  alias RM.System
  alias RM.System.Feedback

  #
  # Lifecycle
  #

  @impl true
  def mount(_params, _session, socket) do
    user_agent = get_connect_info(socket, :user_agent)

    parsed_user_agent =
      if user_agent do
        ua = UAParser.parse(user_agent)
        "#{ua} on #{ua.os}"
      else
        "Unknown"
      end

    socket
    |> assign_feedback_form()
    |> assign(
      page_title: "Feedback",
      parsed_user_agent: parsed_user_agent,
      user_agent: user_agent
    )
    |> ok()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("feedback_change", %{"feedback" => params}, socket) do
    socket
    |> assign_feedback_form(params)
    |> noreply()
  end

  def handle_event("feedback_submit", %{"feedback" => params}, socket) do
    socket
    |> feedback_submit(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_feedback_form(Socket.t()) :: Socket.t()
  @spec assign_feedback_form(Socket.t(), map) :: Socket.t()
  defp assign_feedback_form(socket, params \\ %{}) do
    user_agent = socket.assigns[:user_agent]
    user_id = socket.assigns[:current_user].id

    form =
      Map.merge(params, %{"user_agent" => user_agent, "user_id" => user_id})
      |> Feedback.create_changeset()
      |> to_form()

    assign(socket, form: form)
  end

  @spec feedback_submit(Socket.t(), map) :: Socket.t()
  defp feedback_submit(socket, params) do
    user_agent = socket.assigns[:user_agent]
    user_id = socket.assigns[:current_user].id

    params = Map.merge(params, %{"user_agent" => user_agent, "user_id" => user_id})

    case System.create_feedback(params) do
      {:ok, _feedback} ->
        socket
        |> assign_feedback_form()
        |> put_flash(:info, "Feedback submitted. Thank you!")

      {:error, changeset} ->
        assign(socket, form: to_form(changeset))
    end
  end

  #
  # Template Helpers
  #

  @spec category_options :: [{String.t(), String.t()}]
  defp category_options do
    [
      {"Issue", "issue"},
      {"Request", "request"},
      {"Other", "other"}
    ]
  end
end
