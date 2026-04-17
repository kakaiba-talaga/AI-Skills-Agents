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

### Walk through a minimal template

Start with the [Minimal template example](#minimal-template-example) below — it is the smallest working template. Then extend it section by section as needed:

- **`template_id` / `version` / `name` / `description`** — Header metadata. `template_id` is the only required field; use kebab-case. It is the id you pass to `--template`.
- **`parameters`** — Values the user provides at `start` via `--param key=value`. Reference them anywhere in the template as `{{param_name}}`; placeholders are resolved once at creation and frozen. Types: `string`, `number`, `path`, `boolean`. See [template-system.md](../template-system.md#default-fill-semantics) for Default-fill semantics and how the resolver writes the fully-expanded frozen copy.
- **`acceptance_criteria`** — Defines when the task is done. Choose a `mode` (`overall`, `per_category`, or `all_pass`), set thresholds, and list categories with `metric_path` keys. The loop evaluates these automatically during Verify. Full rules and the results-table format are in [Acceptance Criteria](../execution-extras.md#acceptance-criteria).
- **`hooks`** — Inject commands at pipeline stages (`frame`, `plan`, `execute`, `verify`, `cleanup`, `reflect`). The `verify` stage has extra fields: `command`, `metric_extraction` (json / regex / table parsers), and `for_each` for fan-out across multiple inputs. Fan-out details are in [Subagent Parallelism in Verify](../execution-extras.md#subagent-parallelism-in-verify). The `cleanup` hooks (`pre` / `post`) wrap the deslop pass; see [cleanup-deslop.md](../cleanup-deslop.md). Read cadence (the loop reads the frozen template once per iteration at Frame) is described in [template-system.md](../template-system.md#read-cadence).
- **`auto_pause`** — Heuristics that trigger a recommended stop: plateau detection, diminishing-returns window, max-iterations cap, regression halt, recurring-failure streak. In interactive mode these are recommendations you can override; in headless mode they trigger automatic stops. All fields have safe defaults and can be omitted.
- **`auto_advance`** — Controls whether the loop can skip or combine stages on resume (`frame_plan_combine`, `skip_frame_on_resume`, `conditions`). Only evaluated when resuming a paused task; fresh iterations always run all stages.
- **`headless`** — Defaults for unattended execution (`auto_decide`, `max_iterations_per_run`, `exit_on_target`, `exit_on_plateau`, `report_format`). Requires `--headless` at start. Fields can be overridden on the command line.

When in doubt, compare against the built-in templates in this directory. Good starting points by purpose:

- **`refactor.yaml`** — test-gated refactoring with a single test command
- **`test-coverage.yaml`** — coverage target with regex metric extraction
- **`accuracy-improvement.yaml`** — multi-category per-file fan-out verification

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
