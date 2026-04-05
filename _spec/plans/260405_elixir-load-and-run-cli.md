# Implementation Plan: Elixir Load and Run CLI

**Spec:** `_spec/features/260405_elixir-load-and-run-cli.md`
**Generated:** 2026-04-05

---

## Goal

Build `elr`, an escript CLI that parses reference strings (Hex packages, GitHub
repos, git URLs, remote `.exs` URLs, local files), fetches dependencies via
`Mix.install/2`, detects entrypoints, and executes them — with caching for fast
repeated runs.

## Scope

### In scope
- CLI argument parsing and option handling (`--help`, `--version`, `--verbose`, `--no-cache`, `--cache`)
- Reference parsing for all five reference types (Hex, GitHub, git URL, remote `.exs`, local file)
- Dependency loading via `Mix.install/2`
- Entrypoint detection (escript definition in `mix.exs`, or `main/1` convention)
- Filesystem caching keyed by reference + Elixir/OTP version
- Cache management subcommands (dir, list, clean, prune)
- Escript build configuration
- Environment variable support (`ELR_CACHE_DIR`, `ELR_NO_COLOR`)

### Out of scope
- Publishing to Hex
- Mix task interface
- Windows-specific path handling
- Private repo authentication

## Architecture & Design Decisions

### Module structure

Organize around a pipeline: **parse → resolve → cache check → load → detect entrypoint → execute**.

- `Elr.CLI` — escript entrypoint, argument parsing, option handling
- `Elr.Ref` — reference string parsing into a structured type (`%Elr.Ref{}`)
- `Elr.Resolver` — resolves a parsed ref into a `Mix.install` dependency spec or a downloadable script URL
- `Elr.Cache` — cache directory management, lookup, storage, pruning
- `Elr.Loader` — calls `Mix.install/2` or downloads scripts, using cache when available
- `Elr.Runner` — entrypoint detection and execution
- `Elr.Output` — user-facing output (respects `--verbose` and `ELR_NO_COLOR`)

### Mix.install constraints

`Mix.install/2` can only be called once per BEAM VM and cannot be called from within an active Mix project. Since `elr` is distributed as an escript (a standalone compiled binary), it runs outside of any Mix project context — so `Mix.install/2` can be called directly from the escript's BEAM process. This is the intended usage path.

However, `Mix.install/2` caches internally to `~/.cache/mix/installs/` by default. We will layer our own cache on top to handle:
- Escript builds (which `Mix.install` doesn't cache)
- Script downloads (which bypass `Mix.install` entirely)
- Cache management subcommands

For Hex/git references, we call `Mix.install/2` with the `force: true` option when `--no-cache` is set, and otherwise rely on its built-in caching plus our metadata layer.

### Entrypoint detection strategy

1. Check if the resolved package defines `escript: [main_module: ...]` in its `mix.exs` — if so, build the escript and run it.
2. Otherwise, look for a module with a `main/1` function in the loaded code.
3. For `.exs` scripts (remote or local), simply `Code.eval_file/1` the script.

### Reference type detection (parse order)

Apply rules in this order to the first CLI argument:
1. Starts with `./` or `/` or ends with `.exs` / `.escript` → **local file**
2. Starts with `https://` and ends with `.exs` → **remote script**
3. Starts with `https://` or `http://` → error (non-`.exs` URLs not supported)
4. Starts with `github:` → **GitHub shorthand**
5. Starts with `git+` → **git URL**
6. Everything else → **Hex package** (with optional `@version` suffix)

## Implementation Steps

1. **Configure escript build in `mix.exs`**
   - Files: `mix.exs`
   - Add `escript: [main_module: Elr.CLI]` to the project config
   - Add any needed runtime dependencies (e.g. `req` for HTTP fetching of remote scripts)

2. **Define the `Elr.Ref` struct and parser**
   - Files: `lib/elr/ref.ex`
   - Define `%Elr.Ref{type, name, version, url, path, git_ref}` struct
   - Implement `Elr.Ref.parse/1` that takes a reference string and returns `{:ok, %Elr.Ref{}}` or `{:error, reason}`
   - Follow the parse-order rules above
   - Handle version extraction from `package@version` syntax
   - Handle `#ref` extraction from GitHub and git URLs

3. **Write tests for reference parsing**
   - Files: `test/elr/ref_test.exs`
   - Cover all five reference types with valid and invalid inputs
   - Test edge cases: missing version, malformed GitHub shorthand, relative vs absolute paths

4. **Implement `Elr.Cache` module**
   - Files: `lib/elr/cache.ex`
   - Implement cache directory resolution: `$ELR_CACHE_DIR` > `$XDG_CACHE_HOME/elr` > `~/.cache/elr`
   - Implement `cache_key/1` that generates a deterministic key from ref + Elixir version + OTP version
   - Implement `lookup/1`, `store/2`, `delete/1`, `list/0`, `prune/1`
   - Store metadata (timestamp, ref string, versions) alongside cached artifacts

5. **Write tests for cache module**
   - Files: `test/elr/cache_test.exs`
   - Test directory resolution with different env var combinations
   - Test cache key generation determinism
   - Test store/lookup/delete/list/prune lifecycle
   - Use a temporary directory for test isolation

6. **Implement `Elr.Resolver` module**
   - Files: `lib/elr/resolver.ex`
   - Convert `%Elr.Ref{type: :hex}` → `Mix.install` dependency tuple `{:package, "~> version"}`
   - Convert `%Elr.Ref{type: :github}` → `{:package, github: "user/repo", ref: "ref"}`
   - Convert `%Elr.Ref{type: :git}` → `{:package, git: "url", ref: "ref"}`
   - For `:remote_script`, return the URL to download
   - For `:local`, return the validated file path

7. **Write tests for resolver**
   - Files: `test/elr/resolver_test.exs`
   - Test each reference type produces the correct dependency spec or path

8. **Implement `Elr.Loader` module**
   - Files: `lib/elr/loader.ex`
   - For Hex/git refs: check cache, then call `Mix.install/2` with the resolved dep spec
   - For remote scripts: download via HTTP to cache dir, then return path
   - For local files: validate existence, return path
   - Respect `--no-cache` flag (pass `force: true` to `Mix.install`, skip cache lookup)
   - Log steps when `--verbose` is set

9. **Implement `Elr.Runner` module**
   - Files: `lib/elr/runner.ex`
   - For loaded Hex/git packages: inspect loaded applications for escript config; if found, build and run escript; otherwise find a module with `main/1` and call it with argv
   - For `.exs` scripts (remote or local): use `Code.eval_file/1`
   - Forward all post-reference CLI arguments as argv

10. **Implement `Elr.Output` module**
    - Files: `lib/elr/output.ex`
    - Provide `info/1`, `error/1`, `verbose/1` functions
    - Check `ELR_NO_COLOR` env var to conditionally disable ANSI colors
    - `verbose/1` only prints when verbose mode is active

11. **Implement `Elr.CLI` — the escript entrypoint**
    - Files: `lib/elr/cli.ex`
    - Implement `main/1` that receives argv
    - Parse options with `OptionParser`: `--help`, `--version`, `--verbose`, `--no-cache`, `--cache`
    - Route `--help` → print help text and exit
    - Route `--version` → print version and exit
    - Route `--cache <subcommand>` → delegate to `Elr.Cache` management functions
    - Otherwise: parse ref → resolve → load → run, with error handling at each stage

12. **Write integration tests**
    - Files: `test/elr/cli_test.exs`
    - Test `--help` and `--version` output
    - Test `--cache dir` prints a path
    - Test running a local `.exs` script end-to-end
    - Test error handling for invalid references

13. **Update the top-level `Elr` module**
    - Files: `lib/elr.ex`
    - Replace the scaffold with version info and any top-level API if needed
    - Add `@version` attribute read from `mix.exs` or hardcoded

14. **Build and manually verify the escript**
    - Run `mix escript.build` and test the binary with sample references
    - Verify `elr --help`, `elr --version`, `elr ./test_script.exs`

## Dependencies & Ordering

- **Step 1** (mix.exs config) must come first — everything depends on the project being buildable as an escript.
- **Steps 2-3** (Ref parsing) have no dependencies beyond step 1 and form the foundation for all later steps.
- **Steps 4-5** (Cache) can be built in parallel with steps 2-3 since they're independent.
- **Step 6-7** (Resolver) depends on step 2 (uses `%Elr.Ref{}`).
- **Step 8** (Loader) depends on steps 4 and 6 (uses Cache and Resolver).
- **Step 9** (Runner) depends on step 8 (receives loaded code/paths from Loader).
- **Step 10** (Output) has no code dependencies and can be built at any point, but is used by steps 8, 9, and 11.
- **Step 11** (CLI) depends on all prior modules — it's the orchestration layer.
- **Steps 12-14** (integration tests and verification) come last.

Suggested parallel tracks:
- Track A: Steps 2 → 3 → 6 → 7 → 8 → 9
- Track B: Steps 4 → 5 (merge into Track A at step 8)
- Track C: Step 10 (merge at step 11)

## Edge Cases & Risks

- **`Mix.install` called from within a Mix project**: If a user runs `elr` from within a Mix project directory during development (not as an installed escript), `Mix.install` will fail. The escript distribution avoids this, but tests need to handle it — tests should either mock `Mix.install` or run in an isolated environment.
- **Package name ambiguity**: A bare argument like `benchee` could theoretically be a local file name. The parse order (local files require `./` or `/` prefix or `.exs`/`.escript` extension) disambiguates this, but the error message should be helpful if a user means a local file but forgets the prefix.
- **Network failures**: HTTP fetches for remote scripts and `Mix.install` for packages can fail. Each must produce a clear error message and clean up partial cache state.
- **Escript entrypoint detection**: Not all Hex packages define an escript. Detecting `main/1` across loaded modules could find multiple candidates. Strategy: prefer the module matching the package name, then fall back to the first module with `main/1`, then error with a clear message.
- **Version conflicts**: `Mix.install` handles version resolution, but cryptic error messages from it should be caught and re-presented clearly.
- **Large downloads / slow networks**: The `--verbose` flag should show progress. Consider a timeout for HTTP requests.
- **Cache corruption**: If a cached entry is corrupted (partial download, interrupted build), `elr` should detect this and re-fetch rather than crash.

## Testing Strategy

- **Unit tests** for `Elr.Ref.parse/1` — pure function, extensive input coverage.
- **Unit tests** for `Elr.Cache` — use `tmp` dirs for isolation, test full CRUD lifecycle.
- **Unit tests** for `Elr.Resolver` — pure mapping from ref structs to dep specs.
- **Integration tests** for `Elr.CLI` — invoke `main/1` with various argv, assert output and exit codes.
- **End-to-end test** with a local `.exs` script — create a temp script, run it through `elr`, verify output.
- **Manual testing** with real Hex packages and GitHub repos after escript build.

Run all tests with `mix test`. Use `mix test --only integration` tag to separate slow network-dependent tests.

## Open Questions

- [x] Should `elr` support running `.ex` files (compiled modules) in addition to `.exs` scripts?  Answer: no - just scripts.  If the script doesn't have a .exs extention, it should be executable and have a 'shebang' ("#!/usr/bin/env elixir")
- [x] For Hex packages without an escript or obvious `main/1`, should `elr` drop into an IEx shell with the package loaded?  Answer: if the reference is a package without an escript, raise an error.
- [x] Should there be a config file (`~/.config/elr/config.exs`) for setting defaults like verbosity or custom registries? Answer: not for now
- [x] What HTTP client should be used for remote script downloads? `req` is a natural fit but adds a dependency to the escript. Alternatively, use Erlang's built-in `:httpc`. Answer: what ever makes the code simpler.  In any case, wrapper the HTTP client in a module to make it easier to switch in the future.
- [x] Should `elr` support running `mix` tasks from fetched packages (e.g. `elr benchee.run`)?  Answer: not now.  Just scripts and escripts.
