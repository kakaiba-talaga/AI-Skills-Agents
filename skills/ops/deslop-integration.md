<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

## Deslop Integration

After all verify tasks pass and before code review begins, the team manager runs `/deslop` on the files modified during the run. This cleans up AI-generated structural bloat (unnecessary abstractions, redundant comments, dead code, verbose patterns) that executors naturally produce.

**Default behavior:** Deslop is **enabled by default**. Use `--no-deslop` to skip.

**How it works:**

1. After all verify tasks complete, collect the list of files modified by executor agents during the run.
2. Check if the `/deslop` skill is available (file exists at `~/.claude/skills/deslop/SKILL.md`). If not, skip silently and log: "Adapted: skipped deslop — skill not available."
3. Create an internal task (`metadata._internal: true`) for the deslop pass.
4. Invoke `/deslop --conservative` on the modified file set. Conservative mode ensures only high-confidence deletions are auto-applied — deslop will not undo intentional executor work.
5. If deslop makes changes, dispatch a verifier agent to re-verify the modified files. If re-verification fails, revert all deslop changes and proceed to code review with the original (pre-deslop) code. Log: "Adapted: reverted deslop changes — re-verification failed."
6. If deslop makes no changes (all findings were report-only), proceed directly to code review.
7. Include the deslop report summary in the handoff document for the code-reviewer — the reviewer should know what was cleaned and what was left as report-only.

**When deslop is skipped:**

- `--no-deslop` flag is set
- The `/deslop` skill file is not available
- The run produced no code changes (e.g., documentation-only tasks)
- The "Trivial/mechanical changes" edge case applies (verify and review are also skipped)

**Dashboard display:** The deslop task is internal — it does not appear in the user-facing progress bar or task count. It appears under the collapsed "Internal tasks" section.

**Stage transition:** In interactive mode, the deslop pass runs silently during the verify→review transition. The stage checkpoint after verify mentions deslop results: "Deslop: cleaned N findings in M files" or "Deslop: no changes" or "Deslop: skipped (--no-deslop)".
