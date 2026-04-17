<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Required State Fields

## Pruning policy

Three state arrays are capped to bound state-file growth. Pruning runs at **state persist time** (before the JSON write to disk), after any stage has added new entries.

| Field | Cap | On-overflow behavior |
| :--- | :--- | :--- |
| `context.modified_files` | 50 most-recent entries | Drop oldest beyond 50; prepend a single `"+N more (see JSONL)"` summary entry so the caller knows how many were elided. |
| `progress.per_item_results` | 5 most-recent iterations (keyed by iter) | Drop oldest iter keys beyond 5. |
| `iteration_snapshots` | 20 most-recent entries | Drop oldest beyond 20. |

**JSONL is the full-history fallback.** The state JSON is a working-window optimization; the JSONL history log (`<task_id>.history.jsonl`) retains every entry ever written and is authoritative for audit and analytics.

**`progress.iteration_history` is NOT capped.** Trend detection and auto-pause heuristics read this array in full; truncating it would break those calculations.

## State Cache Semantics

The loop maintains an in-memory snapshot (cache) of the state file to avoid re-reading the full JSON before every stage message. The file on disk remains the authoritative source of truth — the cache is a read optimization only.

### Invalidation events

The cache is invalidated (state file re-read from disk) on these events and no others:

1. **Bootstrap** — when the task first resumes (`resume` subcommand or context recovery at the start of a new conversation turn).
2. **Persist-before-proceed** — immediately after writing new fields to the state file; always read back after a write to confirm the persisted values.
3. **User new input** — when the user sends a message that may have amended the state (mid-run commands, feedback, or corrections during an active loop).
4. **Iteration increment** — at the boundary between iterations (when Reflect completes and the decision is to continue).
5. **Rollback** — after a `rollback` sub-command completes. The rollback mutates both git state and the state file out-of-band relative to the running loop's snapshot; re-read to pick up the restored state.

Between these events, operate on the last-read snapshot. Do not re-read on routine stage transitions within a single iteration.

### Safety note

If a second process edits the state file between invalidation events (out-of-band edit), those changes will not be visible until the next invalidation trigger. Concurrent-writer workflows are not supported — the state file is written exclusively by the running loop. If the user needs to intervene, pause the loop and resume; the bootstrap invalidation event on resume guarantees a fresh read.

```json
{
  "task_id": "string",
  "title": "string",
  "status": "active | paused | blocked | done",
  "loop_mode": "balanced | strict",
  "template_id": "string | null (references the resolved <task_id>.template.yaml in the same directory)",
  "headless_mode": false,
  "lightweight_mode": false,
  "deslop_enabled": true,
  "full_deslop_enabled": false,
  "target": { "percent": 0, "goal": "string" },
  "iteration": 0,
  "progress": {
    "achieved_percent": 0,
    "current_stage": "Frame | Plan | Execute | Verify | Cleanup | Reflect",
    "completed_items": [],
    "remaining_items": [],
    "category_results": [
      { "name": "string", "measured": 0, "threshold": 0, "status": "pass | fail" }
    ],
    "per_item_results": [
      { "item": "string", "metrics": { "key": 0 } }
    ],
    "work_items": [
      {
        "id": "WI-001",
        "title": "short imperative description of the deliverable",
        "acceptance_criteria": [
          "specific, testable criterion (e.g., 'parse_date(\"2026-13-01\") raises InvalidDateError')"
        ],
        "status": "done | in_progress | pending",
        "iteration_started": "number | null (iteration when work began)",
        "iteration_completed": "number | null (iteration when all criteria verified)"
      }
    ]
  },
  "iteration_snapshots": [
    { "iter": 0, "git_ref": "ralph/<task_id>/iter-0", "timestamp": "ISO-8601" }
  ],
  "auto_pause_state": {
    "last_trigger": "string | null",
    "plateau_count": 0,
    "last_meaningful_improvement_iter": 0,
    "recurring_failures": [
      {
        "signature": "test name, error message, or file:line that identifies the failure",
        "first_seen_iter": 0,
        "consecutive_count": 0,
        "last_seen_iter": 0
      }
    ]
  },
  "blockers": [],
  "next_step": "string",
  "resume_hint": "string",
  "context": {
    "summary": "2-5 sentence narrative of current task state, approach, and key findings",
    "modified_files": ["paths of files created or modified during this task (capped at 50; oldest dropped when exceeded; a \"+N more (see JSONL)\" summary entry is prepended when the cap is hit)"],
    "comparisons": "structured comparison data if any; omit if none",
    "notes": "key decisions, known limitations, error patterns; omit if summary is sufficient",
    "learnings": [
      "short, actionable insight discovered during the task (e.g., 'Config parser silently drops keys with dots -- use bracket notation')",
      "codebase pattern or gotcha worth carrying into the next iteration"
    ],
    "headless_report": "string | null (summary written on headless exit)"
  },
  "storage": {
    "mode": "global | project | folder",
    "root": "string",
    "resolved_path": "string"
  },
  "updated_at": "ISO-8601 timestamp"
}
```
