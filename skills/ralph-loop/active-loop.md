<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Active Loop — Part A Re-read Discipline

Extended rules for Stage Execution Discipline step 0. The inline invariant in `SKILL.md` is the minimum required on every response; read this companion when an active loop starts, on continuation after context recovery, or when you need the full invalidation and cadence detail.

## Re-read before every response

Non-negotiable — skipping this is the leading cause of drift. Before generating any response during an active loop:

1. **Re-read Part A of `SKILL.md`** — everything above the `# Part B` separator: Stage Execution Discipline, Headless Gate, Checklist Format, Workflow condensed, Cleanup Stage safety rails, Constraints, Output Tagging. Part B and the preamble are loaded once at start; re-read them only if you need argument-parsing details or a pointer block.

2. **State JSON — invalidation events only.** Re-read the task's state JSON **only on these invalidation events**:
   - (a) the task first resumes (`resume` subcommand or context recovery);
   - (b) you have just written new fields to it (persist-before-proceed — always read back after a write);
   - (c) the user sent new input that may have amended it;
   - (d) on iteration increment (boundary between iterations);
   - (e) after a `rollback` sub-command completes (rollback mutates state out-of-band).

   Between events, operate on the last-read snapshot. If a second process edits the state file mid-run, the change won't be picked up until a trigger fires — acceptable because concurrent-writer workflows are not supported.

3. **Template YAML — once per iteration.** If `template_id` is present, read the template YAML **once per iteration**, at Frame or on first Reflect-side evaluation — not before every stage message. Between those read points, operate on the cached snapshot. Invalidate on event (d) iteration increment (same as state invalidation). The resolved `<task_id>.template.yaml` is frozen at task creation and never re-resolved (see `template-system.md`, "Never re-resolve" and "Read cadence").

4. **Resume from `next_step`.** Recover position from `next_step` in the state file; never guess loop state from summarized context.
