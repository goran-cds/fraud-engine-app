defmodule RiskEngine.Validator.FastPathValidators.NewAccount do
  @behaviour RiskEngine.Validator

  alias SharedContracts.TransactionRequest
  alias SharedContracts.ScoreDecision
  alias RiskEngine.Cache.SeenAccounts

  @large_first_transaction_cents 500_000

  @spec validate(TransactionRequest.t()) :: {:ok, ScoreDecision.t()} | {:error, ScoreDecision.t()}
  def validate(transaction_request) do
    decision = %ScoreDecision{
      transaction_id: transaction_request.transaction_id,
      provisional: true
    }

    new_account? = SeenAccounts.new?(transaction_request.account_id)
    SeenAccounts.mark_seen(transaction_request.account_id)

    if new_account? and transaction_request.amount_cents >= @large_first_transaction_cents do
      {:error, %{decision | verdict: :REVIEW}}
    else
      {:ok, %{decision | verdict: :APPROVE}}
    end
  end
end
