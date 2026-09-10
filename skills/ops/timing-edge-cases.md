<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Timing Edge Cases

**1. Retry time:** When a task fails and is re-dispatched, the fields this needs already exist on the task object — no separate metadata block is required:

- `attempts`: the existing top-level integer field, incremented on every return (`phase-dispatch.md` Step 4's outcome table increments it alongside `status` on every outcome, not only on failure).
- `duration_seconds`: the existing top-level field. Step 4 overwrites it on every return with that return's own measured duration, so a failed attempt's duration does not survive the next attempt's write. By the time a task reaches `completed`, `duration_seconds` already holds only the duration of the attempt that succeeded — there is nothing else left to compare it against, so no separate "first success" field is needed.
- In the dashboard, show `duration_seconds` as the Actual time and note the retry count alongside it: `"3:42 (2 retries)"`, where retries = `attempts - 1`. Compare `duration_seconds` directly against the estimate for variance — it already reflects the single successful pass the estimate assumed, not a sum across failed attempts, so nothing further is needed for an apples-to-apples comparison.

**2. Parallel execution:** Track both wall time and agent time:

- **Agent time** (sum of all task durations) — how much total work was done.
- **Wall time** (first `started_at` to last `completed_at`) — how long the user waited.
- In the Timing table, show both: `"Agent: 30m / Wall: 12m (parallel)"`.
- Estimated total is agent time (sequential sum). Compare estimated agent time to actual agent time for accuracy. Show wall time separately as an efficiency metric.

**3. Internal tasks:** Internal bookkeeping tasks (`"_internal": true` on the task object) have no estimates. Exclude them from the estimated total and variance calculation. Show them in a separate row: `"Internal (unestimated): 1:15"`.

**4. Resume after session loss:** When resuming, tasks marked `in_progress` have a stale `started_at`. Fix this:

- On resume, check each `in_progress` task. If the agent's work was applied (files changed), mark `completed` and set `duration_seconds: null` — reusing the same null convention a not-yet-measured `pending` task already carries, now for "measured, but the measurement was lost." Exclude a `completed` task with a `null` `duration_seconds` from variance.
- If the agent's work was not applied, reset to `pending` and clear `started_at`. Re-dispatch normally with fresh timing.
- Never report a duration that includes session downtime.

**5. Model escalation:** When a task is retried on a different model, `model_used` — like `duration_seconds` — is overwritten on each attempt, so a completed task's `model_used` names the model of the attempt that actually succeeded, not a full escalation history. Variance comparison still uses `duration_seconds` regardless of model, since it is already scoped to that one successful attempt. The adaptation log notes the model change separately — timing and adaptation are reported independently.

**6. No calibration baseline:** When the team-manager produces its own estimates (no scoping doc), flag them in the dashboard: `"Est. 15m (heuristic)"` vs `"Est. 2h (scoped)"`. At completion, if heuristic estimates had >50% variance on average, note: `"Heuristic estimates were unreliable for this run. Consider using the project-scoper for future estimates."` Feed the actual durations into cross-run learning to calibrate future heuristics.

**7. Idle time in wall clock:** Wall time includes interactive checkpoints (user thinking, approving). Track separately:

- `checkpoint_pauses`: root-level array on the state file (see `state-schema.md` § checkpoint_pauses), one `{paused_at, resumed_at, duration_seconds}` entry per interactive pause. Unlike the fields in rules 1, 4, and 5 above, nothing pre-existing carries this information — a pause span is genuinely new data, not a different view of a field the schema already had, so it gets a field of its own.
- **Active wall time** = wall time minus the sum of `checkpoint_pauses[].duration_seconds`.
- In the completion summary, show: `"Wall time: 25m (20m active, 5m in checkpoints)"`.
- In autonomous mode, there are no checkpoint pauses, so wall time = active wall time.

**8. Background notification pickup:** A detached agent finishes its work at one moment, and the orchestrator learns of it only later, when it processes the completion notification. The gap between those two moments is dispatch latency, not agent runtime:

- `duration_seconds` — the existing top-level task field — is taken from the duration the completion notification itself reports (the agent's own measured runtime), not computed by subtracting `started_at` from `completed_at`. This yields true agent time directly, so nothing needs excluding and full calibration coverage is retained.
- `completed_at` minus `started_at` no longer equals `duration_seconds` once pickup latency is present. That divergence is correct: agent time is the agent's own reported runtime, while wall time correctly still includes the pickup latency, because the user really did wait through it.
- This behavior has been observed on one harness. Harnesses or notifications that do not carry a duration use the exclusion mechanism already defined in rule 4 as the fallback: marking `duration_seconds: null` and the rule against reporting a duration that includes downtime.
