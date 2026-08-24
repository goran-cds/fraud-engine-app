defmodule ClientSimulatorTest do
  use ExUnit.Case
  doctest ClientSimulator

  test "greets the world" do
    assert ClientSimulator.hello() == :world
  end
end
