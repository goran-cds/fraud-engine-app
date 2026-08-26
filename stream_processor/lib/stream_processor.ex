defmodule StreamProcessor do
  @moduledoc """
  Documentation for `StreamProcessor`.
  """

  alias StreamProcessor.Infra.ClickhouseClient

  require Logger

  @doc """
  Takes a decoded transaction, builds a ClickHouse row from it, and persists it.
  """
  @spec persist_transaction(map()) :: :ok | {:error, term()}
  def persist_transaction(decoded) do
    case ClickhouseClient.insert_transaction(to_clickhouse_row(decoded)) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.error("failed to persist transaction to ClickHouse: #{inspect(reason)}")
        error
    end
  end

  defp to_clickhouse_row(decoded) do
    %{
      "transaction_id" => decoded["transaction_id"],
      "account_id" => decoded["account_id"],
      "amount_cents" => decoded["amount_cents"],
      "currency" => decoded["currency"],
      "merchant_id" => decoded["merchant_id"],
      "ip_address" => decoded["ip_address"],
      "device_fingerprint" => decoded["device_fingerprint"],
      "timestamp" => DateTime.from_unix!(decoded["timestamp"], :millisecond),
      "metadata" => decoded["metadata"],
      "fast_path_verdict" => decoded["fast_path_verdict"],
      "provisional" => decoded["provisional"]
    }
  end
end
