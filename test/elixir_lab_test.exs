defmodule ElixirLabTest do
  use ExUnit.Case
  doctest ElixirLab

  test "greets the world" do
    assert ElixirLab.hello() == :world
  end
end
