Capture timing patterns from completed agent runs and calibrate future estimates. Arguments: $ARGUMENTS

Parse arguments as follows:

- `capture <task-data>` — persist timing data from a completed run to the memory file.
- `read` — read the memory file and return calibration data for the current project.
- `help` — display usage summary.

If the argument is `help`, display this quick reference and stop:

```
Commands: /timing-calibrator capture | read | help
Capture:  Persist timing patterns from a completed run
Read:     Load calibration data for estimate adjustment
Storage:  feedback_ops_timing_patterns.md in project memory directory
```

---

## Core Concept

This skill implements a self-improving calibration loop for agent task duration estimates. Each completed run contributes timing data; future runs read that data to produce more accurate estimates.

```
Run N completes → capture timing patterns → write to memory file
Run N+1 starts  → read memory file → apply calibration to estimates
```

The memory file uses rolling averages with a 10-run sliding window per agent type. Outlier tasks (> 3x estimate) are excluded from averages but recorded for pattern visibility.

---

## Memory File

**Location:** `feedback_ops_timing_patterns.md` in the project memory directory.

- Claude Code: `~/.claude/projects/<project>/memory/`
- Cursor: project-local memory if available, otherwise the project root

**Format:**

```markdown
---
name: Ops timing patterns
description: Historical timing data from agent runs — used to calibrate future estimates
type: feedback
---

## Estimation Calibration

- executor tasks average 8.2min in this project (based on 12 tasks across 3 runs)
- verifier tasks average 4.5min (based on 8 tasks across 3 runs)
- code-reviewer tasks average 6.0min (based on 5 tasks across 2 runs)
- Overall estimation accuracy: 1.35x (estimates are ~35% too low)

**Why:** Default estimates are rough guesses. Historical data makes them accurate.
**How to apply:** At run start, read this file and multiply default estimates by the calibration ratio. For agent types with specific averages, use those averages directly instead of defaults.

## Model Escalation Patterns

- executor tasks touching auth module: escalated to opus 2/3 times
- verifier tasks with integration tests: consistently need opus

**Why:** Some task types are harder than others. Pre-assigning opus saves retry overhead.
**How to apply:** When creating tasks matching these patterns, assign opus from the start instead of waiting for failure-driven escalation.

## Outlier Notes

- executor task "Implement authentication middleware": 3.5x estimate (debugging token validation) — excluded from averages
```

**Fields maintained per agent type:**

- `average_minutes`: rolling average of actual duration
- `sample_count`: total tasks included in the average
- `run_count`: number of distinct runs contributing to the average

---

## `capture` Command

Persist timing data from a completed run.

### Input

The caller provides task metadata — either inline in the arguments or as a reference to a state file. Each task entry needs:

- `agent_type` — which agent ran the task
- `estimated_minutes` — what was estimated
- `duration_seconds` — actual duration (convert to minutes for storage)
- `model_used` — which model ran the task
- `attempts` — number of dispatch attempts
- `stage` — pipeline stage (plan, implement, verify, review, document)

### Write threshold

Only write when at least one of these is true:

- Overall variance exceeds 30% (actual/estimated ratio > 1.3x or < 0.7x)
- A new agent type or pipeline stage appeared that has no prior data
- Model escalation occurred at least once
- This is the 3rd or later run for the project

If none are true, skip the write. Single-run data is noise — write only when there's a meaningful signal.

### What to capture

From the task metadata, extract:

1. **Per-agent-type average:** average actual duration for each agent type used
2. **Per-stage average:** average actual duration grouped by stage
3. **Estimation accuracy ratio:** overall `actual / estimated` ratio across all tasks
4. **Outlier tasks:** any task that exceeded 2x its estimate — record agent type and context
5. **Model escalation patterns:** which agent types triggered model escalation

### Update procedure

If the memory file already exists:

1. Read it
2. Use rolling averages to incorporate new data:
   ```
   new_avg = (old_avg × old_count + new_value) / (old_count + 1)
   new_count = old_count + 1
   ```
3. Cap history at 10 runs per agent type. Beyond 10, use a sliding window.
4. Exclude outlier tasks (> 3x estimate) from averages but note them. Keep at most the 5 most recent outliers.
5. Update model escalation patterns cumulatively.
6. Write the updated file.

If the memory file does not exist, create it with initial data from this run.

### Output

Report what was captured:

```
Timing calibration captured:
- N tasks across M agent types
- Overall accuracy ratio: X.Xx
- Outliers excluded: N
- Model escalations recorded: N
- Memory file: [path]
```

---

## `read` Command

Read the memory file and return calibration data.

### Procedure

1. Check if `feedback_ops_timing_patterns.md` exists in the project memory directory
2. If it exists, read and parse the Estimation Calibration and Model Escalation Patterns sections
3. Return the calibration data in a structured format

### Output

If the memory file exists:

```
Estimation calibration available (N prior runs):
- Overall accuracy ratio: X.Xx
- Agent type averages:
  - executor: X.Xmin (N tasks across M runs)
  - verifier: X.Xmin (N tasks across M runs)
  - [...]
- Model escalation patterns:
  - [pattern]: escalated N/M times
  - [...]

How to apply:
- For agent types with historical averages: use the average as the estimate
- For agent types with no history: multiply default estimate × overall ratio
- For tasks matching escalation patterns: assign opus from the start
```

If the memory file does not exist:

```
No calibration data available for this project.
Use default estimates. Data will accumulate after completed runs.
```

---

## Edge Cases

**First run:** No memory file exists. Use defaults. After the run, create the file if the write threshold is met. Note `run_count: 1` as provisional.

**Anomalous run:** Tasks > 3x estimate are excluded from averages but recorded in Outlier Notes with context.

**Memory file deleted:** Fall back to defaults gracefully. No error. Begin accumulating fresh data.

**Per-project isolation:** Memory is per-project. Calibration data does not transfer between projects.

**Incomplete timing data:** If tasks are missing `started_at` or `completed_at` values, skip the capture for that run. Do not overwrite valid history with incomplete observations.

**Run with no timing data:** If all tasks lack timing data (e.g., session interrupted before any task completed), skip the write entirely.

---

## Cross-Run Learning Patterns

Beyond raw timing, capture behavioral patterns as a separate memory file (`feedback_team_patterns.md`):

- Task patterns needing adaptation (e.g., "auth module tasks consistently need opus")
- Agent effectiveness (e.g., "verifier catches more issues when given narrower scope")
- Dispatch patterns (e.g., "sequential dispatch was forced after file conflicts in past runs")

Each entry has a **Why** and **How to apply** line. These are soft defaults — they inform decisions but don't override explicit user instructions.

Do **not** record: specific file paths/line numbers, task descriptions, or anything derivable from git history.
