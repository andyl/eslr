defmodule Elr.Loader do
  @moduledoc """
  Clones repos, downloads scripts, and locates valid scripts. Uses cache when available.
  """

  alias Elr.{Cache, Datastore, Http, Output, Ref, Resolver, Script}

  @spec load(Ref.t(), keyword()) :: {:ok, {:script, String.t()}} | {:error, String.t()}
  def load(%Ref{} = ref, opts \\ []) do
    no_cache = Keyword.get(opts, :no_cache, false)

    case Resolver.resolve(ref) do
      {:clone, url, git_ref} ->
        clone_and_find_script(ref, url, git_ref, no_cache)

      {:script, url} ->
        download_script(ref, url, no_cache)

      {:local, path} ->
        load_local(path)
    end
  end

  defp load_local(path) do
    expanded = Path.expand(path)

    if File.exists?(expanded) do
      case Script.validate(expanded) do
        {:ok, _} -> {:ok, {:script, expanded}}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "file not found: #{path}"}
    end
  end

  defp clone_and_find_script(ref, url, git_ref, no_cache) do
    cache_key = Cache.cache_key(ref)

    unless no_cache do
      case find_cached_script(cache_key) do
        {:ok, script_path} ->
          Output.verbose("Using cached script: #{script_path}")
          {:ok, {:script, script_path}}

        :miss ->
          do_clone_and_find_script(ref, url, git_ref, cache_key)
      end
    else
      do_clone_and_find_script(ref, url, git_ref, cache_key)
    end
  end

  defp do_clone_and_find_script(ref, url, git_ref, cache_key) do
    Output.verbose("Cloning #{url}...")

    tmp_dir = Path.join(System.tmp_dir!(), "elr_build_#{:rand.uniform(1_000_000)}")

    try do
      clone_args =
        case git_ref do
          nil -> ["clone", "--depth", "1", url, tmp_dir]
          ref -> ["clone", "--depth", "1", "--branch", ref, url, tmp_dir]
        end

      case System.cmd("git", clone_args, stderr_to_stdout: true) do
        {_, 0} ->
          find_script_in_repo(ref, tmp_dir, cache_key)

        {output, _} ->
          {:error, "git clone failed: #{String.trim(output)}"}
      end
    after
      File.rm_rf(tmp_dir)
    end
  end

  defp find_script_in_repo(ref, project_dir, cache_key) do
    case ref.script_path do
      nil ->
        find_single_script(project_dir, cache_key)

      path_or_glob ->
        if String.contains?(path_or_glob, "*") do
          resolve_glob(project_dir, path_or_glob, cache_key)
        else
          resolve_literal_path(project_dir, path_or_glob, cache_key)
        end
    end
  end

  defp find_single_script(project_dir, cache_key) do
    case Script.list_scripts(project_dir) do
      [] ->
        {:error, "no valid elr scripts found in repository"}

      [script] ->
        cache_script(script, cache_key)

      scripts ->
        relative =
          Enum.map(scripts, &Path.relative_to(&1, project_dir))
          |> Enum.join("\n  ")

        {:error,
         "multiple scripts found in repository, specify one with a path or glob:\n  #{relative}"}
    end
  end

  defp resolve_glob(project_dir, glob, cache_key) do
    matches =
      Path.wildcard(Path.join(project_dir, glob))
      |> Enum.filter(&Script.valid?/1)

    case matches do
      [] ->
        {:error, "no valid scripts matching glob pattern: #{glob}"}

      [script] ->
        cache_script(script, cache_key)

      scripts ->
        relative =
          Enum.map(scripts, &Path.relative_to(&1, project_dir))
          |> Enum.join("\n  ")

        {:error,
         "multiple scripts match glob pattern '#{glob}', refine your pattern:\n  #{relative}"}
    end
  end

  defp resolve_literal_path(project_dir, script_path, cache_key) do
    full_path = Path.join(project_dir, script_path)

    if File.exists?(full_path) do
      case Script.validate(full_path) do
        {:ok, _} -> cache_script(full_path, cache_key)
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "script not found in repository: #{script_path}"}
    end
  end

  defp cache_script(script_path, cache_key) do
    {:ok, cached_path} =
      Cache.store(cache_key, %{"ref" => Path.basename(script_path), "type" => "script"})

    dest = Path.join(cached_path, Path.basename(script_path))
    File.cp!(script_path, dest)

    Datastore.record_install(cache_key, %{
      "name" => Path.basename(script_path),
      "description" => Datastore.extract_description(dest),
      "deps" => Datastore.extract_deps(dest)
    })

    {:ok, {:script, dest}}
  end

  defp find_cached_script(cache_key) do
    case Cache.lookup(cache_key) do
      {:ok, path, _metadata} ->
        path
        |> File.ls!()
        |> Enum.find_value(:miss, fn file ->
          full = Path.join(path, file)

          if file != "metadata.json" and not File.dir?(full) do
            {:ok, full}
          end
        end)

      :miss ->
        :miss
    end
  end

  defp download_script(ref, url, no_cache) do
    cache_key = Cache.cache_key(ref)

    unless no_cache do
      case Cache.lookup(cache_key) do
        {:ok, path, _metadata} ->
          script_path = Path.join(path, "script.exs")

          if File.exists?(script_path) do
            Output.verbose("Using cached script: #{script_path}")
            {:ok, {:script, script_path}}
          else
            do_download(url, cache_key)
          end

        :miss ->
          do_download(url, cache_key)
      end
    else
      do_download(url, cache_key)
    end
  end

  defp do_download(url, cache_key) do
    Output.verbose("Downloading #{url}...")

    case Http.get(url) do
      {:ok, body} ->
        {:ok, cache_path} = Cache.store(cache_key, %{"url" => url})
        script_path = Path.join(cache_path, "script.exs")
        File.write!(script_path, body)
        {:ok, {:script, script_path}}

      {:error, reason} ->
        {:error, "failed to download script: #{reason}"}
    end
  end
end
