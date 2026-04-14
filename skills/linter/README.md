# Linter

Automatically lint modified files using each file type's project tooling, apply safe fixes, and report what remains. Discovers linters from your repo's config files -- no setup required.

## How it works

```
Build file set --> Discover tooling --> Group & parallelize --> Lint & fix --> Cache --> Report
```

1. Builds the file set from git status, staged changes, or explicit paths
2. Auto-discovers which linters your project uses from config files
3. Groups files by linter and runs them in parallel (up to 4 groups)
4. Applies safe auto-fixes, asks before risky ones
5. Updates incremental cache if enabled
6. Reports results with a pass/fail verdict

## Quick start

```bash
# Lint modified files (unstaged + staged)
/linter

# Lint staged changes only
/linter staged

# Lint a specific directory
/linter src/api/

# Lint specific files
/linter src/utils.py src/models.py

# Check only -- report issues but don't fix anything
/linter --no-fix

# Quick gate check -- errors only
/linter --severity error staged
```

## Flags

| Flag | Effect |
|---|---|
| `--no-fix` | Check-only mode -- report findings but don't apply any fixes |
| `--only <types>` | Restrict to specific languages: `--only py,ts,js` |
| `--severity <level>` | Filter output: `error`, `warning`, or `info` (default: all) |
| `--changed-lines-only` | Only report issues on lines you actually changed |
| `--incremental` | Skip files that were clean on the last run (cache-based) |
| `--no-cache` | Force full re-lint, clear incremental cache |
| `staged` | Lint staged changes only (`git diff --cached`) |

## Supported languages

The linter auto-discovers tooling from your repo's config files:

| Language | Detected from | Tools used |
|---|---|---|
| **JavaScript/TypeScript** | `eslint.config.*`, `.eslintrc*`, `package.json` | `eslint`, `npm run lint` |
| **Python** | `pyproject.toml`, `ruff.toml` | `ruff check`, `flake8` |
| **Go** | `golangci-lint` config, `go.mod` | `golangci-lint run`, `go vet` |
| **Rust** | `Cargo.toml`, `clippy.toml`, `rustfmt.toml` | `cargo clippy`, `cargo fmt` |
| **C/C++** | `.clang-tidy`, `.clang-format` | `clang-tidy`, `clang-format` |
| **Java/Kotlin** | `build.gradle*`, `pom.xml`, `checkstyle.xml` | Gradle/Maven plugins, `ktlint` |
| **C#** | `*.csproj`, `*.sln`, `.editorconfig` | `dotnet format`, Roslyn analyzers |
| **Ruby** | `.rubocop.yml` | `rubocop` |
| **Dart** | `pubspec.yaml`, `analysis_options.yaml` | `dart analyze`, `dart format` |
| **SQL** | `.sqlfluff`, `pyproject.toml` | `sqlfluff lint`, `sqlfluff fix` |
| **PowerShell** | `PSScriptAnalyzerSettings.psd1` | `Invoke-ScriptAnalyzer` |
| **Shell** | `.shellcheckrc` | `shellcheck` |

Discovery priority: (1) explicit project script (e.g., `npm run lint`), (2) standard CLI for the config found, (3) editor diagnostics.

> **Permissions:** Each tool the linter invokes needs a `Bash(...)` allow entry in `settings.json`. Common ones: `Bash(ruff *)`, `Bash(eslint *)`, `Bash(flake8 *)`, `Bash(shellcheck *)`, `Bash(black *)`. If a tool is not in the allow list, you'll be prompted for approval on each invocation.

## Safe fixes vs user confirmation

Not all fixes are created equal. The linter draws a clear line:

**Auto-applied (no ask):**
- Formatting (indentation, whitespace, line length)
- Import sorting
- Unused import removal
- Trailing commas, semicolons (per project style)
- Trivial auto-fixable rule violations

**Requires your approval:**
- Possible behavior changes
- Type changes (wider, narrower, generics)
- Logic rewrites
- Lint suppressions (`// eslint-disable`, `# noqa`)
- Aggressive auto-fixes with ambiguous intent

When approval is needed, you get a short summary of the proposed change and can approve or reject.

## Pass/fail verdict

Every lint run starts with a one-liner at the top:

```
**PASS**
```
or
```
**FAIL (2 error(s), 5 warning(s))**
```

- **PASS**: Zero remaining issues after fixes (at the filtered severity level if `--severity` is active)
- **FAIL**: One or more remaining issues, with counts by severity

This makes the linter usable as a gate check -- glance at the first line and move on.

## File-type filtering

Restrict linting to specific languages when you only care about part of the codebase:

```bash
# Only Python files
/linter --only py

# Only TypeScript and JavaScript
/linter --only ts,js

# Only Go and Rust in a specific directory
/linter --only go,rs src/

# Only C# staged changes
/linter --only cs staged
```

Accepted type names: `py`, `ts`, `js`, `go`, `rs`, `c`, `cpp`, `java`, `kt`, `rb`, `sh`, `dart`, `sql`, `ps1`, `cs`.

Files not matching the filter are silently excluded (not shown in Skipped).

## Severity filtering

Control how much noise you see:

```bash
# Errors only -- ignore warnings and info
/linter --severity error

# Errors and warnings -- skip info-level findings
/linter --severity warning

# Everything (default)
/linter --severity info
```

The filter affects **output only** -- linters still run at full sensitivity so auto-fixes catch everything. A file with only warning-level findings will still get auto-fixed even if you pass `--severity error`.

## Diff-aware mode

When editing a function in a legacy file full of pre-existing violations, you don't want to see 50 unrelated warnings. Diff-aware mode solves this:

```bash
# Only report issues on lines you actually changed
/linter --changed-lines-only

# Combine with staged
/linter --changed-lines-only staged
```

How it works: the linter runs on the full file (most linters don't support line-range filtering), then the skill cross-references each finding against the git diff. Findings on unchanged lines are silently suppressed. Auto-fixes still apply to changed lines.

## Incremental caching

For large codebases, skip files that haven't changed since they were last lint-clean:

```bash
# Enable caching -- skip known-clean files
/linter --incremental

# Force full re-lint, clear cache
/linter --no-cache
```

How it works:
- Before linting, each file's content hash is checked against `<workspace>/.claude/cache/linter/manifest.json`
- If the hash matches a cached clean entry AND the linter config hasn't changed, the file is skipped
- After linting, files that came back clean get cache entries written
- When linter config changes (detected by config hash), all cache entries for that linter are invalidated

The cache is project-local and has no effect on CI or other developers.

## Deferred tooling and install offers

When a linter is needed but not installed, it shows up as "deferred" in the output. If the install command is known, the skill offers to install it:

```
### Deferred tooling

#### Python (ruff)

- **Files:** src/utils.py, src/models.py
- **Why deferred:** ruff not found on PATH
- **Install command:** `pip install ruff`
- **Options:**
  - Install now (runs `pip install ruff` with your confirmation)
  - Skip for this run
```

If you approve, the tool is installed and those files are linted immediately. Only the tool is installed -- no project config files are created.

Known install commands: `pip install ruff`, `npm install -D eslint`, `gem install rubocop`, `dotnet tool install dotnet-format`, `dart pub get`, `pip install sqlfluff`, `Install-Module PSScriptAnalyzer`, and others.

In non-interactive contexts (e.g., called from Ralph Loop's Cleanup stage), the install offer is skipped.

## Monorepo support

The linter splits at config boundaries. If your repo has:

```
frontend/.eslintrc.json
backend/.eslintrc.json
```

Each gets its own linter invocation with the correct working directory and config. This happens automatically -- no flags needed.

## Output format

Every message starts with the **`Linter`** badge. The final report includes:

1. **Pass/fail** -- bold one-liner at the top
2. **Lint run summary** -- scope, tooling, result, mode, filter
3. **Files touched** -- what was auto-fixed, manually fixed, or clean
4. **Skipped** -- excluded files and reasons
5. **Remaining issues** -- file:line, severity, rule ID, description
6. **Deferred tooling** -- tools not installed, with install offers

Empty sections are omitted entirely.

## Examples

### Basic usage

```bash
# Lint all modified files
/linter

# Lint staged changes
/linter staged

# Lint a specific directory
/linter src/components/

# Lint specific files
/linter src/api/routes.ts src/api/middleware.ts

# Check only -- no fixes applied
/linter --no-fix
```

### Filtering by language

```bash
# Only Python
/linter --only py

# Only TypeScript and JavaScript
/linter --only ts,js

# Only Dart files in lib/
/linter --only dart lib/

# Only C# staged changes
/linter --only cs staged

# Only SQL files, check-only
/linter --only sql --no-fix
```

### Filtering by severity

```bash
# Errors only -- cleanest output
/linter --severity error

# Errors and warnings
/linter --severity warning

# Errors only on staged changes
/linter --severity error staged

# Quick gate check: errors only, Python only
/linter --severity error --only py
```

### Diff-aware mode

```bash
# Only issues on lines you changed
/linter --changed-lines-only

# Changed lines in staged changes
/linter --changed-lines-only staged

# Changed lines, errors only
/linter --changed-lines-only --severity error

# Changed lines in a specific directory
/linter --changed-lines-only src/api/
```

### Incremental caching

```bash
# Skip known-clean files
/linter --incremental

# Incremental + staged
/linter --incremental staged

# Force full re-lint, clear cache
/linter --no-cache

# Incremental with type filter
/linter --incremental --only py,ts
```

### Combining flags

```bash
# Full combo: Python only, errors only, changed lines, incremental
/linter --only py --severity error --changed-lines-only --incremental

# Quick pre-commit check: staged, errors only
/linter --severity error staged

# Thorough check: all types, all severities, no cache
/linter --no-cache

# Check-only gate: staged changes, errors only, no fixes
/linter --no-fix --severity error staged

# Focused review: TypeScript in src/, changed lines only
/linter --only ts --changed-lines-only src/

# CI-style: incremental, errors only, staged
/linter --incremental --severity error staged
```
