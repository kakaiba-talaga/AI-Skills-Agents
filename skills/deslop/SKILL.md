Clean AI-generated code slop with a regression-safe, deletion-first workflow. Arguments: $ARGUMENTS

Parse the arguments as follows:

**Scope (mutually exclusive, first match wins):**

- `staged` — build the file set from `git diff --cached --name-only`
- `changed` — build the file set from `git diff --name-only` (unstaged + staged vs HEAD); this is the **default** when no scope is given
- `all` — whole codebase; respects `.gitignore`; excludes `vendor/`, `node_modules/`, `third_party/`, lock files (`*.lock`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, etc.), and binary files
- `branch` — all files changed on the current branch vs merge base: `git diff $(git merge-base HEAD main)...HEAD --name-only`
- A file path or directory — that specific target (recursively includes all source files under a directory)

**Flags:**

- `--dry-run` / `--report-only` — analyze and report findings but make no changes; no savepoint is created; output uses "would remove" / "would simplify" language
- `--aggressive` — auto-apply all findings including LOW-confidence (<60%). Maximum cleanup, highest risk. Every finding is applied and verified — use when you want deslop to take every shot.
- `--conservative` — only auto-apply HIGH-confidence findings (>90%). MEDIUM and LOW findings are report-only. Safest mode — for unfamiliar codebases or when you want minimal risk.
- `--category <list>` — comma-separated list of taxonomy category names to target (default: all); e.g., `--category dead-code,verbose-patterns`
- `--no-verify` — skip regression verification after each batch (dangerous; savepoint is still created)
- `--no-lint` — skip the linter pass after all batches
- `--max-retries N` — max verify retry attempts per batch before skipping (default: 2)
- `help` — display the quick-reference card and stop

## Help Reference Card

Display this card when `help` is given, then stop:

```
**`Deslop`** Quick Reference

### What it does
  Finds and removes AI-generated structural bloat: dead code, redundant
  comments, unnecessary abstractions, over-engineering, speculative
  generality, and more. Regression-safe: verifies after each batch and
  reverts on failure. Deletion-first: less code is better code.

### Scope modes
  staged        Files from git diff --cached
  changed       Files from git diff (unstaged + staged) [default]
  all           Entire codebase (respects .gitignore, skips vendor/lock)
  branch        All files changed on current branch vs merge base
  <path>        Specific file or directory

### Flags
  --dry-run / --report-only   Analyze only; make no changes
  --aggressive                Auto-apply all findings including LOW confidence (<60%)
  --conservative              Only apply HIGH-confidence (>90%) findings
  --category <list>           Comma-separated categories to target
  --no-verify                 Skip regression verification (dangerous)
  --no-lint                   Skip linter pass after batches
  --max-retries N             Max verify retries per batch (default: 2)
  help                        Show this card

### Taxonomy categories
  dead-code                   Unused functions, unreachable branches
  redundant-comments          Comments restating obvious code
  unnecessary-abstractions    Single-call-site helpers, no-behavior wrappers
  over-engineering            Config for hardcoded values, always-on flags
  speculative-generality      Unused params, single-impl interfaces
  excessive-error-handling    Catches around code that cannot throw
  backwards-compat-shims      Deprecated aliases, unsupported-version branches
  verbose-patterns            `if x == True`, unnecessary else after return
  unnecessary-type-annotations Obvious-literal annotations
  import-bloat                Delegated to /linter

### Agent delegation
  Verifier agent      After each batch (regression check)
  Code-reviewer agent Once at the end (correctness of deletions)
  /linter skill       After all batches (formatting cleanup)

### Pipeline
  Resolve scope → Savepoint → Analyze → Batch →
  Apply-Verify loop → Linter pass → Code review → Report
```

## Core Philosophy

Deslop operates on a single principle: **less code is better code**.

AI models generate slop because they are trained to be helpful and complete. When asked to write a function, an AI adds error handling for every conceivable state, wraps simple logic in abstractions "for extensibility," documents every line, and leaves room for future requirements that may never arrive. The result is syntactically valid code that does what it should — but is twice as long as necessary.

The antidote is deletion-first thinking:

- **Prefer deletion over refactoring.** A deleted function has no bugs.
- **If it is not clearly needed, remove it.** The burden of proof is on the code, not the deletion.
- **Inline rather than abstract.** A helper called once is a function that exists to name something; if the name adds no clarity, inline it.
- **Do not protect against impossible states.** Error handling for situations that cannot occur is noise, not safety.

Deslop does not improve code. It removes what should not be there.

## Slop Detection Taxonomy

### 1. Dead Code

**Risk:** LOW

Code that is never executed: unused functions, methods, or classes; unreachable branches after unconditional returns or throws; commented-out code blocks (not documentation).

**Example patterns:**

- A function defined but never called anywhere in the codebase
- `else` branch after a `return` statement in every preceding `if`
- Ten lines of code commented out with `# OLD` or `// TODO: remove`

**Detection heuristic:** Grep for all call sites and references across the codebase. Zero references = dead. For commented-out blocks: 3+ consecutive commented lines containing code syntax.

Note: Unused imports are handled by category 10 (Import Bloat) via `/linter`. Do not flag them under Dead Code.

**Fix action:** Delete.

**Never-delete guard:** Do not delete exported/public API symbols that may have external callers outside the repository. Do not delete code decorated with `@preserve` or suppression annotations.

---

### 2. Redundant Comments and Docstrings

**Risk:** LOW

Comments that restate what the adjacent code obviously does, docstrings that merely repeat the function signature with no added meaning.

**Example patterns:**

- `# increment counter` above `counter += 1`
- `// returns the user` above `return user`
- Docstring: `"""Gets the name. Returns: the name."""` on a `get_name()` method
- `# end of for loop` on a closing brace

**Detection heuristic:** The comment contains the same words as the code immediately following it, or the docstring contains only a restatement of the function/parameter names with no behavioral description.

**Fix action:** Delete the comment or docstring.

**Never-delete guard:** Do not delete regulatory or compliance comments, license headers, copyright notices, or comments that explain *why* (not *what*) — "why" comments document intent that the code cannot express.

---

### 3. Unnecessary Abstractions

**Risk:** MEDIUM

Helper functions called exactly once with no polymorphism, wrapper classes that add no behavior, utility modules containing a single function, factory patterns for a single concrete implementation.

**Example patterns:**

- `def _format_user_name(u): return f"{u.first} {u.last}"` called in exactly one place
- A `ResponseWrapper` class whose only method is `get_data()` returning `self.data`
- A `utils.py` containing one function that could live in its only caller
- A `UserFactory.create()` that always instantiates `User` with no variation

**Detection heuristic:** Count call sites and implementations. Single call site with no subclasses/overrides = abstraction candidate. Single implementation with no interface consumers = abstraction candidate.

**Fix action:** Inline the abstraction into its call site and delete the wrapper.

**Never-delete guard:** Do not inline if the symbol is part of a public API or interface contract. Do not inline if it is used in tests as a seam for mocking.

---

### 4. Over-Engineering

**Risk:** MEDIUM

Configuration objects for values that are always hardcoded, feature flags that are always on or always off, strategy pattern implementations with one strategy, builder patterns for objects with two fields.

**Example patterns:**

- A `Config` dataclass with five fields all set to the same value in every instantiation, never read from environment or file
- `FEATURE_NEW_PARSER = True` used in `if FEATURE_NEW_PARSER:` with the old path long gone
- A `SortStrategy` protocol with `AlphabeticalSort` as its only implementation
- A `QueryBuilder` with `.add_filter()`, `.set_limit()`, `.build()` used in one place always with the same arguments

**Detection heuristic:** Config with one consumer and no external source. Flag referenced in exactly one branch, never toggled. Strategy/builder with one implementation and no injection point.

**Fix action:** Replace with direct, inline code. Remove the configuration layer.

**Never-delete guard:** Do not simplify if config values are read from external sources (env vars, config files, CLI arguments). Do not remove flags if there is evidence they will be toggled (e.g., A/B test infrastructure).

---

### 5. Speculative Generality

**Risk:** MEDIUM

Parameters that are never called with a non-default value, interfaces with exactly one implementation (not used for test mocking), abstract base classes with one concrete subclass, unused generic type parameters.

**Example patterns:**

- `def process(data, mode="fast", retries=3)` where every call site uses `process(data)` with both defaults
- An `IRepository` interface with `SqlRepository` as its only implementation, not injected anywhere
- `class BaseExporter(ABC)` with `CsvExporter` as its only subclass and no polymorphic usage
- `def get_items[T]()` where `T` is declared but never constrained or used

**Detection heuristic:** Grep for all call sites. If a parameter is always called with its default value, it is speculative. If an interface or abstract class has one implementation and no injection sites, it is speculative.

**Fix action:** Remove unused parameters (update all call sites). Collapse single-implementation interfaces into the concrete class.

**Never-delete guard:** Do not remove if it is part of a public SDK or library API (external callers may pass non-default values). Do not remove abstract classes if they serve as documentation of intended extension points.

---

### 6. Excessive Error Handling

**Risk:** MEDIUM

This is the highest-risk MEDIUM category. Assign MEDIUM confidence only when the error path is provably unreachable. Assign LOW confidence when there is any doubt — LOW findings are report-only in normal mode and require human judgment.

Try/catch blocks wrapping code that cannot throw the caught exception, error handling for impossible states, defensive null/type checks duplicating upstream validation that already guarantees the input, fallback values for fields that are required and always present.

**Example patterns:**

- `try { return parseInt(x) } catch (NaN) {}` where `x` is already validated as a numeric string
- `if (user == null) { throw Error("user required") }` immediately after `user = db.getUser(id)` which never returns null (checked in ORM layer)
- `except FileNotFoundError` around a file path that was just confirmed to exist two lines above
- `|| "default"` fallback on a field populated by a required schema with no nullable annotation

**Detection heuristic:** Trace data flow from the error handler back to the source. If the error condition requires violating a guarantee already established by the caller or the type system, the handler is unreachable.

**Fix action:** Remove the dead error path. Simplify to the success path only.

**Never-delete guard:** NEVER remove error handling in public API endpoints, network I/O, file I/O, database calls, parsing of external data, or security-critical paths (authentication, authorization, cryptography, input sanitization). When in doubt, keep the handler.

---

### 7. Backwards-Compatibility Shims

**Risk:** MEDIUM

Deprecated function aliases that nothing calls, version-check branches for runtime versions no longer supported per the project's stated requirements, polyfills for language features universally supported by the project's target environments.

**Example patterns:**

- `def get_user(): return fetch_user()` — deprecated alias for `fetch_user()`, no callers
- `if sys.version_info < (3, 8): ...` in a project with `python_requires = ">=3.11"` in `pyproject.toml`
- `if (!Array.prototype.flat) { Array.prototype.flat = ... }` polyfill when the project targets only modern browsers
- `v1_compat_handler()` registered but never invoked anywhere

**Detection heuristic:** Grep for callers of the alias. Check version constraints in `pyproject.toml`, `package.json`, `.nvmrc`, etc. vs. the version being checked. Polyfill browser support tables vs. `browserslist` config.

**Fix action:** Delete the shim and any call sites (there should be none).

**Never-delete guard:** Do not delete if the package is published as a library — external consumers may depend on the shim. Do not delete if the version constraint is not definitively pinned (e.g., open-ended `>=3.8`).

---

### 8. Verbose Patterns

**Risk:** LOW

Code that is functionally correct but uses verbose forms where idiomatic equivalents exist: explicit boolean comparisons, unnecessary `else` after `return`, verbose null checks replaceable by language idioms, manual loops replaceable by built-in operations.

**Example patterns:**

- `if x == True:` instead of `if x:`
- `if condition: return True\nelse: return False` instead of `return condition`
- `if items is not None and len(items) > 0:` instead of `if items:`
- `result = []; for x in items: result.append(x*2); return result` instead of `return [x*2 for x in items]`

**Detection heuristic:** Pattern matching on AST or text structure. These are mechanical transformations with no behavior change.

**Fix action:** Replace with the idiomatic equivalent.

**Never-delete guard:** Do not change if the verbose form is an explicit project convention documented in a style guide. Do not change if the verbose form is intentional for readability (e.g., explicit boolean comparison for clarity in configuration-heavy code).

---

### 9. Unnecessary Type Annotations

**Risk:** LOW

Type annotations on variables assigned an obvious literal, return type annotations where the single return value makes the type trivially inferable, redundant generic parameters the compiler can infer.

**Example patterns:**

- `x: int = 5` — the literal `5` already establishes the type
- `name: str = "Alice"` — the literal `"Alice"` is obviously `str`
- `def get_count() -> int: return len(self.items)` — inferrable but borderline; check project convention
- `items: List[str] = []` in Python 3.9+ where `list[str]` or inference suffices

**Detection heuristic:** Is the type trivially inferable from the assigned value or the sole return expression? Would removing the annotation cause a type-checker error or loss of documented API contract?

**Fix action:** Remove the annotation.

**Never-delete guard:** Do not remove type annotations in TypeScript strict mode projects. Do not remove if the project uses `mypy --strict` or `pyright` in strict mode where explicit annotations are required. Do not remove from public API signatures where annotations serve as documentation.

Detect mypy strict mode by checking for `strict = true` in `mypy.ini` or `[tool.mypy] strict = true` in `pyproject.toml`. Detect pyright strict mode by checking for `typeCheckingMode = 'strict'` in `pyrightconfig.json` or `[tool.pyright]` in `pyproject.toml`.

---

### 10. Import Bloat

**Risk:** LOW

**Never-delete guard:** Not applicable — detection and removal delegated entirely to `/linter`.

**Delegate entirely to `/linter`. Do not duplicate detection.**

This category exists in the taxonomy for completeness — unused imports are a common form of slop. However, linters (ruff, eslint, etc.) detect and fix unused imports automatically and more accurately than static text analysis. When `/linter` runs as part of the deslop workflow (step 6), it handles this category.

If `--no-lint` is passed, unused imports will NOT be addressed by deslop — inform the user in the report.

---

## Workflow

### Step 1 — Resolve Scope

**Pre-check:** Verify git is available and the working directory is inside a git repository (`git rev-parse --is-inside-work-tree`). If git is unavailable or the directory is not a repo: warn the user that no savepoint, no per-batch rollback (`git checkout -- <files>`), and no git-based scope modes (staged, changed, branch) will be available. Require explicit user confirmation to proceed. If confirmed, force `--dry-run` mode automatically — deslop will analyze and report but will not make any changes. Only `all` and direct file-path scopes are available without git.

Build the file set from the parsed scope argument:

- Run the appropriate git command or traverse the directory.
- Exclude always: binaries, lock files (`*.lock`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Gemfile.lock`, `Cargo.lock`, `composer.lock`, `go.sum`, `poetry.lock`), vendor directories (`vendor/`, `node_modules/`, `third_party/`, `external/`), auto-generated files (files with `# Auto-generated`, `// Code generated`, `@generated`, `DO NOT EDIT` in the first 5 lines).
- For `all` scope: respect `.gitignore` (use `git ls-files` to enumerate tracked files).
- If `--category` flag is present, note which categories are active — this affects analysis in step 3 but not scope.
- **Scale warnings:**
  - 50–199 files: warn the user ("Large scope: N files. This may take a while.")
  - 200–499 files: strongly warn ("Very large scope: N files. Consider narrowing to a directory or using `branch`.")
  - 500+ files: strongly warn and suggest narrowing ("N files is very large. Consider targeting a specific directory or branch. Proceeding anyway.")

If the resolved file set is empty after filtering, halt immediately and report: **`Deslop`** 'No files in scope. Verify your scope argument or stage some changes.' Do not create a savepoint or proceed to analysis.

Send a **`Deslop`**-badged progress message: "Resolved scope: N files from [scope description]."

### Step 2 — Create Savepoint

Before making any changes, create a rollback anchor.

- If in `--dry-run` mode: skip this step (no changes will be made). Note in output.
- If the working tree is dirty (has uncommitted changes): run `git stash push -m "deslop-savepoint-<ISO-timestamp>"`. Record the stash ref.

If `git stash push` fails (e.g., merge conflicts in the working tree, pre-stash hooks, or the directory is not a git repository), **halt immediately**. Report the error and instruct the user to resolve the git state before re-running deslop. Do not proceed to analysis or any mutations without a confirmed savepoint. The savepoint is non-negotiable.

- If the working tree is clean: note the current HEAD SHA (`git rev-parse HEAD`). This is the rollback anchor.
- Record the savepoint info. Include it in every subsequent progress message so the user can manually restore at any time.
- **Rollback instructions to include in progress messages:** `git stash pop` (if stashed) or `git checkout <sha>` (if clean tree).

### Step 3 — Analyze

Read all files in scope and apply the slop detection taxonomy. Batch reading by module or directory to preserve context (related files help disambiguate whether something is "dead" or called from a sibling).

For each file:

- Apply each active taxonomy category.
- For each finding, record: `{ file, line_range, category, confidence (HIGH/MEDIUM/LOW), description, proposed_action }`.
- Apply confidence thresholds based on mode:
  - **Normal mode:** HIGH (>90%) = auto-apply. MEDIUM (60–90%) = auto-apply. LOW (<60%) = report-only.
  - **`--aggressive`:** All findings auto-apply, including LOW (<60%). Every finding is applied and verified.
  - **`--conservative`:** Only HIGH >90% auto-applies. MEDIUM and LOW are report-only.
- Group findings by file.

Send a **`Deslop`**-badged progress message: "Analyzing N files... (savepoint: [correct savepoint command])". Include the correct savepoint command in every progress message: `git stash pop` if the savepoint was a stash, or `git checkout <sha>` if the savepoint was a HEAD SHA ref.

After analysis, send a summary: "Found N findings across M files (X auto-apply, Y report-only)."

If in `--dry-run` mode, skip to step 8.

### Step 4 — Batch

Group findings into batches for the apply-verify loop:

- **Per-file batching:** All findings within one file form one batch by default.
- **Cross-file batching:** If a fix requires editing multiple files (e.g., inlining a helper used from another file), group those files into a single multi-file batch. Both files must be within scope — if any required file is outside scope, report the finding but do not apply (scope boundary is strict).
- **Ordering:** Apply LOW-risk batches first, MEDIUM second, HIGH last. This minimizes the blast radius of early failures.
- Number the batches for progress reporting.

### Step 5 — Apply-Verify Loop

For each batch, in order:

**a. Apply changes.** Edit the files in the batch. Make only the changes identified in step 3 for this batch.

**b. Skip verification if `--no-verify`.** Proceed directly to the next batch and log a warning.

**c. Invoke the verifier agent.** Use the Agent tool with `subagent_type: "verifier"`.

  **Memory-injection predicate.** Before composing the brief, evaluate the predicate documented in `skills/ops/SKILL.md` Phase 3 Step 3 and call the selector from `skills/cross-memory/brief-injector.md`. For deslop's per-batch verifier dispatches, the simplified predicate is:

  - If `--memory-inject=off`: skip injection.
  - Otherwise: `verifier` is not in `MECHANICAL_AGENTS`, and each per-batch dispatch is the first (and only) attempt for that batch — no prior handoff exists. Apply the default `auto` path: call the selector with `enable_agent_type_intersection=true`.
  - If `--memory-inject=always`: call the selector with `enable_agent_type_intersection=false`.

  If the selector returns non-empty bytes, render them as `## Project Knowledge` placed **before** the inline prose brief. If the selector returns empty bytes, omit the section and proceed with the prose brief alone.

  Brief the verifier:
  > "Run the tests relevant to these modified files: [file list]. Focus on regression detection — any test failure counts as FAIL. Do not evaluate acceptance criteria. Report PASS or FAIL with a brief reason."

  **Fallback if verifier unavailable:** If the verifier agent cannot be invoked (agent file missing at `~/.claude/agents/verifier.md` or invocation fails), fall back to a **lightweight build/compile check** directly via Bash. Detect the project's build tool from config files and run: `go build ./...` (Go), `tsc --noEmit` (TypeScript), `python -m py_compile <file>` (Python), `cargo check` (Rust), or the equivalent. This catches syntax errors, import breakage, and type errors from deletions — not as thorough as a full test suite, but sufficient to detect the most common deslop regressions. Automatically shift to `--conservative` mode if not already in it. Log: 'Verifier unavailable — using lightweight build check as fallback (conservative mode).' If no build tool is detected, proceed without verification, warn the user, and note in the report: 'Per-batch verification: skipped (no verifier agent and no build tool found).' The memory-injection predicate applies only when the verifier agent dispatch fires — the lightweight build/compile fallback runs without injection.

**d. On PASS:** Record the batch as applied. Proceed to the next batch.

**e. On FAIL:** Revert the batch using `git checkout -- <files>`. Log the failure reason.

  - If `--max-retries > 0`: attempt to narrow the batch by removing the highest-risk finding from the batch, then retry from step (a) with the narrowed batch. Decrement the retry counter. Track attempted batch configurations to avoid re-trying the exact same set.
  - After exhausting `--max-retries`: skip the entire batch. Log it as reverted in the report.
  - Never re-attempt the exact same batch configuration.
  - The retry counter is per-batch — it resets to the `--max-retries` value for each new batch. A batch that exhausts all retries is skipped and reverted; the counter resets for the next batch.

**f. Progress message** (every batch): **`Deslop`** badge + "Batch N/M: [applied|reverted|skipped] — [file(s)] ([K findings]). Savepoint: `git stash pop`"

### Step 6 — Linter Pass

After all batches are complete, run `/linter` on all files that were modified by deslop.

- Skip this step if `--no-lint` was passed. Note in the report.
- **Fallback if /linter unavailable:** If the `/linter` skill is not available (file missing at `~/.claude/skills/linter/SKILL.md` or invocation fails), fall back to a **basic direct linter invocation** via Bash. Detect the project's linter from config files: `ruff check --fix` (Python with `pyproject.toml`/`ruff.toml`), `eslint --fix` (JS/TS with `.eslintrc*` or `eslint.config.*`), `go vet` (Go with `go.mod`), `cargo clippy` (Rust with `Cargo.toml`). Run the detected linter directly on files modified by deslop. This is simpler than the full `/linter` skill — no incremental caching, no install offers, no diff-aware mode, no multi-linter parallelization — but still catches formatting issues left by deletions and inlinings. Log: 'Linter skill unavailable — running basic linter directly as fallback.' If no linter is detected, skip the linter pass and note in the report: 'Linter pass: skipped (no /linter skill and no linter detected).'
- The linter catches formatting issues introduced by inlining or deletion (e.g., orphaned blank lines, import order changes from removal).
- Collect the linter summary for inclusion in the final report.

### Step 7 — Code Review Pass

**Fallback if code-reviewer unavailable:** If the code-reviewer agent cannot be invoked (agent file missing at `~/.claude/agents/code-reviewer.md` or invocation fails), fall back to a **lightweight self-review diff scan**. Deslop reads its own cumulative diff (`git diff` on modified files) and checks for the most dangerous deslop-specific mistakes: (1) deleted lines that are still referenced by other files (grep for the deleted symbol name across the codebase), (2) inlined code where indentation or scope changed incorrectly, (3) removed error handlers in functions that perform I/O, network calls, or database operations. This is not as thorough as a dedicated code-reviewer agent — it cannot catch subtle logic bugs or assess architectural impact — but it catches the highest-risk deslop regressions. Log: 'Code-reviewer unavailable — running lightweight self-review diff scan as fallback.' Include the self-review findings in the report under Code Review with the note: 'Code review: lightweight self-review (code-reviewer agent unavailable). Manual review still recommended for complex changes.' The memory-injection predicate applies only when the code-reviewer agent dispatch fires — the lightweight self-review fallback runs without injection.

Invoke the **code-reviewer** agent once on the cumulative diff of all applied deslop changes. Use the Agent tool with `subagent_type: "code-reviewer"`.

**Memory-injection predicate.** Before composing the brief, evaluate the predicate documented in `skills/ops/SKILL.md` Phase 3 Step 3 and call the selector from `skills/cross-memory/brief-injector.md`. For the code-reviewer dispatch, the simplified predicate is:

- If `--memory-inject=off`: skip injection.
- Otherwise: `code-reviewer` is not in `MECHANICAL_AGENTS`, and this dispatch is the first (and only) attempt for the review pass — no prior handoff exists. Apply the default `auto` path: call the selector with `enable_agent_type_intersection=true`.
- If `--memory-inject=always`: call the selector with `enable_agent_type_intersection=false`.

If the selector returns non-empty bytes, render them as `## Project Knowledge` placed **before** the inline prose brief. If the selector returns empty bytes, omit the section and proceed with the prose brief alone.

Brief the reviewer:

> "Review this diff for correctness. Focus specifically on: (1) Did any deletion break logic that the tests did not catch? (2) Did any inlining introduce subtle bugs? (3) Did removal of error handling leave a gap that could cause a silent failure in production? Do not review style. Report APPROVE, APPROVE WITH COMMENTS, or REQUEST CHANGES."

If the reviewer issues REQUEST CHANGES on critical findings: report the findings to the user in the final report but do not auto-fix. These require human judgment and are outside deslop's scope.

If the reviewer issues APPROVE or APPROVE WITH COMMENTS: include the summary in the report.

### Step 8 — Report

Generate the final report using the output template below.

---

## Safety Mechanisms

### Never-Delete Rules

The following are absolute prohibitions — deslop will never remove or modify these, regardless of mode or flags:

- **Public/exported API symbols** with potential external callers (exported functions, public class members, symbols in published packages)
- **Test files and test helpers** — deslop targets production code only
- **Configuration files** — `.env`, `.env.*`, `*.config.*`, CI/CD files (`*.yml`/`*.yaml` in `.github/`, `.gitlab-ci.yml`, `Dockerfile`, `docker-compose.*`)
- **License headers and copyright notices**
- **Security-related code** — authentication, authorization, cryptography, input validation, input sanitization, XSS/CSRF protection, secrets handling
- **Code with suppression annotations** — anything with `@preserve`, `noinspection`, `eslint-disable`, `noqa`, `nolint`, `type: ignore`, `@ts-ignore`, `@ts-expect-error`, `pragma: no cover` — these exist for documented reasons

### Verification Strategy

- **Per-batch:** After each batch, invoke the verifier agent to run tests relevant to the modified files. The verifier identifies the relevant test files from the modified source files.
- **No test suite:** If no test runner is discoverable, attempt a build/compile check (`go build`, `tsc --noEmit`, `python -m py_compile`, `cargo check`, etc.). Report the verification method used.
- **No tests and no build:** Warn the user explicitly. Ask to confirm proceeding without verification. Automatically shift to `--conservative` mode if the user confirms. Document this in the report.
- **Final verification:** After all batches, the code-reviewer agent reviews the cumulative diff as a final correctness check.

### Rollback Strategy

- **Per-batch rollback:** `git checkout -- <files>` reverts the specific files in a failed batch. The rest of the applied changes are preserved.
- **Full rollback:** The user can restore all changes using the savepoint:
  - If stashed: `git stash pop`
  - If clean tree: `git checkout <sha>`
- **Savepoint info appears in every progress message** so the user can manually restore at any time without waiting for deslop to finish.

### Confidence Thresholds

| Confidence | Threshold | Conservative | Normal | Aggressive |
|---|---|---|---|---|
| HIGH | >90% | Auto-apply | Auto-apply | Auto-apply |
| MEDIUM | 60–90% | Report-only | Auto-apply | Auto-apply |
| LOW | <60% | Report-only | Report-only | Auto-apply |

**Normal mode** (default) auto-applies HIGH and MEDIUM confidence findings. LOW-confidence findings are reported but not applied — these are uncertain enough to need human judgment. **`--conservative`** restricts auto-apply to HIGH-confidence findings only (>90%). Use for unfamiliar codebases or when you want minimal risk. **`--aggressive`** auto-applies all findings including LOW confidence (<60%). Use when you want maximum cleanup and are willing to accept more reverted batches.

### Scope Containment

The scope boundary is strict:

- Never modify files outside the resolved scope, even if a fix logically requires it (e.g., inlining a helper whose callers are in out-of-scope files).
- If a fix requires editing an out-of-scope file, record the finding as "skipped — out-of-scope dependency" in the report.
- The user can re-run deslop with a broader scope to address cross-scope fixes.

---

## Output Template

Use this template for both dry-run reports and final reports.

For `--dry-run` mode: prefix the report with "DRY RUN —". Replace "Applied" with "Would Apply". Replace "removed" / "inlined" with "would remove" / "would inline". Omit the Reverted section entirely. The Savepoint section is omitted (no savepoint was created).

```
**`Deslop`** [summary sentence — e.g., "Cleaned 15 findings across 8 files, 2 reverted"]

## Deslop Report

- **Scope:** [scope description, e.g., "changed files (12 files)"]
- **Mode:** [normal | dry-run | aggressive | conservative]
- **Files scanned:** N
- **Findings:** N total (X applied, Y skipped, Z reverted)

### Applied (N)
- `file.py:42` — [dead-code] Removed unused function `_legacy_handler`
- `utils.ts:15-28` — [unnecessary-abstractions] Inlined `wrapResponse()` into single call site
- `config.go:88` — [verbose-patterns] Replaced `if err != nil { return err }` chain with early returns

### Skipped (N)
- `auth.py:80` — [excessive-error-handling] — skipped: security-critical path (never-delete rule)
- `api.ts:120` — [speculative-generality] — skipped: low confidence (55%)
- `models.py:200` — [unnecessary-abstractions] — skipped: out-of-scope dependency (caller in `api/views.py`)

### Reverted (N)
- `config.py:30-45` — [over-engineering] — reverted: `test_config_parsing` failed after removal
- `helpers.js:10-25` — [unnecessary-abstractions] — reverted: after 2 retry attempts, narrowing did not resolve test failures

### Linter Pass
[PASS — 3 formatting issues auto-fixed in 2 files]
[or: Skipped (--no-lint)]

### Code Review
- **Verdict:** APPROVE WITH COMMENTS
- Reviewer noted: `auth.py:80` — the removed error handler did not create a gap; upstream validation covers it. No action required.
[or: Verdict: REQUEST CHANGES — [critical finding summary] — manual review required, not auto-fixed]

### Savepoint
- Restore all changes: `git stash pop` (or `git checkout <sha>`)
- Created at: [ISO timestamp]
```

**Dry-run variant header:**

```
**`Deslop`** DRY RUN — Found 15 findings across 8 files (7 would apply, 8 would skip)

## Deslop Report (Dry Run)

- **Scope:** [scope description]
- **Mode:** dry-run
- **Files scanned:** N
- **Findings:** N total (X would apply, Y would skip)

### Would Apply (N)
- `file.py:42` — [dead-code] Would remove unused function `_legacy_handler`

### Skipped (N)
- `auth.py:80` — [excessive-error-handling] — skipped: security-critical path (never-delete rule)
```

---

## Agent Delegation

### What Deslop Does Itself

- Scope resolution and file set construction
- Reading files and applying taxonomy analysis
- Identifying findings (file, line, category, confidence, proposed action)
- Batching findings and ordering by risk
- Applying changes to files (edits)
- Managing the apply-verify loop (retries, narrowing, skipping)
- Per-batch reversion on failure (`git checkout -- <files>`)
- Generating progress messages and the final report

### Verifier Agent

**When:** After each applied batch (step 5c). Skipped if `--no-verify`.

**How:** Invoke via the Agent tool with `subagent_type: "verifier"`.

**Brief:**
> "Run the tests relevant to these modified files: [list]. Focus on regression detection. Any test failure = FAIL. Do not evaluate acceptance criteria or coverage. Report PASS or FAIL with a one-line reason."

**Response used for:** Deciding whether to keep or revert the batch.

### Code-Reviewer Agent

**When:** Once, after all batches complete and the linter pass runs (step 7).

**How:** Invoke via the Agent tool with `subagent_type: "code-reviewer"`.

**Brief:**
> "Review this diff for correctness. Focus on: (1) Did any deletion break logic that tests missed? (2) Did inlining introduce bugs? (3) Did error handling removal leave silent failure gaps? Do not review style or formatting. Verdict: APPROVE, APPROVE WITH COMMENTS, or REQUEST CHANGES."

**Response used for:** The Code Review section of the final report. Critical REQUEST CHANGES findings are surfaced to the user but not auto-fixed.

### /linter Skill

**When:** Once, after all batches complete (step 6). Skipped if `--no-lint`.

**How:** Reference the `/linter` skill by name, invoked on all files modified by deslop.

**Brief:** Default linter behavior — auto-fix safe issues, report remaining issues.

**Response used for:** The Linter Pass section of the final report.

### Graceful Degradation

Deslop is designed to degrade gracefully when delegated agents or skills are unavailable. The principle: **never crash, always produce a report.**

| Dependency | Check | Fallback |
| :--- | :--- | :--- |
| **Verifier agent** | Agent file at `~/.claude/agents/verifier.md` exists | Lightweight build/compile check via Bash (`go build`, `tsc --noEmit`, `python -m py_compile`, `cargo check`); auto-shift to `--conservative` |
| **Code-reviewer agent** | Agent file at `~/.claude/agents/code-reviewer.md` exists | Lightweight self-review diff scan: check for dangling references, scope errors in inlined code, removed I/O error handlers |
| **`/linter` skill** | Skill file at `~/.claude/skills/linter/SKILL.md` exists | Basic direct linter invocation via Bash (`ruff check --fix`, `eslint --fix`, `go vet`, `cargo clippy`) |
| **git** | `git rev-parse --is-inside-work-tree` succeeds | Force `--dry-run`; restrict scope modes (already implemented) |
| **Test suite** | Verifier finds runnable tests | Fall back to build/compile check; if neither exists, warn and shift to `--conservative` (already implemented) |

When a fallback activates, it is always:

1. **Logged** — noted in the progress message with the **`Deslop`** badge
2. **Reported** — included in the final report under the relevant section
3. **Non-blocking** — deslop continues to the next step rather than halting

Multiple fallbacks can activate in the same run. In the worst case (no git, no verifier, no linter, no reviewer), deslop runs in forced dry-run mode and produces an analysis-only report — still useful for identifying slop even without the ability to fix it.

---

## Constraints

- **No compound Bash commands** — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls. Use parallel calls for independent commands.
- **No `cd` prefix** — the working directory is the project root. Run commands directly.
- **Use relative paths from project root** — never use absolute paths in Bash commands. Only use absolute paths for resources genuinely outside the project (e.g., `~/.claude/`).
- Temporary files go in the **project root** (e.g., `_tmp_test.py`, `_tmp_payload.json`) — never in `/tmp/`, `%TEMP%`, or any path outside the project. Paths outside the project trigger sensitive-file prompts. Use the `_tmp_` prefix. Do not delete individually — clean up in batch at checkpoints with `rm _tmp_*`.
- **Respect `.gitignore`** — when building file sets for `all` scope, use `git ls-files` to enumerate tracked files. Do not analyze ignored files.
- **Do not create new config files** — deslop never adds configuration, tool configs, or setup files.
- **Do not install tools or packages** — if a required tool is missing, report it and proceed without it.
- **Do not modify files outside the resolved scope** — the scope boundary is strict. Cross-scope dependencies are reported, not fixed.
- **Always create a savepoint before changes** — unless `--dry-run` is active. The savepoint is non-negotiable.
- **Git operations via git-master agent** — For complex git operations (branching, merging, conflict resolution), delegate to the git-master agent. For simple, atomic git commands within the apply-verify loop (`git stash push`, `git checkout -- <files>`, `git rev-parse`), execute directly via Bash for efficiency. The workflow steps specify which git commands run directly.
- **Fix production code, not tests** — if verification fails, the deslop change was wrong. Revert it. Do not modify tests to make them pass.

---

## Relationship to Other Tools

### vs. /linter

`/linter` handles mechanical, formatting-level issues: unused imports, whitespace, style rule violations, import order. These are issues a linter rule can detect by pattern alone.

`/deslop` handles structural bloat that is syntactically valid and passes all linters: functions that exist but aren't needed, abstractions that add no value, error handlers that guard against impossible states. Deslop catches what the linter cannot.

In the deslop workflow, `/linter` runs as a cleanup step *after* deslop — deslop's deletions and inlinings may leave formatting issues that the linter then cleans up.

### vs. /simplify

`/simplify` (if it exists as a skill) improves code quality broadly: eliminates duplication, improves efficiency, extracts reusable patterns, improves naming.

`/deslop` is specifically targeted at AI-generated bloat patterns — the structural slop that emerges when an AI optimizes for completeness and correctness over minimalism. Deslop's heuristics are tuned to catch patterns that AI code generators produce systematically.

### vs. ralph-loop Cleanup Stage

The ralph-loop Cleanup stage is a lightweight linter pass run on files modified during a loop iteration. It is scoped to a single iteration's changes and focused on formatting.

`/deslop` is a comprehensive, standalone analysis targeting structural issues that the linter cannot detect. It operates across the full scope, applies a multi-category taxonomy, uses a regression-safe apply-verify loop, and delegates to multiple agents. It is not a cleanup pass — it is a full structural audit.

Ralph-loop references deslop in its `--no-deslop` flag, which skips the Cleanup stage. That flag skips the entire Cleanup stage in ralph-loop (linter pass plus regression re-verification), not this skill.

---

## Context Resilience

No state file is used. If the thread appears summarized or mid-run state is missing:

1. Re-read this skill file (`~/.claude/skills/deslop/SKILL.md`) to restore the workflow.
2. Re-run `git diff` / `git stash list` / `git status` to reconstruct the current git state and identify the savepoint (if one was created).
3. Re-scan the resolved scope to rebuild the file set.
4. Restart from the analysis phase (step 3). Do not attempt to infer what was applied — start clean from the current file state.
5. Announce recovery with the **`Deslop`** badge on the first line of the recovery message.

**Recovery message format:**

```
**`Deslop`** Recovering from interrupted session. Re-analyzing scope from current file state. Savepoint: [stash ref or SHA if found].
```

---

## Output Tagging

The first line of each assistant turn MUST begin with **Deslop** (bold-only, no backticks). Apply on turns containing scope resolution messages, savepoint creation, analysis progress, per-batch progress, linter pass status, code review delegation status, final report, warnings, and context recovery. Do not repeat on continuation lines (bullets, sub-items, tables) within the same turn.

**Example:**

```
**`Deslop`** Batch 3/7: applied — utils.py (2 findings removed). Savepoint: `git stash pop`
```
