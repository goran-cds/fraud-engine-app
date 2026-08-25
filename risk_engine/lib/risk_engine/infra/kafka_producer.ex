defmodule RiskEngine.Infra.KafkaProducer do
  require Logger

  @topic "transactions.raw"
  @schema_name "com.fraud_engine.Transaction"

  @spec produce_transaction_scored(map()) :: :ok
  def produce_transaction_scored(%{"account_id" => account_id} = payload) do
    with {:ok, encoded} <- Avrora.encode(payload, schema_name: @schema_name),
         :ok <- Kaffe.Producer.produce_sync(@topic, account_id, encoded) do
      :ok
    else
      {:error, reason} ->
        Logger.error("failed to produce to #{@topic}: #{inspect(reason)}")
        :ok
    end
  end
end
