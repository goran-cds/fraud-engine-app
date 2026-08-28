defmodule RiskEngine.Validator.FastPathValidators.ShortWindowVelocityTest do
  use ExUnit.Case, async: false

  alias SharedContracts.TransactionRequest
  alias RiskEngine.Validator.FastPathValidators.ShortWindowVelocity

  defp transaction(account_id) do
    %TransactionRequest{
      transaction_id: "txn-#{System.unique_integer([:positive])}",
      account_id: account_id,
      amount_cents: 1_000,
      currency: "USD",
      merchant_id: "merchant-1",
      ip_address: "1.2.3.4",
      device_fingerprint: "device-1",
      timestamp: System.os_time(:second)
    }
  end

  test "approves transactions under the per-account velocity limit" do
    account_id = "acct-#{System.unique_integer([:positive])}"

    for _ <- 1..5 do
      assert {:ok, decision} = ShortWindowVelocity.validate(transaction(account_id))
      assert decision.verdict == :APPROVE
    end
  end

  test "flags an account for review once it exceeds the velocity limit" do
    account_id = "acct-#{System.unique_integer([:positive])}"

    for _ <- 1..5 do
      ShortWindowVelocity.validate(transaction(account_id))
    end

    assert {:error, decision} = ShortWindowVelocity.validate(transaction(account_id))
    assert decision.verdict == :REVIEW
  end

  test "tracks each account independently" do
    account_a = "acct-#{System.unique_integer([:positive])}"
    account_b = "acct-#{System.unique_integer([:positive])}"

    for _ <- 1..5, do: ShortWindowVelocity.validate(transaction(account_a))

    assert {:ok, decision} = ShortWindowVelocity.validate(transaction(account_b))
    assert decision.verdict == :APPROVE
  end
end
