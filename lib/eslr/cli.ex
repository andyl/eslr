defmodule Eslr.CLI do
  @moduledoc """
  Escript entrypoint. Parses arguments and orchestrates the pipeline.
  """

  alias Eslr.{Cache, Datastore, Loader, Output, Ref, Script}

  @switches [
    help: :boolean,
    version: :boolean,
    verbose: :boolean,
    no_cache: :boolean,
    cache: :string,
    find: :boolean
  ]

  @aliases [
    h: :help,
    v: :version,
    V: :verbose
  ]

  def main(argv) do
    {eslr_argv, script_ref, script_argv} = split_argv(argv)

    {opts, args, _invalid} = OptionParser.parse(eslr_argv, strict: @switches, aliases: @aliases)

    Output.set_verbose(opts[:verbose] || false)

    cond do
      opts[:help] ->
        print_help()

      opts[:version] ->
        IO.puts("eslr #{Eslr.version()}")

      opts[:cache] ->
        handle_cache(opts[:cache])

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
    with {:ok, ref} <- Ref.parse(ref_string),
         {:ok, result} <- Loader.load(ref, no_cache: opts[:no_cache] || false) do
      cache_key = Cache.cache_key(ref)
      Datastore.record_run(cache_key)

      case Eslr.Runner.run(result, ref, argv) do
        :ok ->
          :ok

        {:error, reason} ->
          Output.error(reason)
          exit({:shutdown, 1})
      end
    else
      {:error, reason} ->
        Output.error(reason)
        exit({:shutdown, 1})
    end
  end

  defp handle_find(nil, _opts) do
    Output.error("--find requires a repository reference")
    exit({:shutdown, 1})
  end

  defp handle_find(ref_string, opts) do
    with {:ok, ref} <- Ref.parse(ref_string) do
      case Eslr.Resolver.resolve(ref) do
        {:clone, url, git_ref} ->
          find_scripts_in_repo(url, git_ref, opts)

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

  defp find_scripts_in_repo(url, git_ref, _opts) do
    tmp_dir = Path.join(System.tmp_dir!(), "eslr_find_#{:rand.uniform(1_000_000)}")

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
            IO.puts("No valid eslr scripts found.")
          else
            Enum.each(scripts, fn script ->
              IO.puts(Path.relative_to(script, tmp_dir))
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

  defp handle_cache(subcommand) do
    case subcommand do
      "dir" ->
        IO.puts(Cache.dir())

      "list" ->
        case Cache.list() do
          [] ->
            IO.puts("Cache is empty.")

          entries ->
            Enum.each(entries, fn {key, metadata} ->
              stored = Map.get(metadata, "stored_at", "unknown")
              IO.puts("#{key}  (stored: #{stored})")
            end)
        end

      "clean" ->
        Cache.clean()
        Output.info("Cache cleaned.")

      "prune" ->
        Cache.prune()
        Output.info("Old cache entries pruned.")

      other ->
        Output.error("unknown cache subcommand: #{other}")
        exit({:shutdown, 1})
    end
  end

  defp print_help do
    IO.puts("""
    eslr — Elixir Script Load & Run

    Usage:
      eslr [options] [--] <reference> [args...]
      eslr --find <reference>
      eslr --cache <subcommand>

    Options:
      -h, --help       Show this help
      -v, --version    Show version
      -V, --verbose    Verbose output
      --no-cache       Skip cache, force fresh fetch
      --find           List valid scripts in a repository

    Cache subcommands:
      eslr --cache dir     Show cache directory path
      eslr --cache list    List cached entries
      eslr --cache clean   Remove all cached entries
      eslr --cache prune   Remove entries older than 30 days

    Reference types:
      github:user/repo              GitHub repo (default branch)
      github:user/repo#ref          GitHub repo (specific ref)
      github:user/repo:path/glob    GitHub repo with script path or glob
      git+https://url               Git repository
      git+https://url#ref           Git repository (specific ref)
      https://url/file.exs          Remote .exs script
      ./path/to/file.exs            Local .exs script
      /path/to/file.exs             Local .exs script

    Argument separation:
      Use -- to separate eslr options from script arguments:
      eslr --verbose -- github:user/repo --help
      (--help is passed to the script, not to eslr)

    Environment variables:
      ESLR_CACHE_DIR    Override cache directory
      ESLR_NO_COLOR     Disable colored output
    """)
  end
end
