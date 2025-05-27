defmodule RM.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    Oban.Telemetry.attach_default_logger(events: [:job, :notifier, :peer, :queue, :stager])

    children = [
      RMWeb.Telemetry,
      RM.Repo,
      RM.System.Config,
      {DNSCluster, query: Application.get_env(:rm, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RM.PubSub},
      {Finch, name: RM.Finch},
      RMWeb.Endpoint,
      {Oban, Application.fetch_env!(:rm, Oban)}
    ]

    opts = [strategy: :one_for_one, name: RM.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    RMWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
