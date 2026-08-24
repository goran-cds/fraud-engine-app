defmodule FraudEngine.Verdict do
  @moduledoc false

  use Protobuf,
    enum: true,
    full_name: "fraud_engine.Verdict",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :APPROVE, 0
  field :REVIEW, 1
  field :DECLINE, 2
end

defmodule FraudEngine.TransactionRequest.MetadataEntry do
  @moduledoc false

  use Protobuf,
    full_name: "fraud_engine.TransactionRequest.MetadataEntry",
    map: true,
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule FraudEngine.TransactionRequest do
  @moduledoc false

  use Protobuf,
    full_name: "fraud_engine.TransactionRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :transaction_id, 1, type: :string, json_name: "transactionId"
  field :account_id, 2, type: :string, json_name: "accountId"
  field :amount_cents, 3, type: :int64, json_name: "amountCents"
  field :currency, 4, type: :string
  field :merchant_id, 5, type: :string, json_name: "merchantId"
  field :ip_address, 6, type: :string, json_name: "ipAddress"
  field :device_fingerprint, 7, type: :string, json_name: "deviceFingerprint"
  field :timestamp, 8, type: :int64

  field :metadata, 9,
    repeated: true,
    type: FraudEngine.TransactionRequest.MetadataEntry,
    map: true
end

defmodule FraudEngine.ScoreDecision do
  @moduledoc false

  use Protobuf,
    full_name: "fraud_engine.ScoreDecision",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :transaction_id, 1, type: :string, json_name: "transactionId"
  field :verdict, 2, type: FraudEngine.Verdict, enum: true
  field :provisional, 3, type: :bool
end

defmodule FraudEngine.RiskEngine.Service do
  @moduledoc false

  use GRPC.Service, name: "fraud_engine.RiskEngine", protoc_gen_elixir_version: "0.17.0"

  rpc :ScoreTransaction, FraudEngine.TransactionRequest, FraudEngine.ScoreDecision

  rpc :StreamTransactions,
      stream(FraudEngine.TransactionRequest),
      stream(FraudEngine.ScoreDecision)
end

defmodule FraudEngine.RiskEngine.Stub do
  @moduledoc false

  use GRPC.Stub, service: FraudEngine.RiskEngine.Service
end
