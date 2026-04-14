<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Timing Edge Cases

**1. Retry time:** When a task fails and is re-dispatched, track each attempt separately:

- `metadata.attempts`: array of `{started_at, completed_at, duration_seconds, model, outcome}`.
- `metadata.duration_seconds`: total across all attempts (for the Actual column).
- `metadata.duration_first_success`: duration of the successful attempt only (for variance comparison against estimate).
- In the dashboard, show total actual time but note retries: `"3:42 (2 retries)"`. Calculate variance against `duration_first_success`, not total duration — the estimate assumed a single pass, so compare apples to apples.

**2. Parallel execution:** Track both wall time and agent time:

- **Agent time** (sum of all task durations) — how much total work was done.
- **Wall time** (first `started_at` to last `completed_at`) — how long the user waited.
- In the Timing table, show both: `"Agent: 30m / Wall: 12m (parallel)"`.
- Estimated total is agent time (sequential sum). Compare estimated agent time to actual agent time for accuracy. Show wall time separately as an efficiency metric.

**3. Internal tasks:** Internal bookkeeping tasks (`metadata._internal: true`) have no estimates. Exclude them from the estimated total and variance calculation. Show them in a separate row: `"Internal (unestimated): 1:15"`.

**4. Resume after session loss:** When resuming, tasks marked `in_progress` have a stale `started_at`. Fix this:

- On resume, check each `in_progress` task. If the agent's work was applied (files changed), mark `completed` with `metadata.timing_note: "duration unknown (session lost)"`. Exclude from variance.
- If the agent's work was not applied, reset to `pending` and clear `started_at`. Re-dispatch normally with fresh timing.
- Never report a duration that includes session downtime.

**5. Model escalation:** When a task is retried on a different model, the `attempts` array captures which model was used for each attempt. Variance comparison uses `duration_first_success` regardless of model. The adaptation log notes the model change separately — timing and adaptation are reported independently.

**6. No calibration baseline:** When the team-manager produces its own estimates (no scoping doc), flag them in the dashboard: `"Est. 15m (heuristic)"` vs `"Est. 2h (scoped)"`. At completion, if heuristic estimates had >50% variance on average, note: `"Heuristic estimates were unreliable for this run. Consider using the project-scoper for future estimates."` Feed the actual durations into cross-run learning to calibrate future heuristics.

**7. Idle time in wall clock:** Wall time includes interactive checkpoints (user thinking, approving). Track separately:

- `metadata.checkpoint_pauses`: array of `{paused_at, resumed_at, duration_seconds}` for each interactive pause.
- **Active wall time** = wall time minus checkpoint pauses.
- In the completion summary, show: `"Wall time: 25m (20m active, 5m in checkpoints)"`.
- In autonomous mode, there are no checkpoint pauses, so wall time = active wall time.
