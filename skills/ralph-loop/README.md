# Ralph Loop

`/ralph-loop` runs an iterative AI development loop that keeps working on a task until it's done. It breaks work into discrete, testable deliverables (work items), executes them through a 6-stage loop — Frame → Plan → Execute → Verify → Cleanup → Reflect — and tracks progress across iterations using a persistent state file. Each iteration ends with automatic linting cleanup and a git snapshot, giving you rollback to any prior state. The loop knows when to stop: it detects plateaus, regressions, and recurring failures, and reports them before retrying endlessly.

Use it when a task is too large or uncertain for a single shot and you want checkpoints, measurable progress, and automatic cleanup along the way.

## Quick start

```bash
# Start a new task with a percentage target
/ralph-loop start --percent 90 improve API response times

# Resume a paused task
/ralph-loop resume --task search-optimizer-v2

# Check progress on a running task
/ralph-loop status --task search-optimizer-v2

# List all tasks (optionally filter by status)
/ralph-loop list --status active

# Use a template for structured verification, run unattended
/ralph-loop start --template test-coverage \
  --param test_command="pytest --cov=src --cov-report=json" \
  --headless --max-headless-iters 10
```

## Skill file structure

All files live in `~/.claude/skills/ralph-loop/`. The main file orchestrates; companions are loaded on demand.

| File | Lines | Purpose | Loaded when |
| :--- | ---: | :--- | :--- |
| `SKILL.md` | 345 | Argument parsing, workflow, stage discipline, all cross-references | Every invocation |
| `template-system.md` | 157 | Template resolution, YAML schema, template fields, read cadence | `--template` is used |
| `state-schema.md` | 112 | Complete JSON schema, field types, pruning policy | State init or troubleshooting |
| `cleanup-deslop.md` | 76 | Linter rules, deslop escalation, regression procedure | Cleanup stage execution |
| `lightweight-mode.md` | 43 | Single-pass Execute + Verify workflow, badge format, upgrade path | `--lightweight` is used |
| `history-analytics.md` | 38 | JSONL log format, write procedure, event types | Writing history events |
| `rollback.md` | 32 | Git snapshot procedure, rollback command sequence, safety rules | `rollback` command or Reflect snapshot |
| `usage-examples.md` | 32 | Full command and flag examples | Help / reference |
| `acceptance-criteria.md` | 29 | Auto-evaluation modes, per-category thresholds | Template defines `acceptance_criteria` |
| `subagent-parallelism.md` | 22 | Fan-out verification, aggregation strategies | Template defines `for_each` |
| `templates/README.md` | — | YAML schema, parameter reference, template authoring guide | Writing or debugging templates |

## When to use / When not to use

**Use `/ralph-loop` when:**

- The task spans multiple deliverables or iterations — you need work-item tracking and per-iteration checkpoints.
- You want iterative improvement toward a measurable target: a percent, a metric threshold, or a milestone.
- Automatic cleanup (linting, deslop) after every iteration is important for code quality.
- You need unattended (headless) execution with a structured verify command and auto-stop on plateau.
- Rollback to a prior iteration state is a realistic need.

**Skip it when:**

- The task is a simple one-liner — use `--lightweight` for trivial fixes, or run directly.
- You need a code review pass only — use `/code-review`.
- You're deploying — use `tooling/deploy.{ps1,sh}` directly (not `/deploy`).
- The task is fully specified with no iteration needed — a single executor invocation finishes it faster.

## Key flags

| Flag | What it does |
| :--- | :--- |
| `--percent <0-100>` | Target completion percentage; loop stops when reached |
| `--goal "<text>"` | Milestone-based target instead of (or alongside) a percentage |
| `--template <id>` | Load a YAML template for structured verify, metrics, and auto-pause |
| `--param <key>=<value>` | Set a template parameter (repeatable); only valid with `--template` |
| `--headless` | Unattended mode — no prompts, auto-decides at every stage; requires a template |
| `--max-headless-iters N` | Override headless iteration cap (default 5) |
| `--lightweight` | Single-pass Execute + Verify for trivial fixes; incompatible with `--template` and `--headless` |
| `--no-deslop` | Skip the Cleanup stage (linter pass) entirely |
| `--full-deslop` | Force full `/deslop` skill every Cleanup stage; incompatible with `--no-deslop`. |
| `--loop-mode balanced\|strict` | `balanced` (default) auto-advances stages; `strict` sends one stage per message always |

For the full flag list and detailed behavior, see `SKILL.md` (argument parsing section).

## Templates

Five built-in templates are available. Each defines verify commands, metric extraction, acceptance criteria, and auto-pause rules. Templates are optional — the loop works without one.

| Template | Best for |
| :--- | :--- |
| `accuracy-improvement` | ML metrics, detection precision, per-category thresholds |
| `refactor` | Code refactoring with test safety gates |
| `test-coverage` | Pushing test coverage toward a target percentage |
| `bug-hunt` | Systematic reproduce → fix → verify cycles |
| `migration` | Moving code from one pattern or framework to another |

Load a template with `--template <id>` and pass parameters with `--param <key>=<value>`. For the full YAML schema and authoring guide, see `templates/README.md`.

## Storage

Task state is stored as JSON files outside `.claude/` to avoid confirmation prompts. Three scope modes:

| Mode | Location | Use for |
| :--- | :--- | :--- |
| `project` (default) | `<workspace>/.ralph-state/` | Project-specific tasks |
| `global` | `~/.ralph-state/` | Cross-project tasks |
| `folder` | `<custom_path>/ralph-state/` | Custom location |

Each task produces up to three files: `<task_id>.json` (state), `<task_id>.template.yaml` (resolved template, frozen at creation), and `<task_id>.history.jsonl` (append-only event log). Tasks created in the legacy `.claude/state/ralph-wiggum-loop/` location are auto-discovered and migrated on first write. See `state-schema.md` for the full schema.

## Output format

Every turn during an active loop opens with the **`Ralph Loop`** badge and a 6-step progress checklist showing which stages are done (`✅`) and which remain (`🟦`). In lightweight mode the checklist collapses to 2 steps. In headless mode no user prompts are issued — the loop auto-decides at every decision point and exits on plateau or target-reached per the template config.

## For details, see

| Topic | File |
| :--- | :--- |
| Full argument parsing, stage rules, workflow, all constraints | `SKILL.md` |
| Template YAML schema, resolution order, parameter reference | `template-system.md` |
| Cleanup stage: linter rules, deslop escalation, regression procedure | `cleanup-deslop.md` |
| State JSON schema, field types, pruning policy | `state-schema.md` |
| Lightweight mode workflow, badge format, upgrade path | `lightweight-mode.md` |
| JSONL history log format, event types, write procedure | `history-analytics.md` |
| Rollback procedure, git snapshot sequence, safety rules | `rollback.md` |
| Full command and flag examples | `usage-examples.md` |
| Acceptance criteria auto-evaluation, per-category thresholds | `acceptance-criteria.md` |
| Subagent parallelism, fan-out verification, aggregation | `subagent-parallelism.md` |
| Template YAML schema, authoring guide, built-in templates | `templates/README.md` |
