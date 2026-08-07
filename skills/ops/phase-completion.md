# Phase 4 completion and dashboards

> **Parent:** `~/.claude/skills/ops/SKILL.md` — Non-negotiables #3, #4, #6, #7, #8, #12 govern completion behavior.

## Phase 4 — Completion

Phase 4 triggers when every task has reached a **terminal status** — `completed`, `failed`, `blocked`, `deleted`, or `cancelled` — not only when every task is `completed`. Phase 4 is where durable content is relocated to its real home (step 9a) before the run's scaffolding is deleted (step 9b); a run that never reaches Phase 4 strands whatever it produced and leaves its board sitting on disk, which Non-negotiable #12 already treats as hiding content rather than preserving it. A run containing a `failed` or `blocked` task therefore still walks the full phase.

Such a run is **not** a clean run, and the completion output must say so plainly: render the **Run Outcome** block (see Status Dashboard below) above the progress bar rather than letting "N/M complete" stand as the only signal. The completion menu at step 10 is still offered regardless — a user may legitimately want to merge partial work, open a pull request against it, or discard — so it is never gated on every task having reached `completed`.

**Empty-subset rule.** Several steps below compute a figure, or decide whether to persist one, from a subset of this run's tasks rather than the full board — `completed` tasks only, or the adaptations logged this run, for instance. An all-failure run, which the broadening above exists to admit, can leave that subset empty even while the board itself is not. Two consequences follow, and steps 4a and 7a below each point back here rather than restating their own version: **first**, a figure computed from an empty subset is not computed at all — no placeholder, no zero standing in for a real measurement — and the write that figure feeds is skipped, with the completion output stating plainly that it was skipped and which subset came up empty. **Second**, a gate that decides whether to persist a record by checking one subset for emptiness must not read that emptiness as proof the whole record is empty: a different, non-empty subset of the same run can still hold something worth keeping.

**If `tasks.length == 1` (single-task run):** collapse Phase 4 to steps 1, 2, 9, and 10 only — plus the ledger capture (step 7a). The collapse trims steps 3–8; it does not touch step 9's internal structure, so all three of step 9's sub-steps still run on a single-task run: 9a's relocation sweep, 9b's unconditional delete, and 9c's verify-and-report. Skip steps 3–8 (include timing and file list in step 10 instead; compute per-type adaptation counts inline for step 7a even though the full step-7 summary is skipped; also compute `reflection_action_counts` and `triage_confidence_dist` inline using the same derivation as the multi-task path). Timing on this path is written at step 9a rather than step 4a, since step 4a is skipped along with the rest of step 4; 9a's destination table names this explicitly, so a reader does not conclude timing is simply lost. The collapsed path runs the **step-7a ledger capture before step 9b** deletes the board, applying step 7a's gate exactly as written there, carve-out included — see step 7a for the write/skip condition. Step 10 is one concise paragraph: when the lone task's terminal status is not `completed`, open with that outcome stated plainly — mirroring step 7's run-outcome-first rule — before the rest of the paragraph; a task that completed cleanly skips straight to the summary. Then: what was done, file(s) changed, actual duration, next steps, and the 9c Cleanup block's relocation result and cleanup line, so that 9c's "every run that reaches Phase 4" claim holds on this path too.

**Otherwise (multi-task run):** execute all 10 steps as specified below.

1. **Confirm all agents have finished** — read the state file and verify no tasks are `"in_progress"`. If any agent is still running, wait for it to return before proceeding — under detached dispatch this means waiting at a beat for outstanding completion notifications, not spinning in a busy loop, and not merely checking once and moving on. Never report completion while agents are still active.
2. **Verify deliverables exist on disk** — for every deliverable task whose status is `completed`, check that it produced a real file. Read (or at minimum glob for) each expected artifact. If a `completed` deliverable task's file is missing or empty, the workflow is **not complete** — dispatch the appropriate agent to create it before proceeding, and run that dispatch in the **foreground**: step 3 follows immediately with no check between them, so a still-running deliverable dispatch would leave step 3's verifier to run its final pass against an incomplete deliverable set and report a pass that isn't earned yet. A deliverable task whose terminal status is `failed` or `blocked` is **exempt** from this check — it produced no deliverable to verify, and Phase 4 does not dispatch an agent to manufacture one; its missing output is reported as part of the Run Outcome (see Status Dashboard below), not repaired. Never report completion based on chat output alone for a `completed` task; the user should not have to ask "where is the document?" (Non-negotiable — see #4.)
3. **Run a final verification pass** — if the work involved code changes, dispatch a **verifier** agent in the **foreground** to run the full test suite against the combined changes, since this dispatch is a named foreground exception in `dispatch-policy.md` and the last correctness check before completion is reported. This catches integration issues that per-task verification may miss.

> **Re-entrant guard, immediately before step 4:** re-run the zero-in-progress check from step 1 — read the state file again and verify no tasks are `"in_progress"`. Steps 2 and 3 dispatch agents of their own, so by this point the phase may have put new work in flight itself; step 4 must not proceed until that work has also returned.

4. **Compute timing summary** — (Non-negotiable — see #3.) Read all task entries from the state file. Calculate:
   - **Total wall time** — from the first task's `started_at` to the last task's `completed_at`.
   - **Total estimated time** — sum of all `estimated_minutes`.
   - **Per-stage totals** — estimated vs actual durations grouped by `stage`.
   - **Per-task durations** — estimated vs actual for each task.
   - **Variance** — percentage over/under estimate per task and overall. Flag tasks that exceeded their estimate by more than 2x.
   - **Longest task** — flag the slowest task (useful for future optimization).
   - **Estimation accuracy** — overall ratio of actual to estimated. Feed significant variances into cross-run learning (e.g., "verification tasks in this project consistently take 2x the estimate"). This ratio covers every task on the board, including any that ended `failed` or `blocked`; it is a different, wider population than the ratio step 4a below persists to the calibration file, and the two are not expected to match.

   > **Reference:** See `~/.claude/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, model escalation, calibration, idle time, background notification pickup). If the file is missing, proceed using the bullet points above.

   **4a. Write this run's timing data to the calibration file directly.** After computing the timing summary above, or reading the same per-task fields directly from the board on paths where step 4 is skipped, write this run's per-agent-type durations and its run-level estimate ratio — both computed over `completed` tasks only, a narrower population than step 4's dashboard ratio above — to the timing calibration file in the project memory directory (`~/.claude/projects/<project>/memory/feedback_ops_timing_patterns.md`). The write:

   - **Filters to `completed` tasks only, before the threshold gate below runs.** Restrict the input set to tasks whose `status` is `completed` first, ahead of any other check in this write. Per `timing-edge-cases.md` rule 1, a retried task's `duration_seconds` is the total across every attempt, so a task that failed at the loop cap would otherwise contribute its full summed failure duration to the rolling average as though it were one successful dispatch. A failed task's duration measures how long failing took, which is not evidence about how long the work takes, so it is excluded outright rather than folded in and relied on to be caught later — the outlier exclusion in `timing-calibrator/SKILL.md` keys on duration magnitude, not status, and does not substitute for this filter.
   - **Is threshold-gated on that filtered set — not on the unfiltered board.** Skip the write entirely when the filtered set is empty. Testing the unfiltered board here would be wrong: every returning task records a duration, `failed` included, so a gate that checked "any dispatch with a recorded duration" before filtering would pass on a run where every task failed, and only the filter afterward would empty the set — after the gate had already let the write proceed. This is the empty-subset rule above: a run with nothing left to calibrate from, once filtered, skips the write, and the completion output says so rather than letting the write proceed against nothing.
   - **Is a direct, non-interactive write.** It does not route through `/timing-calibrator capture`. Invoking a skill here would halt the completion phase and require an `/ops resume` before the run could finish, the same reason the step 7a ledger capture writes its own file directly rather than routing through `/cross-memory save`.
   - **Is keyed by project.** The file lives in this project's memory directory; a record never applies to another project.
   - **Recomputes the per-agent-type averages and appends the run-level entry.** Both halves of the file update on every write, both drawing only from the completed-task filter above: recompute each dispatched agent type's rolling average under `## Estimation Calibration` from this run's completed-task durations, then append this run's estimate ratio, computed from the same completed-task filter, as a new entry under `## Run-Level Aggregate`, matching the shape of the entries already present in that section. See `~/.claude/skills/timing-calibrator/SKILL.md` → the `capture` command's update procedure for the weighted-average formula, the 10-run sliding window, and the rule that excludes tasks over 3x estimate from the averages while still recording them as outliers.
   - **Leaves `/timing-calibrator` as the user-invoked path.** The skill is still there for a full recomputation on demand; the pipeline does not call it.

   **Hard ordering invariant:** this write happens **before** step 9b deletes the board, because the durations it records live on the board. There is no path in which the board is deleted before this write: the record derives entirely from the board's per-task `estimated_minutes`, `duration_seconds`, and `agent_type` fields, so a delete-first ordering would leave nothing to write.

5. **Compute cost estimate (opt-in)** — Skip this step unless the user invoked with `--cost` flag or explicitly asked for cost information. When enabled, estimate token usage and cost per task based on `model_used`, `attempts`, and agent type. Prefer per-task token estimation from observed tool-use patterns; fall back to agent-type baselines only when that signal isn't available.

   > **Reference:** See `~/.claude/skills/ops/cost-tracking.md` for token estimation heuristics, model pricing, and cost dashboard format. If the file is missing, proceed without cost tracking.

6. Display the final task board (with per-task durations).
7. **State the run outcome first, then summarize.** When the run contains any task in a non-`completed` terminal status (`failed`, `blocked`, `deleted`, `cancelled`), open this step's output with that fact stated plainly — see Status Dashboard's Run Outcome block above — before the rest of the summary; a clean run skips straight to the summary below. Summarize: what was accomplished, how many tasks, retries, escalations, the reflection-beat count (number of `adaptations` entries with `type: reflection` recorded this run), the re-plan count (number of `adaptations` entries with `type: replan` recorded this run), the preflight-yield count (number of `adaptations` entries with `type: preflight-yield` recorded this run; optionally broken down by yield value (`changed-brief` / `confirmed` / `no-yield`) or by `query_type` when the sub-field is present), the health-action count (number of `adaptations` entries with `type: health-action` recorded this run), the applied-prior count (number of `adaptations` entries with `type: prior-applied` recorded this run), the budget line when a budget was set (consumed vs. ceiling — `budget.consumed_so_far` of `budget.ceiling` dispatches — plus the budget-escalation count, the number of `adaptations` entries with `type: budget-escalation` recorded this run; **omit the budget line entirely on a run with no budget set** — no empty or zero budget line appears on a no-budget run), total time (and estimated cost if `--cost` was set). The budget line renders independent of `--cost`: a dispatch-count budget needs no cost heuristics, so it appears whenever a budget was set whether or not `--cost` was also passed.

   **7a. Capture the run's adaptations to the durable ledger.** After computing the per-type counts above, and **before** step 9b deletes this run's board file, write a per-run rollup record to the durable adaptation ledger in the project memory directory (`~/.claude/projects/<project>/memory/`). The record carries the `run_id`, the project slug, the per-`type` adaptation counts just computed (`reflection` / `promotion` / `replan` / `preflight-yield` / `health-action` / `prior-applied` / `budget-escalation`), two derived breakdown fields — `reflection_action_counts` (filter `adaptations` to `type=="reflection"`, group by `action_taken`, emit all six enum keys with zero for absent values) and `triage_confidence_dist` (scan every task for a non-null `triage_confidence.level` (in practice only the triage anchor task carries one — the single task on trivial runs, the classifying task on pipeline runs) and increment its `high`/`medium`/`low` counter; then filter `adaptations` to `type=="promotion"`, group by `action_taken` into the three promotion outcomes for the nested `promotion` sub-block) — the file-pairs that forced any parallel-to-sequential adaptation this run, the plan-validation tier, whether a critic REVISE occurred, and `terminal_failure_count` (count the tasks on the board whose `status` is `failed` or `blocked` — excluding `deleted` and `cancelled`, which are user-initiated removals rather than failures, so a run where the user dropped a task through the remove-task flow or the mid-run skip command and everything else completed still reads zero — so a rollup can be told apart from a fully clean run at the same validation tier) (see `state-schema.md` → adaptation ledger for the record shape). The write:

   - **Is threshold-gated, with a carve-out for terminal failure.** Skip the write when the run produced **zero actionable adaptations** — a run of only `no-concern` reflections has nothing worth persisting — **unless** `terminal_failure_count` (computed above) is non-zero. This is the empty-subset rule's second consequence: a task that exhausts the Verify → Fix loop cap appends no `adaptations` entry of any type, so the adaptations subset going empty on such a run is not proof the whole record is empty — `terminal_failure_count` is drawn from a different subset (task status, not adaptation entries) and can still be the plainest thing worth persisting. Capture when the run made at least one actionable adaptation, when `terminal_failure_count` is non-zero, or both.
   - **Is redacted unconditionally and non-interactively.** Run the record body through **Passes A and B** of the redaction pipeline (`skills/cross-memory/redaction.md` — the `<private>` strip pass and the regex denylist pass) before writing. These two passes run non-interactively: the confirmation gate is **not** invoked, because this is a default-on, no-prompt write. There is no opt-out from redaction on this persistent file.
   - **Is keyed by project slug.** The record is stored under this project's slug; a record never applies to another project.
   - **Applies the rolling 10-run window on write.** Append the new record, then trim the ledger to the most recent 10 runs for this project.
   - **Writes the dedicated ledger file directly.** This is a non-interactive write to the dedicated ledger file — it does not route through `/cross-memory save`.

   **Hard ordering invariant:** the capture writes the ledger **before** this run's board file is deleted in step 9b. There is no path in which the board is deleted before the ledger is written — the ledger derives entirely from the board's `adaptations` and `triage_confidence`, so a delete-first ordering would persist nothing. The `--no-adaptation-memory` flag skips this capture step entirely for the run.
8. List all files changed across all agents.

> **Re-entrant guard, immediately before step 9:** re-run the zero-in-progress check once more — read the state file and verify no tasks are `"in_progress"` before step 9's sweep begins. This confirms that nothing steps 1 through 8 put in flight (the deliverable dispatch in step 2, the verifier in step 3, the ledger capture in step 7a) is still running as cleanup starts. It does not, and cannot, cover work that step 9a itself puts in flight after this point. See the guard immediately before step 9b for that.

9. **Clean up ephemeral (short-lived; this run only) temp files, handoffs, state, and advisory preflight run artifacts.** This runs as three ordered sub-steps: 9a sweeps for anything durable and relocates it, 9b then deletes unconditionally, and 9c verifies the deletes landed and renders the Cleanup block.

   **9a. Durable-content relocation sweep (runs before any delete).** Before any delete, sweep this run's ephemeral scaffolding (the board file, the save file if one exists, and this run's handoff files) for content that outlives the run, and route each item to its real home. An item already captured through its normal channel earlier in the run (a handoff written at its stage transition, the step 4a timing write, or the step 7a ledger record) does not need a second relocation here; this sweep exists to catch what a normal channel would otherwise miss. Any dispatch or nested-skill invocation the sweep itself makes to relocate content, such as the documentor dispatch below for non-obvious decisions, runs in the **foreground** and must return before 9b begins: the relocating agent may well be reading the very board or handoff files 9b is about to delete.

   | Content found in ephemeral scaffolding | Its real home |
   | :--- | :--- |
   | Discovered follow-up work this run did not do | The plan doc under `docs/plan/` when the run has one, and the relocation report (9c) when it does not |
   | Unresolved findings and anything under a handoff's `### Open items` heading | Surfaced explicitly in the relocation report (9c), so the user sees it without reading a deleted file |
   | Non-obvious decisions made mid-run that later work depends on | Documentation (dispatch `documentor`) or the plan doc |
   | Investigation or forensic evidence that explains why a change took the shape it did | The commit message body when a commit for this work is still to be made, and the documentation for the change otherwise |
   | Cross-run adaptation patterns | The durable adaptation ledger, via step 7a. When step 7a did not run (the trivial path never reaches Phase 4's numbered steps), the entity running this sweep (`phase-intake.md`'s On-result sweep) performs that same write itself, following 7a's procedure — gate, carve-out, and record shape included, exactly as written there. |
   | This run's per-task durations and estimate variance | The timing calibration file, via step 4a. When step 4a did not run (the single-task collapse, or the trivial path), the entity running this sweep (9a on the collapsed path, or `phase-intake.md`'s On-result sweep on the trivial path) performs that same write itself, following 4a's procedure. |
   | Durable user preferences or project facts learned this run | `/cross-memory save` |
   | Dispatch audit trail | `docs/ops-dispatch-log.md`, and only when `--dispatch-log` is set |

   The sweep **records** what it relocates; rendering happens later, at 9c. Each recorded entry names the content and the destination it went to, specifically enough that a reader could go find it. If the sweep finds nothing durable, record that fact and proceed. An empty sweep is a normal outcome, not a signal that something is wrong. If the sweep finds something durable with no home on the table above, record it as an item still needing a home so it surfaces in the relocation report (9c) rather than getting silently dropped. Never retain the board as a substitute for finding it a home.

   Both the sweep's own record of what it relocated and the board's `worktrees_created` array must still be readable after this point, even though 9b is about to delete every file that currently holds them. **9a writes a cleanup record file, `.ops-state/<run-id>-cleanup.json`, fresh, before 9b's deletes.** It holds two things: the relocation record (one entry per item the sweep relocated, naming the content and the destination it went to) and the `worktrees_created` array copied verbatim from the board. It exists for one reason: it is the only thing that carries cleanup state across 9b's deletes, because nothing else does. See `state-schema.md` for its schema.

   > **Re-entrant guard, immediately before step 9b:** re-run the zero-in-progress check once more, reading the state file and verifying no tasks are `"in_progress"` before 9b's first delete. 9a may have put new work in flight itself (a documentor dispatch to relocate non-obvious decisions, for instance), which is exactly why the earlier guard immediately before step 9 is not sufficient here: it fires before 9a has dispatched anything. This is the last point in the phase at which a zero-in-progress check is evaluable at all: 9b deletes the very state file the check reads. Every step after it, including 9c's report, the completion-options menu in step 10, and the worktree removal it can reach, inherits this checkpoint's guarantee and cannot re-derive it: a downstream step trying to check for itself would be reading a file that no longer exists.

   **9b. Delete (unconditional).** Content value is not an input to this decision: the board, the save file, and the handoffs are deleted regardless of how valuable their contents are. `.ops-state/` and `.agents/handoffs/` are gitignored: they are excluded from the repository, invisible to code review, and unreadable by any future session that does not go digging for them. A file scheduled for deletion is the worst available home for anything worth keeping. If the content mattered, step 9a already moved it to a real home. If step 9a did not move it, it was not worth keeping. Both branches end in deletion.

   The cleanup record 9a just wrote is not an exception to this. It is deleted, just not here: step 10 deletes it, once the worktree-cleanup-by-provenance procedure and the user's chosen completion option have both finished reading it. That deferral is a sequencing consequence of step 10 needing the file, not a judgment that the file is worth keeping, and it is never described as exempt, preserved, or retained. It is not on the never-delete list below. The run still ends with none of its own scaffolding on disk; step 10 is simply where that last piece happens.

   "This board anchors retained evidence," "it holds the multi-stage history," and "it is the forensic trail for this run" are **not** valid reasons to retain it, and neither is any other rationalization built on the same shape. These three are named because they are the ones that surface in practice, not because they are the only ones that could: the closing rule above, content value is not an input to this decision, is categorical and admits no fourth exception dressed up in different language. Each one is a signal that step 9a was skipped or done carelessly. The correct response is to go back and run the sweep properly, then delete. It is never to keep the board.

   > **Run-id confirmation gate:** For each `<run-id>`-bearing path below, confirm the embedded `<run-id>` segment matches the active run's `run_id` field from the state file before issuing the `rm`. For `_tmp_*` (which carries no `<run-id>` segment), apply the no-bulk-delete rule: remove files one at a time. Never issue a directory-level or recursive delete for any path.

   **Delete (this run only):**
   - `_tmp_*` — temporary files created during this run; delete only the files this run created, one `rm` per file. Never `rm _tmp_*` — the glob also catches another agent's scratch files and prior runs' artifacts.
   - `.agents/handoffs/<run_id>/` — this run's handoff subdirectory; verify the `<run_id>` segment matches the active `run_id` before each `rm`
   - `.code-intel/runs/<run-id>/` — ephemeral run-scoped impact-analysis reports and JSON sidecars for this run only; confirm the `<run-id>` segment matches before each `rm`
   - `.corpus-search/runs/<run-id>/` — ephemeral corpus-search reports and JSON sidecars for this run only; confirm the `<run-id>` segment matches before each `rm`
   - `.ops-state/<run-id>-board.json` — this run's state file; confirm the `<run-id>` segment matches before `rm`
   - `.ops-state/<run-id>-save.json` — this run's save file; delete only if the file is present; confirm the `<run-id>` segment matches before `rm`

   **Deleted, but not here:** the cleanup record 9a wrote, `.ops-state/<run-id>-cleanup.json`, is not deleted in this step. Step 10 deletes it, once the worktree-cleanup-by-provenance procedure and the chosen completion option have both finished reading it. This is not an exception to the delete list above: the file is going away, only after its last readers, not instead of them. It is not on the never-delete list below.

   **Never delete:**
   - `docs/plan/` — plan documents are persistent deliverable artifacts; provenance (origin — which run created it) does not make them ephemeral
   - `docs/ops-dispatch-log.md` — persistent audit trail written only when `--dispatch-log` is set (see `dispatch-log.md`)
   - The durable adaptation ledger in the project memory directory (`~/.claude/projects/<project>/memory/`) — the cross-run learning corpus; it must survive the board's deletion, which is the entire reason it lives outside the per-run board
   - Any other run's handoff subdirectory under `.agents/handoffs/` or state files under `.ops-state/`
   - `.code-intel/index.sqlite` — persistent shared infrastructure
   - `.code-intel/index.sqlite-wal` and `.code-intel/index.sqlite-shm` — WAL/SHM sidecars (`.sqlite-wal` and `.sqlite-shm` — SQLite companion files; deleting them can corrupt the database)
   - `.code-intel/runs/` — the parent runs directory itself
   - `.corpus-search/` — the parent corpus-search directory
   - `docs/corpus-search/` — corpus-search has no persistent index (unlike code-intel's SQLite DB); only the run-scoped subdirectory under `.corpus-search/runs/<run-id>/` is ephemeral

   This list is closed: no path is added to it at runtime on the basis of a judgment made during the run. Anything a run wants to preserve goes through step 9a's relocation, never through an ad-hoc addition here.

   **9c. Verify the deletes landed, then render the Cleanup block.** After the deletes, confirm each targeted path no longer exists on disk. Use the same per-path enumeration the deletes used. If any target still exists, cleanup has not completed. Retry the delete once, and if it still exists, report the failure explicitly to the user with the path and the reason. Never report run completion with the board still on disk and no explanation for why.

   Once the deletes are verified, render a single **Cleanup** block as part of the completion output, immediately before step 10's menu. This is its rendering site: no other step in the phase renders it. The block has two parts:

   1. **Relocation report:** one line per item recorded in the cleanup record file 9a wrote (`.ops-state/<run-id>-cleanup.json`), naming the content and the destination it went to, so a reader can go find it. When the sweep found nothing durable, render a single line saying so; that is a normal outcome, not a gap in the report.
   2. **Cleanup line:** the existing one-line shape naming what was deleted:

      `Cleanup: board + N handoff file(s) removed[ + save file]; <M item(s) relocated: brief list> | nothing durable to relocate`

   Both parts are mandatory and appear on every run that reaches Phase 4, including single-task runs and runs ending in a terminal failure; a run with nothing to relocate still renders the "nothing durable" line rather than omitting the relocation report entirely.
10. **Present completion options** — the step 9c Cleanup block has already rendered immediately above; now render the structured four-option menu (merge locally / push and PR / keep branch / discard) and capture user decision before exiting.

   > **Reference:** You MUST Read `~/.claude/skills/ops/completion-options.md` for the four-option menu, per-option workflow, destructive-option confirmation gate, and worktree-cleanup-by-provenance procedure. If the file is missing, fall back to suggesting natural next steps (e.g., "Ready for commit" or "Run the full test suite").

   **Delete the cleanup record once its readers are done.** After the chosen completion option's procedure and the worktree-cleanup-by-provenance check have both finished, confirm the `<run-id>` segment in `.ops-state/<run-id>-cleanup.json` against the cleanup record's own `run_id` field and the run this Phase 4 execution is completing. The board is already gone by this point, so there is no still-live state file to re-read the way every other path's gate works here; this is an internal-consistency check between the path, the record's own field, and the run being completed, not a re-derivation from the board. Only then delete the file and confirm the path no longer exists on disk. This holds even when that procedure ends in a surfaced failure, such as a failed fast-forward merge or a failed pull-request creation: the completion option's procedure and the worktree-cleanup-by-provenance check are done reading the record either way, and a run whose completion option failed is the worst case to leave this scaffolding behind on, since the user's attention is already on the failure. Retry the delete once on failure; if it still exists, report the failure explicitly to the user with the path and the reason, the same discipline 9c applies to the board, save file, and handoffs. The run may not report completion while this file is still present. It is the last piece of this run's own scaffolding left on disk, and once it is gone, nothing of this run remains outside its real deliverables.

---

## Status Dashboard

Show the full dashboard on `status` command and at completion. For runs with ≥ 3 non-internal tasks, also show at stage transitions. For runs with ≤ 2 non-internal tasks, stage transitions collapse to a one-line status — see Non-negotiables #8.

Render the dashboard using native Markdown — output the `##` headers, `|...|` tables, and `**bold**` directly into chat. **Do NOT wrap your dashboard output in a fenced code block** (triple backticks); fencing causes the chat UI to render it as gray raw text instead of formatted sections.

Past user incident: the team manager wrapped its dashboard output in fences and the renderer showed raw `##` and `|` characters in a gray box. The unfence-by-default rule prevents recurrence.

---

## Team Manager — Status

### Run Outcome
(Rendered only when at least one task ended in a non-`completed` terminal status — `failed`, `blocked`, `deleted`, or `cancelled`. States this plainly, above every other subsection here including Progress, naming the affected task(s) and their terminal status, so a run that did not fully pass never reads as a clean success. Omitted entirely on a run where every task completed.)

### Active
- <agent> → Task #N: "<subject>" (in_progress, Xs elapsed) [health indicator]

Health indicators: ✓ ON TRACK (elapsed < 1.5× estimate), ⚠️ SLOW (1.5–2.5×), 🔴 OVERRUN (> 2.5×; a sustained OVERRUN may trigger a diagnose-and-recover action — see Phase 3 Step 4 in `phase-dispatch.md`), 👻 ORPHAN? (elapsed > agent-type timeout, no completion received)

### Task Board
| # | Task | Agent | Status | Est. | Actual | Blocked By |
|---|------|-------|--------|------|--------|------------|

### Progress
[████░░░░░░░░░░░░] N/M tasks complete (X%) — elapsed Xm / est. Xm total

### Timing
| Stage | Tasks | Est. | Actual | Variance |
|-------|-------|------|--------|----------|
| **Total** | | | | |

(When step 4a's calibration write or step 7a's ledger capture was skipped this run under the empty-subset rule, name it here in one line: `Skipped: <write> — <subset> empty this run.` Omit this line entirely when neither write was skipped.)

### Cost
(Opt-in: rendered only when `--cost` was set or the user asked. Omit from mid-run dashboards. See `cost-tracking.md` for format.)

### Preflight
- (show checklist if preflight was run this session)

### Adaptations
- (list any mid-run adaptations made — strategy switches, plan adjustments, and reflection-beat notes from the `adaptations` log; reflection-beat entries have `type: reflection` and show the finishing stage plus the `action_taken` (pipeline route only; never emitted on trivial runs); re-plan entries have `type: replan` and show the finishing stage plus the `action_taken` (`logged`, `replanned`, or `replan-escalated`); preflight-yield entries have `type: preflight-yield` and show the answering preflight kind (the `query_type`, e.g. `find_callers` or `evidence_search`) plus the categorical yield value (`changed-brief`, `confirmed`, or `no-yield`); health-action entries have `type: health-action` and show the affected task plus the `action_taken` (`diagnosed-alive`, `re-dispatched`, or `re-dispatch-escalated`); prior-applied entries have `type: prior-applied` and show which consumer fired (e.g. `tier-upgrade` or `file-conflict`) plus what default it changed; budget-escalation entries have `type: budget-escalation` and show the cost-affecting choice point plus the `action_taken` (`budget-near`, `budget-escalated`, `budget-deferred`, or `budget-spent`))

### Escalations
- (none)

---

The Timing section is mandatory in every dashboard display — see Non-negotiables #7. Show elapsed time for in-progress tasks and final duration for completed tasks. At completion, always include total wall time, per-stage totals, and the longest task.

> **Reference:** See `~/.claude/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, model escalation, calibration, idle time, background notification pickup). If the file is missing, proceed using the dashboard template above.
