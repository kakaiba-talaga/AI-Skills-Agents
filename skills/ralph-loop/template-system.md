<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Template System

Templates define reusable loop recipes: verify commands, metric extraction, acceptance criteria, stage hooks, auto-pause rules, and auto-advance behavior. They are stored as YAML files at `~/.claude/skills/ralph-loop/templates/`.

**Resolution order (on `start` only):**

1. If `--template <id>` is provided, load `~/.claude/skills/ralph-loop/templates/<id>.yaml`.
2. Resolve `{{param_name}}` placeholders using `--param` values, then template `parameters[].default` values.
3. Error if any parameter with `required: true` has no value.
4. Write the fully resolved template to `<state_dir>/<task_id>.template.yaml` alongside the state JSON.
5. Store `template_id` in the state file (as a reference to the original; the resolved copy is authoritative).

**On `resume`:** Read the resolved `<task_id>.template.yaml` from the state directory. Never re-resolve from the original template. This ensures the task is self-contained and immune to later edits of the source template.

**Task file layout:**

```text
<state_dir>/
  <task_id>.json              # state file (where you are)
  <task_id>.template.yaml     # resolved template (how to operate, frozen at creation)
  <task_id>.history.jsonl     # event log (append-only)
```

**Template fields used by stages:**

- `acceptance_criteria` -- used by Verify and Reflect to auto-evaluate pass/fail per category.
- `hooks.verify.command` -- the verification command to run during Verify.
- `hooks.verify.metric_extraction` -- how to parse numeric metrics from command output.
- `hooks.verify.for_each` -- fan-out verification across multiple inputs (see Subagent Parallelism).
- `hooks.cleanup` -- optional pre/post hooks for the Cleanup (deslop) stage.
- `auto_pause` -- evaluated during Reflect (see Auto-pause Heuristics).
- `auto_advance` -- evaluated when resuming (see Stage Transitions).
- `headless` -- defaults for headless mode.

**Without a template:** The loop behaves exactly as before. All template features are opt-in. State files without `template_id` are fully backward-compatible.

**Template YAML schema:**

```yaml
template_id: string              # unique identifier, kebab-case
version: 1                       # schema version for forward compat
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
  overall_threshold: number       # optional floor
  categories:
    - name: string
      threshold: number
      metric_path: string         # key in metric output to extract
      weight: number              # optional, for weighted average

hooks:
  frame:   { pre: string|null, post: string|null }
  plan:    { pre: string|null, post: string|null }
  execute: { pre: string|null, post: string|null }
  verify:
    pre: string|null
    command: "{{param}}-interpolated command"
    metric_extraction:
      format: json|regex|table
      paths:                      # for json format
        metric_name: ".jq.style.path"
      pattern: "regex with named groups"  # for regex format
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
