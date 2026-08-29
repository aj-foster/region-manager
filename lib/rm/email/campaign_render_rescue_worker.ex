defmodule RM.Email.CampaignRenderRescueWorker do
  @moduledoc """
  Analogue of `Keila.Mailings.CampaignRenderWorker` for rescuing unrendered campaign messages
  """

  use Oban.Worker, queue: :system
  require Logger
  import Ecto.Query
  alias Keila.Mailings.Message

  def perform(%Oban.Job{}) do
    from(m in Message,
      where: m.status == :unrendered,
      group_by: m.campaign_id,
      select: m.campaign_id
    )
    |> Keila.Repo.all()
    |> Enum.each(fn campaign_id ->
      RM.Email.CampaignRenderWorker.new(%{campaign_id: campaign_id})
      |> Oban.insert()
      |> case do
        {:ok, _} ->
          Logger.warning(
            "CampaignRenderRescueWorker: Enqueued campaign render worker for campaign_id: #{campaign_id}"
          )

        _ ->
          :ok
      end
    end)
  end
end
