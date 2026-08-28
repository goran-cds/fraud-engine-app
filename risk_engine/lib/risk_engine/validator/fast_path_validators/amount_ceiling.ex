defmodule RiskEngine.Validator.FastPathValidators.AmountCeiling do
  @behaviour RiskEngine.Validator

  alias SharedContracts.TransactionRequest
  alias SharedContracts.ScoreDecision

  @hard_ceiling_cents 1_000_000

  @spec validate(TransactionRequest.t()) :: {:ok, ScoreDecision.t()} | {:error, ScoreDecision.t()}
  def validate(transaction_request) do
    decision = %ScoreDecision{
      transaction_id: transaction_request.transaction_id,
      provisional: true
    }

    cond do
      transaction_request.amount_cents >= @hard_ceiling_cents ->
        {:error, %{decision | verdict: :REVIEW}}

      transaction_request.amount_cents < @hard_ceiling_cents ->
        {:ok, %{decision | verdict: :APPROVE}}

      true ->
        {:ok, %{decision | verdict: :APPROVE}}
    end
  end
end
