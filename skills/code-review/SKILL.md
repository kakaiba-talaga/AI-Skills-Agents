Perform a code review. Arguments: $ARGUMENTS

Parse the arguments as follows:

- If `--full` is present, run a full review (skip the depth prompt).
- If `--quick` is present, run a quick scan — critical and warning issues only, no narrative (skip the depth prompt).
- If neither flag is present, ask the user to choose: **Full review**, **Quick scan**, or **Skip**.
- If `staged` is present, review staged changes (`git diff --cached`).
- If a PR number is present (e.g., `#123`, `123`), or a PR URL (e.g., `https://github.com/owner/repo/pull/123`), review that PR's diff using `gh pr diff <number>`.
- If a commit hash or range is present (e.g., `abc1234`, `HEAD~3..HEAD`, `main...HEAD`), review that range.
- If `--no-exclude` is present, skip file exclusions and review all files.
- If no target is specified, review the latest commit (`git diff HEAD~1 HEAD`).

## Workflow

1. **Gather the diff** — run **only** the command that matches the parsed arguments. Do not run other commands or check other targets.
   - If `staged` is present, use `git diff --cached`.
   - If a PR number or URL is present, use `gh pr diff <number>`. Also run `gh pr view <number> --json title,body,baseRefName,headRefName` to get PR context (title, description, base/head branches). Include the PR title and description in the review context.
   - If a commit hash or range is present, use `git show <hash>` or `git diff <range>`.
   - If no target is specified, default to checking staged changes first with `git diff --cached`; if the staged diff is empty, ask the user to clarify what they want reviewed.
   - If the arguments are ambiguous, ask the user to clarify.
2. **Filter exclusions** — remove files from the diff that should not be reviewed. Drop silently and list excluded files at the end of the review under a collapsed "Excluded files" section. Default exclusions:
   - Lock files: `*.lock`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Pipfile.lock`, `poetry.lock`, `Gemfile.lock`, `composer.lock`, `Cargo.lock`, `go.sum`
   - Auto-generated code: files containing `// Code generated`, `# Auto-generated`, `@generated`, or `DO NOT EDIT` in the first 5 lines
   - Vendored dependencies: `vendor/`, `node_modules/`, `third_party/`, `external/`
   - Binary files: images, fonts, compiled artifacts (detected by git's binary marker in the diff)
   - Minified bundles: `*.min.js`, `*.min.css`, `*.bundle.js`
   - IDE/editor config: `.idea/`, `.vscode/settings.json`, `*.swp`
   - If `--no-exclude` is present in the arguments, skip this step entirely and review all files.
3. **Assess scope and guardrail** — count remaining changed files after exclusions.
   - **< 5 files**: proceed as a single pass.
   - **5-30 files**: split into up to 4 roughly equal groups (1 per ~3-5 files) and analyze each group in parallel. Merge and deduplicate findings.
   - **31-80 files**: warn the user: "Large diff (N files). Review depth may be reduced. Consider splitting into smaller reviews." Split into up to 6 parallel groups. Prioritize files with logic changes over config/documentation changes.
   - **81+ files**: strongly warn: "Very large diff (N files). Recommend reviewing in parts." Offer three options: (a) proceed with best-effort review (up to 8 parallel groups, reduced depth), (b) review only files matching a pattern the user specifies, (c) abort. In quick-scan mode, proceed automatically with reduced depth.
4. **Analyze in chunks** — break the diff into manageable units by file and logical change. For each chunk, evaluate intent, correctness, patterns, and risk.
5. **Cross-file impact analysis** — after per-file analysis, check whether changes in one file break or affect other files in the diff or the broader codebase. Specifically:
   - **Renamed or removed exports**: If a function, class, constant, or type is renamed, removed, or has its signature changed, grep for usages outside the changed file. Flag any callers that were not updated.
   - **Changed function signatures**: If parameters were added, removed, reordered, or had their types changed, check all call sites.
   - **Interface/contract changes**: If an interface, abstract class, protocol, or trait is modified, check implementations.
   - **Shared state changes**: If a shared config key, environment variable, database column, or API endpoint is renamed or restructured, flag consumers.
   - **Import path changes**: If a file was moved or a module was restructured, check that imports across the codebase were updated.
   - Report cross-file findings as 🔴 Critical if they would cause build or runtime failures, 🟠 Warning if they could cause subtle behavioral changes.
6. **Corroborate findings** — independently verify all findings (including cross-file ones) against the actual diff. For each finding, determine: **valid**, **false positive**, or **needs refinement**. Flag any **missed issues**. If **5 or more findings**, split into up to 4 groups and corroborate in parallel. Drop false positives, incorporate refinements, and add newly identified issues.
7. **Classify findings** using four severity tiers:

| Tier | Label | Meaning |
| :----- | :----- | :----- |
| 🔴 | **Critical** | Must fix before merge — bugs, security vulnerabilities, data loss risks. |
| 🟠 | **Warning** | Should fix — performance bottlenecks, error handling gaps, fragile logic. |
| 🟡 | **Suggestion** | Consider improving — readability, naming, structure, minor optimizations. |
| 🔵 | **Info** | Observation — alternative approaches, knowledge sharing, minor style notes. |

<!-- markdownlint-disable-next-line MD029 -->
8. **Generate output** using the template below.

## Output Template

```text
# Code Review: [commit summary or PR title]

## Summary Checklist

- [ ] Correctness — Logic is sound, edge cases handled.
- [ ] Security — No vulnerabilities introduced (injection, XSS, auth bypass, secrets exposure).
- [ ] Performance — No unnecessary allocations, N+1 queries, or blocking operations.
- [ ] Error Handling — Failures are caught, logged, and surfaced appropriately.
- [ ] Readability — Code is clear, well-named, and follows project conventions.
- [ ] Testing — Changes are covered by tests, or test gaps are noted.
- [ ] Dependencies — New dependencies are justified and version-pinned.

## Detailed Findings

### [filename:line-range]

**[🔴/🟠/🟡/🔵] [Short title]**

[Explanation of the issue, why it matters, and the recommended fix.]

**Current:**
[problematic code snippet]

**Suggested:**
[improved code snippet]

---

## Cross-File Impact

[Only include if cross-file issues were found. Otherwise omit this section.]

- `callers/of/renamed_function.ts:42` — calls `oldName()` which was renamed to `newName()` in `lib/utils.ts`

---

## Verdict

**[APPROVE / APPROVE WITH COMMENTS / REQUEST CHANGES]**

[1-3 sentence rationale.]

### Excluded files

<details>
<summary>N file(s) excluded from review</summary>

- `package-lock.json` — lock file
- `src/generated/api.ts` — auto-generated

</details>
```

**Verdict criteria:**

| Verdict | When to use |
|---|---|
| **APPROVE** | Zero Critical and zero Warning findings. Suggestions/Info only, or no findings at all. |
| **APPROVE WITH COMMENTS** | Zero Critical findings, but one or more Warnings exist that are low-risk or have straightforward fixes. No blocking issues. |
| **REQUEST CHANGES** | One or more Critical findings, OR multiple Warnings that together represent significant risk. Must be addressed before merge. |

The verdict is determined mechanically from the classified findings, not from subjective judgment. If in doubt between APPROVE WITH COMMENTS and REQUEST CHANGES, check whether any Warning could cause a production incident — if yes, REQUEST CHANGES.

For **quick scan** mode, omit the Summary Checklist, Cross-File Impact, and any Suggestion/Info findings. Still include the Verdict and the Excluded files section. Only output Critical and Warning findings.

<!-- markdownlint-disable-next-line MD029 -->
9. **Offer to apply fixes** — after presenting the review, ask the user a **single multi-select question**: "Select which fixes to apply:" — only include tiers that have at least one finding with a concrete Suggested code block:
     - "Apply all fixes"
     - "🔴 Critical — apply all critical fixes" (only if critical findings exist)
     - "🟠 Warning — apply all warning fixes" (only if warning findings exist)
     - "🟡 Suggestion — apply all suggestion fixes" (only if suggestion findings exist)
     - "Skip — don't apply any"
     - Do **not** include 🔵 Info.
     - If **"Apply all fixes"** is selected, apply all tiers regardless of any other selections. If one or more severity tiers are selected, apply only those tiers. If **"Skip"** is selected, end the review.
     - Apply each finding that has a concrete **Suggested** code block to the corresponding file and line range.
     - Apply fixes in reverse line-number order within each file to avoid offset drift.
     - Skip 🔵 Info findings and prose-only recommendations without replacement code.
     - Confirm: "All suggested fixes have been applied. Please review the changes and run your test suite to verify."

## Analysis Priorities

Evaluate in this order:

1. **Security** — Injection flaws, hardcoded secrets, improper auth, insecure deserialization, exposed endpoints. Flag string concatenation in SQL, unsanitized shell input, `innerHTML`/`dangerouslySetInnerHTML`/`v-html`, unsanitized file paths, hardcoded credentials, `.env` files not in `.gitignore`, JWTs without expiration.
2. **Correctness** — Off-by-one errors, null/undefined access, race conditions, incorrect type coercion, logic inversions.
3. **Error Handling** — Empty `catch` blocks, bare `except:`/`catch (Exception)`, missing context in error messages, missing cleanup (`finally`/`using`/`with`/`defer`), unvalidated public API inputs, null dereferences, unchecked type casts.
4. **Performance** — N+1 queries, missing `WHERE` on `UPDATE`/`DELETE`, `SELECT *` in production, missing indexes, large allocations in loops, unclosed resources, string concatenation in loops, blocking calls in async contexts, missing `await`, shared mutable state without synchronization.
5. **Maintainability** — Dead code, magic numbers, overly complex functions, unclear naming, code duplication.
6. **Testing** — Missing coverage for new logic, brittle tests, untested edge cases.

## Language-Specific Checks

**Python**: Mutable default arguments, bare `except:`, `from module import *` in non-`__init__` files.

**JavaScript/TypeScript**: `==` vs `===`, unhandled promise rejections, `var` instead of `const`/`let`, excessive `any` types.

**C#/.NET**: `async void` (should be `async Task`), `IDisposable` without `using`, missing null-conditional (`?.`).

**SQL**: Dynamic SQL via concatenation, missing transactions on multi-statement operations, undocumented `NOLOCK` hints, cursors where set-based logic suffices.

**PowerShell**: `Write-Host` vs `Write-Output`/`Write-Verbose`, missing `-ErrorAction`, `try/catch` without `-ErrorAction Stop`, missing parameter validation attributes.

**Dart/Flutter**: `print()` in production (use `debugPrint()`), missing `await` on `Future`-returning calls, undisposed controllers (`TextEditingController`, `AnimationController`), `setState()` after `dispose()` (guard with `mounted`), `late` variables accessed before initialization, `dynamic` where a concrete type can be inferred, missing `const` constructors on immutable widgets, deeply nested widget trees, `BuildContext` used across async gaps without `mounted` check.

**Bash/Shell**: Unquoted variables, missing `set -euo pipefail`, `eval` with user input, unchecked exit codes.

**Go**: Unchecked error returns (`val, _ := fn()`), goroutine leaks (unbuffered channels with no reader, missing context cancellation), `defer` in loops (resource accumulation), `sync.Mutex` copied by value, `interface{}` / `any` where a concrete type is known, race conditions on shared maps without `sync.Map` or mutex, `init()` functions with side effects, panics in library code (should return errors).

**Rust**: Unwrap/expect on `Result`/`Option` in non-test code (use `?` or match), `unsafe` blocks without safety comments, `clone()` on large types in hot paths, unbounded `Vec::push` in loops without `with_capacity`, `Arc<Mutex<>>` where channels would be clearer, missing `Send`/`Sync` bounds, `.unwrap()` after `.lock()` without poisoning rationale, raw pointer dereference without invariant documentation.

**Java/Kotlin**: Checked exceptions swallowed silently, `== ` on objects instead of `.equals()` (Java), mutable collections exposed from getters (return defensive copy or `Collections.unmodifiable*`), `synchronized` on non-final fields, resource leaks (streams/connections not in try-with-resources), `@SuppressWarnings` without justification, `Optional.get()` without `isPresent()` check, Kotlin `!!` (non-null assertion) outside test code, `lateinit` without initialization guarantee, data class with mutable properties.

**Ruby**: Monkey-patching core classes, `rescue Exception` (too broad, catches `SystemExit`/`SignalException`), mutable default arguments (`def foo(arr = [])`), string interpolation in logs without level guard, missing `freeze` on string constants, `eval`/`send` with user input, N+1 queries in ActiveRecord (missing `includes`/`preload`).

**C/C++**: Buffer overflows (unbounded `strcpy`/`sprintf`/`gets` — use `strncpy`/`snprintf`/`fgets`), use-after-free, double-free, null pointer dereference without check, memory leaks (malloc without corresponding free, `new` without `delete` or smart pointer), uninitialized variables, signed/unsigned comparison, integer overflow in arithmetic, `printf` format string mismatches, missing `virtual` destructor in base classes with virtual methods (C++), raw `new`/`delete` instead of `std::unique_ptr`/`std::shared_ptr` (C++), dangling references from returning reference to local (C++).

## Code Smells

Flag: long methods (>40 lines), deep nesting (>3 levels), magic numbers, god classes, feature envy, shotgun surgery, dead code, and copy-paste duplication.

## Contextual Awareness

- Read surrounding files before flagging issues — a pattern that looks wrong in isolation may be consistent with the codebase.
- Consider the commit message for intent.
- Some commits are intentionally incremental — note incomplete work without penalizing it.
- Favor project conventions and language idioms. Consistency with the codebase takes priority over personal preference.

## Continuous Improvement

Track recurring feedback themes. Note frequently repeated suggestions so they can be addressed systematically. Acknowledge improvements when previously flagged patterns are corrected.

## Constraints

- No compound Bash commands — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls instead — use parallel calls for independent commands.
- No `cd` prefix — the working directory is already the project root. Run commands directly instead of `cd "/path/to/project" && command`.
- Use relative paths from the project root — never use absolute paths in Bash commands. Use `.venv/3.11/Scripts/python.exe`, `data/output/`, etc. Only use absolute paths for resources genuinely outside the project (e.g., `~/.claude/`).
- Temporary files go in the **project root** (e.g., `_tmp_test.py`, `_tmp_payload.json`) — never in `/tmp/`, `%TEMP%`, or any path outside the project. Paths outside the project trigger sensitive-file prompts. Use the `_tmp_` prefix. Do not delete individually — clean up in batch at checkpoints with `rm _tmp_*`.

## Output tagging

**`Code Review`** appears on the **opening line** of each assistant turn only. Do **not** prefix every bullet or heading in the same turn.

The **first line** of each assistant turn for this command MUST begin with: **`Code Review`**

Continuation lines within the same turn (sub-items, indented details, bullet lists, tables) do NOT repeat the badge. Only the opening line carries it.

Apply the badge on the opening line of turns that contain: review headings, status/progress messages, error messages, and confirmations.

**Format:** **`Code Review`** (bold backtick-wrapped) as the **first element** on the **opening line** of the turn.
