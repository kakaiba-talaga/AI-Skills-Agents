Perform a code review. Arguments: $ARGUMENTS

Parse the arguments as follows:

- If `--full` is present, run a full review (skip the depth prompt).
- If `--quick` is present, run a quick scan — critical and warning issues only, no narrative (skip the depth prompt).
- If neither flag is present, ask the user to choose: **Full review**, **Quick scan**, or **Skip**.
- If `staged` is present, review staged changes (`git diff --cached`).
- If a PR number is present (e.g., `#123`, `123`), or a PR URL (e.g., `https://github.com/owner/repo/pull/123`), review that PR's diff using `gh pr diff <number>`.
- If a commit hash or range is present (e.g., `abc1234`, `HEAD~3..HEAD`, `main...HEAD`), review that range.
- If `--no-exclude` is present, skip file exclusions and review all files.
- If no target is specified, default to staged changes (`git diff --cached`); if the staged diff is empty, ask the user to clarify what they want reviewed.

## Workflow

**Review classification contract.** Read `~/.claude/agents/_shared/code-review-contract.md` and apply it as the classification taxonomy for this review: it defines the file-exclusion list, scope-guardrail thresholds and tier labels, severity tiers, verdict criteria, the findings output template, and the language-specific checks. (The skill's own scope-guardrail *actions*, analysis priorities, and fix-application step below are NOT in that file.)

1. **Gather the diff** — run **only** the command that matches the parsed arguments. Do not run other commands or check other targets.
   - If `staged` is present, use `git diff --cached`.
   - If a PR number or URL is present, use `gh pr diff <number>`. Also run `gh pr view <number> --json title,body,baseRefName,headRefName` to get PR context (title, description, base/head branches). Include the PR title and description in the review context.
   - If a commit hash or range is present, use `git show <hash>` or `git diff <range>`.
   - If no target is specified, default to checking staged changes first with `git diff --cached`; if the staged diff is empty, ask the user to clarify what they want reviewed.
   - If the arguments are ambiguous, ask the user to clarify.
2. **Filter exclusions** — remove files from the diff that should not be reviewed using the exclusion list from the contract. Drop silently and list excluded files at the end of the review under a collapsed "Excluded files" section.
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
7. **Classify findings** using the four severity tiers defined in the contract.
<!-- markdownlint-disable-next-line MD029 -->
8. **Generate output** using the template defined in the contract.

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
- Temporary files go in the **project root** (e.g., `_tmp_test.py`, `_tmp_payload.json`) — never in `/tmp/`, `%TEMP%`, or any path outside the project. Paths outside the project trigger sensitive-file prompts. Use the `_tmp_` prefix. Delete only the files you created, one `rm` per file. Never `rm _tmp_*` — the glob also removes another agent's scratch files and prior runs' artifacts, some of which cannot be regenerated.

## Output tagging

**`Code Review`** appears on the **opening line** of each assistant turn only. Do **not** prefix every bullet or heading in the same turn.

The **first line** of each assistant turn for this command MUST begin with: **`Code Review`**

Continuation lines within the same turn (sub-items, indented details, bullet lists, tables) do NOT repeat the badge. Only the opening line carries it.

Apply the badge on the opening line of turns that contain: review headings, status/progress messages, error messages, and confirmations.

**Format:** **`Code Review`** (bold backtick-wrapped) as the **first element** on the **opening line** of the turn.
