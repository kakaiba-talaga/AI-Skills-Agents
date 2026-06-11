<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Help Card

````
## Team Manager — Quick Reference

### Commands
  /ops <spec>           Plan and execute a task from a spec
  /ops plan             Dispatch planner first, then execute
  /ops execute          Execute a plan already in conversation
  /ops status           Show current task board and progress
  /ops resume           Pick up from existing task list
  /ops save             Manual checkpoint: state + redacted conversation context, optional reflect
  /ops ralph "<goal>"   Wrap in a ralph loop for iterative goals
  /ops help             Show this reference card

### Flags
  --autonomous     Run end-to-end; stops on escalation/blockers and brainstorm approval gates
  --supervised     Checkpoint after every single task
  --parallel N     Max concurrent agents (default: 3)
  --agents <list>  Comma-separated agent types to use
  --dry-run        Show task board without dispatching
  --worktree       Isolate parallel agents in git worktrees
  --no-branch      Skip working branch creation, work on current branch
  --no-deslop      Skip the deslop cleanup stage after verification
  --cost           Enable cost estimate reporting in Phase 4 and the completion dashboard (off by default)
  --budget=<N>     Optional run-level dispatch-count ceiling, advisory/escalation-only (never drops work or skips a correctness check)
  --no-adaptation-memory  Skip the Phase 4 durable-ledger capture of this run's adaptations
  --brainstorm     Run interviewer → architect and require design approval before planning
  --dispatch-log   Opt-in audit log: append each dispatch to docs/ops-dispatch-log.md (off by default)
  --security-review  off|always  By default runs only when the change looks security-related; off disables it; always runs it on every stage
  --tdd            Executor follows RED-GREEN-REFACTOR; verifier adds a TDD-discipline check
  (advanced: --code-intel, --corpus-search, --memory-inject, --skip-baseline — see README Options)

### Mid-run actions (say these during a run)
  stop / cancel    Stop dispatching, preserve task list
  pause            Pause dispatching, resume later with "resume"
  status           Show dashboard without interrupting
  skip <stage/#N>  Skip a stage or task, update dependencies
  drop #N          Remove a task, clear downstream blockers
  do #N next       Promote a task to dispatch immediately
  add <task>       Inject a new task into the board
  reprioritize     Pause and show board for reordering

### Autonomy modes
  Interactive (default)  Checkpoints after each pipeline stage
  Autonomous             Runs end-to-end, stops at decision points
  Supervised             Checkpoints after every task

### Pipeline
  executor → verifier → [security-reviewer] → deslop → code-reviewer → documentor
  (verify → fix loops up to 3× before escalation)
  (deslop runs by default; --no-deslop to skip)

### Adaptability
  Plan adjustment    Adds/splits/reorders tasks when agents discover issues
  Model escalation   sonnet → opus, opus → fable on 3rd failure before escalating to user
  Strategy shift     Sequential ↔ parallel based on conflicts and throughput
  Cross-run learning Recalls patterns from past runs (agent fit, model needs)
  Adaptation memory  Phase 4 writes a rollup to the durable per-project ledger (--no-adaptation-memory to skip)
  Budget governor    Consults the --budget=<N> dispatch ceiling at cost choice points; escalation-only, never skips verification

### Timing (always tracked)
  Per-task           Start/end timestamps, duration
  Per-stage          Sum of task durations grouped by pipeline stage
  Total wall time    First dispatch to last completion
  Dashboard          Timing section shown in every status display
````
