# Phase 4 completion and dashboards

> **Parent:** `~/.claude/skills/ops/SKILL.md` — Non-negotiables #3, #4, #6, #7, #8 govern completion behavior.

### Phase 4 — Completion

When every task is `completed`:

**If `tasks.length == 1` (single-task run):** collapse Phase 4 to steps 1, 2, 9, and 10 only. Skip steps 3 (final verification — redundant for 1 task), 4 (timing summary — trivially one line; include in step 10 summary instead), 5 (cost — opt-in per Non-negotiable #6), 6 (final task board — redundant with the step 10 summary), 7 (narrative summary — fold into step 10), 8 (file list — include in step 10). For single-task runs, step 10 should be one concise paragraph: what was done, the file(s) changed, the actual duration, and next steps.

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
7. Summarize: what was accomplished, how many tasks, retries, escalations, total time (and estimated cost if `--cost` was set).
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

Health indicators: ✓ ON TRACK (elapsed < 1.5× estimate), ⚠️ SLOW (1.5–2.5×), 🔴 OVERRUN (> 2.5×), 👻 ORPHAN? (elapsed > agent-type timeout, no completion received)

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
- (list any mid-run adaptations made)

### Escalations
- (none)

---

The Timing section is mandatory in every dashboard display — see Non-negotiables #7. Show elapsed time for in-progress tasks and final duration for completed tasks. At completion, always include total wall time, per-stage totals, and the longest task.

> **Reference:** See `~/.claude/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, model escalation, calibration, idle time). If the file is missing, proceed using the dashboard template above.
