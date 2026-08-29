defmodule StreamProcessor.Validator.HeavyPathValidators.VelocityAnomaly do
  @behaviour StreamProcessor.Validator

  alias StreamProcessor.Infra.ClickhouseClient

  @lookback_days 30
  @anomaly_multiplier 5

  @spec validate(map()) :: :ok | {:error, :DECLINE}
  def validate(transaction) do
    case ClickhouseClient.account_baseline(transaction["account_id"], @lookback_days) do
      {:ok, nil} ->
        :ok

      {:ok, avg_daily_amount_cents} ->
        if transaction["amount_cents"] > avg_daily_amount_cents * @anomaly_multiplier do
          {:error, :DECLINE}
        else
          :ok
        end
    end
  end
end
