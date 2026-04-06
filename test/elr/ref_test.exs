defmodule Elr.RefTest do
  use ExUnit.Case, async: true

  alias Elr.Ref

  describe "local files" do
    test "relative path with ./" do
      assert {:ok, %Ref{type: :local, path: "./script.exs"}} = Ref.parse("./script.exs")
    end

    test "absolute path" do
      assert {:ok, %Ref{type: :local, path: "/tmp/script.exs"}} = Ref.parse("/tmp/script.exs")
    end

    test ".exs extension without path prefix" do
      assert {:ok, %Ref{type: :local, path: "script.exs"}} = Ref.parse("script.exs")
    end

    test "name is extracted from basename" do
      assert {:ok, %Ref{name: "script"}} = Ref.parse("./dir/script.exs")
    end
  end

  describe "remote scripts" do
    test "https URL ending in .exs" do
      url = "https://example.com/scripts/run.exs"
      assert {:ok, %Ref{type: :remote_script, url: ^url, name: "run"}} = Ref.parse(url)
    end
  end

  describe "non-.exs URLs" do
    test "https URL not ending in .exs returns error" do
      assert {:error, "non-.exs URLs are not supported:" <> _} =
               Ref.parse("https://example.com/page")
    end

    test "http URL returns error" do
      assert {:error, "non-.exs URLs are not supported:" <> _} =
               Ref.parse("http://example.com/page")
    end
  end

  describe "GitHub references" do
    test "basic github:user/repo" do
      assert {:ok, %Ref{type: :github, name: "my_lib", url: "user/my_lib"}} =
               Ref.parse("github:user/my_lib")
    end

    test "github:user/repo#ref" do
      assert {:ok, %Ref{type: :github, name: "repo", url: "user/repo", git_ref: "v1.0"}} =
               Ref.parse("github:user/repo#v1.0")
    end

    test "github:user/repo:path" do
      assert {:ok,
              %Ref{
                type: :github,
                name: "repo",
                url: "user/repo",
                script_path: "scripts/run.exs"
              }} = Ref.parse("github:user/repo:scripts/run.exs")
    end

    test "github:user/repo:glob#ref" do
      assert {:ok,
              %Ref{
                type: :github,
                name: "repo",
                url: "user/repo",
                script_path: "**/run.exs",
                git_ref: "main"
              }} = Ref.parse("github:user/repo:**/run.exs#main")
    end

    test "github:user/repo:glob without ref" do
      assert {:ok,
              %Ref{
                type: :github,
                name: "repo",
                url: "user/repo",
                script_path: "lib/**/script.exs",
                git_ref: nil
              }} = Ref.parse("github:user/repo:lib/**/script.exs")
    end

    test "invalid github reference (no slash)" do
      assert {:error, "invalid GitHub reference:" <> _} = Ref.parse("github:noslash")
    end

    test "invalid github reference (empty repo)" do
      assert {:error, "invalid GitHub reference:" <> _} = Ref.parse("github:user/")
    end
  end

  describe "git URLs" do
    test "git+ URL" do
      assert {:ok, %Ref{type: :git, name: "my_dep", url: "https://example.com/my_dep.git"}} =
               Ref.parse("git+https://example.com/my_dep.git")
    end

    test "git+ URL with ref" do
      assert {:ok,
              %Ref{
                type: :git,
                name: "my_dep",
                url: "https://example.com/my_dep.git",
                git_ref: "main"
              }} = Ref.parse("git+https://example.com/my_dep.git#main")
    end

    test "strips .git suffix from name" do
      assert {:ok, %Ref{name: "repo"}} = Ref.parse("git+https://host.com/repo.git")
    end
  end

  describe "Hex package rejection" do
    test "bare package name returns error" do
      assert {:error, msg} = Ref.parse("jason")
      assert msg =~ "Hex package references are not supported"
    end

    test "package with version returns error" do
      assert {:error, msg} = Ref.parse("jason@~> 1.4")
      assert msg =~ "Hex package references are not supported"
    end

    test "invalid name returns error" do
      assert {:error, msg} = Ref.parse("Invalid-Name")
      assert msg =~ "Hex package references are not supported"
    end

    test "empty string returns error" do
      assert {:error, msg} = Ref.parse("")
      assert msg =~ "Hex package references are not supported"
    end
  end
end
