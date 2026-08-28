defmodule RiskEngine.Cache.SeenAccounts do
  @moduledoc """
  In-process ETS set of account ids seen since this node booted.
  """

  use GenServer

  @table __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec new?(String.t()) :: boolean()
  def new?(account_id) do
    not :ets.member(@table, account_id)
  end

  @spec mark_seen(String.t()) :: :ok
  def mark_seen(account_id) do
    :ets.insert(@table, {account_id, true})
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end
end
