defmodule SharedContracts.Verdict do
  @moduledoc false

  use Protobuf,
    enum: true,
    full_name: "shared_contracts.Verdict",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:APPROVE, 0)
  field(:REVIEW, 1)
  field(:DECLINE, 2)
end

defmodule SharedContracts.TransactionRequest.MetadataEntry do
  @moduledoc false

  use Protobuf,
    full_name: "shared_contracts.TransactionRequest.MetadataEntry",
    map: true,
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule SharedContracts.TransactionRequest do
  @moduledoc false

  use Protobuf,
    full_name: "shared_contracts.TransactionRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:transaction_id, 1, type: :string, json_name: "transactionId")
  field(:account_id, 2, type: :string, json_name: "accountId")
  field(:amount_cents, 3, type: :int64, json_name: "amountCents")
  field(:currency, 4, type: :string)
  field(:merchant_id, 5, type: :string, json_name: "merchantId")
  field(:ip_address, 6, type: :string, json_name: "ipAddress")
  field(:device_fingerprint, 7, type: :string, json_name: "deviceFingerprint")
  field(:timestamp, 8, type: :int64)

  field(:metadata, 9,
    repeated: true,
    type: SharedContracts.TransactionRequest.MetadataEntry,
    map: true
  )
end

defmodule SharedContracts.ScoreDecision do
  @moduledoc false

  use Protobuf,
    full_name: "shared_contracts.ScoreDecision",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:transaction_id, 1, type: :string, json_name: "transactionId")
  field(:verdict, 2, type: SharedContracts.Verdict, enum: true)
  field(:provisional, 3, type: :bool)
end

defmodule SharedContracts.RiskEngine.Service do
  @moduledoc false

  use GRPC.Service, name: "shared_contracts.RiskEngine", protoc_gen_elixir_version: "0.17.0"

  rpc(:ScoreTransaction, SharedContracts.TransactionRequest, SharedContracts.ScoreDecision)

  rpc(
    :StreamTransactions,
    stream(SharedContracts.TransactionRequest),
    stream(SharedContracts.ScoreDecision)
  )
end

defmodule SharedContracts.RiskEngine.Stub do
  @moduledoc false

  use GRPC.Stub, service: SharedContracts.RiskEngine.Service
end
