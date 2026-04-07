defmodule Scriptlr.Loader do
  @moduledoc """
  Clones repos, downloads scripts, and locates valid scripts. Uses cache when available.
  """

  alias Scriptlr.{Cache, Datastore, Http, Output, Ref, Resolver, Script}

  @spec load(Ref.t(), keyword()) :: {:ok, {:script, String.t()}} | {:error, String.t()}
  def load(%Ref{} = ref, opts \\ []) do
    update = Keyword.get(opts, :update, false)
    ref_string = Keyword.get(opts, :ref_string)

    case Resolver.resolve(ref) do
      {:clone, url, git_ref} ->
        clone_and_find_script(ref, url, git_ref, update, ref_string)

      {:script, url} ->
        download_script(ref, url, update, ref_string)

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

  defp clone_and_find_script(ref, url, git_ref, update, ref_string) do
    cache_key = Cache.cache_key(ref)

    unless update do
      case find_cached_script(cache_key) do
        {:ok, script_path} ->
          Output.verbose("Using cached script: #{script_path}")
          {:ok, {:script, script_path}}

        :miss ->
          do_clone_and_find_script(ref, url, git_ref, cache_key, ref_string)
      end
    else
      do_clone_and_find_script(ref, url, git_ref, cache_key, ref_string)
    end
  end

  defp do_clone_and_find_script(ref, url, git_ref, cache_key, ref_string) do
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
          find_script_in_repo(ref, tmp_dir, cache_key, ref_string)

        {output, _} ->
          {:error, "git clone failed: #{String.trim(output)}"}
      end
    after
      File.rm_rf(tmp_dir)
    end
  end

  defp find_script_in_repo(ref, project_dir, cache_key, ref_string) do
    case ref.script_path do
      nil ->
        find_single_script(project_dir, cache_key, ref_string)

      script_path ->
        resolve_literal_path(project_dir, script_path, cache_key, ref_string)
    end
  end

  defp find_single_script(project_dir, cache_key, ref_string) do
    case Script.list_scripts(project_dir) do
      [] ->
        {:error, "no valid scriptlr scripts found in repository"}

      [script] ->
        cache_script(script, cache_key, ref_string)

      scripts ->
        relative =
          Enum.map(scripts, &Path.relative_to(&1, project_dir))
          |> Enum.join("\n  ")

        {:error,
         "multiple scripts found in repository, specify one with a path:\n  #{relative}"}
    end
  end

  defp resolve_literal_path(project_dir, script_path, cache_key, ref_string) do
    full_path = Path.join(project_dir, script_path)

    if File.exists?(full_path) do
      case Script.validate(full_path) do
        {:ok, _} -> cache_script(full_path, cache_key, ref_string)
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "script not found in repository: #{script_path}"}
    end
  end

  defp cache_script(script_path, cache_key, ref_string) do
    {:ok, cached_path} =
      Cache.store(cache_key, %{"ref" => Path.basename(script_path), "type" => "script"})

    dest = Path.join(cached_path, Path.basename(script_path))
    File.cp!(script_path, dest)

    Datastore.record_install(cache_key, %{
      "name" => Path.basename(script_path),
      "description" => Datastore.extract_description(dest),
      "deps" => Datastore.extract_deps(dest),
      "scriptlr_command" => "scriptlr #{ref_string}"
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

  defp download_script(ref, url, update, ref_string) do
    cache_key = Cache.cache_key(ref)

    unless update do
      case Cache.lookup(cache_key) do
        {:ok, path, _metadata} ->
          script_path = Path.join(path, "script.exs")

          if File.exists?(script_path) do
            Output.verbose("Using cached script: #{script_path}")
            {:ok, {:script, script_path}}
          else
            do_download(url, cache_key, ref_string)
          end

        :miss ->
          do_download(url, cache_key, ref_string)
      end
    else
      do_download(url, cache_key, ref_string)
    end
  end

  defp do_download(url, cache_key, ref_string) do
    Output.verbose("Downloading #{url}...")

    case Http.get(url) do
      {:ok, body} ->
        {:ok, cache_path} = Cache.store(cache_key, %{"url" => url})
        script_path = Path.join(cache_path, "script.exs")
        File.write!(script_path, body)

        Datastore.record_install(cache_key, %{
          "name" => "script.exs",
          "description" => Datastore.extract_description(script_path),
          "deps" => Datastore.extract_deps(script_path),
          "scriptlr_command" => "scriptlr #{ref_string}"
        })

        {:ok, {:script, script_path}}

      {:error, reason} ->
        {:error, "failed to download script: #{reason}"}
    end
  end
end
