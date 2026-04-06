defmodule Eslr.Cache do
  @moduledoc """
  Filesystem caching keyed by reference + Elixir/OTP version.
  """

  @metadata_file "metadata.json"

  def dir do
    cond do
      dir = System.get_env("ESLR_CACHE_DIR") -> dir
      xdg = System.get_env("XDG_CACHE_HOME") -> Path.join(xdg, "eslr")
      true -> Path.join(System.user_home!(), ".cache/eslr")
    end
  end

  def cache_key(%Eslr.Ref{} = ref) do
    elixir_version = System.version()
    otp_release = :erlang.system_info(:otp_release) |> to_string()

    parts = [ref.type, ref.name, ref.version || "latest", ref.git_ref || "HEAD", ref.script_path || ""]
    ref_hash = :crypto.hash(:sha256, Enum.join(parts, ":")) |> Base.encode16(case: :lower)

    "#{ref.name}-#{String.slice(ref_hash, 0, 12)}-elixir#{elixir_version}-otp#{otp_release}"
  end

  def lookup(key) do
    path = entry_path(key)
    metadata_path = Path.join(path, @metadata_file)

    if File.exists?(metadata_path) do
      case File.read(metadata_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, metadata} -> {:ok, path, metadata}
            _ -> :miss
          end

        _ ->
          :miss
      end
    else
      :miss
    end
  end

  def store(key, metadata \\ %{}) do
    path = entry_path(key)
    File.mkdir_p!(path)

    meta =
      Map.merge(metadata, %{
        "stored_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "cache_key" => key
      })

    File.write!(Path.join(path, @metadata_file), Jason.encode!(meta, pretty: true))
    {:ok, path}
  end

  def delete(key) do
    path = entry_path(key)

    if File.exists?(path) do
      File.rm_rf!(path)
      :ok
    else
      {:error, :not_found}
    end
  end

  def list do
    cache_dir = dir()

    if File.exists?(cache_dir) do
      cache_dir
      |> File.ls!()
      |> Enum.filter(fn entry ->
        File.exists?(Path.join([cache_dir, entry, @metadata_file]))
      end)
      |> Enum.map(fn entry ->
        metadata_path = Path.join([cache_dir, entry, @metadata_file])

        metadata =
          case File.read(metadata_path) do
            {:ok, content} ->
              case Jason.decode(content) do
                {:ok, meta} -> meta
                _ -> %{}
              end

            _ ->
              %{}
          end

        {entry, metadata}
      end)
    else
      []
    end
  end

  def clean do
    cache_dir = dir()

    if File.exists?(cache_dir) do
      File.rm_rf!(cache_dir)
      File.mkdir_p!(cache_dir)
      :ok
    else
      :ok
    end
  end

  def prune(max_age_days \\ 30) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-max_age_days * 86400, :second)

    list()
    |> Enum.filter(fn {_key, metadata} ->
      case Map.get(metadata, "stored_at") do
        nil ->
          true

        stored_at ->
          case DateTime.from_iso8601(stored_at) do
            {:ok, dt, _} -> DateTime.compare(dt, cutoff) == :lt
            _ -> true
          end
      end
    end)
    |> Enum.each(fn {key, _} -> delete(key) end)

    :ok
  end

  defp entry_path(key) do
    Path.join(dir(), key)
  end
end
