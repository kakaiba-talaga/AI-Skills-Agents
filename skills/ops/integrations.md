<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

## Deslop Integration

After all verify tasks pass and before code review begins, the team manager runs `/deslop` on the files modified during the run. This cleans up AI-generated structural bloat (unnecessary abstractions, redundant comments, dead code, verbose patterns) that executors naturally produce.

**Default behavior:** Deslop is **enabled by default**. Use `--no-deslop` to skip.

**How it works:**

1. After all verify tasks complete, collect the list of files modified by executor agents during the run.
2. Check if the `/deslop` skill is available (file exists at `~/.claude/skills/deslop/SKILL.md`). If not, skip silently and log: "Adapted: skipped deslop — skill not available."

**Precondition before invoking (below).** Zero tasks are in progress before deslop's savepoint runs. Deslop's savepoint (`~/.claude/skills/deslop/SKILL.md` § Step 2 — Create Savepoint) runs `git stash push` with no pathspec — a whole-tree operation on the shared branch. An agent still writing files when that stash fires has its uncommitted output swept into the stash, then keeps writing into a tree that was reverted underneath it. This skill's Parallel Safety Rules (`SKILL.md` § Parallel Safety Rules) already forbid parallelizing git operations on the same branch for the same reason; the file-disjointness escape used elsewhere does not apply here, because a whole-tree stash is disjoint from nothing.

3. Invoke `/deslop --conservative` on the modified file set. Conservative mode ensures only high-confidence deletions are auto-applied — deslop will not undo intentional executor work.
4. After the skill returns, create the internal task row for the deslop pass — `"_internal": true`, `status: "completed"`. `started_at` is the `invoked_at` value already recorded on the `pending_nested_skill` marker. `completed_at` is the moment the skill itself returned, not the moment this step happens to run — unrelated in-flight work can delay the orchestrator's attention past the return, and stamping the row at ritual time would fold that delay into the pass's measured duration. `duration_seconds` is the difference between the two. A `Skill()` call produces no spawn, so no board row can honestly describe the pass as running, which is why it is recorded once finished rather than transitioned through a running state.
5. If deslop makes changes, dispatch a verifier agent, in the foreground, to re-verify the modified files — its verdict selects a destructive branch in the same turn, and a delayed restore would discard work that landed after the verdict was formed. If re-verification fails, revert deslop's changes by restoring **deslop's recorded savepoint** — delegate to deslop's own rollback contract (see `~/.claude/skills/deslop/SKILL.md` § Step 2 — Create Savepoint and § Rollback Strategy). Because deslop runs at the verify→review transition — *before* the Phase-4 commit — the executor's verified work is still uncommitted in the working tree at this point. The savepoint is the only thing that captures that pre-deslop working-tree state (executor changes applied but uncommitted). Restore from it according to which anchor deslop recorded: if deslop stashed a dirty working tree, run `git stash pop` (the recorded `deslop-savepoint-<ISO-timestamp>` stash); if the tree was clean, run `git checkout <savepoint-sha>` (the recorded HEAD SHA). **Do NOT use a bare `git restore <file>` or any restore-from-HEAD/index here** — at this stage the executor's pre-deslop work is uncommitted, so restoring from HEAD/index would discard the executor's verified work, not just deslop's edits. After the savepoint restore, proceed to code review with the restored pre-deslop code. Log: "Adapted: reverted deslop changes — re-verification failed."
6. If deslop makes no changes (all findings were report-only), proceed directly to code review.
7. Include the deslop report summary in the handoff document for the code-reviewer — the reviewer should know what was cleaned and what was left as report-only.

**When deslop is skipped:**

- `--no-deslop` flag is set
- The `/deslop` skill file is not available
- The run produced no code changes (e.g., documentation-only tasks)
- The "Trivial/mechanical changes" edge case applies (verify and review are also skipped)

**Dashboard display:** The deslop task is internal and, since its row is not recorded until the pass has finished, it never appears in the user-facing progress bar or task count while deslop is running. Once recorded, it appears under the collapsed "Internal tasks" section.

**Stage transition:** In interactive mode, the deslop pass runs silently during the verify→review transition. The stage checkpoint after verify mentions deslop results: "Deslop: cleaned N findings in M files" or "Deslop: no changes" or "Deslop: skipped (--no-deslop)".

**After this nested skill returns, do not end the turn and do not write "Handing control back."** A nested-skill return is a mid-loop event (see Non-negotiable #10). The precondition that zero tasks are in progress before deslop's savepoint runs is established above, immediately before the invoke step; not restated here. Before invoking, apply a targeted `Edit` setting `pending_nested_skill` on the state file's root object to `skill: "/deslop"`, `resume_phase: "phase-3-deslop-stage"`, and `resume_notes: "integrations.md steps 5-6"`, then `Read` the file back to confirm the field matches and the document still parses as valid JSON. After the skill returns, re-read the state file, create the internal task row per step 4, then follow integrations.md steps 5–6 — if deslop made changes, re-dispatch the verifier against the modified files; if deslop made no changes, proceed to the code-review stage. Either branch: do not end the turn. Then apply a targeted `Edit` clearing `pending_nested_skill` back to `null`, `Read` the file back to verify, and continue.

---

## Ralph Loop Integration

When invoked with `ralph` (e.g., `/ops ralph "improve test coverage to 80%"`), the team manager wraps its entire workflow inside a `/ralph-loop` persistence loop:

1. The ralph loop provides the outer iteration — each loop pass runs one full team-manager cycle (plan → implement → verify → review).
2. After each cycle, the ralph loop's **Reflect** stage evaluates whether the acceptance criteria (e.g., 80% coverage) have been met.
3. If not met, the ralph loop starts a new iteration — the team manager re-plans based on what's still missing, creates new tasks, and dispatches again.
4. Each ralph iteration runs as a complete team-manager cycle in its own right, including that cycle's own Phase 4 completion. Phase 4 deletes the iteration's task board and its handoff subdirectory under `.agents/handoffs/` unconditionally as part of ordinary per-run cleanup, so no handoff document survives from one iteration into the next. Context instead carries forward through the ralph loop's own persisted state file: its `context.summary`, `context.learnings`, and `context.notes` fields, together with the `progress.work_items` array, are what the team manager draws on when planning the next iteration's tasks.

**When to use ralph mode:**

- The goal is metric-driven (accuracy %, test coverage %, performance targets)
- The work requires iterative refinement that can't be fully planned upfront
- You want persistence across potential interruptions

**When NOT to use ralph mode:**

- The work is a one-shot implementation with clear tasks
- The plan is already complete and won't need iteration
