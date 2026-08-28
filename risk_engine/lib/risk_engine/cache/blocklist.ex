defmodule RiskEngine.Cache.Blocklist do
  @moduledoc """
  In-process ETS-backed blocklist of account/device/IP identifiers.
  """

  use GenServer

  @table __MODULE__

  @type entry_type :: :account | :device | :ip

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec member?(entry_type(), String.t()) :: boolean()
  def member?(type, value) do
    :ets.member(@table, {type, value})
  end

  @spec add(entry_type(), String.t()) :: :ok
  def add(type, value) do
    :ets.insert(@table, {{type, value}, true})
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end
end
