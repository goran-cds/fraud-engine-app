defmodule StreamProcessor do
  @moduledoc """
  Documentation for `StreamProcessor`.
  """

  alias StreamProcessor.Infra.ClickhouseClient
  alias StreamProcessor.Validator.Verifier

  require Logger

  @doc """
  Takes a decoded transaction, scores it against the heavy-path rules, builds the ClickHouse row
  with the final combined verdict, and persists it.
  """
  @spec persist_transaction(map()) :: :ok | {:error, term()}
  def persist_transaction(decoded) do
    score = Verifier.validate(decoded["fast_path_verdict"], decoded)

    case ClickhouseClient.insert_transaction(to_clickhouse_row(decoded, score)) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.error("failed to persist transaction to ClickHouse: #{inspect(reason)}")
        error
    end
  end

  defp to_clickhouse_row(decoded, score) do
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
      "heavy_path_verdict" =>
        score.heavy_path_verdict && Atom.to_string(score.heavy_path_verdict),
      "verdict" => Atom.to_string(score.verdict),
      "provisional" => false
    }
  end
end
