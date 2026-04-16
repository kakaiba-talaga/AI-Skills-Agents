<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Interruption Recovery — Detailed Procedures

## Cancel / Abort

When the user says "stop", "cancel", or "abort":

1. **Stop dispatching** — do not spawn any new agents.
2. **Let active agents finish** — foreground agents are already running and will return. For background agents, wait for them to complete their current work (they cannot be killed mid-execution).
3. **Mark remaining pending tasks as cancelled** — update their descriptions with the reason. Do not delete them (the user may want to resume later).
4. **Show the final dashboard** — display what completed, what was in progress when cancelled, and what never started.
5. **Preserve the state file** — the user can `/ops resume` later to pick up from the cancelled state.

Do not ask "are you sure?" — if the user says stop, stop. They can always resume.

## Reprioritize

When the user asks to change priority, reorder tasks, or skip a stage mid-run:

1. **Pause new dispatches** — finish any agents currently running but don't start new ones.
2. **Show the current task board** so the user sees the full picture.
3. **Apply the change:**
   - **Skip a stage** — mark all pending tasks in that stage as `deleted`. Update dependency chains so downstream tasks are no longer blocked by the skipped tasks.
   - **Reorder tasks** — update `metadata.priority` values. The dispatch loop picks the highest-priority ready tasks first.
   - **Promote a task** — if the user says "do task #7 next", mark it as priority `1` and dispatch it immediately (if its dependencies are met).
   - **Demote or defer a task** — set priority to `5` or add a manual blocker.
4. **Show the updated board** and resume dispatching.

## Inject Tasks

When the user adds new work mid-run ("also add X" or "we need to handle Y too"):

1. Create the new task(s) in the state file with appropriate metadata and dependencies.
2. Wire dependencies — if the new task depends on existing tasks, set `blockedBy`. If existing tasks should wait for the new task, update their `blockedBy`.
3. Show the updated board with the new task(s) highlighted.
4. Resume dispatching — the new task enters the normal dispatch loop.

Do not re-plan the entire board. The new task slots into the existing structure.

## Remove Tasks

When the user says to drop a task ("skip #4", "we don't need the documentation"):

1. Mark the task as `deleted`.
2. **Update downstream dependencies** — any task that was `blockedBy` the removed task should have that blocker cleared. Check if this unblocks new work.
3. Show the updated board.
4. Resume dispatching.

## Session Recovery

If the conversation is interrupted (terminal closed, context reset, session timeout):

- The **state file persists on disk** — `.ops-state/<run-id>-board.json` survives conversation boundaries.
- **Handoff files on disk** survive — they contain the full inter-stage context (what was done, key decisions, files changed, guidance for next agent), referenced by file path in task metadata (`metadata.handoff_file`).
- **Plan document on disk** survives — it contains the overall work scope and acceptance criteria.
- Tasks that were `in_progress` when the session died remain marked as such, but the agent that was working on them is gone.

All `in_progress` tasks are considered **orphaned** after a session boundary — the agents from the prior session no longer exist (see `agent-health-monitoring.md` Section 3b for the formal orphan detection logic). The dedup verification procedure (`resume-dedup.md`) determines whether each orphaned task's work was actually applied.

On `/ops resume`:

1. Read the state file from `.ops-state/` to recover the board.
2. For tasks still marked `in_progress` — check whether the agent's work was actually applied (read the files, check git status). If changes are present and look correct, mark as `completed`. If not, reset to `pending` for re-dispatch.
3. **Read the plan document** from `docs/plan/` (look for the most recently modified `*-plan.md` file, or use the path stored in task board metadata `metadata.plan_file`).
4. **Read handoff files** from the run's subdirectory in `docs/plan/.handoffs/<run_id>/` (the run_id is stored in `metadata.run_id` on every task). Use these to reconstruct the context chain when briefing the next agent to dispatch.
5. Rebuild the dispatch state from the task board (what's done, what's blocked, what's ready).
6. Show the recovered dashboard — including a note about which handoff files were recovered — and ask the user to confirm before resuming.

The team manager does not rely on conversation history for stage-to-stage context — everything is on disk (plan doc + handoff files + state file).
