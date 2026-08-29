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

  @doc """
  This account's own average daily total amounts over the last `lookback_days`.
  """
  @spec account_baseline(String.t(), pos_integer()) :: {:ok, float() | nil} | {:error, term()}
  def account_baseline(account_id, lookback_days) do
    GenServer.call(__MODULE__, {:account_baseline, account_id, lookback_days})
  end

  @doc """
  Distinct `account_id` counts for this `device_fingerprint` and this `ip_address` independently, each over the last `lookback_hours.
  """
  @spec distinct_accounts_for_device_or_ip(String.t(), String.t(), pos_integer()) ::
          {:ok, %{device_fan_out: non_neg_integer(), ip_fan_out: non_neg_integer()}}
          | {:error, term()}
  def distinct_accounts_for_device_or_ip(device_fingerprint, ip_address, lookback_hours) do
    GenServer.call(
      __MODULE__,
      {:distinct_accounts_for_device_or_ip, device_fingerprint, ip_address, lookback_hours}
    )
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

  @impl true
  def handle_call({:account_baseline, account_id, lookback_days}, _from, state) do
    {:reply, do_account_baseline(state.ch_pid, account_id, lookback_days), state}
  end

  @impl true
  def handle_call(
        {:distinct_accounts_for_device_or_ip, device_fingerprint, ip_address, lookback_hours},
        _from,
        state
      ) do
    {:reply,
     do_distinct_accounts_for_device_or_ip(
       state.ch_pid,
       device_fingerprint,
       ip_address,
       lookback_hours
     ), state}
  end

  defp do_insert_transaction(pid, row) do
    sql = """
    INSERT INTO #{@table_name}
    (transaction_id, account_id, amount_cents, currency, merchant_id, ip_address, device_fingerprint, timestamp, metadata, fast_path_verdict, heavy_path_verdict, verdict, provisional)
    VALUES (
      {transaction_id:String}, {account_id:String}, {amount_cents:Int64}, {currency:String},
      {merchant_id:String}, {ip_address:String}, {device_fingerprint:String}, {timestamp:DateTime64(3)},
      {metadata:Map(String, String)}, {fast_path_verdict:String}, {heavy_path_verdict:Nullable(String)},
      {verdict:String}, {provisional:Bool}
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

  defp do_account_baseline(pid, account_id, lookback_days) do
    sql = """
    SELECT avgOrNull(daily_total) AS avg_daily_amount_cents
    FROM (
        SELECT sum(amount_cents) AS daily_total
        FROM #{@table_name}
        WHERE account_id = {account_id:String}
          AND timestamp >= now() - INTERVAL {lookback_days:UInt32} DAY
        GROUP BY toDate(timestamp)
    )
    """

    case Ch.query(pid, sql, %{"account_id" => account_id, "lookback_days" => lookback_days}) do
      {:ok, %Ch.Result{rows: [[avg_daily_amount_cents]]}} ->
        {:ok, avg_daily_amount_cents}

      {:error, reason} ->
        Logger.error("failed to query account baseline from ClickHouse: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_distinct_accounts_for_device_or_ip(pid, device_fingerprint, ip_address, lookback_hours) do
    sql = """
    SELECT
      uniqExactIf(account_id, device_fingerprint = {device_fingerprint:String}) AS device_fan_out,
      uniqExactIf(account_id, ip_address = {ip_address:String}) AS ip_fan_out
    FROM #{@table_name}
    WHERE (device_fingerprint = {device_fingerprint:String} OR ip_address = {ip_address:String})
      AND timestamp >= now() - INTERVAL {lookback_hours:UInt32} HOUR
    """

    case Ch.query(pid, sql, %{
           "device_fingerprint" => device_fingerprint,
           "ip_address" => ip_address,
           "lookback_hours" => lookback_hours
         }) do
      {:ok, %Ch.Result{rows: [[device_fan_out, ip_fan_out]]}} ->
        {:ok, %{device_fan_out: device_fan_out, ip_fan_out: ip_fan_out}}

      {:error, reason} ->
        Logger.error("failed to query device/IP fan-out from ClickHouse: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_table_exists(pid) do
    create_sql = """
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
        heavy_path_verdict  Nullable(Enum8('APPROVE' = 1, 'DECLINE' = 2)),
        verdict             Enum8('APPROVE' = 1, 'REVIEW' = 2, 'DECLINE' = 3),
        provisional         Bool
    )
    ENGINE = MergeTree()
    PARTITION BY toYYYYMM(timestamp)
    ORDER BY (account_id, timestamp)
    """

    add_columns_sql = """
    ALTER TABLE #{@table_name}
        ADD COLUMN IF NOT EXISTS heavy_path_verdict Nullable(Enum8('APPROVE' = 1, 'DECLINE' = 2)) AFTER fast_path_verdict,
        ADD COLUMN IF NOT EXISTS verdict Enum8('APPROVE' = 1, 'REVIEW' = 2, 'DECLINE' = 3) AFTER heavy_path_verdict
    """

    with {:ok, _result} <- Ch.query(pid, create_sql),
         {:ok, _result} <- Ch.query(pid, add_columns_sql) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
