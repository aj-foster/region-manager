defmodule RMWeb.EmailLive.Edit do
  use RMWeb, :live_view

  alias Keila.Contacts
  alias Keila.Mailings
  alias Keila.Mailings.Renderer.Input
  alias Keila.Mailings.Renderer.Output
  alias Keila.Mailings.Renderer.BodyRenderer.Markdown, as: MarkdownBodyRenderer
  alias Keila.Mailings.Renderer.LiquidRenderer

  #
  # Lifecycle
  #

  on_mount {__MODULE__, :require_current_season}
  on_mount {__MODULE__, :preload_message}
  on_mount {__MODULE__, :require_correct_segment}
  on_mount {__MODULE__, :require_permission}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_changeset()
    |> put_campaign_preview()
    |> ok()
  end

  def on_mount(:require_current_season, _params, _session, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]

    redirect_target = url_for([season, region, league])

    cond do
      season > region.current_season ->
        socket
        |> put_flash(:error, "Messaging for #{season} is not yet available.")
        |> push_navigate(to: redirect_target)
        |> halt()

      season < region.current_season ->
        socket
        |> put_flash(:error, "Messaging for #{season} is no longer available.")
        |> push_navigate(to: redirect_target)
        |> halt()

      :else ->
        {:cont, socket}
    end
  end

  def on_mount(:preload_message, %{"message" => campaign_id}, _session, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]
    project_id = socket.assigns[:region].metadata.keila_project_id

    case Keila.Mailings.get_project_campaign(project_id, campaign_id) do
      %Keila.Mailings.Campaign{sent_at: nil} = campaign ->
        socket
        |> assign(campaign: campaign)
        |> cont()

      %Keila.Mailings.Campaign{} = campaign ->
        socket
        |> put_flash(:error, "This email has already been sent and cannot be edited.")
        |> push_navigate(to: url_for([season, region, league, campaign]))
        |> halt()

      nil ->
        socket
        |> put_flash(:error, "Could not load email message.")
        |> push_navigate(to: ~p"/dashboard")
        |> halt()
    end
  end

  def on_mount(:require_correct_segment, _params, _session, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]
    campaign = socket.assigns[:campaign]

    segment_ids = [
      (league || region).metadata.keila_segment_id,
      (league || region).metadata.keila_coach_segment_id,
      (league || region).metadata.keila_extended_coach_segment_id
    ]

    if campaign.segment_id in segment_ids do
      {:cont, socket}
    else
      socket
      |> put_flash(:error, "An error occurred. Please contact support (incorrect_segment).")
      |> push_navigate(to: url_for([season, region, league, campaign]))
      |> halt()
    end
  end

  def on_mount(:require_permission, _params, _session, socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    user = socket.assigns[:current_user]

    if can?(user, :email_message_send, league || region) do
      {:cont, socket}
    else
      socket
      |> put_flash(
        :error,
        "You do not have permission to send messages for this #{if league, do: "league", else: "region"}."
      )
      |> push_navigate(to: url_for([season, region, league]))
      |> halt()
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("update", %{"campaign" => params}, socket) do
    socket
    |> assign(:changeset, merged_changeset(socket, params))
    |> put_campaign_preview()
    |> noreply()
  end

  def handle_event("save", %{"campaign" => params}, socket) do
    changeset = merged_changeset(socket, params)
    merged_params = changeset.params || %{}

    case Mailings.update_campaign(socket.assigns.campaign.id, merged_params, false) do
      {:ok, campaign} ->
        socket
        |> assign(:campaign, campaign)
        |> assign(:changeset, Keila.Mailings.Campaign.preview_changeset(campaign, %{}))
        |> put_campaign_preview()
        |> put_flash(:info, "Draft saved.")
        |> noreply()

      {:error, changeset} ->
        socket
        |> assign(:changeset, %{changeset | action: :update})
        |> put_campaign_preview()
        |> noreply()
    end
  end

  #
  # Helpers
  #

  defp assign_changeset(socket) do
    assign(
      socket,
      :changeset,
      Keila.Mailings.Campaign.preview_changeset(socket.assigns.campaign, %{})
    )
  end

  defp merged_changeset(socket, params) do
    merged_params =
      Keila.Mailings.Campaign.preview_changeset(socket.assigns.changeset, params)
      |> Map.fetch!(:params)
      |> then(fn params -> params || %{} end)

    Keila.Mailings.Campaign.preview_changeset(socket.assigns.campaign, merged_params)
  end

  defp put_campaign_preview(socket) do
    campaign = Ecto.Changeset.apply_changes(socket.assigns.changeset)
    output = render_markdown_preview(campaign)

    preview =
      cond do
        is_binary(output.html_body) and output.html_body != "" ->
          output.html_body

        is_binary(output.text_body) and output.text_body != "" ->
          escaped_text =
            output.text_body
            |> Phoenix.HTML.html_escape()
            |> Phoenix.HTML.safe_to_string()

          "<pre>" <> escaped_text <> "</pre>"

        true ->
          ""
      end

    assign(socket, :preview, preview)
  end

  defp render_markdown_preview(campaign) do
    contact = %Keila.Contacts.Contact{
      id: "c_id",
      first_name: "Jane",
      last_name: "Doe",
      email: "jane.doe@example.com",
      data: %{}
    }

    input = %Input{
      type: campaign.settings.type,
      subject: campaign.subject,
      mjml_body: campaign.mjml_body,
      html_body: campaign.html_body,
      text_body: campaign.text_body,
      json_body: campaign.json_body,
      mjml_content: campaign.mjml_content,
      html_content: campaign.html_content,
      text_content: campaign.text_content,
      template: campaign.template,
      contact: contact,
      recipient_email: contact.email,
      recipient_name: "#{contact.first_name} #{contact.last_name}",
      assigns: %{
        "campaign" => Map.take(campaign, [:data, :subject, :preview_text]),
        "unsubscribe_link" => "#unsubscribe-preview-link",
        "assets_url" => "/"
      }
    }

    assigns = preview_assigns(input)

    case campaign.settings.type do
      :markdown -> MarkdownBodyRenderer.render(%Output{}, input, assigns)
      _other -> %Output{valid?: true, text_body: campaign.text_body, html_body: nil}
    end
  end

  defp preview_assigns(input) do
    template_assigns =
      case input.template do
        %{assigns: assigns} when is_map(assigns) -> assigns
        _ -> %{}
      end

    contact_assigns =
      input.contact
      |> LiquidRenderer.process_assigns()
      |> Map.put("display_name", Contacts.display_name(input.contact))

    template_assigns
    |> Map.merge(input.assigns)
    |> Map.put_new("contact", contact_assigns)
    |> LiquidRenderer.process_assigns()
  end
end
