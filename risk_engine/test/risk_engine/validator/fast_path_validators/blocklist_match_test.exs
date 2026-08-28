defmodule RiskEngine.Validator.FastPathValidators.BlocklistMatchTest do
  use ExUnit.Case, async: false

  alias SharedContracts.TransactionRequest
  alias RiskEngine.Cache.Blocklist
  alias RiskEngine.Validator.FastPathValidators.BlocklistMatch

  defp transaction(attrs) do
    struct(
      %TransactionRequest{
        transaction_id: "txn-#{System.unique_integer([:positive])}",
        account_id: "acct-#{System.unique_integer([:positive])}",
        amount_cents: 1_000,
        currency: "USD",
        merchant_id: "merchant-1",
        ip_address: "1.2.3.4",
        device_fingerprint: "device-1",
        timestamp: System.os_time(:second)
      },
      attrs
    )
  end

  test "approves when no field is blocklisted" do
    assert {:ok, decision} = BlocklistMatch.validate(transaction(%{}))
    assert decision.verdict == :APPROVE
  end

  test "declines when the account is blocklisted" do
    txn = transaction(%{})
    Blocklist.add(:account, txn.account_id)

    assert {:error, decision} = BlocklistMatch.validate(txn)
    assert decision.verdict == :DECLINE
  end

  test "declines when the device fingerprint is blocklisted" do
    txn = transaction(%{device_fingerprint: "device-#{System.unique_integer([:positive])}"})
    Blocklist.add(:device, txn.device_fingerprint)

    assert {:error, decision} = BlocklistMatch.validate(txn)
    assert decision.verdict == :DECLINE
  end

  test "declines when the ip address is blocklisted" do
    txn = transaction(%{ip_address: "9.9.9.#{System.unique_integer([:positive])}"})
    Blocklist.add(:ip, txn.ip_address)

    assert {:error, decision} = BlocklistMatch.validate(txn)
    assert decision.verdict == :DECLINE
  end
end
