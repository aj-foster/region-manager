defmodule RM.Email.Mailings do
  @moduledoc """
  Analogue to `Keila.Mailings` with customization
  """
  import Ecto.Query
  require Logger

  alias Keila.Mailings.{Campaign, Message}
  alias Keila.Repo

  @doc """
  Delivers a campaign.

  Returns `:ok`.
  If there were no recipients, returns `{:error, :no_recipients}`
  If no sender is set, returns `{:error, :no_sender}`

  In case of an error, the campaign is un-scheduled if it was previously
  scheduled for sending.
  """
  @spec deliver_campaign(Campaign.id()) :: {:error, :no_recipients} | {:error, term()} | :ok
  def deliver_campaign(id) do
    result =
      Repo.transaction(
        fn ->
          case get_and_lock_campaign(id) do
            %Campaign{sent_at: sent_at} when not is_nil(sent_at) -> Repo.rollback(:already_sent)
            %Campaign{sender_id: nil} -> Repo.rollback(:no_sender)
            campaign = %Campaign{} -> do_deliver_campaign(campaign)
          end
        end,
        timeout: 60_000
      )

    case result do
      {:ok, _n} ->
        :ok

      {:error, reason} ->
        maybe_unschedule_campaign_after_failed_delivery(id)
        {:error, reason}
    end
  end

  defp maybe_unschedule_campaign_after_failed_delivery(campaign_id) do
    campaign = Keila.Mailings.get_campaign(campaign_id)

    if campaign && campaign.scheduled_for do
      campaign |> Campaign.unschedule_after_failed_delivery_changeset() |> Repo.update()
    end
  end

  @doc """
  Searches for campaigns in a given project that contain the given search string.

  Returns a list of campaigns that match the search string or an empty list if no campaigns match.

  The search string is matched against the `text_body`, `html_body`, `mjml_body`, and `json_body` fields.
  """
  @spec search_in_project_campaigns(Project.id(), String.t()) :: [Campaign.t()]
  def search_in_project_campaigns(project_id, search_string)
      when is_binary(project_id) or is_integer(project_id) do
    from(c in Campaign,
      where: c.project_id == ^project_id,
      where:
        fragment(
          "text_body LIKE ? OR html_body LIKE ? OR mjml_body LIKE ? OR json_body::text LIKE ?",
          ^"%#{search_string}%",
          ^"%#{search_string}%",
          ^"%#{search_string}%",
          ^"%#{search_string}%"
        ),
      order_by: [desc: :updated_at]
    )
    |> Repo.all()
  end

  defp get_and_lock_campaign(id) do
    from(c in Campaign, where: c.id == ^id, lock: "FOR NO KEY UPDATE", preload: :segment)
    |> Repo.one()
  end

  defp do_deliver_campaign(campaign) do
    {:ok, campaign} =
      campaign
      |> Ecto.Changeset.change(sent_at: DateTime.truncate(DateTime.utc_now(), :second))
      |> Repo.update()

    segment_filter = if campaign.segment, do: campaign.segment.filter, else: %{}
    filter = %{"$and" => [segment_filter, %{"status" => "active"}]}

    Keila.Contacts.stream_project_contacts(campaign.project_id, filter: filter)
    |> Stream.chunk_every(5000)
    |> Stream.map(fn contacts ->
      insert_messages(contacts, campaign)
    end)
    |> Enum.sum()
    |> tap(&insert_rendering_job(&1, campaign))
    |> tap(&ensure_not_empty/1)
  end

  @unrendered_status Ecto.Enum.mappings(Message, :status)[:unrendered]
  defp insert_messages(contacts, campaign) do
    {:ok, campaign_id} = Keila.Mailings.Campaign.Id.dump(campaign.id)
    {:ok, sender_id} = Keila.Mailings.Sender.Id.dump(campaign.sender_id)
    Logger.info("Inserting messages for campaign #{campaign_id} with sender #{sender_id}")

    # Inserting entries like this is about 1/3 more performant than constructing structs first
    contact_ids =
      Enum.map(contacts, fn contact ->
        {:ok, id} = Keila.Contacts.Contact.Id.dump(contact.id)
        %{id: id}
      end)

    {:ok, project_id} = Keila.Projects.Project.Id.dump(campaign.project_id)

    {count, _} =
      Repo.insert_all(
        Message,
        from(c in values(contact_ids, %{id: :integer}),
          select: %{
            contact_id: c.id,
            campaign_id: ^campaign_id,
            sender_id: ^sender_id,
            inserted_at: fragment("now()"),
            updated_at: fragment("now()"),
            status: @unrendered_status,
            project_id: ^project_id
          }
        )
      )

    count
  end

  defp insert_rendering_job(0, _campaign), do: :ok

  defp insert_rendering_job(_, campaign),
    do: RM.Email.CampaignRenderWorker.new(%{"campaign_id" => campaign.id}) |> Oban.insert!()

  defp ensure_not_empty(0), do: Repo.rollback(:no_recipients)
  defp ensure_not_empty(_), do: :ok
end
