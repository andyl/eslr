# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**scriptlr** (Elixir Script Load & Run) is a CLI tool — the Elixir equivalent of `npx`. It loads and runs Elixir scripts (`.exs` files containing `Mix.install`) from git repos or URLs with automatic dependency fetching. Distributed as an escript.

## Build & Development Commands

```bash
mix deps.get          # Fetch dependencies
mix compile           # Compile the project
mix test              # Run all tests
mix test test/scriptlr/ref_test.exs       # Run a single test file
mix test --only tag_name              # Run tests matching a tag
mix format            # Format code
mix format --check-formatted          # Check formatting without changing
mix escript.build     # Build the escript locally (produces ./scriptlr)
```

## Architecture

Pipeline: **parse → resolve → clone/download → find script → execute as subprocess**

- **lib/scriptlr/cli.ex** — Escript entrypoint (`main/1`), argument parsing with `--` separator for script args, dispatches to cache/find/run subcommands
- **lib/scriptlr/ref.ex** — Parses reference strings (github:, git+, URLs, local paths) into `%Scriptlr.Ref{}` struct
- **lib/scriptlr/resolver.ex** — Converts `%Scriptlr.Ref{}` into actionable tuples: `{:clone, url, git_ref}`, `{:script, url}`, or `{:local, path}`
- **lib/scriptlr/loader.ex** — Orchestrates clone/download with cache integration; returns `{:ok, {:script, path}}`
- **lib/scriptlr/script.ex** — Validates scripts (must have `Mix.install` call; shebang scripts must also be executable); `list_scripts/1` finds all valid scripts in a directory
- **lib/scriptlr/runner.ex** — Executes scripts as subprocesses via `Port.open` with the `elixir` interpreter
- **lib/scriptlr/cache.ex** — Filesystem cache in `~/.cache/scriptlr`, keyed by reference + Elixir/OTP version
- **lib/scriptlr/datastore.ex** — YAML-based usage tracking (install dates, run counts) stored in cache dir
- **lib/scriptlr/output.ex** — User-facing output with color/verbosity support
- **lib/scriptlr/http.ex** — HTTP client wrapper using Erlang's `:httpc`

## Key Design Decisions

- Only `.exs` files containing `Mix.install` are valid scripts; extensionless files also need an Elixir shebang and executable bit
- Runner executes scripts as subprocesses (not in-process) via `elixir` command through `Port.open`
- The `--` separator in argv splits scriptlr options from script arguments
- Cache keyed by reference + Elixir/OTP version; managed via `scriptlr --cache {dir,list,clean,prune}`
- Datastore tracks per-script usage stats in YAML alongside the cache

## Specs & Plans

- **_spec/designs/** — Design specifications
- **_spec/features/** — Feature specifications
- **_spec/plans/** — Implementation plans
