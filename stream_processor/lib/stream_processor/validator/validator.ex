defmodule StreamProcessor.Validator do
  @callback validate(map()) :: :ok | {:error, :DECLINE}
end
