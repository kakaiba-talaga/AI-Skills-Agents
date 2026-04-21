<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

## Deslop Integration

After all verify tasks pass and before code review begins, the team manager runs `/deslop` on the files modified during the run. This cleans up AI-generated structural bloat (unnecessary abstractions, redundant comments, dead code, verbose patterns) that executors naturally produce.

**Default behavior:** Deslop is **enabled by default**. Use `--no-deslop` to skip.

**How it works:**

1. After all verify tasks complete, collect the list of files modified by executor agents during the run.
2. Check if the `/deslop` skill is available (file exists at `~/.claude/skills/deslop/SKILL.md`). If not, skip silently and log: "Adapted: skipped deslop — skill not available."
3. Create an internal task (`"_internal": true` on the task object) for the deslop pass.
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

**After this nested skill returns, do not end the turn and do not write "Handing control back."** A nested-skill return is a mid-loop event (see Non-negotiable #10). Before invoking, write `pending_nested_skill` to the state file with `skill: "/deslop"`, `resume_phase: "phase-3-deslop-stage"`, and `resume_notes: "integrations.md steps 5-6"`. After the skill returns, re-read the state file, follow integrations.md steps 5–6 — if deslop made changes, re-dispatch the verifier against the modified files; if deslop made no changes, proceed to the code-review stage. Either branch: do not end the turn. Then clear `pending_nested_skill` back to `null` and continue.

---

## Ralph Loop Integration

When invoked with `ralph` (e.g., `/ops ralph "improve test coverage to 80%"`), the team manager wraps its entire workflow inside a `/ralph-loop` persistence loop:

1. The ralph loop provides the outer iteration — each loop pass runs one full team-manager cycle (plan → implement → verify → review).
2. After each cycle, the ralph loop's **Reflect** stage evaluates whether the acceptance criteria (e.g., 80% coverage) have been met.
3. If not met, the ralph loop starts a new iteration — the team manager re-plans based on what's still missing, creates new tasks, and dispatches again.
4. The team manager's task board is reset between ralph iterations. Handoff files from the previous iteration persist on disk in `docs/plan/.handoffs/` and carry forward as context — the team manager reads them when planning the next iteration.

**When to use ralph mode:**

- The goal is metric-driven (accuracy %, test coverage %, performance targets)
- The work requires iterative refinement that can't be fully planned upfront
- You want persistence across potential interruptions

**When NOT to use ralph mode:**

- The work is a one-shot implementation with clear tasks
- The plan is already complete and won't need iteration
