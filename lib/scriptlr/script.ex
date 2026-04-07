defmodule Scriptlr.Script do
  @moduledoc """
  Script validation for elr. A valid script is either:

  1. A `.exs` file containing `Mix.install`
  2. An executable file with an Elixir shebang and `Mix.install`
  """

  import Bitwise

  @mix_install_pattern ~r/^\s*Mix\.install\s*[\(\[]/m

  @valid_shebangs [
    "#!/usr/bin/env elixir",
    "#!/usr/bin/env mix run",
    "#!/usr/bin/elixir",
    "#!/usr/bin/env mix"
  ]

  @doc """
  Returns `true` if the file at `path` is a valid elr script.
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(path) do
    match?({:ok, _}, validate(path))
  end

  @doc """
  Validates a script file, returning `{:ok, path}` or `{:error, reason}`.
  """
  @spec validate(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate(path) do
    cond do
      not File.exists?(path) ->
        {:error, "file not found: #{path}"}

      File.dir?(path) ->
        {:error, "not a file: #{path}"}

      String.ends_with?(path, ".exs") ->
        validate_exs(path)

      Path.extname(path) == "" ->
        validate_shebang_script(path)

      true ->
        {:error,
         "unsupported file type: #{path}. Expected .exs file or executable with Elixir shebang"}
    end
  end

  @doc """
  Recursively finds all valid scripts in a directory.
  """
  @spec list_scripts(String.t()) :: [String.t()]
  def list_scripts(dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.reject(&File.dir?/1)
    |> Enum.reject(&hidden_or_deps?(&1, dir))
    |> Enum.filter(&valid?/1)
    |> Enum.sort()
  end

  defp hidden_or_deps?(path, base_dir) do
    relative = Path.relative_to(path, base_dir)

    relative
    |> Path.split()
    |> Enum.any?(fn segment ->
      String.starts_with?(segment, ".") or segment in ["deps", "_build", "node_modules", "test"]
    end)
  end

  defp validate_exs(path) do
    case File.read(path) do
      {:ok, content} ->
        if Regex.match?(@mix_install_pattern, content) do
          {:ok, path}
        else
          {:error, "script #{Path.basename(path)} does not contain Mix.install"}
        end

      {:error, reason} ->
        {:error, "cannot read file #{path}: #{reason}"}
    end
  end

  defp validate_shebang_script(path) do
    case File.read(path) do
      {:ok, content} ->
        first_line = content |> String.split("\n", parts: 2) |> List.first("")

        has_shebang = Enum.any?(@valid_shebangs, &String.starts_with?(first_line, &1))
        has_mix_install = Regex.match?(@mix_install_pattern, content)
        executable = executable?(path)

        cond do
          not executable ->
            {:error, "file #{Path.basename(path)} is not executable"}

          not has_shebang ->
            {:error, "file #{Path.basename(path)} does not have an Elixir shebang"}

          not has_mix_install ->
            {:error, "script #{Path.basename(path)} does not contain Mix.install"}

          true ->
            {:ok, path}
        end

      {:error, reason} ->
        {:error, "cannot read file #{path}: #{reason}"}
    end
  end

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mode: mode}} -> (mode &&& 0o111) != 0
      _ -> false
    end
  end
end
