defmodule Eslr.DatastoreTest do
  use ExUnit.Case

  alias Eslr.Datastore

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "elr_ds_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    System.put_env("ESLR_CACHE_DIR", tmp_dir)

    on_exit(fn ->
      System.delete_env("ESLR_CACHE_DIR")
      File.rm_rf!(tmp_dir)
    end)

    %{tmp_dir: tmp_dir}
  end

  describe "read/write round-trip" do
    test "empty datastore returns empty map" do
      assert Datastore.read() == %{}
    end

    test "write and read back" do
      data = %{
        "my-script-key" => %{
          "name" => "myscript",
          "run_count" => 3
        }
      }

      Datastore.write(data)
      result = Datastore.read()
      assert result["my-script-key"]["name"] == "myscript"
      assert result["my-script-key"]["run_count"] == 3
    end
  end

  describe "record_install/2" do
    test "creates entry with correct fields" do
      Datastore.record_install("key1", %{
        "name" => "test_script",
        "source" => "github:user/repo",
        "description" => "A test script"
      })

      record = Datastore.get("key1")
      assert record["name"] == "test_script"
      assert record["source"] == "github:user/repo"
      assert record["installed_at"]
      assert record["run_count"] == 0
    end

    test "preserves run_count on reinstall" do
      Datastore.record_install("key2", %{"name" => "s"})
      Datastore.record_run("key2")
      Datastore.record_run("key2")
      Datastore.record_install("key2", %{"name" => "s"})

      record = Datastore.get("key2")
      assert record["run_count"] == 2
    end
  end

  describe "record_run/1" do
    test "increments count and updates timestamp" do
      Datastore.record_install("run-key", %{"name" => "s"})
      Datastore.record_run("run-key")
      Datastore.record_run("run-key")

      record = Datastore.get("run-key")
      assert record["run_count"] == 2
      assert record["last_execution"]
    end

    test "works even without prior install" do
      Datastore.record_run("new-key")
      record = Datastore.get("new-key")
      assert record["run_count"] == 1
    end
  end

  describe "extract_description/1" do
    test "extracts first comment block", %{tmp_dir: dir} do
      path = Path.join(dir, "script.exs")

      File.write!(path, """
      # This is a test script
      # It does cool things

      Mix.install([:jason])
      IO.puts("hi")
      """)

      desc = Datastore.extract_description(path)
      assert desc =~ "This is a test script"
      assert desc =~ "It does cool things"
    end

    test "skips shebang line", %{tmp_dir: dir} do
      path = Path.join(dir, "shebang_script")

      File.write!(path, """
      #!/usr/bin/env elixir
      # Real description here

      Mix.install([])
      """)

      desc = Datastore.extract_description(path)
      assert desc == "Real description here"
      refute desc =~ "#!/usr/bin/env"
    end

    test "returns nil for script with no comments", %{tmp_dir: dir} do
      path = Path.join(dir, "nocomment.exs")
      File.write!(path, "Mix.install([])\nIO.puts(\"hi\")")
      assert Datastore.extract_description(path) == nil
    end
  end

  describe "extract_deps/1" do
    test "extracts dep names from Mix.install", %{tmp_dir: dir} do
      path = Path.join(dir, "deps.exs")

      File.write!(path, """
      Mix.install([
        :jason,
        :req,
        {:plug, "~> 1.0"}
      ])
      """)

      deps = Datastore.extract_deps(path)
      assert "jason" in deps
      assert "req" in deps
      assert "plug" in deps
    end
  end

  describe "list/0" do
    test "returns all records" do
      Datastore.record_install("a", %{"name" => "script_a"})
      Datastore.record_install("b", %{"name" => "script_b"})

      all = Datastore.list()
      assert map_size(all) == 2
      assert all["a"]["name"] == "script_a"
      assert all["b"]["name"] == "script_b"
    end
  end
end
