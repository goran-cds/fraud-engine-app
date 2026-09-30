defmodule RiskEngine.GRPC.Endpoint do
  use GRPC.Endpoint

  intercept(RiskEngine.Otel.GrpcServerInterceptor)

  run(RiskEngine.GRPC.Server)
end
