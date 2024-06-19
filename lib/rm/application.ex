defmodule RM.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RMWeb.Telemetry,
      RM.Repo,
      {DNSCluster, query: Application.get_env(:rm, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RM.PubSub},
      {Finch, name: RM.Finch},
      RMWeb.Endpoint
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
