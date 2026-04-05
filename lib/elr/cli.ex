defmodule Elr.CLI do
  @moduledoc """
  Escript entrypoint. Parses arguments and orchestrates the pipeline.
  """

  alias Elr.{Cache, Loader, Output, Ref}

  @switches [
    help: :boolean,
    version: :boolean,
    verbose: :boolean,
    no_cache: :boolean,
    cache: :string
  ]

  @aliases [
    h: :help,
    v: :version,
    V: :verbose
  ]

  def main(argv) do
    {opts, args, _invalid} = OptionParser.parse(argv, strict: @switches, aliases: @aliases)

    Output.set_verbose(opts[:verbose] || false)

    cond do
      opts[:help] ->
        print_help()

      opts[:version] ->
        IO.puts("elr #{Elr.version()}")

      opts[:cache] ->
        handle_cache(opts[:cache])

      args == [] ->
        print_help()

      true ->
        [ref_string | rest_argv] = args
        run(ref_string, rest_argv, opts)
    end
  end

  defp run(ref_string, argv, opts) do
    with {:ok, ref} <- Ref.parse(ref_string),
         {:ok, result} <- Loader.load(ref, no_cache: opts[:no_cache] || false) do
      case Elr.Runner.run(result, ref, argv) do
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
    elr — Elixir Load & Run

    Usage:
      elr [options] <reference> [args...]
      elr --cache <subcommand>

    Options:
      -h, --help       Show this help
      -v, --version    Show version
      -V, --verbose    Verbose output
      --no-cache       Skip cache, force fresh fetch

    Cache subcommands:
      elr --cache dir     Show cache directory path
      elr --cache list    List cached entries
      elr --cache clean   Remove all cached entries
      elr --cache prune   Remove entries older than 30 days

    Reference types:
      hex_package          Hex package (latest version)
      hex_package@1.0.0    Hex package (specific version)
      github:user/repo     GitHub repo (default branch)
      github:user/repo#ref GitHub repo (specific ref)
      git+https://url      Git repository
      git+https://url#ref  Git repository (specific ref)
      https://url/file.exs Remote .exs script
      ./path/to/file.exs   Local .exs script
      /path/to/file.exs    Local .exs script

    Environment variables:
      ELR_CACHE_DIR    Override cache directory
      ELR_NO_COLOR     Disable colored output
    """)
  end
end
