defmodule RMWeb.EmailLive.Edit do
  use RMWeb, :live_view
  import RMWeb.EmailLive.Util, only: [segment_options: 1, validate_params: 2]

  alias Keila.Contacts
  alias Keila.Mailings
  alias Keila.Mailings.Renderer.Input
  alias Keila.Mailings.Renderer.Output
  alias Keila.Mailings.Renderer.LiquidRenderer
  alias RM.Email.Renderer, as: MarkdownBodyRenderer

  #
  # Lifecycle
  #

  on_mount {RMWeb.EmailLive.Util, :require_current_season}
  on_mount {RMWeb.EmailLive.Util, :require_permission}
  on_mount {RMWeb.EmailLive.Util, :require_keila_records}
  on_mount {__MODULE__, :preload_message}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_changeset()
    |> put_campaign_preview()
    |> ok()
  end

  def on_mount(:preload_message, %{"message" => campaign_id}, _session, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]
    project_id = socket.assigns[:keila_project].id

    case Keila.Mailings.get_project_campaign(project_id, campaign_id) do
      %Keila.Mailings.Campaign{sent_at: nil} = campaign ->
        campaign = Keila.Repo.preload(campaign, :segment)

        socket
        |> assign(campaign: campaign, segment: campaign.segment)
        |> cont()

      %Keila.Mailings.Campaign{} = campaign ->
        socket
        |> put_flash(:error, "This email has already been sent and cannot be edited.")
        |> push_navigate(to: url_for([season, region, league, campaign]))
        |> halt()

      nil ->
        socket
        |> put_flash(:error, "Could not load email message.")
        |> push_navigate(to: url_for([season, region, league]))
        |> halt()
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("save", %{"campaign" => params} = full_params, socket) do
    autosave? = full_params["autosave"] == "true"

    socket
    |> assign_changeset(params)
    |> save_campaign(autosave?)
    |> noreply()
  end

  def handle_event("send_init", _params, socket) do
    socket
    |> push_js("#send-modal", "data-show")
    |> noreply()
  end

  def handle_event("send", _params, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]
    campaign = socket.assigns[:campaign]

    case RM.Email.Mailings.deliver_campaign(campaign.id) do
      :ok ->
        socket
        |> put_flash(:info, "Email is being sent.")
        |> push_navigate(to: url_for([season, region, league, :messages]))
        |> noreply()

      {:error, reason} ->
        socket
        |> put_flash(:error, "Failed to send email: #{inspect(reason)}")
        |> noreply()
    end
  end

  #
  # Helpers
  #

  defp assign_changeset(socket, params \\ %{}) do
    campaign = socket.assigns.campaign

    params =
      params
      |> Map.put("data", extract_profile_data(socket))
      |> Map.put_new("segment_id", campaign.segment_id)
      |> then(&validate_params(socket, &1))
      |> Map.delete("settings")

    changeset = Keila.Mailings.Campaign.preview_changeset(campaign, params)
    assign(socket, changeset: changeset)
  end

  defp extract_profile_data(socket) do
    if profile = socket.assigns[:current_user].profile do
      Map.take(profile.settings || %{}, [:email_signature_html, :email_signature_text])
    else
      %{}
    end
  end

  # Autosaves persist quietly; only manual saves surface a confirmation flash.
  defp maybe_flash_saved(socket, true), do: socket
  defp maybe_flash_saved(socket, false), do: put_flash(socket, :info, "Draft saved.")

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
        "unsubscribe_link" => "/user/settings",
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

  defp save_campaign(socket, autosave?) do
    merged_params = socket.assigns.changeset.params || %{}

    case Mailings.update_campaign(socket.assigns.campaign.id, merged_params, false) do
      {:ok, campaign} ->
        campaign = Keila.Repo.preload(campaign, :segment)

        socket
        |> assign(campaign: campaign, segment: campaign.segment)
        |> assign_changeset()
        |> put_campaign_preview()
        |> maybe_flash_saved(autosave?)
        |> push_js("#autosave-status", "data-saved")

      {:error, changeset} ->
        socket
        |> assign(:changeset, %{changeset | action: :update})
        |> put_campaign_preview()
    end
  end
end
