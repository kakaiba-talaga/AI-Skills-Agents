<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

## Deslop Integration

After all verify tasks pass and before code review begins, the team manager runs `/deslop` on the files modified during the run. This cleans up AI-generated structural bloat (unnecessary abstractions, redundant comments, dead code, verbose patterns) that executors naturally produce.

**Default behavior:** Deslop is **enabled by default**. Use `--no-deslop` to skip.

**How it works:**

1. After all verify tasks complete, collect the list of files modified by executor agents during the run.
2. Check if the `/deslop` skill is available (file exists at `~/.claude/skills/deslop/SKILL.md`). If not, skip silently and log: "Adapted: skipped deslop — skill not available."

**Precondition before invoking (below).** Zero tasks are in progress before deslop's savepoint runs. `in_progress` on the board covers two distinct states here, the same as everywhere else: a dispatch still writing files, and a dispatch already finished whose completion Step 4 has not yet processed (the finished-unprocessed window; see `phase-dispatch.md`'s liveness table). The precondition waits for both alike, because the board alone cannot tell them apart and the risk below is specific to the first case. Deslop's savepoint (`~/.claude/skills/deslop/SKILL.md` § Step 2 — Create Savepoint) runs `git stash push` with no pathspec — a whole-tree operation on the shared branch. An agent still writing files when that stash fires has its uncommitted output swept into the stash, then keeps writing into a tree that was reverted underneath it. This skill's Parallel Safety Rules (`SKILL.md` § Parallel Safety Rules) already forbid parallelizing git operations on the same branch for the same reason; the file-disjointness escape used elsewhere does not apply here, because a whole-tree stash is disjoint from nothing.

3. Invoke `/deslop --conservative` on the modified file set. Conservative mode ensures only high-confidence deletions are auto-applied — deslop will not undo intentional executor work.
4. After the skill returns, create the internal task row for the deslop pass — `"_internal": true`, `status: "completed"`. `started_at` is the `invoked_at` value already recorded on the `pending_nested_skill` marker. `completed_at` is the moment the skill itself returned, not the moment this step happens to run — unrelated in-flight work can delay the orchestrator's attention past the return, and stamping the row at ritual time would fold that delay into the pass's measured duration. `duration_seconds` is the difference between the two. A `Skill()` call produces no spawn for the pass row, so no board row can honestly describe the pass as running, which is why the pass row is recorded once finished rather than transitioned through a running state. That reaches the pass row and nothing else on the board; the spawns this path does make are enumerated below.
5. If deslop makes changes, dispatch a verifier agent, in the foreground, to re-verify the modified files — its verdict selects a destructive branch in the same turn, and a delayed restore would discard work that landed after the verdict was formed. If re-verification fails, revert deslop's changes by restoring **deslop's recorded savepoint** — delegate to deslop's own rollback contract (see `~/.claude/skills/deslop/SKILL.md` § Step 2 — Create Savepoint and § Rollback Strategy). The savepoint is the only recorded anchor for the pre-deslop working-tree state, whatever mix of committed and uncommitted work the tree held when deslop ran. Restore from it according to which anchor deslop recorded: if deslop stashed a dirty working tree, run `git stash pop` (the recorded `deslop-savepoint-<ISO-timestamp>` stash); if the tree was clean, run `git checkout <savepoint-sha>` (the recorded HEAD SHA). **Do NOT use a bare `git restore <file>` or any restore-from-HEAD/index here** — HEAD and the index are not the recorded savepoint, so restoring from either discards whatever the tree held that no commit covers, not just deslop's edits. After the savepoint restore, proceed to code review with the restored pre-deslop code. Log: "Adapted: reverted deslop changes — re-verification failed."
6. If deslop makes no changes (all findings were report-only), proceed directly to code review.
7. Include the deslop report summary in the handoff document for the code-reviewer — the reviewer should know what was cleaned and what was left as report-only.

**The spawns on this path enrol separately.** Three of them exist here, and Non-negotiable #13 binds each. Deslop dispatches a `verifier` per applied batch and a single `code-reviewer` over its cumulative diff; it runs inline in this context, so those Agent-tool calls are this orchestrator's own spawns, not the nested skill's private business. Step 5's re-verification `verifier` is this skill's own. Each of the three gets its own board task, transitioned to `in_progress` in the message that carries its dispatch and closed out when the agent returns (see `orchestrator-obligations.md`). And on a harness that invokes the deslop pass itself through a spawn tool rather than through `Skill()`, Cursor dispatching it via `Task(subagent_type="generalPurpose")` being the case in point, the pass row is a spawn as well: it transitions to `in_progress` in that message and is closed out on return, and step 4's retroactive completed row does not describe it. Tell the two apart by reading back which tool the dispatch actually was, not by which one the pass is usually made with.

**When deslop is skipped:**

- `--no-deslop` flag is set
- The `/deslop` skill file is not available
- The run produced no code changes (e.g., documentation-only tasks)
- The "Trivial/mechanical changes" edge case applies (verify and review are also skipped)

**Dashboard display:** The deslop task is internal and, since its row is not recorded until the pass has finished, it never appears in the user-facing progress bar or task count while deslop is running. Once recorded, it appears under the collapsed "Internal tasks" section.

**Stage transition:** In interactive mode, the deslop pass runs silently during the verify→review transition. The stage checkpoint after verify mentions deslop results: "Deslop: cleaned N findings in M files" or "Deslop: no changes" or "Deslop: skipped (--no-deslop)".

**After this nested skill returns, do not end the turn and do not write "Handing control back."** A nested-skill return is a mid-loop event (see Non-negotiable #10). The precondition that zero tasks are in progress before deslop's savepoint runs is established above, immediately before the invoke step; not restated here. Before invoking, apply a targeted `Edit` setting `pending_nested_skill` on the state file's root object to `skill: "/deslop"`, `resume_phase: "phase-3-deslop-stage"`, and `resume_notes: "if deslop made changes, re-dispatch verifier; if no changes, proceed to code-review stage"`, then `Read` the file back to confirm the field matches and the document still parses as valid JSON. After the skill returns, re-read the state file, settle the pass row, then: if deslop made changes, re-dispatch the verifier against the modified files; if deslop made no changes, proceed to the code-review stage. Settling the pass row branches on which tool the dispatch actually was, read back from the turn that made it, exactly as the enrolment paragraph above requires: a `Skill()` dispatch produced no spawn, so create the retroactive `completed` row per step 4 here; a spawn-tool dispatch already has a row that transitioned to `in_progress` in the message carrying it, so close that row out here instead and do not create a second one. Either branch: do not end the turn. Then apply a targeted `Edit` clearing `pending_nested_skill` back to `null`, `Read` the file back to verify, and continue.

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
