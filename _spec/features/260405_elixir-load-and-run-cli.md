# Feature: Elixir Load and Run CLI

## Summary

Build the core `elr` command-line tool that allows users to load and run Elixir
scripts and escripts from multiple sources (Hex packages, GitHub repos, git
URLs, direct script URLs, and local files) with automatic dependency fetching
via `Mix.install/2`.

## Motivation

Currently, running an Elixir script from Hex or GitHub requires manual steps to
find, download and run. There is no `npx`-equivalent in the Elixir ecosystem.
`elr` eliminates this friction by providing a single command that handles
fetching, caching, and executing Elixir code from any supported reference type.

## User Stories

- As a developer, I want to run a Hex package tool with `elr <package>` so I can use it without adding it to a project.
- As a developer, I want to run a specific version of a Hex package with `elr <package>@<version>` so I can test against a known version.
- As a developer, I want to run a tool from a GitHub repository with `elr github:user/repo` so I can try tools not yet published to Hex.
- As a developer, I want to run a remote `.exs` script by URL so I can execute shared scripts without downloading them manually.
- As a developer, I want to run a local `.exs` file through `elr` so it can resolve dependencies automatically.
- As a developer, I want repeated runs to be fast via caching so I don't wait for dependency resolution every time.
- As a developer, I want to manage my cache with `elr --cache` subcommands so I can reclaim disk space or force a fresh load.

## Functional Requirements

### Reference Parsing

- Parse and resolve the following reference formats from the first CLI argument:
  - **Hex packages**: `<package>` or `<package>@<version>` (e.g. `benchee`, `req@0.5.0`, `req@~>0.5`)
  - **GitHub shorthand**: `github:user/repo`, optionally with `#ref` (branch, tag, or SHA)
  - **Git URLs**: `git+https://...#ref`
  - **Direct script URLs**: any `https://` URL ending in `.exs`
  - **Local files**: relative or absolute paths to `.exs` or `.escript` files

### Dependency Loading

- Use `Mix.install/2` for dependency resolution and loading for Hex and git-based references.
- For direct remote `.exs` scripts, download the script and execute it, honoring any `Mix.install` call within the script itself.
- For local files, execute directly, supporting optional `Mix.install` within the script.

### Entrypoint Detection and Execution

- If a Hex package or git repo defines an escript in its `mix.exs`, build and run the escript.
- Otherwise, load the code and call `MainModule.main(argv)` or a configured entrypoint.
- Pass all arguments after the reference through to the executed script/tool as `argv`.

### Caching

- Cache resolved dependencies and built escripts in `~/.cache/elr` (or `$XDG_CACHE_HOME/elr`, or `$ELR_CACHE_DIR`).
- Key cache entries by reference + Elixir version + OTP version.
- Support `--no-cache` flag to bypass cache and force a fresh load.

### Cache Management

- `elr --cache dir` — Print the cache directory path.
- `elr --cache list` — List all cached entries with details.
- `elr --cache clean [<ref>]` — Remove a specific cached entry, or all entries if no ref given.
- `elr --cache prune` — Remove old or unused cache entries.

### CLI Options

- `--help` / `-h` — Display help text.
- `--version` / `-v` — Display the current `elr` version.
- `--no-cache` — Skip cache, force fresh dependency resolution.
- `--verbose` — Show detailed loading and resolution steps.
- `--cache <subcommand>` — Cache management (dir, list, clean, prune).

### Environment Variables

- `ELR_CACHE_DIR` — Override the default cache directory.
- `ELR_NO_COLOR` — Disable colored output.

## Non-Functional Requirements

- Distributed as an escript, installable via `mix escript.install hex elr`.
- Must work with Elixir ~> 1.19 and current OTP versions.
- Cached runs should start in under 1 second for previously resolved references.
- Provide clear error messages when a reference cannot be resolved or an entrypoint cannot be found.

## Acceptance Criteria

- [ ] `elr <hex_package>` resolves, caches, and runs the package.
- [ ] `elr <hex_package>@<version>` pins to the specified version.
- [ ] `elr github:user/repo` clones and runs the repo's entrypoint.
- [ ] `elr github:user/repo#ref` checks out the specified ref.
- [ ] `elr <url>.exs` downloads and runs the remote script.
- [ ] `elr ./local.exs` runs a local script with dependency support.
- [ ] `--no-cache` forces a fresh load, ignoring existing cache.
- [ ] `--verbose` prints dependency resolution and execution steps.
- [ ] `--cache dir` prints the cache path.
- [ ] `--cache list` shows cached entries.
- [ ] `--cache clean` removes cache entries.
- [ ] `--cache prune` removes stale entries.
- [ ] `--help` and `--version` produce correct output.
- [ ] Subsequent cached runs complete in under 1 second.
- [ ] Arguments after the reference are forwarded to the executed tool.

## Out of Scope

- Publishing `elr` to Hex (separate task).
- A Mix task interface (this is escript-only).
- Windows-specific path handling.
- Authentication for private repositories or packages.

## Dependencies

- `igniter` (dev/test) — code generation and AST manipulation.
- `Mix.install/2` — core dependency resolution mechanism (stdlib).
