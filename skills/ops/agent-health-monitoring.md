<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Agent Health Monitoring

Companion helper for the `/ops` team manager skill. Defines timeout budgets and stall detection for dispatched agents so the team manager can identify and respond when agents are stuck.

---

## 1. Timeout Budgets per Agent Type

Default wall-clock timeouts (configurable via estimation calibration):

| Agent Type | Default Timeout | Rationale |
| :--- | :--- | :--- |
| executor | 15 min | Code changes are bounded by task scope |
| verifier | 10 min | Running tests has a natural ceiling |
| code-reviewer | 10 min | Review is bounded by diff size |
| code-reviewer-diff | 10 min | Inherits from code-reviewer |
| documentor | 8 min | Writing docs for a single task |
| debugger | 20 min | Investigation can be open-ended |
| debugger-build | 10 min | Build issues are usually specific |
| planner | 10 min | Planning is bounded by scope |
| project-scoper | 12 min | Analysis can involve reading many files |
| interviewer | 5 min | Single round of clarification |
| critic | 8 min | Quality gate review |
| git-master | 5 min | Git operations are fast |
| ssh-executor | 10 min | Remote commands that run longer than 10 min should use `nohup`, `screen`, or `tmux` instead of holding the connection open; per-command `timeout` wrapping provides finer control |

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
- **Background agents**: on each notification check, compare elapsed time against the thresholds above.
- **Parallel batches**: when one agent in a batch returns, check the elapsed time of remaining agents to surface early overrun signals.

---

## 4. Escalation Procedure

| Condition | Action |
| :--- | :--- |
| Agent returns within estimate | Normal processing |
| Agent returns between 1–2× estimate | Log as slow: "Task #N took X min (est. Y min)" — feed into estimation calibration |
| Agent returns between 2–3× estimate | Log as stall warning — record in task metadata for pattern detection |
| Agent exceeds type timeout | Cannot kill a foreground agent (Claude Code limitation). Log the overrun and flag in the completion summary. For background agents, note the overrun but let it complete. |
| Agent returns with no meaningful output | Treat as failure — enter the retry escalation path |

---

## 5. Practical Limitations

- Claude Code does **not** support killing a running agent mid-execution.
- Foreground agents block the session — the team manager cannot intervene until they return.
- Background agents can be monitored but also cannot be killed.
- Therefore, health monitoring is primarily **retrospective** (after the agent returns) and **predictive** (using historical data to set better timeouts).
- The real value is in **estimation calibration**: tracking which tasks run long improves future estimates and helps identify tasks that should use opus from the start.

---

## 6. Dashboard Integration

Show health status in the Active section of the dashboard:

```
### Active
- executor → Task #3: "Implement auth middleware" (in_progress, 7m23s elapsed, est. 5m) ⚠️ SLOW
- verifier → Task #5: "Run unit tests" (in_progress, 2m10s elapsed, est. 3m) ✓ ON TRACK
```

Thresholds for status indicators:

| Indicator | Condition |
| :--- | :--- |
| ✓ ON TRACK | elapsed < 1.5× estimate |
| ⚠️ SLOW | elapsed between 1.5× and 2.5× estimate |
| 🔴 OVERRUN | elapsed > 2.5× estimate |

---

## 7. Feeding into Calibration

After each run, health monitoring data feeds into the estimation feedback system:

- Tasks that were SLOW or OVERRUN are flagged.
- Patterns like "executor tasks on module X are consistently 2×" get written to timing memory.
- Agent types that frequently overrun get their default timeouts adjusted upward in memory.

This closes the loop: monitoring → calibration → better estimates → fewer surprises on the next run.
