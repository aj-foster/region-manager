defmodule RMWeb.EmailLive.Show do
  use RMWeb, :live_view

  alias Keila.Contacts
  alias Keila.Mailings.Renderer.Input
  alias Keila.Mailings.Renderer.Output
  alias Keila.Mailings.Renderer.LiquidRenderer
  alias RM.Email.Renderer, as: MarkdownBodyRenderer

  #
  # Lifecycle
  #

  on_mount {RMWeb.EmailLive.Util, :require_current_season}
  on_mount {RMWeb.EmailLive.Util, :require_keila_records}
  on_mount {__MODULE__, :preload_message}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> put_campaign_preview()
    |> ok()
  end

  def on_mount(:preload_message, %{"message" => campaign_id}, _session, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]
    project_id = socket.assigns[:keila_project].id

    case Keila.Mailings.get_project_campaign(project_id, campaign_id) do
      %Keila.Mailings.Campaign{sent_at: %DateTime{}} = campaign ->
        campaign = Keila.Repo.preload(campaign, :segment)

        socket
        |> assign(campaign: campaign, segment: campaign.segment)
        |> cont()

      _ ->
        socket
        |> put_flash(:error, "Could not load email message.")
        |> push_navigate(to: url_for([season, region, league, :messages]))
        |> halt()
    end
  end

  #
  # Helpers
  #

  defp put_campaign_preview(socket) do
    campaign = socket.assigns[:campaign]
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
end
