defmodule RiskEngine.GRPC.Endpoint do
  use GRPC.Endpoint

  run(RiskEngine.GRPC.Server)
end
