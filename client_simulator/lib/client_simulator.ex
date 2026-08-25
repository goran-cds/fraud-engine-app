defmodule ClientSimulator do
  @moduledoc """
  Documentation for `ClientSimulator`.
  """

  alias ClientSimulator.Infra.RiskEngineClient

  alias SharedContracts.TransactionRequest

  require Logger

  @doc """
  Fabricates a transaction, sends it to `risk_engine` over gRPC, and prints
  the decision.
  """
  @spec run(String.t()) :: any()
  def run(address \\ "localhost:50051") do
    case RiskEngineClient.score_transaction(transaction(), address) do
      {:ok, decision} ->
        Logger.info("ScoreDecision: #{inspect(decision)}")

      {:error, reason} ->
        Logger.error("gRPC call failed: #{inspect(reason)}")
    end
  end

  defp transaction do
    %TransactionRequest{
      transaction_id: random_id("txn"),
      account_id: random_id("acct"),
      amount_cents: Enum.random(100..2_000_00),
      currency: "USD",
      merchant_id: random_id("merch"),
      ip_address: "203.0.113.#{Enum.random(1..254)}",
      device_fingerprint: random_id("dev"),
      timestamp: System.os_time(:second),
      metadata: %{"channel" => "web"}
    }
  end

  defp random_id(prefix) do
    suffix = :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
    "#{prefix}_#{suffix}"
  end
end
