<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# History and Analytics

Iteration history is tracked in two places:

1. **State file** `progress.iteration_history` -- the existing array (backward-compatible).
2. **Log file** `<state_dir>/<task_id>.history.jsonl` -- one JSON line per event, append-only.

**JSONL log format:** Each line is a JSON object:

```json
{"event": "stage_complete", "task_id": "...", "iteration": 9, "stage": "Verify", "timestamp": "ISO-8601", "metrics": {"overall": 94.1, "wall": 96.8}, "delta_from_prev": 2.3}
{"event": "cleanup_complete", "task_id": "...", "iteration": 9, "files_scoped": 5, "fixes_applied": 3, "linter": "ruff", "deslop_escalated": false, "regression_passed": true, "reverted": false, "timestamp": "ISO-8601"}
{"event": "cleanup_complete", "task_id": "...", "iteration": 10, "files_scoped": 2, "fixes_applied": 0, "linter": "eslint", "deslop_escalated": false, "regression_passed": true, "reverted": false, "timestamp": "ISO-8601"}
{"event": "cleanup_complete", "task_id": "...", "iteration": 11, "files_scoped": 4, "fixes_applied": 2, "linter": "ruff", "deslop_escalated": false, "regression_passed": false, "reverted": true, "revert_reason": "test_parse_config failed after unused import removal", "timestamp": "ISO-8601"}
{"event": "cleanup_complete", "task_id": "...", "iteration": 5, "files_scoped": 8, "fixes_applied": 3, "linter": "ruff", "deslop_escalated": true, "deslop_findings_applied": 5, "deslop_findings_reported": 3, "regression_passed": true, "reverted": false, "timestamp": "ISO-8601"}
{"event": "iteration_complete", "task_id": "...", "iteration": 9, "label": "description", "overall_precision": 94.1, "category_results": {...}, "learnings": ["Config parser silently drops keys with dots -- use bracket notation", "verify.py needs --strict flag or it skips empty categories"], "timestamp": "ISO-8601"}
{"event": "auto_pause_triggered", "task_id": "...", "iteration": 12, "reason": "plateau", "details": "No improvement >0.5pp in last 3 iterations", "timestamp": "ISO-8601"}
{"event": "recurring_failure_escalated", "task_id": "...", "iteration": 8, "signature": "test_auth_flow::test_token_refresh FAILED AssertionError", "consecutive_count": 3, "first_seen_iter": 6, "action": "block", "timestamp": "ISO-8601"}
{"event": "rollback", "task_id": "...", "from_iter": 12, "to_iter": 9, "timestamp": "ISO-8601"}
{"event": "pause", "task_id": "...", "iteration": 9, "reason": "user requested", "timestamp": "ISO-8601"}
{"event": "resume", "task_id": "...", "iteration": 9, "from_stage": "Verify", "timestamp": "ISO-8601"}
```

**How to write (MANDATORY — no exceptions):**

**NEVER** use inline `echo` with `$(...)` command substitution, braces, or JSON content to append to the JSONL file. Claude Code's security scanner flags brace expansion and subshell patterns, causing interactive prompts that block headless workflows. Instead:

1. Use the **Write tool** to create a temp file (e.g., `_tmp_jsonl_event.txt`) containing the single JSON line. Generate the timestamp internally — do not use `$(date ...)` in Bash.
2. Use **Bash** to append: `cat _tmp_jsonl_event.txt >> .ralph-state/<task_id>.history.jsonl`
3. Leave the temp file in place — it will be cleaned up in batch with other `_tmp_*` files at the next checkpoint.

This is the **only** permitted method for JSONL appends. Direct `echo '...' >>` with JSON content is **forbidden** — it will always trigger a security prompt.

**When to write:**

- After every stage completion (Verify and Reflect are most important).
- On rollback, pause, resume, and completion events.
