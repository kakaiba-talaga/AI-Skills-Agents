# Ralph Loop

An iterative AI development loop that keeps working on a task until it's done. Ralph breaks work into discrete items, executes them stage-by-stage, tracks progress across iterations, and knows when to stop.

## How it works

Ralph runs a **6-stage loop** per iteration:

```
Frame --> Plan --> Execute --> Verify --> Cleanup --> Reflect
  |                                                     |
  +------- next iteration (if work remains) <-----------+
```

1. **Frame** -- Scope the iteration. On iteration 1, scaffold work items from the task description. On iteration 2+, pick the next pending item.
2. **Plan** -- Choose one approach for this iteration. 1-5 sentences, no deliberation.
3. **Execute** -- Implement the planned change.
4. **Verify** -- Run tests, builds, or checks. Confirm the work item's acceptance criteria are met.
5. **Cleanup** -- Auto-fix lint issues on changed files, then re-verify to catch regressions.
6. **Reflect** -- Assess progress, capture learnings, track failures, decide whether to continue.

The loop continues until all work items are done, the target is reached, or a stop condition triggers.

## Quick start

```bash
# Start a task with a target percentage
/ralph-loop start --percent 90 improve API response times

# Start with a goal instead
/ralph-loop start --goal "All legacy callbacks converted to async/await"

# Trivial one-shot fix (skip the full ceremony)
/ralph-loop start --lightweight fix the typo in README header

# Use a template for structured verification
/ralph-loop start --template accuracy-improvement \
  --param verify_command="python verify.py" \
  --param input_dir="data/input" --percent 90

# Unattended execution
/ralph-loop start --template test-coverage \
  --param test_command="pytest --cov=src --cov-report=json" \
  --headless --max-headless-iters 10
```

## Skill file structure

The ralph-loop skill is modular -- the main file orchestrates, and companion files provide detailed reference for specific features. All files live in `~/.claude/skills/ralph-loop/`.

| File | Purpose | Loaded when |
| :--- | :--- | :--- |
| `SKILL.md` | Main skill: argument parsing, workflow, stage discipline, all cross-references | Every invocation |
| `template-system.md` | Template resolution, YAML schema, template fields | `--template` is used |
| `acceptance-criteria.md` | Auto-evaluation modes, per-category thresholds | Template defines `acceptance_criteria` |
| `rollback.md` | Git snapshot procedure, rollback command sequence | `rollback` command or Reflect snapshot |
| `cleanup-deslop.md` | Linter rules, deslop escalation, regression procedure | Cleanup stage execution |
| `lightweight-mode.md` | Single-pass Execute+Verify workflow, upgrade path | `--lightweight` is used |
| `subagent-parallelism.md` | Fan-out verification, aggregation strategies | Template defines `for_each` |
| `history-analytics.md` | JSONL log format, write procedure, event types | Writing history events |
| `state-schema.md` | Complete JSON state schema with all field types | State init or troubleshooting |
| `usage-examples.md` | Full list of command examples | Help / reference |

## Commands

| Command | What it does |
| :--- | :--- |
| `start <description>` | Create a new task |
| `resume --task <id>` | Resume a saved task |
| `status --task <id>` | Show current progress |
| `list` | List all tasks |
| `pause --task <id> --reason "<text>"` | Pause with a reason |
| `complete --task <id>` | Mark a task done |
| `rollback --to-iter N --task <id>` | Restore to iteration N |

### Flags

| Flag | Effect |
| :--- | :--- |
| `--percent <0-100>` | Set target completion percentage |
| `--goal "<text>"` | Set a milestone-based target |
| `--loop-mode balanced\|strict` | `balanced` (default) or `strict` (one stage per message always) |
| `--template <id>` | Load a YAML template from `~/.claude/skills/ralph-loop/templates/` |
| `--param <key>=<value>` | Set a template parameter (repeatable) |
| `--headless` | Run unattended; implies strict mode. Requires a template. |
| `--max-headless-iters N` | Override max iterations in headless mode (default 5) |
| `--no-deslop` | Skip the Cleanup stage entirely |
| `--full-deslop` | Forces the full `/deslop` skill to run during every Cleanup stage iteration, regardless of escalation triggers. Incompatible with `--no-deslop` (error if combined). Sets `full_deslop_enabled: true` in state. |
| `--lightweight` | Single-pass Execute + Verify only. Incompatible with `--template` and `--headless`. |
| `--status <status>` | Filter `list` output by status |
| `--mode global\|project\|folder` | Storage scope for `list` or `track` |
| `--path "<folder>"` | Required with `--mode folder` |

## Work item scaffolding

On iteration 1, Frame analyzes the task and breaks it into **work items** -- ordered deliverables with testable acceptance criteria.

```
| #      | Title                    | Acceptance criteria                              | Status  |
|--------|--------------------------|--------------------------------------------------|---------|
| WI-001 | Add date validation      | parse_date('2026-13-01') raises InvalidDateError  | pending |
| WI-002 | Wire into API endpoint   | POST /events returns 400 for invalid dates        | pending |
| WI-003 | Add regression tests     | tests/test_event_dates.py exists and passes       | pending |
```

**One-time approval:** You review and confirm the scaffold once. After that, the loop auto-advances through items without re-asking.

**Criteria quality matters.** Each criterion must be specific and testable -- never "implementation is complete." The scaffold enforces this:

| Bad | Good |
| :--- | :--- |
| "Tests pass" | "tests/test_date_parser.py exists and `pytest tests/test_date_parser.py` passes" |
| "Error handling works" | "parse_date('invalid') raises InvalidDateError" |

**Discovery:** If new sub-tasks emerge during execution, Reflect adds them as new work items automatically.

## Cleanup (deslop pass)

After Verify passes, the Cleanup stage runs the project's linter on files changed during the iteration. This catches formatting drift, unused imports, and other AI-generated noise before it accumulates.

**What gets auto-fixed:** Formatting, import sorting, unused imports, trailing whitespace, trivial auto-fixable rules.

**What doesn't:** Type changes, logic changes, suppressions, behavioral changes. These require confirmation in interactive mode and are skipped in headless mode.

**Regression safety:** After cleanup, the same verification checks from the Verify stage run again. If anything breaks, cleanup changes are reverted automatically and the loop continues with the pre-cleanup code.

Skip with `--no-deslop` when cleanup is out of scope.

## Iteration learnings

During Reflect, the loop captures **learnings** -- short, actionable insights discovered during the iteration. These persist in the state file and inform future iterations.

Good learnings: "Config parser silently drops keys with dots -- use bracket notation."
Bad learnings: "The parser is complex."

Frame reads learnings on iteration 2+ and surfaces any that affect the current approach. Stale learnings are pruned automatically. Capped at 15 entries.

Each iteration's learnings are also snapshot into the JSONL history log for retrospectives.

## Auto-pause and failure detection

The loop knows when to stop. These heuristics run during every Reflect:

| Heuristic | What it checks | Default |
| :--- | :--- | :--- |
| **Plateau** | No improvement for N iterations | 3 iterations, < 0.5pp delta |
| **Diminishing returns** | Average gain below threshold | Window of 3, < 1.0pp/iter |
| **Max iterations** | Hard cap | Warn at 15, pause at 20 |
| **Regression halt** | Metric dropped significantly | > 5.0pp drop |
| **Recurring failure** | Same failure 3+ consecutive iterations | Blocks with report |

**Recurring failure escalation** is the most aggressive: if the same test, error, or check fails for 3 straight iterations, the loop sets status to `blocked` and reports it as a fundamental problem requiring user input. This prevents infinite retry loops.

The `recurring_failure.action` parameter controls what happens when the threshold is reached: `block` (default) sets status to `blocked`; `pause` sets status to `paused` instead, allowing the loop to be resumed after the issue is addressed.

In interactive mode, heuristics are recommendations. In headless mode, they trigger automatic stops.

All heuristics are configurable via template `auto_pause` settings.

## Lightweight mode

For trivial fixes where the 6-stage workflow is overkill:

```bash
/ralph-loop start --lightweight add missing import for datetime in utils.py
```

Runs Execute + Verify only. No Frame, Plan, Reflect, or Cleanup. If Verify fails, you can retry (max 2 times) or upgrade to the full loop with failure context carried forward.

Cannot be combined with `--template` or `--headless`.

## Headless mode

Runs the loop unattended with no interactive prompts. Requires a template (needs to know how to verify automatically).

> **Permissions:** Headless mode suppresses skill-level prompts but not Claude Code tool permissions. To avoid being prompted for Bash commands during unattended runs, ensure your `settings.json` allows the tools your template uses (e.g., `Bash(.venv/*)` for Python venvs, `Bash(ruff *)` for cleanup). On Windows, add `Bash(tasklist *)` if process monitoring is needed.

```bash
/ralph-loop start --template accuracy-improvement \
  --param verify_command="python verify.py" \
  --headless --max-headless-iters 5
```

Stops when:

- Acceptance criteria are met (`exit_on_target: true`)
- Auto-pause triggers (`exit_on_plateau: true`)
- Max iterations reached

On exit, writes a summary to `context.headless_report` in the state file. Resume interactively to pick up where headless left off.

## Rollback

Every iteration creates a git tag (`ralph/<task_id>/iter-N`). Rollback restores files to that iteration's state without losing git history.

```bash
# See what changed since iteration 7, then restore
/ralph-loop rollback --to-iter 7 --task my-task
```

Shows a diff and asks for confirmation before restoring. The loop resumes from that iteration's Reflect stage.

## Storage

Task state is stored as JSON files outside `.claude/` to avoid sensitive-file confirmation prompts. Three storage modes:

| Mode | Location | Use for |
| :--- | :--- | :--- |
| `project` (default) | `<workspace>/.ralph-state/` | Project-specific tasks |
| `global` | `~/.ralph-state/` | Cross-project tasks |
| `folder` | `<custom_path>/ralph-state/` | Custom location |

**Migration:** Tasks created before the path change are auto-discovered from the legacy `.claude/state/ralph-wiggum-loop/` location and migrated on first write. In Cursor IDE, the fallback discovery path is `.cursor/state/ralph-wiggum-loop/`.

```bash
/ralph-loop track --mode global
/ralph-loop track --mode folder --path "D:/AI-Loop-State"
```

Each task produces up to three files:

```
<task_id>.json              # State (where you are)
<task_id>.template.yaml     # Resolved template (frozen at creation)
<task_id>.history.jsonl     # Event log (append-only)
```

## Templates

Templates define reusable recipes for verification, metrics, acceptance criteria, and auto-pause rules. They are optional -- the loop works fine without one.

Five built-in templates are available:

| Template | Best for |
| :--- | :--- |
| `accuracy-improvement` | ML metrics, detection precision |
| `refactor` | Code refactoring with test safety gates |
| `test-coverage` | Increasing test coverage toward a target % |
| `bug-hunt` | Systematic reproduce-fix-verify cycles |
| `migration` | Moving code from one pattern/framework to another |

See the [Templates README](../skills/ralph-loop/templates/README.md) for the full YAML schema, parameter reference, and guide to writing your own.

## Output format

Every assistant turn during an active loop starts with the **`Ralph Loop`** badge and a progress checklist:

```
**`Ralph Loop`** Iteration 3 -- Verify

Ralph Wiggum Loop Progress (Iteration 3)
- [x] 1) Frame the task.
- [x] 2) Plan the smallest useful step.
- [x] 3) Execute
- [ ] 4) Verify
- [ ] 5) Cleanup (deslop)
- [ ] 6) Reflect and Adjust
```

In lightweight mode: **`Ralph Loop`** (lightweight) with a 2-step checklist.

## Examples

### Starting tasks

```bash
# Free-form task with a percentage target
/ralph-loop start --percent 80 reduce false positives in wall detection

# Goal-based target (milestone instead of percentage)
/ralph-loop start --goal "All legacy callbacks converted to async/await"

# Both percent and goal together
/ralph-loop start --percent 40 --goal "Baseline refactor merged"

# Strict mode -- one stage per message, always
/ralph-loop start --loop-mode strict --percent 60

# Skip the cleanup/deslop pass
/ralph-loop start --no-deslop --percent 90 optimize the search indexer
```

### Lightweight mode (trivial fixes)

```bash
# One-line fix, skip the full 6-stage workflow
/ralph-loop start --lightweight fix the typo in README header

# Rename a variable
/ralph-loop start --lightweight rename getUserName to get_user_name in utils/

# Add a missing import
/ralph-loop start --lightweight add missing import for datetime in utils.py
```

### Using templates

```bash
# Accuracy improvement -- ML metrics with per-category thresholds
/ralph-loop start --template accuracy-improvement \
  --param verify_command="python tools/verify_elements.py" \
  --param input_dir="data/input" \
  --percent 90

# Accuracy improvement -- custom file glob
/ralph-loop start --template accuracy-improvement \
  --param verify_command="python tools/verify.py" \
  --param input_dir="data/input" \
  --param input_glob="*.pdf" \
  --percent 95

# Refactor -- safe code changes with test gates
/ralph-loop start --template refactor \
  --param test_command="pytest tests/" \
  --param scope="rename camelCase to snake_case in utils/"

# Refactor -- with a goal instead of percent
/ralph-loop start --template refactor \
  --param test_command="npm test" \
  --goal "All legacy callbacks converted to async/await"

# Test coverage -- push toward a target %
/ralph-loop start --template test-coverage \
  --param test_command="pytest --cov=src --cov-report=json" \
  --param target_coverage=85

# Bug hunt -- systematic reproduce-fix-verify
/ralph-loop start --template bug-hunt \
  --param test_command="pytest tests/regression/" \
  --param bug_list="login timeout, duplicate entries, missing validation"

# Migration -- move from one pattern to another
/ralph-loop start --template migration \
  --param test_command="pytest" \
  --param source_pattern="from old_auth import" \
  --param target_dir="src/"
```

### Headless (unattended) execution

```bash
# Run unattended with default iteration cap (5)
/ralph-loop start --template accuracy-improvement \
  --param verify_command="python verify.py" \
  --param input_dir="data/input" \
  --headless

# Higher iteration cap
/ralph-loop start --template test-coverage \
  --param test_command="pytest --cov=src --cov-report=json" \
  --headless --max-headless-iters 10

# Refactor in headless mode
/ralph-loop start --template refactor \
  --param test_command="pytest" \
  --headless --max-headless-iters 10

# Resume an existing task in headless mode
/ralph-loop resume --task per-element-accuracy-80 --headless
```

### Managing tasks

```bash
# Resume a paused task
/ralph-loop resume --task search-optimizer-v2

# Check status of a specific task
/ralph-loop status --task search-optimizer-v2

# Pause with a reason
/ralph-loop pause --task search-optimizer-v2 --reason "Waiting for new training data"

# Mark a task as complete
/ralph-loop complete --task search-optimizer-v2
```

### Listing and filtering

```bash
# List all tasks
/ralph-loop list

# List only active tasks
/ralph-loop list --status active

# List paused tasks in current project
/ralph-loop list --mode project --status paused

# List blocked tasks globally
/ralph-loop list --mode global --status blocked

# List completed tasks
/ralph-loop list --status done
```

### Rollback

```bash
# Roll back to iteration 7 (shows diff, asks confirmation)
/ralph-loop rollback --to-iter 7 --task per-element-accuracy-80

# Roll back to the very first iteration
/ralph-loop rollback --to-iter 1 --task search-optimizer-v2
```

### Storage modes

```bash
# Store tasks in the current project (default)
/ralph-loop track --mode project

# Store tasks globally (shared across projects)
/ralph-loop track --mode global

# Store tasks in a custom folder
/ralph-loop track --mode folder --path "D:/AI-Loop-State"
```

### Combining flags

```bash
# Template + no cleanup + percentage target
/ralph-loop start --template accuracy-improvement \
  --param verify_command="python tools/verify.py" \
  --no-deslop --percent 95

# Strict mode + percentage
/ralph-loop start --loop-mode strict --percent 60

# Template + headless + custom iteration cap
/ralph-loop start --template bug-hunt \
  --param test_command="pytest tests/regression/" \
  --param bug_list="login timeout, missing validation" \
  --headless --max-headless-iters 15
```
