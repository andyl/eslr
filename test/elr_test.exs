defmodule ElrTest do
  use ExUnit.Case

  test "version/0 returns the project version" do
    assert Elr.version() == Elr.MixProject.project()[:version]
  end
end
