# elr — Elixir Load & Run

Quickly load and run Elixir scripts (`.exs`) and escripts from Hex packages,
git repos, or direct URLs.  Just point `elr` at a reference and go.

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
# now
mix escript.install github:andyl/elr

# future
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

### Updating

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

| Format                  | Description                        |
|-------------------------|------------------------------------|
| `package_name`          | Hex package (latest version)       |
| `package_name@version`  | Hex package (specific version)     |
| `github:user/repo`      | GitHub repository (default branch) |
| `github:user/repo#ref`  | GitHub repository (specific ref)   |
| `git+https://url`       | Git repository                     |
| `git+https://url#ref`   | Git repository (specific ref)      |
| `https://url/file.exs`  | Remote `.exs` script               |
| `./path/to/script.exs`  | Local `.exs` script                |
| `/path/to/file.escript` | Local escript                      |

## Options

```
-h, --help          Show help
-v, --version       Show version
-V, --verbose       Show detailed loading steps
    --no-cache      Disable caching (force fresh load)
    --cache DIR     Cache subcommand (dir, list, clean, prune)
```

## Cache Management

`elr` caches loaded references in `~/.cache/elr` (or `$XDG_CACHE_HOME/elr`),
keyed by reference + Elixir/OTP version.

```bash
elr --cache dir     # Show cache directory
elr --cache list    # List cached references
elr --cache clean   # Remove all cached entries
elr --cache prune   # Remove entries older than 30 days
```

Use `--no-cache` to bypass the cache and force a fresh load.

## How It Works

1. **Parse** the reference string to determine the source type
2. **Resolve** into a `Mix.install` dependency spec or download URL
3. **Load** via `Mix.install/2` (for packages) or HTTP download (for remote scripts)
4. **Detect** the entrypoint — escript config in `mix.exs`, or a module with `main/1`
5. **Execute** with any remaining CLI arguments forwarded as argv

## Environment Variables

| Variable        | Description                                |
|-----------------|--------------------------------------------|
| `ELR_CACHE_DIR` | Custom cache directory (overrides default) |
| `ELR_NO_COLOR`  | Disable colored output                     |

## Development

```bash
mix deps.get          # Fetch dependencies
mix compile           # Compile
mix test              # Run tests
mix escript.build     # Build the escript locally
```

## License

MIT
