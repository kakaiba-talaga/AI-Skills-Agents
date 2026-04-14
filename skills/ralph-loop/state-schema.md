<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Required State Fields

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
    "modified_files": ["paths of files created or modified during this task"],
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
