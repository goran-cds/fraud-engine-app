defmodule StreamProcessor.Validator.Verifier do
  alias StreamProcessor.Validator.HeavyPathValidators.{VelocityAnomaly, DeviceIpFanOut}

  @spec validate(String.t(), map()) :: %{
          verdict: :APPROVE | :DECLINE,
          heavy_path_verdict: :APPROVE | :DECLINE | nil
        }
  def validate("DECLINE", _transaction) do
    %{verdict: :DECLINE, heavy_path_verdict: nil}
  end

  def validate(_fast_path_verdict, transaction) do
    heavy_path_verdict =
      with :ok <- VelocityAnomaly.validate(transaction),
           :ok <- DeviceIpFanOut.validate(transaction) do
        :APPROVE
      else
        {:error, :DECLINE} -> :DECLINE
      end

    %{verdict: heavy_path_verdict, heavy_path_verdict: heavy_path_verdict}
  end
end
