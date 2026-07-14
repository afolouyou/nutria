defmodule NutriaWebTest do
  use ExUnit.Case
  doctest NutriaWeb

  test "greets the world" do
    assert NutriaWeb.hello() == :world
  end
end
