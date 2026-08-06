defmodule RM.Email.CampaignRenderer do
  @moduledoc """
  Analogue to `Keila.Mailings.CampaignRenderer` with customization
  """
  require Logger

  alias Keila.Contacts.Contact
  alias Keila.Mailings.Campaign
  alias Keila.Mailings.Message
  alias Keila.Mailings.Renderer.{Input, Output}
  alias RM.Email.Renderer

  @doc """
  Renders a campaign message into `Output` and applies open/click tracking if enabled.
  """
  @spec render(Campaign.t(), Message.t()) :: Output.t()
  def render(%Campaign{} = campaign, %Message{} = message) do
    # TODO
    unsubscribe_link = "/"

    campaign
    |> to_input(message.contact, %{"unsubscribe_link" => unsubscribe_link})
    |> Renderer.render()
  end

  @doc "Maps a campaign and contact into an Input."
  @spec to_input(Campaign.t(), Contact.t() | nil, map()) :: Input.t()
  def to_input(%Campaign{} = campaign, contact, assigns \\ %{}) do
    assigns =
      assigns
      |> Map.put_new("campaign", Map.take(campaign, [:data, :subject, :preview_text]))
      # TODO
      |> put_in(["campaign", "public_link"], "/")

    %Input{
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
      recipient_email: contact && contact.email,
      assigns: assigns
    }
  end
end
