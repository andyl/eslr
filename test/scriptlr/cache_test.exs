defmodule Scriptlr.CacheTest do
  use ExUnit.Case, async: true

  alias Scriptlr.{Cache, Ref}

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "elr_cache_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    System.put_env("SCRIPTLR_CACHE_DIR", tmp_dir)

    on_exit(fn ->
      System.delete_env("SCRIPTLR_CACHE_DIR")
      File.rm_rf!(tmp_dir)
    end)

    %{tmp_dir: tmp_dir}
  end

  describe "dir/0" do
    test "uses SCRIPTLR_CACHE_DIR when set", %{tmp_dir: tmp_dir} do
      assert Cache.dir() == tmp_dir
    end

    test "falls back to XDG_CACHE_HOME" do
      System.delete_env("SCRIPTLR_CACHE_DIR")
      System.put_env("XDG_CACHE_HOME", "/tmp/xdg_test")
      assert Cache.dir() == "/tmp/xdg_test/scriptlr"
      System.delete_env("XDG_CACHE_HOME")
    end

    test "falls back to ~/.cache/scriptlr" do
      System.delete_env("SCRIPTLR_CACHE_DIR")
      System.delete_env("XDG_CACHE_HOME")
      assert Cache.dir() == Path.join(System.user_home!(), ".cache/scriptlr")
    end
  end

  describe "cache_key/1" do
    test "produces deterministic keys" do
      ref = %Ref{type: :hex, name: "jason", version: "1.4.0"}
      key1 = Cache.cache_key(ref)
      key2 = Cache.cache_key(ref)
      assert key1 == key2
    end

    test "different versions produce different keys" do
      ref1 = %Ref{type: :hex, name: "jason", version: "1.4.0"}
      ref2 = %Ref{type: :hex, name: "jason", version: "1.5.0"}
      assert Cache.cache_key(ref1) != Cache.cache_key(ref2)
    end

    test "key includes the package name" do
      ref = %Ref{type: :hex, name: "jason", version: "1.4.0"}
      assert Cache.cache_key(ref) =~ "jason-"
    end
  end

  describe "store/lookup/delete lifecycle" do
    test "store and lookup round-trip" do
      key = "test-entry-001"
      assert {:ok, path} = Cache.store(key, %{"ref" => "jason@1.4"})
      assert {:ok, ^path, metadata} = Cache.lookup(key)
      assert metadata["ref"] == "jason@1.4"
      assert metadata["cache_key"] == key
      assert metadata["stored_at"]
    end

    test "lookup returns :miss for nonexistent key" do
      assert :miss == Cache.lookup("nonexistent-key")
    end

    test "delete removes entry" do
      key = "delete-me"
      Cache.store(key)
      assert :ok == Cache.delete(key)
      assert :miss == Cache.lookup(key)
    end

    test "delete returns error for nonexistent key" do
      assert {:error, :not_found} == Cache.delete("nope")
    end
  end

  describe "list/0" do
    test "lists stored entries" do
      Cache.store("entry-a", %{"name" => "a"})
      Cache.store("entry-b", %{"name" => "b"})
      entries = Cache.list()
      keys = Enum.map(entries, &elem(&1, 0))
      assert "entry-a" in keys
      assert "entry-b" in keys
    end

    test "returns empty list when cache is empty" do
      assert Cache.list() == []
    end
  end

  describe "clean/0" do
    test "removes all entries" do
      Cache.store("clean-a")
      Cache.store("clean-b")
      assert :ok == Cache.clean()
      assert Cache.list() == []
    end
  end
end
