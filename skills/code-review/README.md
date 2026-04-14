# Code Review

An automated code review skill that analyzes diffs for bugs, security vulnerabilities, performance issues, and code quality problems. Reviews staged changes, commits, commit ranges, or pull requests -- and offers to apply fixes directly.

## How it works

```
Gather diff --> Filter exclusions --> Scope check --> Analyze --> Cross-file impact --> Corroborate --> Classify --> Output --> Offer fixes
```

1. Gathers the diff from the target you specify (staged, commit, PR)
2. Filters out lock files, generated code, vendored deps, and binaries
3. Checks diff size and parallelizes appropriately
4. Analyzes each file for bugs, security, performance, and style issues
5. Checks whether changes in one file break callers in another
6. Re-verifies every finding against the actual diff to eliminate false positives
7. Classifies findings by severity and renders the review with a merge verdict

## Quick start

```bash
# Review staged changes
/code-review staged

# Review the latest commit
/code-review

# Review a specific commit
/code-review abc1234

# Review a commit range
/code-review HEAD~3..HEAD

# Review a pull request by number
/code-review #123

# Review a pull request by URL
/code-review https://github.com/owner/repo/pull/123

# Quick scan -- critical and warning issues only, no narrative
/code-review --quick staged

# Full review -- skip the depth prompt
/code-review --full #42
```

## Review modes

| Mode | What you get | When to use |
|---|---|---|
| **Full review** (`--full`) | Summary checklist, all findings (all severities), cross-file impact, verdict, fix offers | Pre-merge review, thorough audit |
| **Quick scan** (`--quick`) | Critical and Warning findings only, verdict, no checklist or narrative | Fast gate check, CI-like pass |
| **Interactive** (default) | Asks you to choose Full, Quick, or Skip | When you're not sure |

## What it reviews

### Targets

| Argument | What it reviews |
|---|---|
| `staged` | `git diff --cached` |
| `#123` or PR URL | PR diff via `gh pr diff` (includes PR title/description as context) |
| `abc1234` | Single commit via `git show` |
| `HEAD~3..HEAD` | Commit range via `git diff` |
| `main...HEAD` | Branch diff against base |
| *(nothing)* | Staged changes if any; otherwise asks |

### File exclusions

These are automatically excluded from review (listed in a collapsed section at the bottom of the output):

- **Lock files** -- `package-lock.json`, `yarn.lock`, `Cargo.lock`, `go.sum`, `*.lock`, etc.
- **Auto-generated code** -- files with `@generated`, `DO NOT EDIT`, `// Code generated` in the first 5 lines
- **Vendored dependencies** -- `vendor/`, `node_modules/`, `third_party/`, `external/`
- **Binary files** -- images, fonts, compiled artifacts
- **Minified bundles** -- `*.min.js`, `*.min.css`, `*.bundle.js`
- **IDE config** -- `.idea/`, `.vscode/settings.json`, `*.swp`

Use `--no-exclude` to review everything.

### Diff size guardrails

| Diff size | Behavior |
|---|---|
| < 5 files | Single-pass analysis |
| 5-30 files | Up to 4 parallel analysis groups |
| 31-80 files | Warning + up to 6 parallel groups, logic files prioritized |
| 81+ files | Strong warning + options: best-effort / filter by pattern / abort |

## Severity tiers

Every finding is classified into one of four tiers:

| Tier | Label | Meaning | Blocks merge? |
|---|---|---|---|
| :red_circle: | **Critical** | Bugs, security vulnerabilities, data loss risks | Yes |
| :orange_circle: | **Warning** | Performance bottlenecks, error handling gaps, fragile logic | Depends |
| :yellow_circle: | **Suggestion** | Readability, naming, structure, minor optimizations | No |
| :large_blue_circle: | **Info** | Alternative approaches, knowledge sharing, style notes | No |

## Merge verdict

Every review ends with a structured verdict:

| Verdict | When it applies |
|---|---|
| **APPROVE** | Zero Critical, zero Warning findings |
| **APPROVE WITH COMMENTS** | Zero Critical, but Warnings exist that are low-risk or have straightforward fixes |
| **REQUEST CHANGES** | Any Critical findings, or multiple Warnings representing significant risk |

The verdict is mechanical -- determined by the classified findings, not subjective judgment. If a Warning could cause a production incident, it escalates to REQUEST CHANGES.

## Cross-file impact analysis

After per-file analysis, the review checks whether changes in one file break or affect other files:

- **Renamed/removed exports** -- greps for callers outside the changed file
- **Changed function signatures** -- checks all call sites for parameter mismatches
- **Interface/contract changes** -- checks implementations of modified interfaces or traits
- **Shared state changes** -- flags consumers of renamed config keys, env vars, API endpoints
- **Import path changes** -- verifies imports were updated after file moves

Cross-file findings are classified as Critical (build/runtime failure) or Warning (subtle behavioral change).

## Applying fixes

After the review, you're offered a multi-select menu:

```
Select which fixes to apply:
- Apply all fixes
- Critical -- apply all critical fixes
- Warning -- apply all warning fixes
- Suggestion -- apply all suggestion fixes
- Skip -- don't apply any
```

Only tiers with concrete code suggestions are shown. Info findings and prose-only recommendations are never auto-applied. Fixes are applied in reverse line-number order within each file to avoid offset drift.

## Analysis priorities

The review evaluates issues in this order:

1. **Security** -- Injection, hardcoded secrets, auth bypass, insecure deserialization, exposed endpoints
2. **Correctness** -- Off-by-one, null access, race conditions, type coercion, logic inversions
3. **Error handling** -- Empty catch blocks, bare except, missing cleanup, unvalidated inputs
4. **Performance** -- N+1 queries, missing indexes, allocations in loops, blocking in async, missing await
5. **Maintainability** -- Dead code, magic numbers, complexity, naming, duplication
6. **Testing** -- Missing coverage, brittle tests, untested edge cases

## Language-specific checks

The review applies targeted checks based on the languages in the diff:

| Language | Key checks |
|---|---|
| **Python** | Mutable default args, bare `except:`, wildcard imports |
| **JavaScript/TypeScript** | `==` vs `===`, unhandled promises, `var` usage, excessive `any` |
| **Go** | Unchecked errors, goroutine leaks, defer in loops, map race conditions |
| **Rust** | `.unwrap()` in non-test code, `unsafe` without comments, clone in hot paths |
| **Java/Kotlin** | Swallowed exceptions, `==` on objects, resource leaks, `!!` assertions |
| **C#/.NET** | `async void`, missing `using` on `IDisposable`, null-conditional gaps |
| **C/C++** | Buffer overflows, use-after-free, memory leaks, missing virtual destructors |
| **Ruby** | Monkey-patching, `rescue Exception`, N+1 in ActiveRecord, mutable defaults |
| **SQL** | Dynamic SQL concatenation, missing transactions, undocumented `NOLOCK` |
| **PowerShell** | `Write-Host` misuse, missing `-ErrorAction`, parameter validation |
| **Dart/Flutter** | `print()` in production, undisposed controllers, `setState` after dispose |
| **Bash/Shell** | Unquoted variables, missing `set -euo pipefail`, `eval` with user input |

## Code smells

Flagged automatically: long methods (>40 lines), deep nesting (>3 levels), magic numbers, god classes, feature envy, shotgun surgery, dead code, and copy-paste duplication.

## Corroboration

Every finding goes through a second-pass verification before it reaches the output. The corroboration step independently re-checks each finding against the actual diff and classifies it as:

- **Valid** -- kept as-is
- **False positive** -- dropped silently
- **Needs refinement** -- updated with corrected details

This also catches **missed issues** that the initial analysis didn't flag. For 5+ findings, corroboration runs in parallel groups.

## Contextual awareness

The review reads surrounding code before flagging issues. A pattern that looks wrong in isolation may be consistent with the codebase. Specifically:

- Considers the commit message for intent
- Favors project conventions and language idioms over personal preference
- Notes incremental work without penalizing it
- Consistency with the codebase takes priority

## Output format

Every message starts with the **`Code Review`** badge. A full review includes:

1. **Summary Checklist** -- correctness, security, performance, error handling, readability, testing, dependencies
2. **Detailed Findings** -- grouped by file, each with severity, explanation, current/suggested code
3. **Cross-File Impact** -- only if cross-file issues were found
4. **Verdict** -- APPROVE / APPROVE WITH COMMENTS / REQUEST CHANGES
5. **Excluded files** -- collapsed list of filtered files

Quick scan mode outputs only Critical/Warning findings and the verdict.

## Flags reference

| Flag | Effect |
|---|---|
| `--full` | Full review, skip the depth prompt |
| `--quick` | Critical + Warning only, no narrative |
| `--no-exclude` | Review all files including lock files, generated code, etc. |
| `staged` | Review staged changes |

## Examples

### Reviewing staged changes

```bash
# Review what's staged, interactive mode (asks Full/Quick/Skip)
/code-review staged

# Full review of staged changes, skip the prompt
/code-review --full staged

# Quick scan of staged changes -- Critical and Warning only
/code-review --quick staged
```

### Reviewing commits

```bash
# Review the latest commit (default when no target given)
/code-review

# Review a specific commit by hash
/code-review abc1234

# Review the last 3 commits
/code-review HEAD~3..HEAD

# Review the last 5 commits, full depth
/code-review --full HEAD~5..HEAD

# Review everything since a specific tag
/code-review v2.1.0..HEAD
```

### Reviewing pull requests

```bash
# Review PR by number
/code-review #123

# Quick scan a PR -- fast gate check
/code-review --quick #87

# Full review of a PR by number
/code-review --full #42

# Review PR by full GitHub URL
/code-review https://github.com/owner/repo/pull/123

# Full review of a PR by URL
/code-review --full https://github.com/owner/repo/pull/456
```

### Reviewing branch diffs

```bash
# Review current branch against main
/code-review main...HEAD

# Review current branch against develop
/code-review develop...HEAD

# Full review of branch diff, include generated code
/code-review --full --no-exclude main...HEAD

# Quick scan of branch diff
/code-review --quick main...HEAD
```

### Controlling exclusions

```bash
# Default behavior -- lock files, generated code, etc. are excluded
/code-review --full staged

# Include everything -- lock files, generated code, vendored deps, binaries
/code-review --full --no-exclude staged

# Useful when you specifically want to review generated code changes
/code-review --no-exclude #123
```

### Combining flags

```bash
# Full review of staged changes
/code-review --full staged

# Quick scan of a commit range
/code-review --quick HEAD~10..HEAD

# Full review of a PR, include all files
/code-review --full --no-exclude #42

# Quick scan of branch diff against main
/code-review --quick main...HEAD

# Full review of everything since last release, no exclusions
/code-review --full --no-exclude v3.0.0..HEAD
```
