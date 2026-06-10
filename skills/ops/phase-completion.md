# Phase 4 completion and dashboards

> **Parent:** `~/.claude/skills/ops/SKILL.md` — Non-negotiables #3, #4, #6, #7, #8 govern completion behavior.

### Phase 4 — Completion

When every task is `completed`:

**If `tasks.length == 1` (single-task run):** collapse Phase 4 to steps 1, 2, 9, and 10 only — plus the ledger capture (step 7a). Skip steps 3–8 (include timing and file list in step 10 instead). The collapsed path runs the **step-7a ledger capture before step 9** deletes the board. The same threshold gate applies: write only when the run produced an actionable adaptation (an actionable `triage_confidence` counts); a run with nothing actionable skips the write. Step 10 is one concise paragraph: what was done, file(s) changed, actual duration, and next steps.

**Otherwise (multi-task run):** execute all 10 steps as specified below.

1. **Confirm all agents have finished** — read the state file and verify no tasks are `"in_progress"`. If any agent is still running, wait for it to return before proceeding. Never report completion while agents are still active.
2. **Verify deliverables exist on disk** — check that every deliverable task produced a real file. Read (or at minimum glob for) each expected artifact. If a deliverable file is missing or empty, the workflow is **not complete** — dispatch the appropriate agent to create it before proceeding. Never report completion based on chat output alone; the user should not have to ask "where is the document?" (Non-negotiable — see #4.)
3. **Run a final verification pass** — if the work involved code changes, dispatch a **verifier** agent to run the full test suite against the combined changes. This catches integration issues that per-task verification may miss.
4. **Compute timing summary** — (Non-negotiable — see #3.) Read all task entries from the state file. Calculate:
   - **Total wall time** — from the first task's `started_at` to the last task's `completed_at`.
   - **Total estimated time** — sum of all `estimated_minutes`.
   - **Per-stage totals** — estimated vs actual durations grouped by `stage`.
   - **Per-task durations** — estimated vs actual for each task.
   - **Variance** — percentage over/under estimate per task and overall. Flag tasks that exceeded their estimate by more than 2x.
   - **Longest task** — flag the slowest task (useful for future optimization).
   - **Estimation accuracy** — overall ratio of actual to estimated. Feed significant variances into cross-run learning (e.g., "verification tasks in this project consistently take 2x the estimate").

   > **Reference:** See `~/.claude/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, model escalation, calibration, idle time). If the file is missing, proceed using the bullet points above.

   > **Reference:** Invoke the `/timing-calibrator capture` skill (see `~/.claude/skills/timing-calibrator/SKILL.md`) with the run's task metadata to persist timing patterns.

5. **Compute cost estimate (opt-in)** — Skip this step unless the user invoked with `--cost` flag or explicitly asked for cost information. When enabled, estimate token usage and cost per task based on `model_used`, `attempts`, and agent type. Prefer per-task token estimation from observed tool-use patterns; fall back to agent-type baselines only when that signal isn't available.

   > **Reference:** See `~/.claude/skills/ops/cost-tracking.md` for token estimation heuristics, model pricing, and cost dashboard format. If the file is missing, proceed without cost tracking.

6. Display the final task board (with per-task durations).
7. Summarize: what was accomplished, how many tasks, retries, escalations, the reflection-beat count (number of `adaptations` entries with `type: reflection` recorded this run), the re-plan count (number of `adaptations` entries with `type: replan` recorded this run), the preflight-yield count (number of `adaptations` entries with `type: preflight-yield` recorded this run; optionally broken down by yield value (`changed-brief` / `confirmed` / `no-yield`) or by `query_type` when the sub-field is present), the health-action count (number of `adaptations` entries with `type: health-action` recorded this run), the applied-prior count (number of `adaptations` entries with `type: prior-applied` recorded this run), total time (and estimated cost if `--cost` was set).

   **7a. Capture the run's adaptations to the durable ledger.** After computing the per-type counts above, and **before** step 9 deletes this run's board file, write a per-run rollup record to the durable adaptation ledger in the project memory directory (`~/.claude/projects/<project>/memory/`). The record carries the `run_id`, the project slug, the per-`type` adaptation counts just computed (`reflection` / `promotion` / `replan` / `preflight-yield` / `health-action` / `prior-applied`), the file-pairs that forced any parallel-to-sequential adaptation this run, the plan-validation tier, and whether a critic REVISE occurred (see `state-schema.md` → adaptation ledger for the record shape). The write:

   - **Is threshold-gated.** Skip the write entirely when the run produced **zero actionable adaptations** — a run of only `no-concern` reflections has nothing worth persisting. Capture only when the run made at least one actionable adaptation.
   - **Is redacted unconditionally and non-interactively.** Run the record body through **Passes A and B** of the redaction pipeline (`skills/cross-memory/redaction.md` — the `<private>` strip pass and the regex denylist pass) before writing. These two passes run non-interactively: the confirmation gate is **not** invoked, because this is a default-on, no-prompt write. There is no opt-out from redaction on this persistent file.
   - **Is keyed by project slug.** The record is stored under this project's slug; a record never applies to another project.
   - **Applies the rolling 10-run window on write.** Append the new record, then trim the ledger to the most recent 10 runs for this project.
   - **Writes the dedicated ledger file directly.** This is a non-interactive write to the dedicated ledger file — it does not route through `/cross-memory save`.

   **Hard ordering invariant:** the capture writes the ledger **before** this run's board file is deleted in step 9. There is no path in which the board is deleted before the ledger is written — the ledger derives entirely from the board's `adaptations` and `triage_confidence`, so a delete-first ordering would persist nothing. The `--no-adaptation-memory` flag skips this capture step entirely for the run.
8. List all files changed across all agents.
9. **Clean up ephemeral (short-lived; this run only) temp files, handoffs, state, and advisory preflight run artifacts.**

   > **Run-id confirmation gate:** For each `<run-id>`-bearing path below, confirm the embedded `<run-id>` segment matches the active run's `run_id` field from the state file before issuing the `rm`. For `_tmp_*` (which carries no `<run-id>` segment), apply the no-bulk-delete rule: remove files one at a time. Never issue a directory-level or recursive delete for any path.

   **Delete (this run only):**
   - `_tmp_*` — temporary files created during this run (use `rm _tmp_*` to remove them)
   - `.agents/handoffs/<run_id>/` — this run's handoff subdirectory; verify the `<run_id>` segment matches the active `run_id` before each `rm`
   - `.code-intel/runs/<run-id>/` — ephemeral run-scoped impact-analysis reports and JSON sidecars for this run only; confirm the `<run-id>` segment matches before each `rm`
   - `.corpus-search/runs/<run-id>/` — ephemeral corpus-search reports and JSON sidecars for this run only; confirm the `<run-id>` segment matches before each `rm`
   - `.ops-state/<run-id>-board.json` — this run's state file; confirm the `<run-id>` segment matches before `rm`
   - `.ops-state/<run-id>-save.json` — this run's save file; delete only if the file is present; confirm the `<run-id>` segment matches before `rm`

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
10. **Present completion options** — render the structured four-option menu (merge locally / push and PR / keep branch / discard) and capture user decision before exiting.

   > **Reference:** You MUST Read `~/.claude/skills/ops/completion-options.md` for the four-option menu, per-option workflow, destructive-option confirmation gate, and worktree-cleanup-by-provenance procedure. If the file is missing, fall back to suggesting natural next steps (e.g., "Ready for commit" or "Run the full test suite").

---

## Status Dashboard

Show the full dashboard on `status` command and at completion. For runs with ≥ 3 non-internal tasks, also show at stage transitions. For runs with ≤ 2 non-internal tasks, stage transitions collapse to a one-line status — see Non-negotiables #8.

Render the dashboard using native Markdown — output the `##` headers, `|...|` tables, and `**bold**` directly into chat. **Do NOT wrap your dashboard output in a fenced code block** (triple backticks); fencing causes the chat UI to render it as gray raw text instead of formatted sections.

Past user incident: the team manager wrapped its dashboard output in fences and the renderer showed raw `##` and `|` characters in a gray box. The unfence-by-default rule prevents recurrence.

---

## Team Manager — Status

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

### Cost
(Opt-in: rendered only when `--cost` was set or the user asked. Omit from mid-run dashboards. See `cost-tracking.md` for format.)

### Preflight
- (show checklist if preflight was run this session)

### Adaptations
- (list any mid-run adaptations made — strategy switches, plan adjustments, and reflection-beat notes from the `adaptations` log; reflection-beat entries have `type: reflection` and show the finishing stage plus the `action_taken`; re-plan entries have `type: replan` and show the finishing stage plus the `action_taken` (`logged`, `replanned`, or `replan-escalated`); preflight-yield entries have `type: preflight-yield` and show the answering preflight kind (the `query_type`, e.g. `find_callers` or `evidence_search`) plus the categorical yield value (`changed-brief`, `confirmed`, or `no-yield`); health-action entries have `type: health-action` and show the affected task plus the `action_taken` (`diagnosed-alive`, `re-dispatched`, or `re-dispatch-escalated`); prior-applied entries have `type: prior-applied` and show which consumer fired (e.g. `tier-upgrade` or `file-conflict`) plus what default it changed)

### Escalations
- (none)

---

The Timing section is mandatory in every dashboard display — see Non-negotiables #7. Show elapsed time for in-progress tasks and final duration for completed tasks. At completion, always include total wall time, per-stage totals, and the longest task.

> **Reference:** See `~/.claude/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, model escalation, calibration, idle time). If the file is missing, proceed using the dashboard template above.
