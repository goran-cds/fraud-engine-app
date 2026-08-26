defmodule StreamProcessor.Infra.ClickhouseClient do
  use GenServer

  require Logger

  @table_name "transactions"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec insert_transaction(map()) :: :ok | {:error, term()}
  def insert_transaction(row) do
    GenServer.call(__MODULE__, {:insert_transaction, row})
  end

  @impl true
  def init(_opts) do
    config = Application.fetch_env!(:stream_processor, __MODULE__)

    connection_opts = [
      scheme: "http",
      hostname: config[:host],
      port: config[:port],
      database: config[:database],
      username: config[:username],
      password: config[:password],
      pool_size: 1,
      timeout: :timer.seconds(15)
    ]

    with {:ok, pid} <- Ch.start_link(connection_opts),
         :ok <- ensure_table_exists(pid) do
      {:ok, %{ch_pid: pid}}
    else
      {:error, reason} ->
        Logger.error("failed to start ClickHouse client: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:insert_transaction, row}, _from, state) do
    {:reply, do_insert_transaction(state.ch_pid, row), state}
  end

  defp do_insert_transaction(pid, row) do
    sql = """
    INSERT INTO #{@table_name}
    (transaction_id, account_id, amount_cents, currency, merchant_id, ip_address, device_fingerprint, timestamp, metadata, fast_path_verdict, provisional)
    VALUES (
      {transaction_id:String}, {account_id:String}, {amount_cents:Int64}, {currency:String},
      {merchant_id:String}, {ip_address:String}, {device_fingerprint:String}, {timestamp:DateTime64(3)},
      {metadata:Map(String, String)}, {fast_path_verdict:String}, {provisional:Bool}
    )
    """

    case Ch.query(pid, sql, row) do
      {:ok, _result} ->
        :ok

      {:error, reason} ->
        Logger.error("failed to insert transaction into ClickHouse: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_table_exists(pid) do
    sql = """
    CREATE TABLE IF NOT EXISTS #{@table_name} (
        transaction_id      String,
        account_id          String,
        amount_cents        Int64,
        currency            LowCardinality(String),
        merchant_id         String,
        ip_address          String,
        device_fingerprint  String,
        timestamp           DateTime64(3),
        metadata            Map(String, String),
        fast_path_verdict   Enum8('APPROVE' = 1, 'REVIEW' = 2, 'DECLINE' = 3),
        provisional         Bool
    )
    ENGINE = MergeTree()
    PARTITION BY toYYYYMM(timestamp)
    ORDER BY (account_id, timestamp)
    """

    case Ch.query(pid, sql) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
