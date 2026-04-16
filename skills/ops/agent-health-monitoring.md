<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Agent Health Monitoring

Companion helper for the `/ops` team manager skill. Defines timeout budgets and stall detection for dispatched agents so the team manager can identify and respond when agents are stuck.

---

## 1. Timeout Budgets per Agent Type

Default wall-clock timeouts (configurable via estimation calibration):

| Agent Type | Default Timeout | Rationale |
| :--- | :--- | :--- |
| architect | 15 min | Design exploration reads many files and evaluates alternatives |
| code-reviewer | 10 min | Review is bounded by diff size |
| code-reviewer-diff | 10 min | Inherits from code-reviewer |
| critic | 8 min | Quality gate review |
| debugger | 20 min | Investigation can be open-ended |
| debugger-build | 10 min | Build issues are usually specific |
| documentor | 8 min | Writing docs for a single task |
| executor | 15 min | Code changes are bounded by task scope |
| git-master | 5 min | Git operations are fast |
| interviewer | 5 min | Single round of clarification |
| planner | 10 min | Planning is bounded by scope |
| project-scoper | 12 min | Analysis can involve reading many files |
| security-reviewer | 12 min | Thorough audit requires reading all modified files and checking OWASP patterns |
| ssh-executor | 10 min | Remote commands that run longer than 10 min should use `nohup`, `screen`, or `tmux` instead of holding the connection open; per-command `timeout` wrapping provides finer control |
| verifier | 10 min | Running tests has a natural ceiling |

These are the **absolute maximums**. The per-task timeout is the MINIMUM of (agent type default, 3× task estimate).

---

## 2. Stall Detection

**Potentially stalled** — both conditions must be true:

- Wall-clock time exceeds 2× the task's estimated duration
- AND the task has no visible progress markers (no files changed, no test output)

**Definitely stalled** — either condition is true:

- Wall-clock time exceeds 3× the task's estimated duration
- OR the agent type timeout is exceeded

---

## 3. Monitoring Procedure

The team manager checks health at these points:

- **Foreground agents**: after each agent returns, check whether elapsed time was excessive and feed the result into estimation calibration.
- **Background agents**: the team manager checks background agent health **every time it regains control**:
  - After a foreground agent returns (process that result, then check all background agents)
  - After receiving a background-agent completion notification
  - Before responding to any user message when the team manager has control (e.g., `status`, `resume`, free-form input — not possible while a foreground agent is blocking the session)
  - This is event-driven, not timer-based — Claude Code has no cron/interval mechanism.
- **Parallel batches**: when one agent in a batch returns, check the elapsed time of remaining agents in that batch using the same check-in event logic. This surfaces early overrun signals.

---

## 3a. Proactive Health Warnings

- When a background agent's elapsed time crosses the **SLOW** threshold (1.5× estimate, per Section 6), the team manager emits a warning to the user on the next check-in event.
- When elapsed time crosses the **OVERRUN** threshold (2.5× estimate), the team manager emits an urgent warning.
- **Estimate-source sensitivity:** For tasks with `estimate_source: "ops"` (rough estimates with wide error margins), suppress SLOW warnings — emit OVERRUN only. For tasks with `estimate_source: "scoping-doc"` (calibrated estimates from the project-scoper), apply the full SLOW and OVERRUN thresholds. This prevents noisy warnings on rough estimates while preserving early-warning value on calibrated ones.
- Warnings are emitted **once per threshold crossing per task** — not repeated on every check-in. Track which thresholds have been reported in-memory (this does not need state file persistence since warnings are best-effort).
- On session resume, warning state resets — SLOW and OVERRUN warnings may re-fire for tasks that already crossed these thresholds before the interruption. This is expected and harmless.
- Warning format:
  ```
  ⚠️ Agent health: executor → Task #3 "Implement auth middleware" — SLOW (8m elapsed, est. 5m)
  ```
  ```
  🔴 Agent health: verifier → Task #5 "Run unit tests" — OVERRUN (12m elapsed, est. 3m, timeout 10m)
  ```
- **Foreground limitation:** No proactive warning is possible while a foreground agent is running (the session is blocked). The warning is emitted retroactively when the agent returns — this is already covered by the existing escalation procedure in Section 4.
- **Delivery mechanism:** Warnings are included as text in the team manager's next response to the user. Claude Code has no push notification or terminal alert mechanism — the warning appears the next time the team manager speaks.

---

## 3b. Orphan Detection

An **orphaned task** is one marked `in_progress` in the state file but with no agent actively running. This occurs when:
- A background agent silently completed or errored without the team manager processing its result (e.g., notification was missed).
- The session was disrupted (terminal closed, context reset) while an agent was running.
- A foreground agent returned but the team manager crashed before updating the state file.

**Detection trigger:** Orphan detection runs at the same check-in events as health monitoring (Section 3), plus:
- On every `status` command.
- On every `resume` command (before the dedup procedure in `resume-dedup.md`).

**Detection heuristic** (since Claude Code cannot query "is agent X still running?"):
- If a background agent's elapsed time exceeds its agent-type timeout (Section 1) AND no completion notification has been received → flag as **suspected orphan**.
- On `resume` after a session boundary → ALL `in_progress` tasks are treated as orphaned — the agents from the previous session are gone.

**What is a completion notification?** A completion notification is the return message delivered by Claude Code when a background agent finishes execution. The team manager identifies which task it belongs to by matching the agent description field set during dispatch (e.g., `"executor(Implement auth middleware)"` — see SKILL.md Phase 3 Step 3). If a notification cannot be matched to a specific task, treat all in-progress background tasks as potentially affected and run health checks on each.

**Response to suspected orphan:**
- Display the orphan status in the dashboard (see Section 6).
- Recommend the user run `resume` to trigger dedup verification (Checks A–D from `resume-dedup.md`) which determines whether the agent's work was actually applied.
- Do not automatically reset orphaned tasks — the dedup procedure handles that.

---

## 4. Escalation Procedure

| Condition | Action |
| :--- | :--- |
| Agent returns within estimate | Normal processing |
| Agent returns between 1–2× estimate | Log as slow: "Task #N took X min (est. Y min)" — feed into estimation calibration |
| Agent returns between 2–3× estimate | Log as stall warning — record in task metadata for pattern detection |
| Agent exceeds type timeout | Cannot kill a foreground agent (Claude Code limitation). Log the overrun and flag in the completion summary. For background agents, note the overrun but let it complete. |
| Agent returns with no meaningful output | Treat as failure — enter the retry escalation path |

These escalation actions are evaluated at each check-in event (see Section 3). For background agents, evaluation happens when the team manager regains control — not on a fixed interval.

---

## 5. Practical Limitations

- Claude Code does **not** support killing a running agent mid-execution.
- Foreground agents block the session — the team manager cannot intervene until they return.
- Background agents can be monitored but also cannot be killed.
- Therefore, health monitoring is primarily **retrospective** (after the agent returns) and **predictive** (using historical data to set better timeouts).
- The real value is in **estimation calibration**: tracking which tasks run long improves future estimates and helps identify tasks that should use opus from the start.
- The team manager's background dispatch policy (SKILL.md Phase 3 Step 3) controls which agents run in background vs. foreground. Health monitoring is most actionable for background agents — foreground agents block the session, so monitoring is retrospective only.

---

## 6. Dashboard Integration

Show health status in the Active section of the dashboard:

```
### Active
- executor → Task #3: "Implement auth middleware" (in_progress, 7m23s elapsed, est. 5m) ⚠️ SLOW
- verifier → Task #5: "Run unit tests" (in_progress, 14m elapsed, est. 3m, timeout 10m) 👻 ORPHAN?
```

Thresholds for status indicators:

| Indicator | Condition |
| :--- | :--- |
| ✓ ON TRACK | elapsed < 1.5× estimate |
| ⚠️ SLOW | elapsed between 1.5× and 2.5× estimate |
| 🔴 OVERRUN | elapsed > 2.5× estimate |
| 👻 ORPHAN? | elapsed > agent-type timeout AND no completion notification received |

---

## 7. Feeding into Calibration

After each run, health monitoring data feeds into the estimation feedback system:

- Tasks that were SLOW or OVERRUN are flagged.
- Patterns like "executor tasks on module X are consistently 2×" get written to timing memory.
- Agent types that frequently overrun get their default timeouts adjusted upward in memory.

This closes the loop: monitoring → calibration → better estimates → fewer surprises on the next run.
