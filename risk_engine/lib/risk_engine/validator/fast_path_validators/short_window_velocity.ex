defmodule RiskEngine.Validator.FastPathValidators.ShortWindowVelocity do
  @behaviour RiskEngine.Validator

  alias SharedContracts.TransactionRequest
  alias SharedContracts.ScoreDecision
  alias RiskEngine.Cache.Velocity

  @window_ms 60_000
  @max_transactions_per_window 5

  @spec validate(TransactionRequest.t()) :: {:ok, ScoreDecision.t()} | {:error, ScoreDecision.t()}
  def validate(transaction_request) do
    decision = %ScoreDecision{
      transaction_id: transaction_request.transaction_id,
      provisional: true
    }

    count = Velocity.record_and_count(transaction_request.account_id, @window_ms)

    if count > @max_transactions_per_window do
      {:error, %{decision | verdict: :REVIEW}}
    else
      {:ok, %{decision | verdict: :APPROVE}}
    end
  end
end
