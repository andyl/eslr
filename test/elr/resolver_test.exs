defmodule Elr.ResolverTest do
  use ExUnit.Case, async: true

  alias Elr.{Ref, Resolver}

  test "github ref without git_ref" do
    ref = %Ref{type: :github, name: "my_lib", url: "user/my_lib"}
    assert {:clone, "https://github.com/user/my_lib.git", nil} = Resolver.resolve(ref)
  end

  test "github ref with git_ref" do
    ref = %Ref{type: :github, name: "my_lib", url: "user/my_lib", git_ref: "v1.0"}
    assert {:clone, "https://github.com/user/my_lib.git", "v1.0"} = Resolver.resolve(ref)
  end

  test "git URL without ref" do
    ref = %Ref{type: :git, name: "dep", url: "https://example.com/dep.git"}
    assert {:clone, "https://example.com/dep.git", nil} = Resolver.resolve(ref)
  end

  test "git URL with ref" do
    ref = %Ref{type: :git, name: "dep", url: "https://example.com/dep.git", git_ref: "main"}
    assert {:clone, "https://example.com/dep.git", "main"} = Resolver.resolve(ref)
  end

  test "remote script" do
    ref = %Ref{type: :remote_script, url: "https://example.com/run.exs"}
    assert {:script, "https://example.com/run.exs"} = Resolver.resolve(ref)
  end

  test "local file" do
    ref = %Ref{type: :local, path: "./script.exs"}
    assert {:local, "./script.exs"} = Resolver.resolve(ref)
  end
end
