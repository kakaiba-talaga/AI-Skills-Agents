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

### Pause vs Save

Both verbs interrupt an active run, but they target different problems. **`pause`** is a mid-session bookmark: the team manager stops dispatching new work, lets any currently-running agents finish, and then waits. Conversation context is still alive, so the user can type `resume` moments later and pick up exactly where things left off — no files read back, no reconstruction needed. Use `pause` for a coffee break, a quick side-lookup, or a brief detour inside the same session.

**`save`** is a journal entry for context loss. The user invokes it as a deliberate prelude (step before) to clearing the context window, closing the terminal, or stepping away long enough that the conversation will not survive. Unlike `pause`, `save` captures the conversation-side state that the state file alone cannot hold — verbal decisions made mid-run, the working hypothesis, the "where I was" note — and writes it to a save file on disk. After saving, the user typically clears the window and later runs `/ops resume` in a fresh session, which reads both the on-disk state file and the save file together to reconstruct full context. See `~/.claude/skills/ops/subcommand-save.md` for the complete save invocation flow and file schema.

## Reprioritize

When the user asks to change priority, reorder tasks, or skip a stage mid-run:

1. **Pause new dispatches** — finish any agents currently running but don't start new ones.
2. **Show the current task board** so the user sees the full picture.
3. **Apply the change:**
   - **Skip a stage** — mark all pending tasks in that stage as `deleted`. Update dependency chains so downstream tasks are no longer blocked by the skipped tasks.
   - **Reorder tasks** — update task `priority` values in the state file. The dispatch loop picks the highest-priority ready tasks first.
   - **Promote a task** — if the user says "do task #7 next", mark it as priority `1` and dispatch it immediately (if its dependencies are met).
   - **Demote or defer a task** — set priority to `5` or add a manual blocker.
4. **Show the updated board** and resume dispatching.

## Inject Tasks

When the user adds new work mid-run ("also add X" or "we need to handle Y too"):

1. Create the new task(s) in the state file with appropriate metadata and dependencies.
2. Wire dependencies — if the new task depends on existing tasks, set `blocked_by`. If existing tasks should wait for the new task, update their `blocked_by`.
3. Show the updated board with the new task(s) highlighted.
4. Resume dispatching — the new task enters the normal dispatch loop.

Do not re-plan the entire board. The new task slots into the existing structure.

## Remove Tasks

When the user says to drop a task ("skip #4", "we don't need the documentation"):

1. Mark the task as `deleted`.
2. **Update downstream dependencies** — any task that was `blocked_by` the removed task should have that blocker cleared. Check if this unblocks new work.
3. Show the updated board.
4. Resume dispatching.

## Session Recovery

If the conversation is interrupted (terminal closed, context reset, session timeout):

- The **state file persists on disk** — `.ops-state/<run-id>-board.json` survives conversation boundaries.
- **Handoff files on disk** survive — they contain the full inter-stage context (what was done, key decisions, files changed, guidance for next agent), referenced by file path in each task's `handoff_file` field.
- **Plan document on disk** survives — it contains the overall work scope and acceptance criteria.
- Tasks that were `in_progress` when the session died remain marked as such, but the agent that was working on them is gone.

All `in_progress` tasks are considered **orphaned** (the agent that owned the task is gone, so its status can't be trusted) after a session boundary — the agents from the prior session no longer exist. The **work-verifier** agent (`~/.claude/agents/work-verifier.md`) handles orphan detection (via timeout budgets per agent type) and determines whether each orphaned task's work was actually applied.

On `/ops resume`:

1. Read the state file from `.ops-state/` to recover the board.
2. **Check `pending_nested_skill`.** Read the state file's root-level `pending_nested_skill` field.

   If the field is `null` or absent, proceed to the next step (orphan detection and dedup verification for `in_progress` tasks).

   If the field is non-null, the previous session was interrupted **inside a nested-skill call** (between the write-before step and the return) — meaning the changes already made by that skill may be partial, complete, or absent. **Do not re-invoke the nested skill automatically.** Escalate to the user with the marker's contents (`skill`, `invoked_at`, `resume_phase`, `resume_notes`) and ask which branch applies:

   - **(a) Clear and continue** — the user has verified the nested skill's effects are in the correct terminal state; clear the marker and proceed with resume.
   - **(b) Re-invoke** — the user has verified the pre-invocation conditions still hold; re-run the nested skill from the beginning.
   - **(c) Abort** — neither condition holds; abandon this resume.

   Record the user's decision. Do not clear `pending_nested_skill` automatically until the user confirms. See `state-schema.md` for the field shape.
3. For tasks still marked `in_progress` — the **work-verifier** agent is the authority that determines whether an orphaned task's work was actually applied; the checks described here are what the work-verifier performs. Read the expected deliverable files and check git status. If the expected deliverable files exist and the task's handoff file records completion, mark as `completed`. If not, reset to `pending` for re-dispatch.
4. **Read the plan document** from `docs/plan/` (look for the most recently modified `*-plan.md` file, or use the path stored in the state file's root `plan_file` field).
5. **Read handoff files** from the run's subdirectory in `.agents/handoffs/<run_id>/` (the `run_id` is stored at the root of the state file). Use these to reconstruct the context chain when briefing the next agent to dispatch.
6. Rebuild the dispatch state from the task board (what's done, what's blocked, what's ready).
7. Show the recovered dashboard — including a note about which handoff files were recovered — and ask the user to confirm before resuming.

The team manager does not rely on conversation history for stage-to-stage context — everything is on disk (plan doc + handoff files + state file).

## How Dispatch Works (Foreground vs Background)

By default, the team manager spawns agents in the **foreground** — the session blocks until each agent (or parallel batch) returns. The user cannot send messages while a foreground agent is running.

For longer-running tasks, spawn agents with `run_in_background: true`. The session remains interactive — the user can send messages, and the team manager gets notified when background agents complete. See Phase 3 Step 3 "Foreground vs. Background Dispatch Policy" for the specific criteria governing when to use background dispatch.

The interruption handling below applies at the points where the team manager has control — between foreground agent returns, or any time during background dispatch.
