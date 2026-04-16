<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# State File Schema

## Directory Conventions

- `.ops-state/` holds one board file per run (supports concurrent/sequential runs without collision)
- `.ops-state/` should be in `.gitignore` (ephemeral runtime state, not project content)
- Cleaned up on successful completion (same lifecycle as ralph-loop's `.ralph-state/`)

## State File Structure

The state file JSON structure:

```json
{
  "run_id": "auth-middleware-2026-04-14",
  "state_dir": ".ops-state/",
  "plan_file": "docs/plan/auth-middleware-plan.md",
  "tasks": [
    {
      "id": "task-1",
      "subject": "Implement auth middleware",
      "description": "Full task details with acceptance criteria...",
      "status": "pending",
      "agent_type": "executor",
      "stage": "implement",
      "priority": 1,
      "estimated_minutes": 15,
      "estimate_source": "ops",
      "blocked_by": ["task-0"],
      "started_at": null,
      "completed_at": null,
      "duration_seconds": null,
      "model_used": null,
      "attempts": 0,
      "adaptation": null,
      "handoff_file": null,
      "_internal": false
    }
  ]
}
```
