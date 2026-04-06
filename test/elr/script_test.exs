defmodule Elr.ScriptTest do
  use ExUnit.Case, async: true

  alias Elr.Script

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "elr_script_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    %{tmp_dir: tmp_dir}
  end

  describe "validate/1 for .exs files" do
    test "valid .exs with Mix.install", %{tmp_dir: dir} do
      path = Path.join(dir, "good.exs")
      File.write!(path, "Mix.install([:jason])\nIO.puts(\"hi\")")
      assert {:ok, ^path} = Script.validate(path)
    end

    test "valid .exs with Mix.install using bracket syntax", %{tmp_dir: dir} do
      path = Path.join(dir, "brackets.exs")
      File.write!(path, "Mix.install[\n  :jason\n]")
      assert {:ok, ^path} = Script.validate(path)
    end

    test "invalid .exs without Mix.install", %{tmp_dir: dir} do
      path = Path.join(dir, "bad.exs")
      File.write!(path, "IO.puts(\"hello\")")
      assert {:error, msg} = Script.validate(path)
      assert msg =~ "does not contain Mix.install"
    end

    test "nonexistent file" do
      assert {:error, "file not found:" <> _} = Script.validate("/tmp/no_such_file_elr.exs")
    end
  end

  describe "validate/1 for shebang executables" do
    test "valid executable with elixir shebang and Mix.install", %{tmp_dir: dir} do
      path = Path.join(dir, "myscript")

      File.write!(path, """
      #!/usr/bin/env elixir
      Mix.install([:jason])
      IO.puts("hi")
      """)

      File.chmod!(path, 0o755)
      assert {:ok, ^path} = Script.validate(path)
    end

    test "valid executable with mix shebang", %{tmp_dir: dir} do
      path = Path.join(dir, "mixscript")

      File.write!(path, """
      #!/usr/bin/env mix run
      Mix.install([:jason])
      """)

      File.chmod!(path, 0o755)
      assert {:ok, ^path} = Script.validate(path)
    end

    test "non-executable file without extension is invalid", %{tmp_dir: dir} do
      path = Path.join(dir, "notexec")

      File.write!(path, """
      #!/usr/bin/env elixir
      Mix.install([:jason])
      """)

      File.chmod!(path, 0o644)
      assert {:error, msg} = Script.validate(path)
      assert msg =~ "not executable"
    end

    test "executable without shebang is invalid", %{tmp_dir: dir} do
      path = Path.join(dir, "noshebang")
      File.write!(path, "Mix.install([:jason])")
      File.chmod!(path, 0o755)
      assert {:error, msg} = Script.validate(path)
      assert msg =~ "does not have an Elixir shebang"
    end

    test "executable with shebang but no Mix.install is invalid", %{tmp_dir: dir} do
      path = Path.join(dir, "nomix")
      File.write!(path, "#!/usr/bin/env elixir\nIO.puts(\"hi\")")
      File.chmod!(path, 0o755)
      assert {:error, msg} = Script.validate(path)
      assert msg =~ "does not contain Mix.install"
    end
  end

  describe "validate/1 for unsupported types" do
    test ".ex file is rejected", %{tmp_dir: dir} do
      path = Path.join(dir, "mod.ex")
      File.write!(path, "defmodule Foo do\nend")
      assert {:error, msg} = Script.validate(path)
      assert msg =~ "unsupported file type"
    end

    test ".md file is rejected", %{tmp_dir: dir} do
      path = Path.join(dir, "readme.md")
      File.write!(path, "# Hello")
      assert {:error, msg} = Script.validate(path)
      assert msg =~ "unsupported file type"
    end

    test "directory is rejected", %{tmp_dir: dir} do
      subdir = Path.join(dir, "subdir")
      File.mkdir_p!(subdir)
      assert {:error, "not a file:" <> _} = Script.validate(subdir)
    end
  end

  describe "valid?/1" do
    test "returns true for valid script", %{tmp_dir: dir} do
      path = Path.join(dir, "ok.exs")
      File.write!(path, "Mix.install([:jason])")
      assert Script.valid?(path)
    end

    test "returns false for invalid script", %{tmp_dir: dir} do
      path = Path.join(dir, "nope.exs")
      File.write!(path, "IO.puts(\"hi\")")
      refute Script.valid?(path)
    end
  end

  describe "list_scripts/1" do
    test "finds valid scripts recursively", %{tmp_dir: dir} do
      # Valid .exs
      File.write!(Path.join(dir, "a.exs"), "Mix.install([:jason])")
      # Invalid .exs (no Mix.install)
      File.write!(Path.join(dir, "b.exs"), "IO.puts(\"hi\")")
      # Valid in subdirectory
      sub = Path.join(dir, "scripts")
      File.mkdir_p!(sub)
      File.write!(Path.join(sub, "c.exs"), "Mix.install([:req])")
      # Non-.exs file
      File.write!(Path.join(dir, "readme.md"), "# hello")

      scripts = Script.list_scripts(dir)
      basenames = Enum.map(scripts, &Path.basename/1)

      assert "a.exs" in basenames
      assert "c.exs" in basenames
      refute "b.exs" in basenames
      refute "readme.md" in basenames
    end

    test "skips hidden directories, deps, and test", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, ".git"))
      File.write!(Path.join([dir, ".git", "hook.exs"]), "Mix.install([:jason])")
      File.mkdir_p!(Path.join(dir, "deps"))
      File.write!(Path.join([dir, "deps", "dep.exs"]), "Mix.install([:jason])")
      File.mkdir_p!(Path.join(dir, "test"))
      File.write!(Path.join([dir, "test", "my_test.exs"]), "Mix.install([:jason])")

      assert Script.list_scripts(dir) == []
    end

    test "returns empty list for directory with no scripts", %{tmp_dir: dir} do
      assert Script.list_scripts(dir) == []
    end
  end
end
