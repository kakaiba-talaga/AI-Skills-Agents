<!-- Referenced by ~/.claude/skills/deploy/SKILL.md. Keep in sync. -->
# Response Interpretation — Deploy Skill Reference

## Response Field Reference

| Field | Type | Description |
| :--- | :--- | :--- |
| `status` | `"success"` or `"failed"` | `success` means all commands exited 0 and the health check passed. `failed` means at least one command or the health check did not pass. |
| `failed_at` | string or null | The `id` of the command that failed. Null on success. |
| `failure_reason` | string or null | Human-readable explanation of the failure. Null on success. |
| `commands` | list of command result objects | One entry per command that executed, in execution order. Does not include commands that were never reached due to an earlier failure. |
| `pre_hooks` | list of command result objects | One entry per pre-hook that executed. |
| `post_hooks` | list of command result objects | One entry per post-hook that executed. Only populated when the main deployment succeeded. |
| `artifact_transfer` | transfer result object or null | Result of the scp/tar-ssh transfer. Null if no artifact was specified in the brief. |
| `health_check` | health check result object or null | Result of the health check. Null if the deployment failed before the health check ran. |
| `remote_state_changes` | list of strings | Human-readable list of what was modified on the remote server: files created, services restarted, configs changed. Use to determine rollback scope and to report to the user. |
| `rollback_available` | map of command id → string | Rollback commands for commands that completed successfully. If step 3 of 5 fails, only entries for steps 1 and 2 are present. Use this — not the original brief — as the sole source of truth for rollback commands. |
| `pre_hook_rollback_available` | map of pre-hook id → string | Rollback commands for pre-hooks that completed successfully. Only populated when the brief included `pre_hook_rollback`. |
| `duration_seconds` | number | Total wall-clock time from start to finish. |

---

## Command Result Object Fields

| Field | Description |
| :--- | :--- |
| `id` | Matches the `id` from the brief. |
| `description` | Matches the `description` from the brief. |
| `command` | The full SSH invocation that was run. |
| `exit_code` | Integer exit code from the remote command. |
| `stdout` | Last 50 lines of stdout output. |
| `stderr` | Stderr output, or empty string. |
| `duration_seconds` | Time this command took to run. |
| `status` | `success`, `failed`, `skipped`, or `timed_out`. |

---

## Decision Tree

Read the response top-to-bottom in this order. The first matching condition determines the action.

| Condition | Action |
| :--- | :--- |
| `artifact_transfer.status == "failed"` | **ABORT.** Report the transfer failure using `failure_reason`. No rollback is needed — no remote state was changed before the transfer failure. |
| Any command has `exit_code == 255` | **CONNECTION DROP.** Do NOT assume failure or success. Dispatch a read-only state-check ssh-executor to the same host to verify whether the dropped command completed. Based on the result: if it completed, treat as success and continue; if it did not complete, enter rollback flow; if state is ambiguous, escalate to the user. See rollback-procedures.md for recovery detail. |
| `status == "failed"` AND `failed_at` matches a pre-hook id | **PRE-HOOK FAILURE.** No main commands ran. Check `pre_hook_rollback_available` and rollback only completed pre-hooks. Construct a rollback brief using those entries in reverse order of the original `pre_hooks` list. |
| `status == "failed"` AND `failed_at` matches a command id | **AUTOMATIC ROLLBACK.** Read `rollback_available` (for main commands) and `pre_hook_rollback_available` (for pre-hooks). Construct a rollback brief: main command rollbacks first (reverse order), then pre-hook rollbacks (reverse order). Proceed to Phase 6. See rollback-procedures.md for the complete rollback contract. |
| `status == "success"` AND `health_check.status == "pass"` | **DEPLOYMENT COMPLETE.** Proceed to Phase 7 reporting. Run post-hooks reporting (list each post-hook result from `post_hooks`). |
| `status == "success"` AND `health_check.status == "fail"` | **ASK USER.** All commands succeeded but the service is unhealthy. Do not rollback automatically. Present the health check output and ask: rollback or investigate? Wait for the user's decision before acting. |
| `status == "success"` AND `health_check.status == "timed_out"` | **ASK USER.** Same handling as health check failure — the service may need more time or may be broken. Present the health check details and ask: rollback or investigate? |

---

## Reading Per-Command Results

Iterate through the `commands` list in order. For each entry:

1. Check `status`. If `failed`, this is where the deployment stopped.
2. Commands after the failed one in the original brief were never executed — they will not appear in the `commands` list.
3. Use `stdout` and `stderr` for diagnostics. `stderr` is the primary signal for why a command failed.
4. Use `exit_code` to distinguish failure types: non-zero is a command error; 255 is a connection drop and requires special handling (see decision tree above).

---

## Health Check Interpretation

The health check result object contains:

| Field | Meaning |
| :--- | :--- |
| `status: pass` | Service is healthy. Proceed. |
| `status: fail` | All retries exhausted. Service is unhealthy after deployment. |
| `status: timed_out` | The health check command itself timed out before returning a result. |
| `attempts` | How many retries occurred (up to `retry_count` from the brief). High attempt count with `pass` means the service came up slowly. |

If `health_check` is null, the deployment failed before reaching the health check step. Check `failed_at` and `commands` to find where it stopped.

---

## State Change Tracking

`remote_state_changes` is a list of human-readable strings describing what was modified on the remote server. Use it for three purposes:

1. **Determining rollback scope** — each entry represents something that needs to be undone if rollback is required. Cross-reference with `rollback_available` to verify that the rollback commands cover the listed changes.
2. **User reporting** — list each entry in the Phase 7 report under "Remote State Changes" so the user knows exactly what was modified.
3. **Diagnosing failures** — if a command failed partway through, `remote_state_changes` reflects the state the server is in right now. Use this to understand what cleanup or rollback is necessary and to communicate the blast radius to the user.
