defmodule ClientSimulator.Infra.RiskEngineClient do
  @moduledoc """
  Plays the role of the payment processor.
  """
  alias SharedContracts.TransactionRequest

  @doc """
  Connects to `risk_engine`, sends one transaction via `ScoreTransaction`, and returns the decision.
  """
  @spec score_transaction(%TransactionRequest{}, String.t(), keyword()) ::
          {:ok, any()} | {:error, any()}
  def score_transaction(transaction, address, opts \\ []) do
    with {:ok, channel} <- GRPC.Stub.connect(address) do
      SharedContracts.RiskEngine.Stub.score_transaction(channel, transaction, opts)
    end
  end
end
