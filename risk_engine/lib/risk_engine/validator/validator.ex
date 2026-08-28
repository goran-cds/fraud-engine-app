defmodule RiskEngine.Validator do
  alias SharedContracts.TransactionRequest
  alias SharedContracts.ScoreDecision

  @callback validate(TransactionRequest.t()) ::
              {:ok, ScoreDecision.t()} | {:error, ScoreDecision.t()}
end
