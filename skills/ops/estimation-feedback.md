<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Estimation Feedback

This file defines how `/ops` captures timing patterns from completed runs and feeds them back into future estimates. The goal is a self-improving calibration loop: each run makes the next one more accurate.

---

## 1. What to Capture

After Phase 4 timing computation, extract these patterns from task metadata:

- **Per-agent-type average:** Average actual duration for each agent type used in the run. Example: "executor tasks averaged 8.2 min in this project (12 tasks across 3 runs)."
- **Per-stage average:** Average actual duration grouped by `metadata.stage` (`plan`, `implement`, `verify`, `review`, `document`).
- **Estimation accuracy ratio:** Overall `actual / estimated` ratio across all tasks. Example: `1.4x` means estimates are 40% too low on average.
- **Outlier tasks:** Any task that exceeded 2x its estimate — record the agent type and a brief context note (e.g., "executor task touching auth module took 3.5x estimate").
- **Model escalation patterns:** Which agent types triggered model escalation (sonnet → opus). Example: "verifier tasks with integration tests: escalated 2/3 times."

---

## 2. When to Write

Write (or update) the memory file at the end of Phase 4, after timing computation, before cleanup.

**Write threshold — only write when at least one of these is true:**

- Overall variance exceeds 30% (actual/estimated ratio > 1.3x or < 0.7x)
- A new agent type or pipeline stage appeared that has no prior data in the memory file
- Model escalation occurred at least once (indicates a task type is harder than expected)
- This is the 3rd or later run for the project (enough data to establish a pattern)

**Do NOT write after every run.** Single-run data is noise. Write only when there is a meaningful signal — a pattern strong enough to change future behavior.

---

## 3. Memory File Format

Write to a single file named `feedback_ops_timing_patterns.md` in the project memory directory (`~/.claude/projects/<project>/memory/`).

```markdown
---
name: Ops timing patterns
description: Historical timing data from /ops runs — used to calibrate future estimates
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

**Fields to maintain per agent type:**

- `average_minutes`: rolling average of actual duration
- `sample_count`: total tasks included in the average
- `run_count`: number of distinct runs contributing to the average

---

## 4. How to Read at Run Start

At the beginning of Phase 2 (Task Board Creation), before assigning estimates:

1. Check if `feedback_ops_timing_patterns.md` exists in the project memory directory.
2. If it exists, read the Estimation Calibration and Model Escalation Patterns sections.
3. Apply calibration when assigning `metadata.estimated_minutes`:
   - For agent types with a historical average: use the historical average as the estimate (instead of the default heuristic).
   - For agent types with no historical data: use the default heuristic × overall calibration ratio.
   - For task types matching a model escalation pattern: set `metadata.model: "opus"` directly — do not wait for failure-driven escalation.
4. Log the calibration at Phase 2 completion: `"Applied estimation calibration from N prior runs (overall ratio: X.Xx, Y agent types with historical averages)."`

If the memory file does not exist, proceed with defaults and write initial data after the run completes (if the write threshold is met).

---

## 5. Update vs. Overwrite

When writing to an existing `feedback_ops_timing_patterns.md`:

- **Do not create a duplicate file.** Read the existing file and update it in place using the Edit tool.
- **Use rolling averages** to incorporate new data without losing history:
  ```
  new_avg = (old_avg × old_count + new_value) / (old_count + 1)
  new_count = old_count + 1
  ```
- **Cap history at last 10 runs** per agent type. When `run_count` exceeds 10, replace the oldest run's contribution with the new one using a sliding window rather than a simple rolling average. This prevents stale data from dominating over time.
- **Outlier tasks** (> 3x estimate) are excluded from the averages but noted in the Outlier Notes section. Keep at most the 5 most recent outliers — remove older entries to avoid unbounded growth.
- **Model escalation patterns** are cumulative — add new patterns as observed, update the "X/Y times" tally for existing patterns.

---

## 6. Edge Cases

**First run in a project:** No memory file exists. Use default estimates. After the run, if the write threshold is met, create the memory file with initial data. The `sample_count` and `run_count` will both be 1 — treat this as provisional data and note it in the calibration log: `"Applied estimation calibration from 1 prior run (provisional — increase reliability after 3+ runs)."`

**Anomalous run:** A single task took far longer than expected due to external factors (debugging a broken environment, waiting for a slow API). Exclude tasks > 3x their estimate from averages, but record them in the Outlier Notes section with a context note so the pattern is visible for future review.

**Memory file manually deleted:** Gracefully fall back to defaults. No error — treat the project as if it has no history. Begin accumulating fresh data from the next run if the write threshold is met.

**Different project structures:** Memory is per-project (stored in `~/.claude/projects/<project>/memory/`). Calibration data does not transfer between projects. A project with many small executor tasks and a project with large refactors will have different natural baselines.

**Run with no timing data:** If task metadata is missing `started_at` or `completed_at` values (e.g., timing was not recorded due to a session interruption), skip the write for that run. Do not overwrite valid historical data with incomplete observations.

## Cross-Run Learning

Informs decisions but doesn't override them.

- **Record:** Task patterns needing adaptation, agent effectiveness, timing patterns.
- **Don't record:** Specific file paths/line numbers, task descriptions, anything derivable from git history.
- **Use:** Check memory at run start, apply as soft defaults, log when applied: "Applied learned pattern: using opus for auth module tasks (based on past run)."
  - Assign preferred model from the start (don't wait for failure to escalate).
  - Default to sequential dispatch or suggest `--worktree` if past runs hit conflicts.
  - Use the mapped agent type directly (don't route to a wrong agent then reassign).

Write patterns as a feedback-type memory file (e.g., `feedback_team_patterns.md`). One pattern per entry with a **Why** and **How to apply** line.
