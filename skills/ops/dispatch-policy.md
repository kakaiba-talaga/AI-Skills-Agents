<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Foreground/Background Dispatch Policy

## Foreground (default)

Default is **foreground** — the team manager blocks until the agent returns. Use foreground for:

- Tasks with `estimated_minutes` under 5 (fast enough that blocking is fine).
- Tasks on the critical path where downstream tasks are immediately blocked.
- The only ready task (no benefit to backgrounding when nothing else can run).

## Background

Use **background** (`run_in_background: true`) when the following conditions are met (guideline — adapt based on runtime conditions):

- The task's `estimated_minutes` is 8 or more (long enough that blocking the session is costly).
- At least one other task is ready or will become ready soon (backgrounding is pointless if there is nothing else to do).
- The run is not in `--supervised` mode (supervised mode implies tighter user control).

### Additional background triggers

- The user explicitly requests it ("run this in the background", "keep the session interactive").
- Two or more independent chains can advance concurrently — dispatch one chain's task in the background and the other in the foreground, or both in the background if the team manager has no foreground work to do.

## Threshold Adaptation

The 8-minute threshold is a guideline, not a hard rule. Adapt based on runtime conditions — if a 6-minute task has 3 downstream dependents waiting, foreground is better to unblock them quickly. If a 5-minute task is the only one running and the user is actively interacting, background may be appropriate.

## Parallel Batch Decisions

When dispatching a parallel batch, apply the foreground/background decision per-task independently. Short tasks in a batch (under 5 minutes) can still run in foreground while longer tasks in the same batch run in background — or background the entire batch for simplicity when any task in it exceeds the threshold.

## Interaction with Health Monitoring

Background agents are subject to the check-in schedule and proactive warnings defined in `agent-health-monitoring.md` Sections 3 and 3a. The team manager must check background agent health at every check-in event.

## Interaction with Worktree Isolation

`run_in_background` and `isolation: "worktree"` are orthogonal — they can be combined. `run_in_background` controls whether the team manager blocks while waiting; `isolation: "worktree"` controls whether the agent gets its own copy of the repo. A long-running executor task that also needs file isolation can use both. When combining, the team manager must track both the background notification and the worktree branch for later merge.
