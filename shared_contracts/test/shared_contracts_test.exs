defmodule SharedContractsTest do
  use ExUnit.Case
  doctest SharedContracts

  test "greets the world" do
    assert SharedContracts.hello() == :world
  end
end
