Lint modified or requested source files using each file type's project tooling; apply safe auto-fixes and fix remaining issues unless disabled. Arguments: $ARGUMENTS

Parse the arguments as follows:

- If `--no-fix` is present, run linters in **check-only** mode (no `eslint --fix`, `ruff check --fix`, etc., and do not apply manual code edits to satisfy rules). Still report findings using the output template.
- If `staged` is present, build the file set from `git diff --cached --name-only` (and `git diff --cached --name-only --diff-filter=ACMR` if you need to exclude deletes). Otherwise, prefer `git diff --name-only` against the default base, or `git status --short`, depending on what the user means by "modified"; if unclear, prefer unstaged + staged names under the repo.
- If `--only <types>` is present, restrict the file set to the specified file types only. Accepts a comma-separated list of language names or extensions: `py`, `ts`, `js`, `go`, `rs`, `c`, `cpp`, `java`, `kt`, `rb`, `sh`, `dart`, `sql`, `ps1`, `cs`. E.g., `--only py,ts` lints only Python and TypeScript files. Files not matching the filter are silently excluded (not shown in Skipped). If a type has no linter discovered, it falls into Deferred as usual.
- If `--severity <level>` is present, filter the **output** to only show findings at or above the specified level. Levels: `error` (errors only), `warning` (errors + warnings), `info` (all -- the default). This does NOT affect which fixes are applied -- only what's reported. Linters still run at full sensitivity to catch everything for auto-fix.
- If `--changed-lines-only` is present, enable diff-aware mode: after running the linter, cross-reference findings against the git diff (`git diff` or `git diff --cached` depending on scope). Only report and fix issues on lines that were actually modified or added. Issues on unchanged lines are silently suppressed. This reduces noise when editing a function in a legacy file that has pre-existing lint violations throughout.
- If `--incremental` is present, enable incremental caching. Before running, check `<workspace>/.claude/cache/linter/<file-hash>.clean` for each file. If the file's content hash matches a cached clean entry AND the linter config hasn't changed since the cache was written, skip that file entirely. After linting, write cache entries for files that came back clean. Cache is stored at `<workspace>/.claude/cache/linter/` with a manifest tracking config hashes. Use `--no-cache` to force a full re-lint and clear the cache.
- Treat the first **non-flag** token that looks like a path or directory as the **scope directory** (prefix filter). All file paths must be under this directory (normalize to repo-relative paths). If no directory token is given, do not filter by directory except as inferred from the user message.
- Remaining non-flag tokens can be explicit file paths (still apply `.txt` exclusion and directory filter).
- Always **exclude `*.txt`** from the lint set.

## Safe fixes and user confirmation

- Apply **obvious, low-risk** fixes without asking: mechanical formatting, import sort where the project already uses that tool, trivial typos clearly required by the linter, documented safe auto-fixes.
- **Ask the user** before changes that are **not generally safe** or where confidence is low: possible behavior change, looser/tighter types, logic rewrites, suppressions that could hide bugs, aggressive auto-fixes, or disputed rules in context.
- Give a **short** proposed-change summary and wait for **explicit approval**, unless the user already approved broad fixes for this run.

**Context resilience:** No state file. If the thread looks summarized or mid-run state is missing, re-read this file, **re-scan git** for paths, re-run discovery and linters, then continue—announce recovery with **`Linter`** on the opening line.

**Output tagging:** Use **`Linter`** on the **first line** of **progress** turns too—not only the final **Lint run summary**. Minimum: one early message (scope/files/tools) and one closing message (results). Avoid one silent run then a single closing report. If constrained to one turn, first line = **`Linter`** + short **what ran** sentence, **then** the summary block—never start with `## Lint run summary` alone.

## Workflow

1. **Build the file set** -- Combine parsed arguments with git output when applicable; drop `.txt`; apply directory prefix if set; apply `--only` type filter if present. If `--incremental` is active, load the cache manifest from `<workspace>/.claude/cache/linter/manifest.json`, compute content hashes for each file, and exclude files whose hash matches a cached clean entry with a matching config hash. Send a **`Linter`**-badged message with a brief sentence, then bullet details (files, exclusions, cached-clean count if incremental).
2. **Discover tooling and partition** -- Infer linters from repo signals (configs, scripts, lockfiles). Common signals:

   | Language | Config signals | Linter tools |
   |---|---|---|
   | JS/TS | `eslint.config.*`, `.eslintrc*`, `package.json` scripts | `eslint`, `npm run lint` |
   | Python | `pyproject.toml` `[tool.ruff]`/`[tool.flake8]`, `ruff.toml` | `ruff check`, `flake8` |
   | Go | `golangci-lint` config, `go.mod` | `golangci-lint run`, `go vet` |
   | Rust | `Cargo.toml`, `clippy.toml`, `rustfmt.toml` | `cargo clippy`, `cargo fmt` |
   | C/C++ | `.clang-tidy`, `.clang-format` | `clang-tidy`, `clang-format` |
   | Java/Kotlin | `build.gradle*`, `pom.xml`, `checkstyle.xml`, `.editorconfig` | Gradle/Maven lint plugins, `ktlint` |
   | Ruby | `.rubocop.yml` | `rubocop` |
   | Shell | `.shellcheckrc` | `shellcheck` |
   | Dart | `pubspec.yaml`, `analysis_options.yaml` | `dart analyze`, `dart format` |
   | SQL | `.sqlfluff`, `pyproject.toml` `[tool.sqlfluff]` | `sqlfluff lint`, `sqlfluff fix` |
   | PowerShell | `PSScriptAnalyzerSettings.psd1`, `.ps1` files present | `Invoke-ScriptAnalyzer` |
   | C# | `*.csproj`, `*.sln`, `.editorconfig` | `dotnet format`, Roslyn analyzers via `dotnet build -warnaserror` |

   Priority: (1) explicit project script (`npm run lint`, `ruff check`, etc.), (2) standard CLI for the config found (correct cwd), (3) editor diagnostics. If multiple tools apply, run the one the project treats as primary. Split into **Runnable** (can invoke linter now), **Deferred tooling** (setup/install possible but not done now -- do not add config or deps unless user asked), and **Skipped** (`*.txt`, binaries, no practical path). Track deferred quietly. Send a **`Linter`**-badged partition summary using bullets (Runnable/Deferred/Skipped with counts and tools); omit zero-count lines.
3. **Group runnable files** — **File type groups** = same primary linter invocation (tool + cwd + config). Split at monorepo boundaries when configs differ.
4. **Parallelize** — **One group:** run steps 5–6 inline. **Two or more groups:** up to **4 parallel sub-tasks** (one per group; merge smallest / same-CLI groups if >4). Each sub-task runs step 5 for its paths only and returns a partial result (**Files touched**, **Tool output summary**, **Remaining issues**, **Pending user confirmations**); merge before step 6.
5. **Run linters and fix** — Skip edits entirely if `--no-fix`. Otherwise per group: run linter (auto-fix when allowed), fix remaining with **user confirmation** for uncertain changes; repeat until stable for that group’s files. If `--changed-lines-only` is active, after collecting all findings, cross-reference each finding’s file:line against the git diff. Suppress any finding whose line was not added or modified in the diff. Still apply auto-fixes for findings on changed lines.
6. **Update incremental cache** — If `--incremental` is active, for each file that came back clean (zero remaining issues after fixes), write a cache entry: `{ "file": "<path>", "content_hash": "<sha256>", "config_hash": "<sha256 of linter config>", "timestamp": "<ISO-8601>" }` to the manifest. Remove stale entries for files that are no longer clean or no longer exist.
7. **Merge and report runnable** — Combine partial results if parallel; apply `--severity` filter to findings (drop findings below the threshold from the output but not from fix application); compute pass/fail; fill template through **Remaining issues**.
8. **Deferred tooling with install offer** — Append **only after** step 7 when the deferred bucket is non-empty. For each deferred group, if the install command is known (e.g., `pip install ruff`, `npm install -D eslint`, `gem install rubocop`, `dotnet tool install dotnet-format`, `dart pub get`, `pip install sqlfluff`, `Install-Module PSScriptAnalyzer`), include it in the output and offer to run it:
   - In interactive mode: ask the user "Install [tool] now? (`[command]`)" with yes/no. If yes, run the install command, then re-run discovery and lint for that group’s files.
   - In non-interactive contexts (e.g., called from Ralph Loop’s Cleanup stage): skip the install offer, just report the deferred group as before.

## Output template

Render with **full markdown formatting** -- headings, bold labels, bullet lists, and blank lines between sections. Never collapse into a flat paragraph or strip the markdown syntax.

**Omit empty sections entirely.** If a section has no items, leave it out rather than printing "(none)".

```text
**PASS** | **FAIL (N error(s), M warning(s))**

## Lint run summary

- **Scope:** [directory / git ref / explicit paths]
- **Tooling:** [what was run, per root or file group]
- **Result:** [clean | N issue(s) fixed | M issue(s) remain]
- **Mode:** [full | changed-lines-only | incremental (N files cached, M re-linted)]
- **Filter:** [all types | --only py,ts | --severity error]

### Files touched

- `[path]`: [brief note: auto-fixed / manual fix / clean]

### Skipped

- `[path or pattern]`: [reason, e.g. *.txt excluded, binary, no practical lint path, cached clean]

### Remaining issues

- `[path:line]` -- [severity] -- [tool/rule id] -- [one-line description; user action if needed]

### Deferred tooling

#### [Group label]

- **Files:** [paths]
- **Why deferred:** [one line]
- **Install command:** `[e.g., pip install ruff, npm install -D eslint]` (if known)
- **Options the user can choose from:**
  - Install now (runs the install command with user confirmation)
  - Skip for this run
  - [Other options if applicable]
```

**Pass/fail determination:**

- **PASS**: Zero remaining issues after fixes (at the filtered severity level if `--severity` is active).
- **FAIL (N error(s), M warning(s))**: One or more remaining issues. Show counts by severity. If `--severity` filters are active, only count issues at or above the filtered level.

The pass/fail line is the **very first line** of the Lint run summary block, rendered bold. It provides a single at-a-glance gate check result.

## Constraints

- Do not introduce new config files unless the user asked to set up linting.
- Installing a linter tool (via the Deferred tooling install offer) is allowed with explicit user confirmation. This installs the tool only, not project-level config.
- Do not reformat files that had no linter findings unless required for a fix.
- Avoid drive-by refactors.
- The `--changed-lines-only` filter applies to reporting and fixing only. The linter itself still runs on the full file (most linters don't support line-range filtering natively). The skill post-filters the output.
- Incremental cache entries are invalidated when the linter config file changes (detected by config hash mismatch). Use `--no-cache` to force a clean run.
- No compound Bash commands — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls instead — use parallel calls for independent commands.
- No `cd` prefix — the working directory is already the project root. Run commands directly instead of `cd "/path/to/project" && command`.
- Use relative paths from the project root — never use absolute paths in Bash commands. Use `.venv/3.11/Scripts/python.exe`, `data/output/`, etc. Only use absolute paths for resources genuinely outside the project (e.g., `~/.claude/`).
- Temporary files go in the **project root** (e.g., `_tmp_test.py`, `_tmp_payload.json`) — never in `/tmp/`, `%TEMP%`, or any path outside the project. Paths outside the project trigger sensitive-file prompts. Use the `_tmp_` prefix. Delete only the files you created, one `rm` per file. Never `rm _tmp_*` — the glob also removes another agent's scratch files and prior runs' artifacts, some of which cannot be regenerated.

## Output tagging

**`Linter`** appears on the **opening line** of each assistant turn only. Do **not** prefix every bullet or heading in the same turn.

The **first line** of each assistant turn for this command MUST begin with: **`Linter`**

Apply the badge on the opening line for: early scope/partition, grouping/parallel launch, status/progress, final **Lint run summary** / **Deferred tooling**, warnings, and context recovery.

**Format:** **`Linter`** (bold backtick-wrapped) as the **first element** on the **opening line** of the turn.

**Example -- single turn:**

```text
**`Linter`** Ran Ruff on `src/foo.py` -- 1 unused import fixed, recheck clean.

## Lint run summary

- **Scope:** `src/foo.py` (explicit path)
- **Tooling:** `ruff check --fix` + `ruff check` (verify)
- **Result:** clean (1 issue auto-fixed, 0 remaining)

### Files touched

- `src/foo.py`: auto-fixed (Ruff removed unused import `re`)
```
