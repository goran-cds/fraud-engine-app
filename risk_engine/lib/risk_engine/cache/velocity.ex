defmodule RiskEngine.Cache.Velocity do
  @moduledoc """
  In-process sliding-window transaction counter per account, used for
  short-window velocity ("card testing") detection.
  """

  use GenServer

  @table __MODULE__

  @spec record_and_count(String.t(), pos_integer()) :: pos_integer()
  def record_and_count(account_id, window_ms) do
    now = System.monotonic_time(:millisecond)
    :ets.insert(@table, {account_id, now, System.unique_integer()})
    prune_stale(account_id, now - window_ms)

    :ets.select_count(@table, [{{account_id, :_, :_}, [], [true]}])
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  defp prune_stale(account_id, cutoff) do
    :ets.select_delete(@table, [
      {{account_id, :"$1", :_}, [{:<, :"$1", cutoff}], [true]}
    ])
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:bag, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end
end
