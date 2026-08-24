defmodule RM.Email.Adapter do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def adapter_rate_limit() do
    Application.get_env(:rm, __MODULE__, [])
    |> Keyword.get(:adapter_rate_limits, nil)
  end

  @impl true
  def name, do: "ses"

  @impl true
  def schema_fields do
    [
      ses_region: :string,
      ses_access_key: :string,
      ses_secret: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:ses_region, :ses_access_key, :ses_secret])
    |> validate_required([:ses_region, :ses_access_key, :ses_secret])
  end

  @impl true
  def to_swoosh_config(%{config: config}) do
    [
      adapter: Swoosh.Adapters.AmazonSES,
      region: config.ses_region,
      access_key: config.ses_access_key,
      secret: config.ses_secret
    ]
  end
end
