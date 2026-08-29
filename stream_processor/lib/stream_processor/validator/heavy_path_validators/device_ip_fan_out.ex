defmodule StreamProcessor.Validator.HeavyPathValidators.DeviceIpFanOut do
  @behaviour StreamProcessor.Validator

  alias StreamProcessor.Infra.ClickhouseClient

  @lookback_hours 24
  @fan_out_threshold 5

  @spec validate(map()) :: :ok | {:error, :DECLINE}
  def validate(transaction) do
    case ClickhouseClient.distinct_accounts_for_device_or_ip(
           transaction["device_fingerprint"],
           transaction["ip_address"],
           @lookback_hours
         ) do
      {:ok, %{device_fan_out: device_fan_out, ip_fan_out: ip_fan_out}}
      when device_fan_out >= @fan_out_threshold or ip_fan_out >= @fan_out_threshold ->
        {:error, :DECLINE}

      {:ok, _fan_out} ->
        :ok
    end
  end
end
