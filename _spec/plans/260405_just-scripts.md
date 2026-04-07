# Implementation Plan: Just Scripts

**Spec:** `_spec/features/260405_just-scripts.md`
**Generated:** 2026-04-05

---

## Goal

Narrow `elr` to support only Elixir scripts (`.exs` files and executable
shebanged files with `Mix.install`), removing all escript support. Add
glob-based script discovery within repos, a `--find` option, a YAML-based cache
datastore for usage stats, and `--` argument separation.

## Scope

### In scope
- Remove all escript code paths, tests, and documentation
- Remove Hex package reference support
- Script validation (`.exs` with `Mix.install`, or executable shebang with `Mix.install`)
- Glob pattern matching within GitHub repo references (e.g. `github:user/repo:**/script`)
- `--find` option to discover scripts in remote repos
- YAML datastore (`.script_directory.yml`) tracking per-script usage stats
- CLI argument separation via `--` between `elr` options and script arguments
- Error messages for Hex references and invalid scripts

### Out of scope
- Escript support of any kind
- Hex package references
- Private repository authentication
- Windows-specific path handling

## Architecture & Design Decisions

### Drop escript, keep the pipeline

The pipeline remains **parse → resolve → cache → load → execute**, but every
step is simplified: no more `:escript` variant in tagged tuples, no `mix
escript.build`, no `find_built_escript`. The loader for cloned repos will
search for a valid script instead of building an escript.

### GitHub references gain a path/glob segment

The current `github:user/repo#ref` format is extended to
`github:user/repo:path_or_glob#ref`. The colon-separated third segment is a
file path or glob pattern within the repo. The `Ref` struct gains a `glob` (or
`script_path`) field.

### Script validation as a first-class concept

A new `Scriptlr.Script` module (or function group in an existing module) encapsulates the two validation rules:
1. `.exs` file containing `Mix.install`
2. Executable, no extension, Elixir shebang (`#!/usr/bin/env elixir` or `#!/usr/bin/env mix`), containing `Mix.install`

This validation is used by `--find`, glob resolution, and the loader.

### YAML datastore

A `.script_directory.yml` file in the cache directory. Use `yaml_elixir` for parsing and a simple serializer for writing (or `yamerl`). Updated on install and on each run. One record per script keyed by reference string.

### CLI `--` separation

New usage: `elr [elr_opts] -- <script_ref> [script_args]`. The `--` is required
to disambiguate. For backward compatibility, if no `--` is present and there
are positional args, treat the first positional as the script reference
(current behavior), but `elr` options like `--help` will be consumed by `elr`
in that case.

## Implementation Steps

### Phase 1: Remove escript and Hex support

1. **Remove Hex reference parsing from `Ref`**
   - Files: `lib/elr/ref.ex`
   - Remove `parse_hex/1`, `valid_hex_name?/1`, and the `:hex` fallthrough in `parse/1`
   - Remove `:hex` from the type spec
   - Replace with an error message: `"Hex package references are not supported. Use a GitHub repo or URL instead."`
   - Remove `.escript` from `local_file?/1`

2. **Remove Hex resolution from `Resolver`**
   - Files: `lib/elr/resolver.ex`
   - Remove the `:hex` clause and `hex_repo_url/1`

3. **Remove escript building from `Loader`**
   - Files: `lib/elr/loader.ex`
   - Remove `build_escript/3`, `find_built_escript/1`, `executable?/1`, `find_cached_escript/1`
   - Rewrite `clone_and_build/4` → `clone_and_find_script/4`: clone repo, validate and locate script, cache it
   - Remove `:escript` from the return type spec
   - All paths now return `{:ok, {:script, path}}` or `{:error, reason}`

4. **Remove escript execution from `Runner`**
   - Files: `lib/elr/runner.ex`
   - Remove the `run({:escript, _}, _, _)` clause
   - Simplify: always run via `elixir` interpreter
   - Remove the second `run_command/2` clause (only need the list-args version)

5. **Update CLI help text and docs**
   - Files: `lib/elr/cli.ex`
   - Remove Hex and escript references from `print_help/0`

6. **Remove escript/Hex tests, update remaining tests**
   - Files: `test/elr/ref_test.exs`, `test/elr/resolver_test.exs`, `test/elr/cli_test.exs`
   - Remove Hex package test cases from `ref_test.exs`
   - Remove `.escript` local file test from `ref_test.exs`
   - Remove Hex resolution tests from `resolver_test.exs`
   - Add test for Hex reference error message
   - Update `cli_test.exs` to remove any escript-dependent tests

### Phase 2: Script validation

7. **Add script validation module**
   - Files: `lib/elr/script.ex` (new)
   - `valid?/1` — returns `true` if file is a valid elr script
   - `validate/1` — returns `{:ok, path}` or `{:error, reason}` with actionable message
   - Rules: check extension, read first ~100 lines for `Mix.install`, check shebang for extensionless executables
   - `list_scripts/1` — given a directory, recursively find all valid scripts (used by `--find` and glob)

8. **Integrate script validation into Loader**
   - Files: `lib/elr/loader.ex`
   - After cloning a repo, use `Script.validate/1` or `Script.list_scripts/1` to find the target script
   - For local files, validate before executing
   - For downloaded remote scripts, validate after download

9. **Add script validation tests**
   - Files: `test/elr/script_test.exs` (new)
   - Test `.exs` with `Mix.install` → valid
   - Test `.exs` without `Mix.install` → invalid with error
   - Test executable shebang file with `Mix.install` → valid
   - Test non-executable no-extension file → invalid
   - Test `.md`, `.ex` files → invalid
   - Test `list_scripts/1` with a directory of mixed files

### Phase 3: Glob pattern matching in repo references

10. **Extend `Ref` struct and parsing for glob/path segment**
    - Files: `lib/elr/ref.ex`
    - Add `script_path` field to `%Ref{}` struct
    - Update `parse_github/1`: parse `github:user/repo:path/glob#ref` — split on `:` first, then `#`
    - The `script_path` field holds the glob/path portion (e.g., `**/myscript.exs`)

11. **Implement glob resolution in Loader**
    - Files: `lib/elr/loader.ex`
    - After cloning a repo, if `ref.script_path` contains glob characters (`*`), use `Path.wildcard/1` to find matches
    - Filter matches through `Script.valid?/1`
    - If exactly one match → use it; if zero → error; if multiple → error listing matches
    - If `ref.script_path` is a literal path (no glob), verify it exists and is valid

12. **Add glob pattern tests**
    - Files: `test/elr/ref_test.exs`, `test/elr/loader_test.exs` (new or extend existing)
    - Test parsing `github:user/repo:**/script` → `script_path: "**/script"`
    - Test parsing `github:user/repo:lib/**/script.exs#main` → correct fields
    - Test glob resolution against a temp directory with test scripts

### Phase 4: `--find` option

13. **Add `--find` flag to CLI**
    - Files: `lib/elr/cli.ex`
    - Add `:find` to `@switches` as `:boolean`
    - When `--find` is set: parse the reference, clone the repo, call `Script.list_scripts/1`, print results
    - Format: one script path per line, relative to repo root

14. **Add `--find` tests**
    - Files: `test/elr/cli_test.exs`
    - Test `--find` with a mock or temp directory containing scripts

### Phase 5: YAML cache datastore

15. **Add `yaml_elixir` dependency**
    - Files: `mix.exs`
    - Add `{:yaml_elixir, "~> 2.9"}` to deps (all envs, since it's needed at runtime)

16. **Implement `Scriptlr.Datastore` module**
    - Files: `lib/elr/datastore.ex` (new)
    - Path: `Cache.dir()/.script_directory.yml`
    - `read/0` — load and parse the YAML file, return map of records keyed by reference string
    - `write/1` — serialize and write the map back to YAML
    - `record_install/2` — `(ref_string, metadata)` — add/update record with script name, source, description, deps, install date, run count 0
    - `record_run/1` — `(ref_string)` — update last_execution timestamp and increment run count
    - `get/1` — get a single record by ref string
    - `list/0` — return all records
    - Script description: extract first comment block (lines starting with `#` until first blank line)
    - Script dependencies: parse `Mix.install` call to extract dep names

17. **Integrate datastore into pipeline**
    - Files: `lib/elr/loader.ex`, `lib/elr/runner.ex` (or `lib/elr/cli.ex`)
    - Call `Datastore.record_install/2` after successful script load/cache
    - Call `Datastore.record_run/1` before or after script execution
    - Update `--cache list` to show datastore info if available

18. **Add datastore tests**
    - Files: `test/elr/datastore_test.exs` (new)
    - Test read/write round-trip
    - Test record_install creates entry with correct fields
    - Test record_run increments count and updates timestamp
    - Test description extraction from script comment block
    - Test dependency extraction from `Mix.install` call

### Phase 6: CLI argument separation

1. **Redesign CLI argument parsing with `--` separator**
    - Files: `lib/elr/cli.ex`
    - Usage Spec: `elr [ELR_OPTIONS...] [--] <target_script_reference> [<target_script_args>...]`
    - Split `argv` on `"--"`: everything before is `elr_args`, everything after starts with script ref then script args
    - Parse `elr_args` with `OptionParser` for `--help`, `--version`, `--verbose`, `--no-cache`, `--cache`, `--find`
    - If no `--` found, fall back to current behavior (first positional arg = script ref)
    - Update `print_help/0` to show new usage format

20. **Update CLI tests for `--` separation**
    - Files: `test/elr/cli_test.exs`
    - Test `elr --verbose -- myscript.exs --help` → `--help` passed to script
    - Test `elr -- myscript.exs --version` → `--version` passed to script
    - Test `elr --help` → shows elr help (no `--`)
    - Test backward compat: `elr myscript.exs` still works

### Phase 7: Cleanup

21. **Update module docs and typespecs**
    - Files: all modified modules
    - Remove references to escripts throughout
    - Update `@moduledoc` strings
    - Update `@spec` types (remove `:escript` variants, `:hex` type)

22. **Update `Scriptlr.Resolver` for script-only resolution**
    - Files: `lib/elr/resolver.ex`
    - Simplify return type: only `{:clone, url, git_ref}`, `{:script, url}`, `{:local, path}`
    - Ensure GitHub refs with `script_path` pass it through

## Dependencies & Ordering

- **Phase 1 must come first**: removing escript/Hex support simplifies every subsequent step and avoids modifying code that will be deleted.
- **Phase 2 before Phase 3**: glob resolution depends on script validation to filter matches.
- **Phase 3 before Phase 4**: `--find` uses `list_scripts/1` which is built in Phase 2, and references with globs from Phase 3.
- **Phase 5 (datastore)** can proceed in parallel with Phases 3-4, as it's mostly independent.
- **Phase 6 (CLI redesign)** should come after Phase 4 so that `--find` is already wired up.
- **Phase 7** is cleanup and should be last.

## Edge Cases & Risks

- **Glob matching multiple scripts**: When a glob pattern matches more than one valid script, the tool must error with a clear listing. Users need to refine their pattern.
- **Large repos with `--find`**: Cloning large repos to list scripts could be slow. Shallow clone (`--depth 1`) mitigates this, but repos with many files will still take time. Consider documenting this.
- **YAML file corruption**: If the YAML datastore becomes corrupted (partial write, manual edit error), the tool should handle parse errors gracefully — log a warning and recreate the file rather than crashing.
- **`Mix.install` detection**: Simple string matching (`Mix.install`) may false-positive on comments or string literals. A regex like `~r/^\s*Mix\.install\s*\(/m` (non-commented, at statement level) would be more reliable.
- **Shebang detection**: Need to handle variations: `#!/usr/bin/env elixir`, `#!/usr/bin/env mix run`, `#!/usr/bin/elixir`. Define the accepted set explicitly.
- **Backward compatibility of CLI**: Users accustomed to `elr script.exs --help` (without `--`) will see different behavior. The fallback (treat first positional as script ref when no `--`) preserves this for simple cases.
- **Script description extraction**: Edge case where script has no comments, or comment block has unusual formatting. Return `nil` or empty string gracefully.
- **`yaml_elixir` as runtime dep**: This adds a dependency to the escript build. Verify it works correctly when bundled into the escript via `mix escript.build`.

## Testing Strategy

- **Unit tests** for each module in isolation:
  - `Script` — validation rules, `list_scripts`, description/dep extraction
  - `Ref` — new GitHub parsing with glob, Hex rejection
  - `Datastore` — YAML read/write, record operations
  - `Resolver` — simplified resolution without Hex
- **Integration tests** via `CLI.main/1`:
  - `--find` against a known test repo or temp directory
  - `--` argument separation (verify script receives correct args)
  - Error messages for Hex references, invalid scripts
- **Manual verification**:
  - Run `elr github:andyl/tango:**/somescript` against a real repo
  - Run `elr --find github:andyl/tango` to list scripts
  - Inspect `.script_directory.yml` after installs and runs
  - Verify `elr --verbose -- ./local_script.exs --help` passes `--help` to the script

## Open Questions

- [x] Should the fallback (no `--`) behavior emit a deprecation warning to encourage migration to the new `--` syntax, or silently support both indefinitely?  Answer: no deprecation warning needed
- [x] For glob matches, should the tool interactively prompt the user to pick from multiple matches, or strictly require a unique match?  Answer: require single match
- [x] Should `--find` support local directories in addition to remote repos?  Answer: no 
- [x] What YAML library to use — `yaml_elixir` (most popular, read+write) or another? `yaml_elixir` depends on `yamerl` (Erlang NIF) which should be fine for escript bundling.  Answer: yaml_elixir
- [x] Should the datastore track scripts by reference string or by a normalized key (e.g., cache key)?  Reference string is more human-readable; cache key is more stable across Elixir/OTP version changes.  Answer: by normalized key
- [x] For description extraction: should it be the first `#` comment block, or should we look for a `@moduledoc`-style comment? The spec says "first comment block from the first `#` until the first blank line."  Answer: first comment block (scripts have no moduledoc)
