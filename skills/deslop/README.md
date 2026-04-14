# Deslop

Clean AI-generated code slop with a regression-safe, deletion-first workflow. Finds and removes structural bloat that passes all linters and tests but should not exist: dead functions, redundant comments, unnecessary abstractions, over-engineered patterns, and more.

## How it works

```
Resolve scope --> Savepoint --> Analyze --> Batch --> Apply-Verify loop --> Linter pass --> Code review --> Report
```

1. Builds the file set from git status, staged changes, a branch diff, or an explicit path
2. Creates a git savepoint so every change can be rolled back
3. Reads all files in scope and applies the 10-category slop taxonomy
4. Groups findings into batches ordered by risk (low-risk first)
5. Applies each batch, then invokes the verifier agent to run tests; reverts on failure
6. Runs `/linter` on all modified files to clean up formatting left by deletions
7. Invokes the code-reviewer agent on the cumulative diff for a final correctness check
8. Generates a structured report (Applied / Skipped / Reverted / Linter Pass / Code Review / Savepoint)

## Quick start

```bash
# Clean modified files (default -- unstaged + staged vs HEAD)
/deslop

# Dry run -- see what would be cleaned without changing anything
/deslop --dry-run

# Clean all files changed on the current branch
/deslop branch

# Clean a specific file or directory
/deslop src/utils.py
/deslop src/api/

# Aggressive mode -- auto-applies all findings including LOW-confidence (<60%)
/deslop --aggressive changed

# Conservative -- only highest-confidence (>90%) findings auto-apply
/deslop --conservative

# Target specific slop categories only
/deslop --category dead-code,redundant-comments

# See what the whole codebase contains (dry run recommended for large scopes)
/deslop --dry-run all
```

## Scope modes

| Scope | What it targets |
|---|---|
| `changed` | Unstaged and staged changes vs HEAD (`git diff --name-only`) — **default when no scope is given** |
| `staged` | Staged changes only (`git diff --cached --name-only`) |
| `branch` | All files changed on the current branch vs its merge base |
| `all` | Entire codebase; respects `.gitignore`; skips vendor directories and lock files |
| `<path>` | Specific file or directory (recursively includes all source files under a directory) |

## Flags

| Flag | Effect |
|---|---|
| `--dry-run` / `--report-only` | Analyze and report findings but make no changes; no savepoint is created |
| `--aggressive` | Auto-apply all findings including LOW confidence (<60%). Maximum cleanup. |
| `--conservative` | Only auto-apply HIGH confidence (>90%) findings. MEDIUM and LOW are report-only. |
| `--category <list>` | Comma-separated list of taxonomy categories to target (default: all) |
| `--no-verify` | Skip regression verification after each batch (dangerous; savepoint still created) |
| `--no-lint` | Skip the linter pass after all batches |
| `--max-retries N` | Max verify retry attempts per failed batch before skipping (default: 2) |
| `help` | Display the quick-reference card and stop |

## What it detects

Deslop applies a 10-category taxonomy. Each finding is assigned a confidence level (HIGH / MEDIUM / LOW) that controls whether it is auto-applied or only reported.

| # | Category | What it finds | Example patterns | Risk |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `dead-code` | Unused functions, unreachable branches, commented-out code blocks | Function defined but never called; `else` after an unconditional `return`; 10 lines commented out with `# OLD` | LOW |
| 2 | `redundant-comments` | Comments that restate what the adjacent code obviously does | `# increment counter` above `counter += 1`; docstring `"""Gets the name. Returns: the name."""` on `get_name()` | LOW |
| 3 | `unnecessary-abstractions` | Helpers called exactly once, wrapper classes with no added behavior | `def _format_name(u)` called in one place; a `ResponseWrapper` whose only method returns `self.data` | MEDIUM |
| 4 | `over-engineering` | Config objects for always-hardcoded values, always-on/off feature flags, single-strategy strategy patterns | `FEATURE_NEW_PARSER = True` with the old path gone; `SortStrategy` protocol with one implementation | MEDIUM |
| 5 | `speculative-generality` | Parameters never called with a non-default value, interfaces with one implementation never injected | `process(data, mode="fast")` where every call site is `process(data)`; `IRepository` with `SqlRepository` as its only impl | MEDIUM |
| 6 | `excessive-error-handling` | Try/catch blocks wrapping code that cannot throw, null checks duplicating upstream validation | `except FileNotFoundError` around a path just confirmed to exist; `if user == null` after an ORM call guaranteed non-null | MEDIUM |
| 7 | `backwards-compat-shims` | Deprecated aliases with no callers, version-check branches for unsupported runtime versions | `def get_user(): return fetch_user()` with zero callers; `if sys.version_info < (3, 8)` in a Python 3.11+ project | MEDIUM |
| 8 | `verbose-patterns` | Correct but unnecessarily verbose forms where idiomatic equivalents exist | `if x == True:` instead of `if x:`; `if condition: return True\nelse: return False` instead of `return condition` | LOW |
| 9 | `unnecessary-type-annotations` | Annotations on obvious literal assignments, redundant generics the compiler can infer | `x: int = 5`; `name: str = "Alice"` | LOW |
| 10 | `import-bloat` | Unused imports | Delegated entirely to `/linter` — not detected by deslop directly | LOW |

> **Confidence thresholds by mode:**
>
> | Confidence | Threshold | Conservative | Normal | Aggressive |
> | :--- | :--- | :--- | :--- | :--- |
> | HIGH | >90% | Auto-apply | Auto-apply | Auto-apply |
> | MEDIUM | 60–90% | Report-only | Auto-apply | Auto-apply |
> | LOW | <60% | Report-only | Report-only | Auto-apply |

**Normal mode** (default) auto-applies HIGH and MEDIUM confidence findings. LOW-confidence findings are reported but not applied. **`--conservative`** restricts auto-apply to HIGH only. **`--aggressive`** auto-applies all findings including LOW confidence.

## Safety mechanisms

### Git savepoint

Before making any changes, deslop creates a rollback anchor:

- If the working tree has uncommitted changes: runs `git stash push -m "deslop-savepoint-<timestamp>"` and records the stash ref.
- If the working tree is clean: records the current HEAD SHA.

The savepoint command (`git stash pop` or `git checkout <sha>`) appears in **every progress message** so you can manually restore at any time without waiting for deslop to finish.

If the savepoint cannot be created (git error, conflicts, not a git repo), deslop halts immediately and does not proceed. The savepoint is non-negotiable.

### Per-batch verification

Findings are grouped into batches (one batch per file by default; multi-file batches for changes that span files). After applying each batch, deslop invokes the verifier agent to run the tests relevant to the modified files. Any test failure counts as FAIL.

### Rollback on failure

If verification fails, deslop reverts the batch with `git checkout -- <files>` and retries with a narrowed set of changes. After exhausting `--max-retries` (default: 2), the batch is skipped entirely and logged as reverted. The rest of the applied changes are preserved — per-batch rollback is surgical, not all-or-nothing.

### Never-delete rules

Deslop will never remove or modify these, regardless of mode:

- **Public/exported API symbols** — exported functions, public class members, symbols in published packages
- **Test files and test helpers** — deslop targets production code only
- **Configuration files** — `.env`, CI/CD files, `Dockerfile`, `docker-compose.*`, `*.config.*`
- **License headers and copyright notices**
- **Security-related code** — authentication, authorization, cryptography, input validation, sanitization, XSS/CSRF protection, secrets handling
- **Code with suppression annotations** — `@preserve`, `eslint-disable`, `noqa`, `nolint`, `type: ignore`, `@ts-ignore`, `@ts-expect-error`, `pragma: no cover`

### Non-git repositories

If deslop is run outside a git repository, it warns you and forces `--dry-run` mode automatically. It will analyze and report findings, but will not apply any changes without a savepoint.

## Dry-run mode

Dry-run analyzes the full scope and produces a report using "would remove" / "would inline" language, but makes no changes and creates no savepoint.

Use dry-run when you want to:

- Preview what deslop would do before committing to changes
- Audit a large codebase (`all` scope) without risk
- Get a report for review before running in normal mode

```bash
# Safe preview of current changes
/deslop --dry-run

# Full codebase audit, no changes
/deslop --dry-run all

# Preview with aggressive thresholds
/deslop --dry-run --aggressive branch
```

The dry-run report header reads `DRY RUN —` and lists findings under "Would Apply" and "Skipped" sections. The Reverted and Savepoint sections are omitted.

## Agent delegation

Deslop delegates to three agents during its workflow:

| Agent | When | Purpose |
| :--- | :--- | :--- |
| **Verifier agent** | After each applied batch | Runs tests relevant to the modified files; returns PASS or FAIL |
| **Code-reviewer agent** | Once after all batches and the linter pass | Reviews the cumulative diff for correctness: broken logic, inlining bugs, silent failure gaps |
| **`/linter` skill** | Once after all batches complete | Cleans up formatting issues left by deletions and inlinings (orphaned blank lines, import order changes) |

Verification can be skipped with `--no-verify` (dangerous — savepoint is still created). The linter pass can be skipped with `--no-lint`.

### Graceful degradation

If any dependency is unavailable, deslop falls back to a lightweight alternative instead of skipping entirely:

| Dependency | Lightweight fallback |
| :--- | :--- |
| **Verifier agent** | Build/compile check via Bash (`go build`, `tsc --noEmit`, `python -m py_compile`, `cargo check`); auto-shifts to `--conservative` |
| **Code-reviewer agent** | Self-review diff scan: checks for dangling references, scope errors in inlined code, removed I/O error handlers |
| **`/linter` skill** | Direct linter invocation via Bash (`ruff check --fix`, `eslint --fix`, `go vet`, `cargo clippy`) |
| **git** | Forces `--dry-run` (analysis-only, no changes) |

Deslop always produces a report, even when running with fallbacks.

## When to use what

| Tool | Use it for |
| :--- | :--- |
| **`/deslop`** | Structural bloat: dead code, redundant comments, unnecessary abstractions, over-engineering, speculative generality, excessive error handling, verbose patterns. Things that pass all linters but should not exist. |
| **`/linter`** | Formatting, import sorting, whitespace, style rule violations. Mechanical issues a linter rule can detect by pattern alone. |
| **`/simplify`** | Code quality improvements: eliminating duplication, improving efficiency, extracting reusable patterns, improving naming. Broader quality pass, not specifically targeting AI-generated patterns. |
| **ralph-loop cleanup** | Lightweight linter pass scoped to a single loop iteration's changes. Escalates to `/deslop --conservative` when triggers fire (>100 lines added, iteration 3+, or `--full-deslop`). |

**Ops integration:** When you use `/ops`, deslop runs automatically after verification and before code review. It uses `--conservative` mode on files modified by executor agents. Use `--no-deslop` on `/ops` to skip it.

**Ralph-loop integration:** Ralph-loop's Cleanup stage normally runs a lightweight linter pass. It escalates to `/deslop --conservative` when triggers fire: >100 lines added in the iteration, iteration 3+, or `--full-deslop` flag. If `/deslop` isn't installed, the lightweight linter pass runs alone.

In practice: run `/deslop` to remove structural slop, then `/linter` to tidy formatting. Deslop already runs `/linter` internally as its final step, so you only need to run it separately if you skipped the linter pass with `--no-lint`.

## Output format

Every message from deslop starts with the **`Deslop`** badge. The final report includes:

- **Header** — summary sentence (e.g., "Cleaned 15 findings across 8 files, 2 reverted")
- **Scope** — which scope mode and how many files were scanned
- **Mode** — normal, dry-run, aggressive, or conservative
- **Findings** — total count with breakdown (applied / skipped / reverted)
- **Applied** — file:line, category, and description for each applied change
- **Skipped** — findings not applied, with reason (security path, low confidence, out-of-scope dependency, never-delete rule)
- **Reverted** — batches that failed verification after all retries, with the test failure reason
- **Linter Pass** — result of the `/linter` run (or "Skipped (--no-lint)")
- **Code Review** — verifier's verdict (APPROVE / APPROVE WITH COMMENTS / REQUEST CHANGES) and any critical findings
- **Savepoint** — the restore command and timestamp (omitted in dry-run)

Empty sections are omitted from the report.

## Examples

### Combining flags

```bash
# Aggressive mode on branch changes, skip linter pass
/deslop --aggressive --no-lint branch

# Conservative dry run on the whole codebase
/deslop --conservative --dry-run all

# Target two categories only, branch scope
/deslop --category dead-code,backwards-compat-shims branch

# Aggressive, specific directory, no verification (fast but risky)
/deslop --aggressive --no-verify src/legacy/
```

### Working with staged changes

```bash
# Clean up only what you've staged for commit
/deslop staged

# Dry run on staged changes before committing
/deslop --dry-run staged

# Conservative pass on staged changes
/deslop --conservative staged
```

### Targeting specific categories

```bash
# Only dead code and redundant comments (lowest-risk categories)
/deslop --category dead-code,redundant-comments

# Only verbose patterns (mechanical, low-risk rewrites)
/deslop --category verbose-patterns

# Skip import bloat (handled by linter) and excessive error handling (highest-risk MEDIUM)
/deslop --category dead-code,redundant-comments,unnecessary-abstractions,over-engineering,speculative-generality,backwards-compat-shims,verbose-patterns,unnecessary-type-annotations
```

### Full codebase scan

```bash
# Dry run first to see what's there
/deslop --dry-run all

# Run for real after reviewing the dry-run report
/deslop all

# Conservative pass on the whole codebase (safest for large repos)
/deslop --conservative all
```
