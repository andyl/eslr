# Scriptlr

I like the npx utility, and wish to create an equivalent for the
elixir ecosystem and leverages escripts and/or elixir scripts (exs /
mix.install). What should the elixir utility be called?

**elr Design Specification**

## Overview

**elr** (Elixir Load & Run) is a lightweight command-line tool that allows
users to instantly load and run Elixir scripts (`.exs`), escripts, and tools
from Hex packages, git repositories, or direct URLs, with automatic dependency
fetching via `Mix.install/2`.

It serves as the Elixir equivalent of `npx`, optimized for Elixir's scripting
model rather than full packages. The tool focuses on the two-step process:
**load** (fetch script + dependencies) and **run** (execute the entrypoint).

**Expanded name:**  
**elr — Elixir Load & Run**

## Core Goals
- Simple, fast, and familiar syntax: `elr <reference> [args...]`
- Strong support for remote Elixir scripts and escripts
- Automatic dependency resolution without requiring a full Mix project
- Local caching for performance on repeated runs
- Clean integration with Elixir ecosystem conventions (Hex, Mix.install, escripts)

## Installation

Users install `elr` globally as an escript:

```bash
mix escript.install hex elr
```

Ensure `~/.mix/escripts` is in `$PATH`.

## Reference Syntax

`elr` supports the following `<reference>` formats:

- **Hex packages**: `benchee`, `req@0.5.0`, `req@~>0.5`
- **GitHub**: `github:user/repo`, `github:user/repo#main`, `github:user/repo#v1.2.3`
- **Git URLs**: `git+https://github.com/user/repo.git#main`
- **Direct scripts**: `https://raw.githubusercontent.com/.../script.exs`
- **Local files**: `./my_script.exs`, `/path/to/tool.escript`

## Behavior

- Uses `Mix.install/2` for dependency loading when needed
- Prefers building and running escripts when the package defines one in `mix.exs`
- Detects and runs appropriate entrypoints (e.g. `main/1`, configured module, or script)
- Caches results in `~/.cache/elr` (or `$XDG_CACHE_HOME/elr`) keyed by reference + Elixir/OTP version
- Supports `--no-cache` to force fresh loading

## Cache Management

Cache management is provided via `--cache` options on the main binary (not as primary Mix tasks):

- `elr --cache dir` — Show cache directory
- `elr --cache list` — List cached items with details
- `elr --cache clean [<ref>]` — Clean specific or all cache entries
- `elr --cache prune` — Remove old/unused entries

## README

```markdown
# elr — Elixir Load & Run

**Quickly load and run Elixir scripts (`.exs`), escripts, and tools from Hex,
git, or direct URLs — with automatic dependency fetching.**

No need to create a full Mix project or manually run `Mix.install/2` every
time. Just point `elr` at a reference and go.

Inspired by `npx`, built for Elixir's scripting strengths.

## Features

- Run Hex packages with a single command (`elr benchee`)
- Support for specific versions, git repositories, and direct `.exs` scripts
- Automatic dependency loading via `Mix.install/2`
- Smart entrypoint detection (escripts preferred when available)
- Local caching for fast repeated runs
- Works with local `.exs` files too

## Installation

```bash
mix escript.install hex elr
```

Make sure `~/.mix/escripts` is in your `$PATH`:

```bash
export PATH="$HOME/.mix/escripts:$PATH"
```

Verify:

```bash
elr --help
```

## Updating

```bash
mix escript.install hex elr --force
```

## Usage

```bash
elr <reference> [args...]
```

## Examples

```bash
# Hex packages
elr benchee
elr req@0.5.0 get https://httpbin.org/json

# GitHub repositories
elr github:livebook-dev/livebook
elr github:wojtekmach/mix_install_examples#main

# Direct remote script
elr https://raw.githubusercontent.com/user/repo/main/tool.exs --help

# Local script
elr ./my_tool.exs --verbose
```

## Reference Types

- `package_name[@version]` — Hex package
- `github:user/repo[#ref]` — GitHub repository
- `git+https://...[#ref]` — Full git URL
- `https://.../*.exs` — Direct remote Elixir script
- `./path/to/script.exs` — Local file

## Options

```bash
--help, -h          Show this help
--version, -v       Show version
--no-cache          Disable caching (force fresh load)
--verbose           Show detailed loading steps
--cache list        List cached references
--cache dir         Show cache directory
--cache clean       Clean the cache (use --force to skip confirmation)
--cache prune       Remove old cache entries
```

Run `elr --help extended` for advanced usage, caching details, and entrypoint configuration.

## How It Works

`elr` loads the referenced code + dependencies (using `Mix.install/2` or escript build), then executes the main entrypoint. Results are cached for speed and reproducibility.

Made with ❤️ for the Elixir community.
```

### Help Text (`elr --help`)

```markdown
elr — Elixir Load & Run

Quickly load and run Elixir scripts (.exs), escripts, and tools from Hex, git, or URLs
with automatic dependency fetching via Mix.install.

Usage:
  elr <reference> [args...]

References:
  <package>[@version]                  Hex package (e.g. benchee, req@0.5.0)
  github:user/repo[#ref]               GitHub repository (e.g. github:wojtekmach/mix_install_examples#main)
  git+https://...[#ref]                Full git URL
  https://.../*.exs                    Direct remote .exs script
  ./local/script.exs                   Local .exs or .escript file

Examples:
  elr benchee
  elr req@0.5.0 get https://httpbin.org/json
  elr github:livebook-dev/livebook
  elr https://raw.githubusercontent.com/user/repo/main/tool.exs --help
  elr ./my_tool.exs --verbose

Options:
  --help, -h          Show this help
  --version, -v       Show version
  --no-cache          Disable caching (force fresh load)
  --verbose           Show detailed loading steps
  --cache list        List cached references
  --cache dir         Show cache directory
  --cache clean       Clean the cache
  --cache prune       Remove old cache entries

For advanced usage and details, run: elr --help extended
```

## Extended Help (`elr --help extended`)

```markdown
elr — Elixir Load & Run

elr lets you run Elixir code instantly without creating a full Mix project.
It handles remote scripts and packages by loading dependencies on the fly
(using Mix.install under the hood) and then executing the main entrypoint.

How references are resolved:
  • Hex packages            → Mix.install([{:package, "~> version"}])
  • Git repos               → Mix.install([{:package, git: "...", tag: "..."}])
  • Direct .exs URLs        → Downloaded and run with its own Mix.install if present
  • Local files             → Executed directly (with optional Mix.install support)

Entry point detection:
  - If the package defines an escript in mix.exs → builds and runs the escript (fastest)
  - Otherwise → loads the code and calls MainModule.main(argv) or a configured entrypoint

Caching:
  elr caches loaded references in ~/.cache/elr (or $XDG_CACHE_HOME/elr).
  Cache is keyed by reference + Elixir/OTP version.
  Use --no-cache to bypass.

Cache Management:
  elr --cache dir          Show cache directory
  elr --cache list         List cached references
  elr --cache clean        Clean the cache
  elr --cache prune        Remove old cache entries

Environment variables:
  ELR_CACHE_DIR     Custom cache directory
  ELR_NO_COLOR      Disable colored output

Feedback and issues:
  https://github.com/yourusername/elr
```

