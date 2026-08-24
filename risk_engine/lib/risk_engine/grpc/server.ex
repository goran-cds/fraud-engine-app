defmodule RiskEngine.GRPC.Server do
  use GRPC.Server, service: SharedContracts.RiskEngine.Service

  alias SharedContracts.ScoreDecision

  def score_transaction(request, _stream) do
    mock_approve(request.transaction_id)
  end

  def stream_transactions(request_stream, stream) do
    Enum.each(request_stream, fn request ->
      GRPC.Server.send_reply(stream, mock_approve(request.transaction_id))
    end)
  end

  defp mock_approve(transaction_id) do
    %ScoreDecision{
      transaction_id: transaction_id,
      verdict: :APPROVE,
      provisional: true
    }
  end
end
