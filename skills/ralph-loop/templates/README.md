# Ralph Loop Templates

Templates are reusable YAML recipes that tell the Ralph Loop **how** to verify, measure, and decide. They pre-define verification commands, acceptance criteria, auto-pause rules, and stage hooks so you don't have to re-explain them every conversation.

For general Ralph Loop usage (commands, workflow, modes, work items), see the [Ralph Loop README](../README.md).

## Do I need a template?

**No.** Ralph Loop works fine without one. Templates are optional.

| Situation | Use a template? |
|---|---|
| Task with known verification steps | Yes |
| Repeating a similar task across projects | Yes |
| One-off exploratory improvement | No |
| Headless (unattended) execution | Yes -- required |

## Available templates

| Template | Best for | Key parameters |
|---|---|---|
| `accuracy-improvement` | ML metrics, detection precision | `verify_command`, `input_dir`, `input_glob` |
| `refactor` | Code refactoring with test safety gates | `test_command`, `target_path`, `scope` |
| `test-coverage` | Increasing test coverage toward a target % | `test_command`, `coverage_report`, `target_coverage` |
| `bug-hunt` | Systematic reproduce-fix-verify cycles | `test_command`, `repro_command`, `bug_list` |
| `migration` | Moving code from one pattern/framework to another | `test_command`, `source_pattern`, `target_dir` |

## Using a template

```bash
/ralph-loop start --template accuracy-improvement \
  --param verify_command="python tools/verify.py" \
  --param input_dir="data/input" \
  --percent 90
```

Pass required parameters with `--param key=value`. Optional parameters use their defaults when omitted.

When a task starts with `--template`, the loop resolves all `{{param}}` placeholders and saves a **frozen copy** alongside the task's state file. The original template is never modified, and later edits to the source template don't affect running tasks.

### File layout per task

```
<state_dir>/
  <task_id>.json              # state (where you are)
  <task_id>.template.yaml     # resolved template (frozen at creation)
  <task_id>.history.jsonl     # event log (append-only)
```

## Writing your own template

Copy any template in this directory and modify it. Save it as `~/.claude/skills/ralph-loop/templates/<your-id>.yaml`.

A template has 7 sections. All are optional except `template_id`.

---

### Header

```yaml
template_id: my-template        # unique, kebab-case -- referenced with --template
version: 1                      # schema version, always 1 for now
name: "Human-Readable Name"     # shown in listings
description: "When and why to use this template"
```

---

### Parameters

Values the user provides at `start` via `--param key=value`. Use `{{param_name}}` anywhere in the template to reference them -- placeholders are resolved once at task creation and frozen.

```yaml
parameters:
  - name: verify_command
    type: string
    required: true
    description: "Command that outputs JSON metrics"

  - name: input_dir
    type: path
    required: false
    default: "data/input"
    description: "Directory containing input files"
```

**Types:**

| Type | Accepts | Example |
|---|---|---|
| `string` | Any text | `"pytest --cov=src"` |
| `number` | Numeric value | `90` |
| `path` | File or directory path | `"data/input"` |
| `boolean` | true/false | `true` |

---

### Acceptance criteria

Defines when the task is considered done. The loop evaluates these automatically during Verify.

```yaml
acceptance_criteria:
  mode: per_category
  overall_threshold: 90
  categories:
    - name: walls
      threshold: 96
      metric_path: "wall"
      weight: 0.5
    - name: doors
      threshold: 90
      metric_path: "door"
      weight: 0.3
    - name: windows
      threshold: 90
      metric_path: "window"
      weight: 0.2
```

**Modes:**

| Mode | Done when | Use for |
|---|---|---|
| `overall` | Single overall metric >= `overall_threshold` | One number to optimize (coverage, score) |
| `per_category` | Every category independently meets its `threshold` | Multiple metrics that all matter |
| `all_pass` | Every category passes AND overall >= `overall_threshold` | Strictest -- both individual and aggregate |

During Verify, the loop outputs a results table:

```
| Category | Measured | Threshold | Status |
|----------|----------|-----------|--------|
| walls    | 96.8%    | 96%       | PASS   |
| doors    | 90.8%    | 90%       | PASS   |
| windows  | 79.8%    | 90%       | FAIL   |
```

`achieved_percent` is computed as the weighted average of `(measured / threshold * 100)` per category, capped at 100.

**Interaction with work items:** Categories track quantitative metrics. Work items (scaffolded by Frame) track qualitative deliverables. Both are evaluated -- a work item can be `done` while a category is still below threshold, and vice versa.

---

### Hooks

Hooks inject commands at specific points in the stage pipeline. Every stage supports `pre` (before) and `post` (after). The `verify` stage has additional fields for automated verification.

```yaml
hooks:
  frame:
    pre: null
    post: null
  plan:
    pre: null
    post: null
  execute:
    pre: "{{test_command}} --tb=short 2>&1 | tail -5"
    post: null
  verify:
    pre: null
    command: "{{verify_command}}"
    metric_extraction:
      format: json
      paths:
        overall: ".overall_precision"
        wall: ".per_type.walls.precision"
        door: ".per_type.doors.precision"
    for_each:
      source: "ls {{input_dir}}/*.pdf"
      parallel: true
      max_concurrency: 4
      per_item_command: "{{verify_command}} --file {{item}}"
      aggregation: average
    post: null
  cleanup:
    pre: null
    post: null
  reflect:
    pre: null
    post: null
```

**`metric_extraction.format` options:**

| Format | How it parses output | When to use |
|---|---|---|
| `json` | Extracts values via `paths` (jq-style dotted keys) | Command outputs JSON |
| `regex` | Extracts named groups via `pattern` | Command outputs human-readable text |
| `table` | Parses tabular output | Command outputs columnar data |

**`regex` example:**

```yaml
metric_extraction:
  format: regex
  pattern: "(?P<passed>\\d+) passed.*(?P<failed>\\d+) failed"
```

**`for_each` -- parallel verification:**

Fans out across multiple inputs instead of running one command.

| Field | What it does |
|---|---|
| `source` | Command that outputs a list of items (one per line) |
| `parallel` | `true` = spawn subagents concurrently; `false` = sequential |
| `max_concurrency` | Max parallel subagents (default 4) |
| `per_item_command` | Command per item -- `{{item}}` is replaced with each item |
| `aggregation` | How to combine results: `average`, `min`, `max`, or `sum` |

If `for_each` is omitted, the single `command` runs once.

**`cleanup` hooks:** Run `pre` before the linter pass and `post` after regression re-verification succeeds. Only relevant when `deslop_enabled` is true (the default).

---

### Auto-pause

Controls when the loop recommends stopping. Evaluated during every Reflect stage.

```yaml
auto_pause:
  plateau_iterations: 3
  plateau_threshold: 0.5
  diminishing_returns:
    enabled: true
    window: 3
    min_delta: 1.0
  max_iterations: 20
  regression_halt: true
  regression_threshold: 5.0
  recurring_failure:
    enabled: true
    threshold: 3
    action: block
```

**Heuristics reference:**

| Setting | What it checks | Default |
|---|---|---|
| `plateau_iterations` | Pause if no improvement for N iterations | 3 |
| `plateau_threshold` | Minimum delta (pp) to count as improvement | 0.5 |
| `diminishing_returns.window` | Sliding window size for average gain | 3 |
| `diminishing_returns.min_delta` | Minimum average gain per iteration (pp) | 1.0 |
| `max_iterations` | Hard cap on iteration count | 20 |
| `regression_halt` | Pause on significant metric drop | true |
| `regression_threshold` | Drop threshold (pp) | 5.0 |
| `recurring_failure.enabled` | Track same-failure streaks | true |
| `recurring_failure.threshold` | Consecutive failures before escalating | 3 |
| `recurring_failure.action` | `block` (hard stop) or `pause` (soft stop) | `block` |

In interactive mode, these are recommendations you can override. In headless mode, they trigger automatic stops.

---

### Auto-advance

Controls whether the loop can skip or combine stages on resume.

```yaml
auto_advance:
  frame_plan_combine: true
  skip_frame_on_resume: false
  conditions:
    - when: "resume and next_step is actionable"
      advance_to: Execute
```

Only applies when **resuming** a paused task. On a fresh iteration, all stages run. The loop checks whether `next_step` in the state file is specific enough to skip discovery stages.

---

### Headless

Defaults for unattended execution. Requires `--headless` flag at start.

```yaml
headless:
  auto_decide: true
  max_iterations_per_run: 5
  exit_on_target: true
  exit_on_plateau: true
  report_format: json
```

| Setting | What it does | Default |
|---|---|---|
| `auto_decide` | Auto-decide at every decision point | true |
| `max_iterations_per_run` | Safety cap per headless invocation | 5 |
| `exit_on_target` | Stop when acceptance criteria met | true |
| `exit_on_plateau` | Stop when auto-pause triggers | true |
| `report_format` | Final report format: `json`, `markdown`, or `silent` | `json` |

`--max-headless-iters N` on the command line overrides `max_iterations_per_run`.

---

## Minimal template example

The smallest useful template -- just a verify command and one threshold:

```yaml
template_id: simple-test-pass
version: 1
name: "Make Tests Pass"
description: "Keep iterating until all tests pass"

parameters:
  - name: test_command
    type: string
    required: true
    description: "Test runner command"

acceptance_criteria:
  mode: overall
  overall_threshold: 100
  categories:
    - name: tests_passing
      threshold: 100
      metric_path: "pass_rate"

hooks:
  verify:
    command: "{{test_command}}"
    metric_extraction:
      format: regex
      pattern: "(?P<pass_rate>\\d+)% passed"
```

Everything else (auto-pause, auto-advance, headless, other hooks) uses built-in defaults when omitted.

## Full YAML schema reference

```yaml
template_id: string              # required, unique, kebab-case
version: 1                       # schema version
name: "Human-readable name"
description: "What this template is for"

parameters:
  - name: string
    type: string|number|path|boolean
    required: true|false
    default: any
    description: "Shown to user on missing required param"

acceptance_criteria:
  mode: overall|per_category|all_pass
  overall_threshold: number
  categories:
    - name: string
      threshold: number
      metric_path: string
      weight: number              # optional

hooks:
  frame:   { pre: string|null, post: string|null }
  plan:    { pre: string|null, post: string|null }
  execute: { pre: string|null, post: string|null }
  verify:
    pre: string|null
    command: "{{param}}-interpolated command"
    metric_extraction:
      format: json|regex|table
      paths:
        metric_name: ".jq.style.path"
      pattern: "regex with named groups"
    for_each:
      source: "command that outputs list of items"
      parallel: true|false
      max_concurrency: 4
      per_item_command: "command with {{item}} placeholder"
      aggregation: average|min|max|sum
    post: string|null
  cleanup: { pre: string|null, post: string|null }
  reflect: { pre: string|null, post: string|null }

auto_pause:
  plateau_iterations: 3
  plateau_threshold: 0.5
  diminishing_returns:
    enabled: true|false
    window: 3
    min_delta: 1.0
  max_iterations: 20
  regression_halt: true|false
  regression_threshold: 5.0
  recurring_failure:
    enabled: true|false
    threshold: 3
    action: block|pause

auto_advance:
  frame_plan_combine: true|false
  skip_frame_on_resume: true|false
  conditions:
    - when: "description of condition"
      advance_to: Execute|Verify

headless:
  auto_decide: true|false
  max_iterations_per_run: 5
  exit_on_target: true|false
  exit_on_plateau: true|false
  report_format: json|markdown|silent
```
