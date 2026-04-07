# scriptlr — Elixir Script Load & Run

Load and run Elixir scripts (`.exs`) from git repos or direct URLs.  

Pronounced `es-lr`, inspired by [npx](https://docs.npmjs.com/cli/v11/commands/npx), 
built for Elixir. Just point `scriptlr` at a script reference and go.  

## Installation

```bash
> mix escript.install github:andyl/scriptlr          # install
> export PATH="$HOME/.mix/escripts:$PATH"        # update $PATH
> scriptlr --help                                    # verify 
> mix escript.install github:andyl/scriptlr --force  # update
```

## Usage

```bash
scriptlr <reference> [args...]
```
| Src    | Example Command                                                         |
|--------|-------------------------------------------------------------------------|
| GitHub | `scriptlr github:wojtekmach:benchee.exs`                                    |
| URL    | `scriptlr https://raw.githubusercontent.com/user/repo/main/tool.exs --help` |
| Local  | `scriptlr ./my_tool.exs --verbose`                                          |

Many example scripts are at [github:wojtekmach/mix_install_examples](https://github.com/wojtekmach/mix_install_examples).

## Reference Types

| Format                  | Description                        |
|-------------------------|------------------------------------|
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
    --find REF      Find all scripts in a repo
    --no-cache      Disable caching (force fresh load)
    --cache DIR     Cache subcommand (dir, list, clean, prune)
```

## Cache Management

`scriptlr` caches loaded references in `~/.cache/scriptlr` (or `$XDG_CACHE_HOME/scriptlr`),
keyed by reference + Elixir/OTP version.

```bash
scriptlr --cache dir     # Show cache directory
scriptlr --cache list    # List cached references
scriptlr --cache clean   # Remove all cached entries
scriptlr --cache prune   # Remove entries older than 30 days
```

Use `--no-cache` to bypass the cache and force a fresh load.

## How It Works

1. **Parse** the reference string to determine the source type
2. **Resolve** into a `Mix.install` dependency spec or download URL
3. **Load** via `Mix.install/2` (for packages) or HTTP download (for remote scripts)
4. **Detect** the entrypoint — escript config in `mix.exs`, or a module with `main/1`
5. **Execute** with any remaining CLI arguments forwarded as argv

## Environment Variables

| Variable         | Description                                |
|------------------|--------------------------------------------|
| `SCRIPTLR_CACHE_DIR` | Custom cache directory (overrides default) |
| `SCRIPTLR_NO_COLOR`  | Disable colored output                     |

## Development

```bash
mix deps.get          # Fetch dependencies
mix compile           # Compile
mix test              # Run tests
mix escript.build     # Build the escript locally
```

## License

MIT
