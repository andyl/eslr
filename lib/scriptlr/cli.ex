defmodule Scriptlr.CLI do
  @moduledoc """
  Escript entrypoint. Parses arguments and orchestrates the pipeline.
  """

  alias Scriptlr.{Cache, Datastore, Loader, Output, Ref, Script}

  @switches [
    help: :boolean,
    version: :boolean,
    verbose: :boolean,
    update: :boolean,
    cache: :string,
    find: :boolean
  ]

  @aliases [
    h: :help,
    v: :version,
    V: :verbose
  ]

  def main(argv) do
    {scriptlr_argv, script_ref, script_argv} = split_argv(argv)

    {opts, args, _invalid} = OptionParser.parse(scriptlr_argv, strict: @switches, aliases: @aliases)

    Output.set_verbose(opts[:verbose] || false)

    cond do
      opts[:help] ->
        print_help()

      opts[:version] ->
        IO.puts("scriptlr #{Scriptlr.version()}")

      opts[:cache] ->
        handle_cache(opts[:cache], args)

      opts[:find] ->
        ref_string = script_ref || List.first(args)
        handle_find(ref_string, opts)

      script_ref != nil ->
        run(script_ref, script_argv, opts)

      args != [] ->
        [ref_string | rest_argv] = args
        run(ref_string, rest_argv, opts)

      true ->
        print_help()
    end
  end

  defp split_argv(argv) do
    case Enum.split_while(argv, &(&1 != "--")) do
      {before, ["--" | rest]} ->
        case rest do
          [ref | script_args] -> {before, ref, script_args}
          [] -> {before, nil, []}
        end

      {all, []} ->
        {all, nil, []}
    end
  end

  defp run(ref_string, argv, opts) do
    case Ref.parse(ref_string) do
      {:ok, ref} ->
        run_ref(ref, ref_string, argv, opts)

      {:error, _reason} ->
        case Datastore.find_by_name(ref_string) do
          {:ok, _key, %{"scriptlr_command" => "scriptlr " <> saved_ref}} ->
            run(saved_ref, argv, opts)

          _ ->
            Output.error("unknown script: #{ref_string}")
            exit({:shutdown, 1})
        end
    end
  end

  defp run_ref(ref, ref_string, argv, opts) do
    case Loader.load(ref, update: opts[:update] || false, ref_string: ref_string) do
      {:ok, result} ->
        cache_key = Cache.cache_key(ref)
        Datastore.record_run(cache_key)

        case Scriptlr.Runner.run(result, ref, argv) do
          :ok ->
            :ok

          {:error, reason} ->
            Output.error(reason)
            exit({:shutdown, 1})
        end

      {:error, reason} ->
        Output.error(reason)
        exit({:shutdown, 1})
    end
  end

  defp handle_find(nil, _opts) do
    Output.error("--find requires a repository reference")
    exit({:shutdown, 1})
  end

  defp handle_find(ref_string, _opts) do
    with {:ok, ref} <- Ref.parse(ref_string) do
      case Scriptlr.Resolver.resolve(ref) do
        {:clone, url, git_ref} ->
          find_scripts_in_repo(ref_string, url, git_ref)

        _ ->
          Output.error("--find only works with repository references (github: or git+)")
          exit({:shutdown, 1})
      end
    else
      {:error, reason} ->
        Output.error(reason)
        exit({:shutdown, 1})
    end
  end

  defp find_scripts_in_repo(ref_string, url, git_ref) do
    # Strip any trailing #ref from the ref_string for building output
    base_ref = String.replace(ref_string, ~r/#.*$/, "")
    tmp_dir = Path.join(System.tmp_dir!(), "scriptlr_find_#{:rand.uniform(1_000_000)}")

    try do
      clone_args =
        case git_ref do
          nil -> ["clone", "--depth", "1", url, tmp_dir]
          ref -> ["clone", "--depth", "1", "--branch", ref, url, tmp_dir]
        end

      case System.cmd("git", clone_args, stderr_to_stdout: true) do
        {_, 0} ->
          scripts = Script.list_scripts(tmp_dir)

          if scripts == [] do
            IO.puts("No valid scriptlr scripts found.")
          else
            Enum.each(scripts, fn script ->
              path = Path.relative_to(script, tmp_dir)
              IO.puts("#{base_ref}:#{path}")
            end)
          end

        {output, _} ->
          Output.error("git clone failed: #{String.trim(output)}")
          exit({:shutdown, 1})
      end
    after
      File.rm_rf(tmp_dir)
    end
  end

  defp handle_cache(subcommand, args) do
    case subcommand do
      "dir" ->
        IO.puts(Cache.dir())

      "list" ->
        case Cache.list() do
          [] ->
            IO.puts("Cache is empty.")

          entries ->
            ds = Datastore.read()

            Enum.each(entries, fn {key, _metadata} ->
              IO.puts(display_name(key, ds))
            end)
        end

      "info" ->
        handle_cache_info(List.first(args))

      "remove" ->
        handle_cache_remove(List.first(args))

      "clean" ->
        Cache.clean()
        Output.info("Cache cleaned.")

      "prune" ->
        Cache.prune()
        Output.info("Old cache entries pruned.")

      other ->
        Output.error(
          "unknown cache subcommand: #{other}. Valid options: dir, list, info, remove, clean, prune"
        )

        exit({:shutdown, 1})
    end
  end

  defp handle_cache_info(nil) do
    Output.error("--cache info requires a script name")
    exit({:shutdown, 1})
  end

  defp handle_cache_info(name) do
    case Datastore.find_by_name(name) do
      {:ok, _key, record} ->
        record
        |> Enum.sort()
        |> Enum.each(fn {k, v} ->
          IO.puts("#{String.pad_trailing(k, 16)} #{format_value(v)}")
        end)

      :miss ->
        Output.error("no cached script found for: #{name}")
        exit({:shutdown, 1})
    end
  end

  defp handle_cache_remove(nil) do
    Output.error("--cache remove requires a script name")
    exit({:shutdown, 1})
  end

  defp handle_cache_remove(name) do
    case Datastore.find_by_name(name) do
      {:ok, key, _record} ->
        Cache.delete(key)
        Datastore.delete(key)
        Output.info("Removed: #{name}")

      :miss ->
        Output.error("no cached script found for: #{name}")
        exit({:shutdown, 1})
    end
  end

  defp format_value(nil), do: "~"
  defp format_value(v) when is_list(v), do: Enum.join(v, ", ")
  defp format_value(v), do: to_string(v)

  defp print_help do
    IO.puts("""
    scriptlr — Elixir Script Load & Run

    Usage:
      scriptlr [options] [--] <reference> [args...]
      scriptlr --find <reference>
      scriptlr --cache <subcommand>

    Options:
      -h, --help       Show this help
      -v, --version    Show version
      -V, --verbose    Verbose output
      --update         Force fresh fetch, replacing cached version
      --find REF       List valid scripts in a repository

    Cache subcommands:
      scriptlr --cache dir          Show cache directory path
      scriptlr --cache list         List cached entries
      scriptlr --cache info NAME    Show details for a cached script
      scriptlr --cache remove NAME  Remove a cached script
      scriptlr --cache clean        Remove all cached entries
      scriptlr --cache prune        Remove entries older than 30 days

    Reference types:
      github:user/repo              GitHub repo (default branch)
      github:user/repo#ref          GitHub repo (specific ref)
      github:user/repo:path         GitHub repo with script path
      git+https://url               Git repository
      git+https://url#ref           Git repository (specific ref)
      https://url/file.exs          Remote .exs script
      ./path/to/file.exs            Local .exs script
      /path/to/file.exs             Local .exs script

    Argument separation:
      Use -- to separate scriptlr options from script arguments:
      scriptlr --verbose -- github:user/repo --help
      (--help is passed to the script, not to scriptlr)

    Environment variables:
      SCRIPTLR_CACHE_DIR    Override cache directory
      SCRIPTLR_NO_COLOR     Disable colored output
    """)
  end

  defp display_name(cache_key, datastore) do
    case Map.get(datastore, cache_key) do
      %{"name" => name} when is_binary(name) ->
        script_name = String.replace_suffix(name, ".exs", "")
        hash = extract_hash(cache_key)
        "#{script_name}-#{hash}"

      _ ->
        cache_key
    end
  end

  defp extract_hash(cache_key) do
    case Regex.run(~r/-([0-9a-f]{12})-/, cache_key) do
      [_, hash] -> String.slice(hash, 0, 5)
      _ -> "00000"
    end
  end
end
