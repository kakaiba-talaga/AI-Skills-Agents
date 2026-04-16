<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Handoff Documents — Full Reference

When a task completes and its output feeds into a downstream task, create a **handoff document** — a structured summary that preserves context across stage transitions. This is critical because each agent starts fresh with no memory of prior agents.

**Handoff documents are persisted to disk**, not kept only in conversation context. This ensures they survive session loss, context compression, and rate-limit interruptions.

## Run identity

A **new run** is created only when the team manager enters Phase 1 with a new spec AND proceeds to Phase 2 (task board creation). All other `/ops` invocations (`resume`, `status`, `add`, `pause`, mid-run instructions, checkpoint approvals) are **continuations** of the current run and reuse its run ID.

**When is it a new run?**

| Invocation | New run? |
| :--- | :--- |
| `/ops <new spec>` with no active tasks | Yes |
| `/ops <new spec>` with active tasks | **Prompt**: "You have an active run with N pending tasks. Start a new run or add to the current?" |
| `/ops resume/status/add/pause/stop` | No — continuation |
| `/ops` with mid-run instructions ("yes proceed", "also do X") | No — continuation |

**Run ID format:** `<plan-slug>-<ISO-date>` derived from the plan document name + run start date (e.g., `caching-layer-2026-04-09`). Stored in the state file's root `run_id` field. This allows any invocation to check "am I part of an existing run?" by reading the state file.

## Storage location

Each run gets its own subdirectory under `docs/plan/.handoffs/`:

```
docs/plan/.handoffs/
  caching-layer-2026-04-09/
    handoff-001-implement-to-verify.md
    handoff-003-verify-to-review.md
  auth-refactor-2026-04-09/
    handoff-001-implement-to-verify.md
```

This ensures multiple concurrent sessions (or sequential runs) never interfere with each other's handoff files.

## Naming convention

`handoff-<task_number>-<from_stage>-to-<to_stage>.md`

- Example: `handoff-003-implement-to-verify.md`
- Example: `handoff-007-verify-to-review.md`
- For verify→fix loops, append the iteration: `handoff-003-verify-to-fix-iter2.md`

## Template

```
## Handoff: [completed stage] → [next stage]
### Run context
- **Run ID:** [run_id from task metadata]
- **Plan document:** [path to plan doc, if one exists]
- **Task #:** [task number]
- **Timestamp:** [ISO-8601]

### What was done
[Summary of the completed work — which files changed, what was implemented/verified/reviewed]

### Key decisions
[Any non-obvious choices the agent made and why]

### Files changed
- `path/to/file.py:42-78` — [what changed]
- `path/to/other.py:10` — [what changed]

### Open items
[Anything the agent flagged but did not address — edge cases, TODO notes, uncertainties]

### For the next agent
[Specific guidance for the downstream task — what to focus on, what to watch for]
```

## Writing handoffs

After marking a task `completed` in the dispatch loop (Phase 3, Step 4), immediately write the handoff document to the run's subdirectory on disk. Store the handoff file path in the task's `handoff_file` field in the state file: `"handoff_file": "docs/plan/.handoffs/<run_id>/handoff-003-implement-to-verify.md"`. This allows `resume` to locate handoffs from the state file.

## Reading handoffs for downstream briefs

When composing an agent brief, read the relevant handoff file(s) from the run's subdirectory and include the content in the **Context** section of the brief. For converging chains (multiple executors → single verifier), concatenate all relevant handoff files.

## Handoff accumulation

Each stage transition writes a new handoff file. The full chain of handoff files for a task represents its complete history. When briefing a downstream agent, include the most recent handoff plus a summary of earlier ones (to avoid oversized briefs).

## Handoff cleanup

Handoff files are scoped per run and cleaned up based on run lifecycle:

1. **On successful completion (Phase 4):** Delete the run's handoff subdirectory. The run is done — `resume` won't be needed, and the deliverable artifacts (plan doc, committed code, documentation) are the permanent record.
2. **On pause/cancel/abort:** Keep the run's handoff subdirectory intact. The user may `resume` later.
3. **Never delete another run's subdirectory.** Each run only manages its own files. This prevents multi-session interference.
4. **Stale run detection:** At the start of a new run (Phase 1), check `docs/plan/.handoffs/` for subdirectories older than 7 days that have no matching state file in `.ops-state/`. If found, warn the user: "Found stale handoffs from run `<run_id>` (7+ days old, no active run). Clean up?" Only delete on explicit user approval — never auto-delete.
