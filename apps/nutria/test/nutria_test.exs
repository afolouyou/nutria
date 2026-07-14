defmodule NutriaTest do
  use ExUnit.Case
  doctest Nutria

  test "greets the world" do
    assert Nutria.hello() == :world
  end
end
