defmodule RM.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Disabled due to Keila cron job logs
    # Oban.Telemetry.attach_default_logger(events: [:job, :notifier, :peer, :queue, :stager])
    maybe_run_keila_migrations()

    children =
      [
        RMWeb.Telemetry,
        RM.Repo,
        RM.System.Config,
        {DNSCluster, query: Application.get_env(:rm, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: RM.PubSub},
        {Finch, name: RM.Finch},
        RMWeb.Endpoint,
        {Oban, Application.fetch_env!(:rm, Oban)},

        # Keila
        Keila.Repo,
        {Task.Supervisor, name: Keila.TaskSupervisor},
        %{
          id: Keila.Id.Cache,
          start: {Agent, :start_link, [&Keila.Id.hashid_config/0, [name: Keila.Id.Cache]]}
        }
      ] ++ keila_scheduler()

    opts = [strategy: :one_for_one, name: RM.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    RMWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_run_keila_migrations do
    unless Application.get_env(:keila, :skip_migrations) do
      Keila.ReleaseTasks.init()
    end
  end

  @env Mix.env()
  defp keila_scheduler do
    if @env == :test do
      []
    else
      [{Keila.Mailings.Scheduler, []}]
    end
  end
end
