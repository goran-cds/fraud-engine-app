defmodule RiskEngine.Validator.Verifier do
  alias SharedContracts.TransactionRequest
  alias SharedContracts.ScoreDecision

  alias RiskEngine.Validator.FastPathValidators.{
    BlocklistMatch,
    ShortWindowVelocity,
    AmountCeiling,
    NewAccount
  }

  @spec validate(TransactionRequest.t()) :: ScoreDecision.t()
  def validate(transaction_request) do
    with {:ok, _} <- BlocklistMatch.validate(transaction_request),
         {:ok, _} <- AmountCeiling.validate(transaction_request),
         {:ok, _} <- NewAccount.validate(transaction_request),
         {:ok, _} <- ShortWindowVelocity.validate(transaction_request) do
      %ScoreDecision{
        transaction_id: transaction_request.transaction_id,
        verdict: :APPROVE,
        provisional: true
      }
    else
      {:error, score_decision} ->
        score_decision
    end
  end
end
