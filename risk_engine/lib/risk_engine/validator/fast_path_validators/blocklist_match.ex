defmodule RiskEngine.Validator.FastPathValidators.BlocklistMatch do
  @behaviour RiskEngine.Validator

  alias SharedContracts.TransactionRequest
  alias SharedContracts.ScoreDecision
  alias RiskEngine.Cache.Blocklist

  @spec validate(TransactionRequest.t()) :: {:ok, ScoreDecision.t()} | {:error, ScoreDecision.t()}
  def validate(transaction_request) do
    decision = %ScoreDecision{
      transaction_id: transaction_request.transaction_id,
      provisional: true
    }

    blocked? =
      Blocklist.member?(:account, transaction_request.account_id) or
        Blocklist.member?(:device, transaction_request.device_fingerprint) or
        Blocklist.member?(:ip, transaction_request.ip_address)

    if blocked? do
      {:error, %{decision | verdict: :DECLINE}}
    else
      {:ok, %{decision | verdict: :APPROVE}}
    end
  end
end
