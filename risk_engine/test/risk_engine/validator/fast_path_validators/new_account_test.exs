defmodule RiskEngine.Validator.FastPathValidators.NewAccountTest do
  use ExUnit.Case, async: false

  alias SharedContracts.TransactionRequest
  alias RiskEngine.Validator.FastPathValidators.NewAccount

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

  test "flags a new account's unusually large first transaction for review" do
    txn = transaction(%{amount_cents: 500_000})

    assert {:error, decision} = NewAccount.validate(txn)
    assert decision.verdict == :REVIEW
  end

  test "approves a new account's small first transaction" do
    txn = transaction(%{amount_cents: 1_000})

    assert {:ok, decision} = NewAccount.validate(txn)
    assert decision.verdict == :APPROVE
  end

  test "approves a large transaction from an already-seen account" do
    txn = transaction(%{amount_cents: 1_000})
    assert {:ok, _} = NewAccount.validate(txn)

    second_txn = %{
      txn
      | transaction_id: "txn-#{System.unique_integer([:positive])}",
        amount_cents: 500_000
    }

    assert {:ok, decision} = NewAccount.validate(second_txn)
    assert decision.verdict == :APPROVE
  end
end
