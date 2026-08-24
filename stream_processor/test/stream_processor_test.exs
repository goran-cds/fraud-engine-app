defmodule StreamProcessorTest do
  use ExUnit.Case
  doctest StreamProcessor

  test "greets the world" do
    assert StreamProcessor.hello() == :world
  end
end
