# elr — Elixir Load & Run

Load and run Elixir scripts (`.exs`) and escripts from Hex packages,
git repos, or direct URLs.  

Pronounced `e-lr`, inspired by [npx](https://docs.npmjs.com/cli/v11/commands/npx), 
built for Elixir. Just point `elr` at a reference and go.  

## Installation

```bash
> mix escript.install github:andyl/elr      # install
> export PATH="$HOME/.mix/escripts:$PATH"   # update $PATH
> elr --help                                # verify 
> mix escript.install hex elr --force       # update 
```

## Usage

```bash
elr <reference> [args...]
```
| Src    | Type    | Example Command                                                        |
|--------|---------|------------------------------------------------------------------------|
| Hex    | Escript | `elr benchee`                                                          |
| Hex    | Escript | `elr req@0.5.0 get https://httpbin.org/json`                           |
| GitHub | Escript | `elr github:livebook-dev/livebook`                                     |
| GitHub | Script  | `elr github:wojtekmach/mix_install_examples#main`                      |
| URL    | Script  | `elr https://raw.githubusercontent.com/user/repo/main/tool.exs --help` |
| Local  | Script  | `elr ./my_tool.exs --verbose`                                          |

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
