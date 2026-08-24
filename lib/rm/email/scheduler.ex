defmodule RM.Email.Scheduler do
  @moduledoc """
  An analogue to `Keila.Mailings.Scheduler` with customization
  """

  use GenServer
  use Keila.Repo

  require Logger
  import Ecto.Query

  alias Keila.Mailings.Message
  alias Keila.Mailings.Sender
  alias Keila.Mailings.SenderAdapters

  @global_send_rate_limit_per_second 20

  @lock_id 3114
  @tick_interval 1_000
  @leadership_check_interval 10_000

  @doc """
  Starts the Scheduler GenServer.

  Options:
  - `:mode` - defaults to `:default` (pass `:manual` to disable scheduling and state persistence)

  Options (all options other than `:mode` are passed to `GenServer.start_link`):
  - `:name` - defaults to `__MODULE__` (pass `nil` to disable setting a name)
  """
  def start_link(opts) do
    {init_opts, gen_server_opts} = Keyword.split(opts, [:mode])
    gen_server_opts = Keyword.put_new(gen_server_opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  @doc """
  Forces the scheduler to fetch partitions and schedule messages.
  Bypasses leadership check. Useful for testing.
  """
  def schedule(pid \\ __MODULE__) do
    GenServer.call(pid, :schedule)
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    Logger.debug("Scheduler: starting")

    mode = opts[:mode] || :default

    {:ok, conn} = checkout_postgres_connection()
    leading? = leading?(conn)

    if leading?, do: Logger.info("Scheduler: acquired leadership")

    state = %{
      conn: conn,
      leading?: leading?,
      rr_offset: 0,
      mode: mode
    }

    case mode do
      :default ->
        schedule_tick()
        schedule_leadership_check()
        {:ok, state}

      :manual ->
        {:ok, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    if Process.alive?(state.conn) do
      GenServer.stop(state.conn, :normal, 5000)
    end

    :ok
  end

  @impl true
  def handle_info(:tick, %{leading?: false} = state) do
    schedule_tick()
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    schedule_tick()
    {:noreply, tick(state)}
  end

  def handle_info(:check_leadership, %{leading?: true} = state) do
    schedule_leadership_check()

    case leading?(state.conn) do
      true ->
        {:noreply, state}

      false ->
        Logger.warning("Scheduler: lost leadership")
        {:noreply, %{state | leading?: false}}
    end
  end

  def handle_info(:check_leadership, %{leading?: false} = state) do
    schedule_leadership_check()

    case leading?(state.conn) do
      true ->
        Logger.info("Scheduler: acquired leadership")

        {:noreply, %{state | leading?: true}}

      false ->
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, conn, reason}, %{conn: conn} = state) do
    Logger.warning("Scheduler: connection exited: #{inspect(reason)}")
    {:stop, reason, state}
  end

  @impl true
  def handle_call(:schedule, _from, state) do
    {:reply, :ok, tick(state)}
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp schedule_leadership_check() do
    Process.send_after(self(), :check_leadership, @leadership_check_interval)
  end

  defp checkout_postgres_connection() do
    Keila.Repo.config()
    |> Keyword.drop([:pool])
    |> Keyword.put(:pool_size, 1)
    |> Postgrex.start_link()
  end

  defp leading?(conn) do
    case Postgrex.query(conn, "SELECT pg_try_advisory_lock($1)", [@lock_id]) do
      {:ok, %{rows: [[true]]}} ->
        true

      _other ->
        false
    end
  end

  defp tick(state) do
    rr_offset = state.rr_offset + 1
    partitions = fetch_partitions()

    for {adapter, senders} <- partitions do
      schedule_partition_messages(nil, adapter, senders, rr_offset)
    end

    %{state | rr_offset: rr_offset}
  end

  defp schedule_partition_messages(table, adapter, senders, rr_offset) do
    schedule_partition_messages(
      table,
      adapter,
      senders,
      rr_offset,
      @global_send_rate_limit_per_second
    )
  end

  defp schedule_partition_messages(_table, _adapter, _, _, 0), do: :ok
  defp schedule_partition_messages(_table, _adapter, [], _, _), do: :ok

  defp schedule_partition_messages(table, adapter, senders, rr_offset, partition_tokens) do
    sender = Enum.at(senders, rem(rr_offset, length(senders)))

    with :ok <- insert_delivery_job(sender) do
      schedule_partition_messages(table, adapter, senders, rr_offset + 1, partition_tokens - 1)
    else
      :error ->
        schedule_partition_messages(
          table,
          adapter,
          senders -- [sender],
          rr_offset,
          partition_tokens
        )
    end
  end

  defp insert_delivery_job(sender) do
    Keila.Repo.transact(fn ->
      case set_next_message_queued(sender) do
        {0, _} ->
          {:error, :error}

        {1, [message_id]} ->
          RM.Email.DeliveryWorker.new(%{"message_id" => message_id})
          |> Oban.insert!()

          {:ok, message_id}
      end
    end)
    |> case do
      {:ok, _message_id} -> :ok
      {:error, _} -> :error
    end
  end

  defp set_next_message_queued(sender) do
    message_id = next_message_id_query(sender)

    from(m in Message,
      where: m.id in subquery(message_id),
      update: [
        set: [status: :queued, queued_at: fragment("NOW()"), updated_at: fragment("NOW()")]
      ],
      select: m.id
    )
    |> Repo.update_all([])
  end

  defp next_message_id_query(sender) do
    from(m in Message,
      where: m.sender_id == ^sender.id and m.status == :ready,
      order_by: [asc: :priority, asc: :inserted_at],
      limit: 1,
      lock: "FOR UPDATE SKIP LOCKED",
      select: m.id
    )
  end

  defp fetch_partitions() do
    messages_ready =
      from(m in Message, where: m.sender_id == parent_as(:sender).id and m.status == :ready)

    senders =
      from(s in Sender,
        as: :sender,
        where: exists(messages_ready)
      )
      |> Keila.Repo.all()

    senders
    |> Enum.reduce(%{}, fn sender, partitions ->
      adapter = SenderAdapters.get_adapter(sender.config.type)
      Map.update(partitions, adapter, [sender], &[sender | &1])
    end)
  end
end
