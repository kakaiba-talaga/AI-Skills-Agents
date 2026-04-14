<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Cleanup Stage (Deslop Pass)

The Cleanup stage runs after Verify and before Reflect. It applies safe linter auto-fixes to files changed during the current iteration, then re-verifies to ensure nothing broke. This prevents AI-generated slop (unnecessary verbosity, formatting drift, unused imports, trailing whitespace) from accumulating across iterations.

**When it runs:** Every iteration where `deslop_enabled` is `true` in state (the default). When `deslop_enabled` is `false` (`--no-deslop` was passed), the stage is skipped entirely -- advance from Verify directly to Reflect and show `⏭️ 5) Cleanup (skipped: --no-deslop)` in the checklist.

**Scope boundary:** Only files listed in `context.modified_files` at the time Cleanup begins. Never broaden the cleanup to unrelated files. If the linter touches a file outside this set (e.g., due to an import chain fix), discard that change.

**What the linter fixes (safe, no-ask):**

- Formatting (indentation, line length, trailing whitespace, final newline)
- Import sorting and unused import removal
- Trailing commas, semicolons (per project style)
- Trivial linter rule violations the project's tooling flags as auto-fixable

**What the linter does NOT fix without confirmation:**

- Type changes (widening, narrowing, adding/removing generics)
- Logic changes (rewriting conditionals, reordering operations)
- Suppressions (adding `// eslint-disable`, `# noqa`, `#[allow(...)]`)
- Behavioral changes (different error handling, fallback paths)

In headless mode, skip uncertain fixes silently rather than prompting.

**Deslop escalation:** After the lightweight linter pass completes, evaluate whether to escalate to the full `/deslop` skill for structural cleanup. The linter handles formatting and import issues; `/deslop` handles structural bloat (dead code, unnecessary abstractions, redundant comments, over-engineering) that the linter cannot detect.

**Escalation triggers (any one is sufficient):**
- `full_deslop_enabled` is `true` in state (user passed `--full-deslop`)
- The current iteration added a significant amount of new code: count the lines added in `context.modified_files` using `git diff --stat`; if >100 lines were added in this iteration, escalate (more code = more potential slop)
- The loop is on iteration 3 or higher -- slop accumulates across iterations, so periodic deep cleanup is valuable
- The lightweight linter pass reported 0 fixes but the iteration generated substantial new code (>50 lines) -- this suggests structural issues the linter can't catch

**How escalation works:**
1. Check if `/deslop` is available (file exists at `~/.claude/skills/deslop/SKILL.md`). If not, skip escalation silently and log: "Deslop escalation skipped — /deslop skill not available."
2. Invoke `/deslop --conservative` on the files in `context.modified_files`. Conservative mode ensures only HIGH-confidence deletions are auto-applied -- deslop will not undo work done in the Execute stage.
3. If deslop makes changes, the regression re-verification (next step) covers both linter changes and deslop changes together.
4. If deslop makes no changes (all findings were report-only), proceed to regression re-verification with just the linter changes.
5. Record deslop results in `context.notes`: "Deslop escalation: [N findings applied, M report-only]" or "Deslop escalation: skipped (no triggers)" or "Deslop escalation: skipped (skill unavailable)".

**On deslop regression:** If regression re-verification fails AFTER deslop changes were applied, revert BOTH deslop and linter changes (revert all cleanup), log the regression, and proceed to Reflect with the pre-cleanup code. The same revert logic as the existing linter regression applies.

**When deslop escalation is skipped:**
- `deslop_enabled` is `false` (`--no-deslop` was passed) -- the entire Cleanup stage is skipped, so escalation never runs
- No escalation triggers are met and `full_deslop_enabled` is `false`
- `/deslop` skill file is not available

**Regression re-verification:** After applying fixes, re-run the same verification checks used in the Verify stage. If the template defines `hooks.verify.command`, use that. Otherwise, use the project's test/build/lint commands. Read the output and confirm all checks pass.

**On regression failure:** Revert cleanup changes for the affected files (`git checkout -- <file>`), log "Cleanup reverted: [failure reason]" in `context.notes`, and proceed to Reflect with the pre-cleanup code. A cleanup regression does NOT block the loop or fail the iteration.

**On success:** Record in `context.notes`: which files were cleaned, what fixes were applied, and that regression re-verification passed. Append any newly modified files to `context.modified_files`.

**Template hook support:** Templates may define `hooks.cleanup.pre` and `hooks.cleanup.post` commands. If defined, run `pre` before the linter pass and `post` after regression re-verification succeeds.

**Output format for Cleanup stage:**

```text
**`Ralph Loop`** Iteration N -- Cleanup

Ralph Wiggum Loop Progress (Iteration N)

✅ 1) Frame the task.
✅ 2) Plan the smallest useful step.
✅ 3) Execute
✅ 4) Verify
🟦 5) Cleanup (deslop)
🟦 6) Reflect and Adjust

### Cleanup summary

- **Scope:** N file(s) from this iteration
- **Linter:** [tool name] with auto-fix
- **Fixes applied:** [count] ([brief list: unused imports, formatting, etc.])
- **Regression re-verification:** PASS | FAIL (reverted)
```
