# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**elr** (Elixir Load & Run) is a CLI tool — the Elixir equivalent of `npx`. It loads and runs Elixir scripts (`.exs`), escripts, and tools from Hex packages, git repos, or URLs with automatic dependency fetching via `Mix.install/2`. Distributed as an escript.

## Build & Development Commands

```bash
mix deps.get          # Fetch dependencies
mix compile           # Compile the project
mix test              # Run all tests
mix test test/elr_test.exs  # Run a single test file
mix test --only tag_name    # Run tests matching a tag
mix format            # Format code
mix format --check-formatted  # Check formatting without changing files
```

## Architecture

- **lib/elr.ex** — Main module (currently scaffolded, not yet implemented)
- **_spec/designs/** — Design specifications; `260404_InitialDesign.md` contains the full product spec
- **deps** — Includes `igniter` (dev/test only) for code generation and AST manipulation via `sourceror`

## Key Design Decisions (from spec)

- References are resolved as: Hex packages, GitHub repos (`github:user/repo`), git URLs, direct `.exs` URLs, or local files
- Prefers building/running escripts when a package defines one; otherwise calls `MainModule.main(argv)`
- Caches in `~/.cache/elr` (or `$XDG_CACHE_HOME/elr`), keyed by reference + Elixir/OTP version
- Cache management via `elr --cache {dir,list,clean,prune}` flags on the main binary
