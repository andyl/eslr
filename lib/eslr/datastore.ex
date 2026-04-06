defmodule Eslr.Datastore do
  @moduledoc """
  YAML-based cache datastore tracking per-script usage stats.
  Stored at `Cache.dir()/.script_directory.yml`.
  """

  alias Eslr.Cache

  @filename ".script_directory.yml"

  @doc """
  Returns the path to the datastore file.
  """
  def path do
    Path.join(Cache.dir(), @filename)
  end

  @doc """
  Load and parse the YAML datastore, returning a map of records keyed by normalized key.
  """
  @spec read() :: map()
  def read do
    ds_path = path()

    if File.exists?(ds_path) do
      case File.read(ds_path) do
        {:ok, content} ->
          case YamlElixir.read_from_string(content) do
            {:ok, nil} -> %{}
            {:ok, data} when is_map(data) -> data
            _ -> %{}
          end

        _ ->
          %{}
      end
    else
      %{}
    end
  end

  @doc """
  Write the full datastore map back to YAML.
  """
  @spec write(map()) :: :ok
  def write(data) when is_map(data) do
    ds_path = path()
    File.mkdir_p!(Path.dirname(ds_path))
    yaml = encode_yaml(data)
    File.write!(ds_path, yaml)
    :ok
  end

  @doc """
  Record a script install/cache event. Creates or updates the record.
  """
  @spec record_install(String.t(), map()) :: :ok
  def record_install(key, metadata \\ %{}) do
    data = read()

    record =
      Map.get(data, key, %{})
      |> Map.merge(%{
        "name" => metadata[:name] || metadata["name"],
        "source" => metadata[:source] || metadata["source"],
        "description" => metadata[:description] || metadata["description"],
        "deps" => metadata[:deps] || metadata["deps"] || [],
        "eslr_command" => metadata[:eslr_command] || metadata["eslr_command"],
        "installed_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "run_count" => Map.get(data[key] || %{}, "run_count", 0)
      })

    write(Map.put(data, key, record))
  end

  @doc """
  Record a script execution. Increments run count and updates last_execution.
  """
  @spec record_run(String.t()) :: :ok
  def record_run(key) do
    data = read()
    record = Map.get(data, key, %{})

    updated =
      record
      |> Map.put("last_execution", DateTime.utc_now() |> DateTime.to_iso8601())
      |> Map.update("run_count", 1, &((&1 || 0) + 1))

    write(Map.put(data, key, updated))
  end

  @doc """
  Get a single record by key.
  """
  @spec get(String.t()) :: map() | nil
  def get(key) do
    Map.get(read(), key)
  end

  @doc """
  Delete a record by key.
  """
  @spec delete(String.t()) :: :ok
  def delete(key) do
    data = read()
    write(Map.delete(data, key))
  end

  @doc """
  Find a record by script name. Matches against the `name` field,
  with or without the `.exs` extension. Returns `{:ok, key, record}` or `:miss`.
  """
  @spec find_by_name(String.t()) :: {:ok, String.t(), map()} | :miss
  def find_by_name(name) do
    candidates = [name, name <> ".exs"]

    read()
    |> Enum.find_value(:miss, fn {key, record} ->
      if Map.get(record, "name") in candidates do
        {:ok, key, record}
      end
    end)
  end

  @doc """
  Return all records.
  """
  @spec list() :: map()
  def list do
    read()
  end

  @doc """
  Extract a description from a script file — the first comment block
  (lines starting with `#` until first blank line, after the shebang).
  """
  @spec extract_description(String.t()) :: String.t() | nil
  def extract_description(script_path) do
    case File.read(script_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.drop_while(&shebang_line?/1)
        |> Enum.drop_while(&(&1 == ""))
        |> Enum.take_while(&comment_line?/1)
        |> Enum.map(&String.replace_leading(&1, "# ", ""))
        |> Enum.map(&String.replace_leading(&1, "#", ""))
        |> case do
          [] -> nil
          lines -> Enum.join(lines, " ")
        end

      _ ->
        nil
    end
  end

  @doc """
  Extract dependency names from a script's `Mix.install` call.
  """
  @spec extract_deps(String.t()) :: [String.t()]
  def extract_deps(script_path) do
    case File.read(script_path) do
      {:ok, content} ->
        case Regex.run(~r/Mix\.install\s*\(\s*\[(.*?)\]/s, content) do
          [_, install_block] ->
            Regex.scan(~r/[:{](\w+)/, install_block)
            |> Enum.map(fn [_, name] -> name end)
            |> Enum.uniq()

          _ ->
            []
        end

      _ ->
        []
    end
  end

  defp shebang_line?("#!" <> _), do: true
  defp shebang_line?(_), do: false

  defp comment_line?("#" <> _), do: true
  defp comment_line?(_), do: false

  defp encode_yaml(data) when map_size(data) == 0, do: "---\n"

  defp encode_yaml(data) do
    lines =
      Enum.flat_map(data, fn {key, value} ->
        [encode_key(key) <> ":" | encode_map_value(value)]
      end)

    ["---" | lines]
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp encode_key(key), do: inspect(to_string(key))

  defp encode_map_value(map) when is_map(map) do
    Enum.flat_map(map, fn {k, v} ->
      ["  #{k}: #{encode_value(v)}"]
    end)
  end

  defp encode_map_value(other), do: ["  #{encode_value(other)}"]

  defp encode_value(nil), do: "~"
  defp encode_value(v) when is_binary(v), do: inspect(v)
  defp encode_value(v) when is_integer(v), do: Integer.to_string(v)
  defp encode_value(v) when is_float(v), do: Float.to_string(v)
  defp encode_value(v) when is_boolean(v), do: to_string(v)
  defp encode_value(v) when is_list(v), do: "[#{Enum.map_join(v, ", ", &encode_value/1)}]"
  defp encode_value(v), do: inspect(v)
end
