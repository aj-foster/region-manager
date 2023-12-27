defmodule RM.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RMWeb.Telemetry,
      RM.Repo,
      {DNSCluster, query: Application.get_env(:rm, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RM.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: RM.Finch},
      # Start a worker by calling: RM.Worker.start_link(arg)
      # {RM.Worker, arg},
      # Start to serve requests, typically the last entry
      RMWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RM.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RMWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
