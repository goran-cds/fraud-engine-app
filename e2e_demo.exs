#
# End-to-end demo.
#
# Prerequisites:
#   - `docker compose up -d` (kafka, clickhouse)
#   - `risk_engine` running (`iex -S mix` in risk_engine/)
#   - `stream_processor` running (`iex -S mix` in stream_processor/)
#
# Run from the repo root:
#   elixir e2e_demo.exs

Mix.install([
  {:shared_contracts, path: Path.expand("shared_contracts", __DIR__)},
  {:grpc, "~> 0.11.5"},
  {:ch, "~> 0.6.0"}
])

Logger.configure(level: :info)

defmodule E2EDemo do
  require Logger

  alias SharedContracts.TransactionRequest

  @risk_engine_endpoint "localhost:50051"
  @clickhouse_opts [
    scheme: "http",
    hostname: "localhost",
    port: 8123,
    database: "default",
    username: "default",
    password: "default"
  ]

  @grpc_concurrency 50
  @poll_timeout_ms 180_000
  @poll_interval_ms 3_000

  @baseline_live_count 2_000
  @amount_ceiling_count 300
  @new_account_count 300
  @short_window_velocity_accounts 30
  @short_window_velocity_burst_size 7

  @baseline_seed_accounts 10
  @baseline_seed_days 8

  # 3 transactions summing to 2_000 cents ($20) per seeded day
  @baseline_seed_amounts [700, 700, 600]

  # 25x the $20/day seeded baseline
  @anomaly_trigger_cents 50_000

  @fan_out_seed_size 5
  @fan_out_trigger_count 10

  def run do
    run_id = "e2e#{System.system_time(:millisecond)}"
    Logger.info("=== e2e scenario run #{run_id} starting ===")

    {:ok, _pid} = GRPC.Client.Supervisor.start_link([])
    {:ok, channel} = GRPC.Stub.connect(@risk_engine_endpoint)
    {:ok, ch} = Ch.start_link(@clickhouse_opts)

    try do
      seed = seed_history!(ch, run_id)

      batch = build_live_batches(run_id, seed)

      Logger.info(
        "#{length(batch)} live transactions to be submitted by clients (concurrency: #{@grpc_concurrency})"
      )

      generic_result = send_live_traffic(channel, batch)

      Logger.info(
        "#{@short_window_velocity_accounts}x#{@short_window_velocity_burst_size} sequential velocity-burst transactions to be submitted by clients"
      )

      velocity_result =
        short_window_velocity_batch(channel, run_id, @short_window_velocity_accounts,
          burst_size: @short_window_velocity_burst_size
        )

      total_ok = generic_result.ok + velocity_result.ok
      total_error = generic_result.error + velocity_result.error

      Logger.info(
        "Live traffic complete: #{total_ok} scored successfully, #{total_error} failed at the gRPC layer"
      )

      expected_total = total_ok

      case await_processed(ch, run_id, expected_total) do
        {:ok, count} ->
          Logger.info("Async pipeline caught up: all #{count} rows landed in ClickHouse")

        {:timeout, count} ->
          Logger.warning(
            "Timed out waiting for async processing: only #{count}/#{expected_total} rows landed"
          )
      end

      verify_results!(ch, run_id)
    after
      cleanup!(ch, run_id)
    end
  end

  # --- seeding ---------------------------------------------------------

  defp seed_history!(ch, run_id) do
    Logger.info("Seeding historical data into ClickHouse (run_id=#{run_id})...")

    baseline_accounts =
      for n <- 1..@baseline_seed_accounts, do: random_id("acct_seed_baseline_#{n}")

    hot_device = random_id("dev_hot")
    hot_ip = random_ip()
    now = DateTime.utc_now()

    baseline_rows =
      for account_id <- baseline_accounts,
          day_offset <- 1..@baseline_seed_days,
          amount_cents <- @baseline_seed_amounts do
        seed_row(run_id, "seed_baseline", %{
          "account_id" => account_id,
          "amount_cents" => amount_cents,
          "timestamp" => DateTime.add(now, -day_offset * 86_400 - Enum.random(0..3_600), :second)
        })
      end

    fan_out_rows =
      for {identifier_key, identifier_value} <-
            List.duplicate({"device_fingerprint", hot_device}, @fan_out_seed_size) ++
              List.duplicate({"ip_address", hot_ip}, @fan_out_seed_size) do
        seed_row(run_id, "seed_fan_out", %{
          "account_id" => random_id("acct_seed_fanout"),
          "amount_cents" => Enum.random(1_000..20_000),
          "timestamp" => DateTime.add(now, -Enum.random(3_600..7_200), :second),
          identifier_key => identifier_value
        })
      end

    rows = baseline_rows ++ fan_out_rows
    Enum.each(rows, &insert_row!(ch, &1))

    Logger.info(
      "Seeded #{length(rows)} historical rows " <>
        "(#{length(baseline_rows)} baseline, #{length(fan_out_rows)} fan-out)"
    )

    %{
      baseline_accounts: baseline_accounts,
      hot_device: hot_device,
      hot_ip: hot_ip,
      seed_row_count: length(rows)
    }
  end

  defp seed_row(run_id, scenario, overrides) do
    %{
      "transaction_id" => random_id("txn_seed"),
      "account_id" => random_id("acct_seed"),
      "amount_cents" => 0,
      "currency" => "USD",
      "merchant_id" => random_id("merch"),
      "ip_address" => random_ip(),
      "device_fingerprint" => random_id("dev"),
      "timestamp" => DateTime.utc_now(),
      "metadata" => %{"e2e_run_id" => run_id, "e2e_scenario" => scenario},
      "fast_path_verdict" => "APPROVE",
      "heavy_path_verdict" => "APPROVE",
      "verdict" => "APPROVE",
      "provisional" => false
    }
    |> Map.merge(overrides)
  end

  defp insert_row!(ch, row) do
    sql = """
    INSERT INTO transactions
    (transaction_id, account_id, amount_cents, currency, merchant_id, ip_address, device_fingerprint, timestamp, metadata, fast_path_verdict, heavy_path_verdict, verdict, provisional)
    VALUES (
      {transaction_id:String}, {account_id:String}, {amount_cents:Int64}, {currency:String},
      {merchant_id:String}, {ip_address:String}, {device_fingerprint:String}, {timestamp:DateTime64(3)},
      {metadata:Map(String, String)}, {fast_path_verdict:String}, {heavy_path_verdict:Nullable(String)},
      {verdict:String}, {provisional:Bool}
    )
    """

    case Ch.query(ch, sql, row) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "failed to seed row into ClickHouse: #{inspect(reason)}"
    end
  end

  # --- live traffic ------------------------------------------------------

  defp build_live_batches(run_id, seed) do
    baseline =
      for _ <- 1..@baseline_live_count do
        {"baseline",
         build_request(
           run_id: run_id,
           scenario: "baseline",
           amount_cents: Enum.random(1_000..50_000)
         )}
      end

    amount_ceiling =
      for _ <- 1..@amount_ceiling_count do
        {"amount_ceiling",
         build_request(
           run_id: run_id,
           scenario: "amount_ceiling",
           amount_cents: Enum.random(1_000_000..2_000_000)
         )}
      end

    new_account =
      for _ <- 1..@new_account_count do
        {"new_account",
         build_request(
           run_id: run_id,
           scenario: "new_account",
           amount_cents: Enum.random(500_000..999_999)
         )}
      end

    velocity_anomaly =
      for account_id <- seed.baseline_accounts do
        {"velocity_anomaly",
         build_request(
           run_id: run_id,
           scenario: "velocity_anomaly",
           account_id: account_id,
           amount_cents: @anomaly_trigger_cents
         )}
      end

    device_fan_out =
      for _ <- 1..@fan_out_trigger_count do
        {"device_fan_out",
         build_request(
           run_id: run_id,
           scenario: "device_fan_out",
           amount_cents: Enum.random(1_000..20_000),
           device_fingerprint: seed.hot_device
         )}
      end

    ip_fan_out =
      for _ <- 1..@fan_out_trigger_count do
        {"ip_fan_out",
         build_request(
           run_id: run_id,
           scenario: "ip_fan_out",
           amount_cents: Enum.random(1_000..20_000),
           ip_address: seed.hot_ip
         )}
      end

    baseline ++ amount_ceiling ++ new_account ++ velocity_anomaly ++ device_fan_out ++ ip_fan_out
  end

  defp send_live_traffic(channel, batch) do
    total = length(batch)

    batch
    |> Task.async_stream(
      fn {scenario, request} -> {scenario, score(channel, request)} end,
      max_concurrency: @grpc_concurrency,
      timeout: 30_000,
      on_timeout: :kill_task
    )
    |> Stream.with_index(1)
    |> Enum.reduce(%{ok: 0, error: 0}, fn {result, index}, acc ->
      if rem(index, 250) == 0 or index == total do
        Logger.info("... #{index}/#{total} gRPC calls completed for a client")
      end

      case result do
        {:ok, {_scenario, {:ok, _decision}}} ->
          %{acc | ok: acc.ok + 1}

        {:ok, {_scenario, {:error, reason}}} ->
          Logger.error("gRPC call failed: #{inspect(reason)}")
          %{acc | error: acc.error + 1}

        {:exit, reason} ->
          Logger.error("gRPC task crashed: #{inspect(reason)}")
          %{acc | error: acc.error + 1}
      end
    end)
  end

  # ShortWindowVelocity needs each account's own burst sent strictly in order
  defp short_window_velocity_batch(channel, run_id, account_count, opts) do
    burst_size = Keyword.fetch!(opts, :burst_size)

    1..account_count
    |> Task.async_stream(
      fn n -> run_velocity_burst(channel, run_id, n, burst_size) end,
      max_concurrency: 10,
      timeout: 30_000,
      on_timeout: :kill_task
    )
    |> Enum.reduce(%{ok: 0, error: 0}, fn
      {:ok, {ok, error}}, acc -> %{ok: acc.ok + ok, error: acc.error + error}
      {:exit, _reason}, acc -> %{acc | error: acc.error + burst_size}
    end)
  end

  defp run_velocity_burst(channel, run_id, n, burst_size) do
    account_id = random_id("acct_swv_#{n}")
    device_fingerprint = random_id("dev")
    ip_address = random_ip()

    Enum.reduce(1..burst_size, {0, 0}, fn _i, {ok, error} ->
      request =
        build_request(
          run_id: run_id,
          scenario: "short_window_velocity",
          account_id: account_id,
          device_fingerprint: device_fingerprint,
          ip_address: ip_address,
          amount_cents: Enum.random(500..5_000)
        )

      case score(channel, request) do
        {:ok, _decision} ->
          {ok + 1, error}

        {:error, reason} ->
          Logger.error("Velocity burst call failed: #{inspect(reason)}")
          {ok, error + 1}
      end
    end)
  end

  defp score(channel, request) do
    SharedContracts.RiskEngine.Stub.score_transaction(channel, request)
  end

  defp build_request(opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    scenario = Keyword.fetch!(opts, :scenario)

    %TransactionRequest{
      transaction_id: random_id("txn"),
      account_id: Keyword.get(opts, :account_id, random_id("acct")),
      amount_cents: Keyword.fetch!(opts, :amount_cents),
      currency: "USD",
      merchant_id: random_id("merch"),
      ip_address: Keyword.get(opts, :ip_address, random_ip()),
      device_fingerprint: Keyword.get(opts, :device_fingerprint, random_id("dev")),
      timestamp: System.os_time(:millisecond),
      metadata: %{"e2e_run_id" => run_id, "e2e_scenario" => scenario}
    }
  end

  # --- waiting for the async pipeline ------------------------------------

  defp await_processed(ch, run_id, expected_count) do
    deadline = System.monotonic_time(:millisecond) + @poll_timeout_ms
    do_await(ch, run_id, expected_count, deadline)
  end

  defp do_await(ch, run_id, expected_count, deadline) do
    count = count_rows(ch, run_id)
    Logger.info("ClickHouse rows processed: #{count}/#{expected_count}")

    cond do
      count >= expected_count ->
        {:ok, count}

      System.monotonic_time(:millisecond) >= deadline ->
        {:timeout, count}

      true ->
        Process.sleep(@poll_interval_ms)
        do_await(ch, run_id, expected_count, deadline)
    end
  end

  defp count_rows(ch, run_id) do
    sql = "SELECT count(*) FROM transactions WHERE metadata['e2e_run_id'] = {run_id:String}"
    {:ok, %Ch.Result{rows: [[count]]}} = Ch.query(ch, sql, %{"run_id" => run_id})
    count
  end

  # --- verification -------------------------------------------------------

  @expected_outcomes [
    {"baseline", "verdict = 'APPROVE'"},
    {"amount_ceiling", "fast_path_verdict = 'REVIEW' AND verdict = 'APPROVE'"},
    {"new_account", "fast_path_verdict = 'REVIEW' AND verdict = 'APPROVE'"},
    {"short_window_velocity", "verdict = 'APPROVE'"},
    {"velocity_anomaly", "verdict = 'DECLINE' AND heavy_path_verdict = 'DECLINE'"},
    {"device_fan_out", "verdict = 'DECLINE' AND heavy_path_verdict = 'DECLINE'"},
    {"ip_fan_out", "verdict = 'DECLINE' AND heavy_path_verdict = 'DECLINE'"}
  ]

  defp verify_results!(ch, run_id) do
    Logger.info("Verifying scoring outcomes per scenario...")

    results =
      Enum.map(@expected_outcomes, fn {scenario, predicate} ->
        verify_scenario(ch, run_id, scenario, predicate)
      end)

    print_report(results)

    if Enum.any?(results, fn {_scenario, passed?, _total, _mismatches} -> not passed? end) do
      Logger.error("=== e2e scenario FAILED ===")
      System.halt(1)
    else
      Logger.info("=== e2e scenario PASSED ===")
    end
  end

  defp verify_scenario(ch, run_id, scenario, predicate) do
    sql = """
    SELECT count(*) AS total, countIf(NOT (#{predicate})) AS mismatches
    FROM transactions
    WHERE metadata['e2e_run_id'] = {run_id:String} AND metadata['e2e_scenario'] = {scenario:String}
    """

    {:ok, %Ch.Result{rows: [[total, mismatches]]}} =
      Ch.query(ch, sql, %{"run_id" => run_id, "scenario" => scenario})

    {scenario, total > 0 and mismatches == 0, total, mismatches}
  end

  defp print_report(results) do
    IO.puts("\n=== scenario verification report ===")

    Enum.each(results, fn {scenario, passed?, total, mismatches} ->
      status = if passed?, do: "PASS", else: "FAIL"
      IO.puts("  [#{status}] #{scenario}: #{total} rows, #{mismatches} mismatched")
    end)

    IO.puts("")
  end

  # --- cleanup -------------------------------------------------------------

  defp cleanup!(ch, run_id) do
    Logger.info("Cleaning up every row tagged with run #{run_id}...")

    sql = """
    DELETE FROM transactions
    WHERE metadata['e2e_run_id'] = {run_id:String}
    SETTINGS mutations_sync = 2
    """

    case Ch.query(ch, sql, %{"run_id" => run_id}) do
      {:ok, _result} ->
        Logger.info("Cleanup complete!")

      {:error, reason} ->
        Logger.error("Cleanup failed! Manual cleanup may be needed: #{inspect(reason)}")
    end
  end

  # --- helpers ---------------------------------------------------------------

  defp random_id(prefix) do
    suffix = :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
    "#{prefix}_#{suffix}"
  end

  defp random_ip do
    "10.#{Enum.random(1..254)}.#{Enum.random(1..254)}.#{Enum.random(1..254)}"
  end
end

E2EDemo.run()
