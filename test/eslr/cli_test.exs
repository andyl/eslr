defmodule Eslr.CLITest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "eslr_cli_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    System.put_env("ESLR_CACHE_DIR", tmp_dir)

    on_exit(fn ->
      System.delete_env("ESLR_CACHE_DIR")
      File.rm_rf!(tmp_dir)
    end)

    %{tmp_dir: tmp_dir}
  end

  describe "--help" do
    test "prints help text" do
      output = capture_io(fn -> Eslr.CLI.main(["--help"]) end)
      assert output =~ "eslr — Elixir Script Load & Run"
      assert output =~ "Usage:"
      assert output =~ "--verbose"
      assert output =~ "--find"
    end
  end

  describe "--version" do
    test "prints version" do
      output = capture_io(fn -> Eslr.CLI.main(["--version"]) end)
      assert output =~ "eslr #{Eslr.version()}"
    end
  end

  describe "--cache dir" do
    test "prints cache directory path" do
      output = capture_io(fn -> Eslr.CLI.main(["--cache", "dir"]) end)
      assert String.trim(output) != ""
    end
  end

  describe "local .exs script" do
    test "runs a valid local script" do
      tmp = Path.join(System.tmp_dir!(), "elr_test_script_#{:rand.uniform(100_000)}.exs")

      File.write!(tmp, """
      Mix.install([])
      IO.puts("hello from elr")
      """)

      output = capture_io(fn -> Eslr.CLI.main([tmp]) end)
      assert output =~ "hello from elr"

      File.rm!(tmp)
    end
  end

  describe "-- argument separation" do
    test "passes arguments after -- to the script" do
      tmp = Path.join(System.tmp_dir!(), "elr_test_args_#{:rand.uniform(100_000)}.exs")

      File.write!(tmp, """
      Mix.install([])
      IO.puts(Enum.join(System.argv(), ","))
      """)

      output = capture_io(fn -> Eslr.CLI.main(["--", tmp, "--help", "foo"]) end)
      assert output =~ "--help,foo"

      File.rm!(tmp)
    end

    test "elr options before -- are consumed by elr" do
      output = capture_io(fn -> Eslr.CLI.main(["--help", "--", "somescript.exs"]) end)
      assert output =~ "eslr — Elixir Script Load & Run"
    end
  end

  describe "error handling" do
    test "invalid reference produces error" do
      output =
        capture_io(:stderr, fn ->
          try do
            Eslr.CLI.main(["Invalid-Package!"])
          catch
            :exit, _ -> :ok
          end
        end)

      assert output =~ "error:"
    end

    test "unknown script name produces helpful error" do
      output =
        capture_io(:stderr, fn ->
          try do
            Eslr.CLI.main(["jason"])
          catch
            :exit, _ -> :ok
          end
        end)

      assert output =~ "unknown script: jason"
    end
  end

  describe "no arguments" do
    test "prints help when no args given" do
      output = capture_io(fn -> Eslr.CLI.main([]) end)
      assert output =~ "eslr — Elixir Script Load & Run"
    end
  end
end
