# Timing Calibrator

Self-improving calibration loop for agent task duration estimates. Captures timing patterns from completed runs and feeds them back into future estimates so each run is more accurate than the last.

## How it works

```
Run N completes → capture timing patterns → write to memory file
Run N+1 starts  → read memory file → apply calibration to estimates
```

1. After a run completes, `capture` extracts per-agent-type averages, estimation accuracy ratios, outlier tasks, and model escalation patterns from the task metadata
2. Data is persisted to a memory file using rolling averages with a 10-run sliding window per agent type
3. Before the next run, `read` loads the calibration data so the orchestrator can adjust estimates and pre-assign models

## Quick start

```bash
# Read calibration data for the current project
/timing-calibrator read

# Capture timing data from a completed run
/timing-calibrator capture <task-data>

# Show usage
/timing-calibrator help
```

## Commands

| Command | What it does |
|---|---|
| `read` | Load calibration data from the memory file. Returns per-agent-type averages, overall accuracy ratio, and model escalation patterns. Returns a "no data" message if no memory file exists. |
| `capture <task-data>` | Persist timing data from a completed run. Task metadata can be inline or a reference to a state file. Only writes when the signal is meaningful (see write threshold below). |
| `help` | Display the quick-reference card |

## Write threshold

The `capture` command only writes to the memory file when at least one of these is true:

- Overall variance exceeds 30% (actual/estimated ratio > 1.3x or < 0.7x)
- A new agent type or pipeline stage appeared with no prior data
- Model escalation occurred at least once
- This is the 3rd or later run for the project

Single-run data is noise. The threshold ensures only meaningful signals are persisted.

## What it captures

| Data | Source | Used for |
|---|---|---|
| Per-agent-type average duration | Task `duration_seconds` grouped by `agent_type` | Replacing default heuristic estimates with historical averages |
| Per-stage average duration | Task `duration_seconds` grouped by `stage` | Stage-level estimation |
| Estimation accuracy ratio | Overall `actual / estimated` across all tasks | Calibrating default estimates for agent types with no history |
| Outlier tasks | Tasks exceeding 2x their estimate | Pattern visibility — excluded from averages to prevent skew |
| Model escalation patterns | Tasks where model was escalated (sonnet → opus) | Pre-assigning opus to task types that consistently need it |

## Memory file

**Location:** `feedback_ops_timing_patterns.md` in the project memory directory.

- Claude Code: `~/.claude/projects/<project>/memory/`
- Cursor: project-local memory if available, otherwise the project root

**Format:** Markdown with YAML frontmatter (`type: feedback`). Three sections: Estimation Calibration, Model Escalation Patterns, Outlier Notes. Each section includes **Why** and **How to apply** lines for the consuming orchestrator.

**Update rules:**

- Rolling averages incorporate new data without losing history
- 10-run sliding window per agent type prevents stale data from dominating
- Outlier tasks (> 3x estimate) are excluded from averages but recorded — keep at most 5 recent outliers
- Model escalation patterns accumulate with tallies (e.g., "escalated 2/3 times")
- Never create a duplicate file — read and update in place

## Ops integration

The `/ops` skill invokes the timing-calibrator at two points:

- **Phase 2 (Task Board Creation):** `read` — load calibration data to adjust `estimated_minutes` for each task. Agent types with historical averages use those averages directly. Agent types with no history use the default heuristic multiplied by the overall calibration ratio. Tasks matching model escalation patterns get opus assigned from the start.
- **Phase 4 (Completion):** `capture` — persist timing data from the completed run's task metadata.

## Edge cases

- **First run:** No memory file exists. Default estimates are used. After the run, the file is created if the write threshold is met.
- **Anomalous run:** Tasks > 3x estimate are excluded from averages but noted in Outlier Notes.
- **Memory file deleted:** Falls back to defaults gracefully. Begins accumulating fresh data.
- **Per-project isolation:** Memory is per-project. Calibration data does not transfer between projects.
- **Incomplete timing:** If tasks are missing `started_at` or `completed_at`, the capture is skipped for that run.

## Cross-run learning

Beyond raw timing, the skill can capture behavioral patterns as a separate memory file (`feedback_team_patterns.md`):

- Task patterns needing adaptation (e.g., "auth module tasks consistently need opus")
- Agent effectiveness (e.g., "verifier catches more issues when given narrower scope")
- Dispatch patterns (e.g., "sequential dispatch was forced after file conflicts")

Each pattern has a **Why** and **How to apply** line. These are soft defaults — they inform decisions but don't override explicit user instructions.
