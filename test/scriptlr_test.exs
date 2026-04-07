defmodule ScriptlrTest do
  use ExUnit.Case

  test "version/0 returns the project version" do
    assert Scriptlr.version() == Scriptlr.MixProject.project()[:version]
  end
end
