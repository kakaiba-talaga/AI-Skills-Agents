Run the Ralph Wiggum loop workflow. Arguments: $ARGUMENTS

<!-- Preamble (this section, above the `# Part A` separator) — parsed once at start; neither Part A nor Part B. -->

**This is a custom skill.** The authoritative file is `~/.claude/skills/ralph-loop/SKILL.md`. It is NOT from the marketplace. The marketplace stub at `~/.claude/plugins/.../ralph-loop/` is unrelated -- do not read or edit it.

Parse arguments as follows:

- Any free-form text after `/ralph-loop` is treated as the task description.
- `start` creates or reinitializes a task.
- `resume --task <id>` resumes a saved task.
- `status --task <id>` reports current saved progress.
- `list` shows tasks with status and summary.
- `pause --task <id> --reason "<text>"` pauses and records reason.
- `complete --task <id>` marks task complete.
- `rollback --to-iter N --task <id>` rolls back to iteration N's git snapshot.
- `--loop-mode balanced|strict` sets loop execution mode.
- `--percent <0-100>` sets target percent.
- `--goal "<text>"` sets target milestone.
- `--status active|paused|blocked|done` filters `list` output.
- `--mode global|project|folder` filters `list` storage scope.
- `track --mode global|project|folder` sets storage mode.
- `--path "<folder>"` is required when `--mode folder`.
- `--template <id>` loads a YAML template from `~/.claude/skills/ralph-loop/templates/<id>.yaml`.
- `--param <key>=<value>` sets a template parameter. Repeatable. Only valid with `--template`.
- `--headless` runs in headless mode (no interactive prompts; auto-decides at each stage).
- `--max-headless-iters N` overrides the template's `headless.max_iterations_per_run` (default 5).
- `--no-deslop` skips the Cleanup stage (linter pass + regression re-verification) entirely. Use this only when the cleanup pass is intentionally out of scope for the run.
- `--full-deslop` forces the full `/deslop` skill to run during every Cleanup stage iteration, regardless of escalation triggers. Use when you want comprehensive structural cleanup every iteration, not just when triggers fire.
- `--lightweight` runs in lightweight mode: a single-pass Execute + Verify cycle with no Frame/Plan/Reflect/Cleanup stages. Use for trivial fixes where the full 6-stage workflow is overkill.

If tracking mode is omitted, default to `project`.
If loop mode is omitted, default to `balanced`.
If `--template` is provided, load the YAML file and resolve all `{{param}}` references using `--param` values and template defaults. Fail if any `required: true` parameter is missing.
If `--headless` is provided, set `headless_mode: true` in state. Implies `--loop-mode strict`.
If `--no-deslop` is provided, set `deslop_enabled: false` in state. Otherwise default to `deslop_enabled: true`.
If `--full-deslop` is provided, set `full_deslop_enabled: true` in state. Incompatible with `--no-deslop` (error if combined).
If `--lightweight` is provided, set `lightweight_mode: true` in state. Implies `deslop_enabled: false` and `loop_mode: strict`. Incompatible with `--template` and `--headless` (error if combined).

# Part A — Always re-read before every response

## Stage Execution Discipline

0. **Re-read before every response.** Non-negotiable — skipping this is the leading cause of drift. Before generating any response during an active loop:
   - Re-read **Part A of this file** (everything above `# Part B`; preamble and Part B load once at start).
   - Re-read state JSON only on invalidation events; operate on the last-read snapshot between events.
   - If `template_id` is present: read template YAML once per iteration (Frame or first Reflect-side evaluation).
   - Resume from `next_step` in the state file.
   > **Reference:** See `~/.claude/skills/ralph-loop/active-loop.md` for invalidation events, template read cadence, and resume rules. If the file is missing, follow the bullets above.
1. **One stage per message.** Complete at most ONE stage per message. Every stage message MUST open with: (a) badge line, (b) progress checklist, (c) stage content. Completed stages: `✅`; remaining (including current): `🟦` (current stays unchecked — not yet done). After completing a stage, persist state, then continue to the next stage in a new message automatically — do NOT stop and wait for user input unless the stage requires it (e.g., Verify needs user to check results).
   - **Auto-advance exception (resume only).** When resuming a paused task where `next_step` is concrete and actionable AND the template (or state) has `auto_advance.frame_plan_combine: true`, Frame and Plan MAY be combined into a single message. Applies ONLY on resume, ONLY when `next_step` is unambiguous, and ONLY for Frame+Plan (never skip Execute, Verify, Cleanup, or Reflect). The combined message must still show the full checklist with both Frame and Plan addressed. After auto-advance, persist state with `current_stage: Execute`.
2. **Badge per turn.** First line of each turn MUST begin with **`Ralph Loop`**. Continuation lines do not repeat it.
3. **Stage output constraints.** Stage content must be **scannable** — never dense paragraph blocks. Use bullets, numbered lists, tables, indentation, and blank lines; bold key terms (file names, thresholds, metric values, work item IDs) so they pop out of surrounding text. When a stage mentions 3+ items of the same kind (sub-checks, files, criteria), use a list or table — never inline them in a run-on sentence.

   | Stage | Must include | Must avoid | Output shape |
   | :--- | :--- | :--- | :--- |
   | **Frame** | Bulleted breakdown: current state, what changed, what's next. Iter 1: work item scaffold table. Iter 2+: current work item + status (compact). Carried-forward learnings set apart as indented block or bullet list. | Learnings buried in a paragraph. | Lead with 1-2 sentence summary of what this iteration targets, then the breakdown. |
   | **Plan** | Explicit target file(s) and function(s). | More than ONE approach. | 1-5 sentences max; numbered steps if multi-step. |
   | **Execute** | Implementation-focused content. | — | Bulleted list of `file:change` pairs summarizing changes. |
   | **Verify** | Per-criterion pass/fail for the current work item. Table when 2+ metrics. | Reporting pass without per-criterion detail. | Bold the overall verdict. |
   | **Cleanup** | Scope (N files), linter used, fixes applied, regression result. | Broadening scope beyond `context.modified_files` (LB4). | Bullet list. |
   | **Reflect** | (1) assessment + `achieved_percent`, (2) work item status summary, (3) trend (1-2 lines), (4) new learnings as a bullet list, (5) next direction. | Flagging an auto-pause trigger without its assessment context. | 5-part structured output in the order shown. |

4. **No exploratory reasoning in messages.** Deliberation happens internally, not in output.
5. **Persist-before-proceed.** State JSON written BEFORE the next stage begins.
6. **Post-summarization strict mode.** After context recovery, first full iteration uses strict discipline (one stage per message, full checklist, state persisted) regardless of `loop_mode`.
7. **Headless stage execution.** In headless mode (`headless_mode: true` in state), do NOT prompt the user at any decision point. The loop does NOT wait for user input between stages or iterations — it proceeds automatically. Instead: (a) at Frame/Plan, use `context.summary` and `next_step` to auto-generate the framing and plan; (b) at Execute, proceed with the planned changes; (c) at Verify, run the template's verify command and auto-evaluate against acceptance criteria; (d) at Cleanup, auto-run the linter on changed files and regression re-verification without prompting (if `deslop_enabled` is true; skip silently if false); (e) at Reflect, auto-assess using iteration_history trends and auto-pause heuristics; (f) at target-reached, auto-select "mark done" if `headless.exit_on_target` is true; (g) at plateau, auto-pause if `headless.exit_on_plateau` is true. Headless mode respects `headless.max_iterations_per_run` as a hard stop. On exit, set status to `done` or `paused` as appropriate, and write a summary to the state file's `context.headless_report`. The next interactive resume picks up from the headless exit point.

## Headless Gate (MANDATORY)

Before EVERY user-facing prompt, structured choice, confirmation request, approval step, or question during an active loop:

1. Check `headless_mode` in your in-memory state snapshot (per `~/.claude/skills/ralph-loop/active-loop.md` state invalidation rules — do not re-read the state file unless an invalidation event has fired).
2. Check `headless_mode`.
3. If `true`: **DO NOT PROMPT.** Auto-decide per the template's headless config and proceed. Log the auto-decision in `context.notes`. This applies to ALL decision points with zero exceptions:
   - Work item scaffold approval (Frame) -- auto-approve immediately
   - Structured choice prompts (Reflect) -- auto-select per headless config
   - Target-reached options -- auto-select "mark done" if `exit_on_target: true`
   - Plateau/pause recommendations -- auto-pause if `exit_on_plateau: true`
   - Any other confirmation or question -- auto-decide the default/safe option
4. Only prompt if `headless_mode` is `false`.

**Violation of this gate is a hard error** -- equivalent to writing to a read-only file. If you catch yourself composing a question or choice list, STOP, check headless_mode, and delete the prompt if true.

## Checklist Format

The progress checklist MUST appear at the **beginning** of every stage message, immediately after the badge line. No text may precede it. Use emoji markers: `✅` for completed stages, `🟦` for remaining stages (including the current one). The current stage stays `🟦` because it is not yet done.

```text
**`Ralph Loop`** Iteration N -- Stage name

Ralph Wiggum Loop Progress (Iteration N)

✅ 1) Frame the task.
🟦 2) Plan the smallest useful step.
🟦 3) Execute
🟦 4) Verify
🟦 5) Cleanup (deslop)
🟦 6) Reflect and Adjust

(stage content here)
```

If `deslop_enabled` is `false` in state, replace step 5 with `⏭️ 5) Cleanup (skipped: --no-deslop)` and do not execute it.

## Workflow (condensed stage-list)

1. Initialize or resume task state. **State directory is `.ralph-state/`** (project mode) or `~/.ralph-state/` (global mode). Do NOT use `.claude/state/ralph-wiggum-loop/` for writes.
2. Run loop based on `loop_mode`: Frame → Plan → Execute → Verify → Cleanup → Reflect. Persist state after every completed stage. Increment `iteration` only when Reflect completes and the decision is to continue. See **Workflow** in Part B for the full per-stage sub-steps.
3. Check pause criteria (target reached, hard blocker, recurring failure escalation, or auto-pause heuristic) and persist JSON state with storage provenance after every stage. Keep `context` block current.
4. Continue loop or exit safely.

## Cleanup Stage (Deslop Pass)

- **When it runs:** Every iteration where `deslop_enabled` is `true`. Skip entirely if `false` — show `⏭️ 5) Cleanup (skipped: --no-deslop)`. Runs after Verify and before Reflect.
- **Scope boundary:** ONLY files in `context.modified_files`. Never broaden to unrelated files.
- **Regression re-verification:** After fixes, re-run verification checks. If regression detected, revert ALL cleanup changes and proceed to Reflect with pre-cleanup code. A cleanup regression does NOT block the loop.

## Constraints

- No compound Bash commands — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls instead — use parallel calls for independent commands.
- No `cd` prefix — the working directory is already the project root. Run commands directly (e.g., `.venv/3.11/Scripts/python.exe -m pytest ...`) instead of `cd "/path/to/project" && command`. If a command genuinely requires a different working directory, use a separate Bash call for `cd` first.
- Use relative paths from the project root — never use absolute paths in Bash commands. Use `.venv/3.11/Scripts/python.exe`, `data/output/`, etc. Only use absolute paths for resources genuinely outside the project (e.g., `~/.claude/`). Absolute paths break permission matching and trigger unwanted prompts.
- Temporary files go in the **project root** (e.g., `_tmp_test.py`, `_tmp_payload.json`) — never in `/tmp/`, `%TEMP%`, or any path outside the project. Paths outside the project trigger sensitive-file prompts. Use the `_tmp_` prefix. Do not delete individually — clean up in batch at checkpoints with `rm _tmp_*`.

## Output tagging

The **first line** of each assistant turn during an active loop MUST begin with the skill badge: **`Ralph Loop`**

Continuation lines within the same turn (sub-items, indented details, bullet lists, tables) do NOT repeat the badge. Only the opening line carries it.

Apply the badge on the opening line of turns that contain:

- status/progress updates
- warnings and blockers
- pause/complete confirmations
- final result summaries
- regression alerts
- recurring failure escalations
- auto-pause recommendations
- headless mode exit reports

Format: Use **`Ralph Loop`** (bold backtick-wrapped) as the first element on the opening line of each assistant turn.

# Part B — Loaded once at start

## Companion file reference

| File | Read when |
| :--- | :--- |
| `~/.claude/skills/ralph-loop/active-loop.md` | Active loop continuation, context recovery, or full Part A re-read detail (rule 0) |
| `template-system.md` | `--template` present, or resume with `template_id` |
| `execution-extras.md` | Reflect stage (git snapshot creation), OR `rollback` sub-command, OR template defines `acceptance_criteria`, OR template defines `hooks.verify.for_each` (fan-out Verify) |
| `cleanup-deslop.md` | Cleanup Stage runs (`deslop_enabled: true`), especially for escalation/regression detail |
| `lightweight-and-examples.md` | `--lightweight` present, or user asks for example invocations of `/ralph-loop` |
| `history-analytics.md` | Appending to the JSONL history log, or computing trend/regression summaries during Reflect |
| `state-schema.md` | Writing or validating the state JSON schema, or applying pruning caps |
| `work-item-scaffolding.md` | Template interaction, work-item discovery, or completion-signal sub-cases (Frame / Reflect) |

When a trigger in column 2 fires, Read the file in column 1. If any referenced file is missing, fall back to the inline summary in SKILL.md for that section.

## Template System

Templates define reusable loop recipes stored as YAML at `~/.claude/skills/ralph-loop/templates/`. They configure: verify commands, metric extraction, acceptance criteria, stage hooks, auto-pause rules, and auto-advance behavior.

**Task file layout:**

```text
<state_dir>/
  <task_id>.json              # state file
  <task_id>.template.yaml     # resolved template (frozen at creation)
  <task_id>.history.jsonl     # event log (append-only)
```

**Without a template:** The loop behaves exactly as before. All template features are opt-in.

## Acceptance Criteria

When the state file has a `template_id` pointing to a template with `acceptance_criteria`, Verify auto-evaluates results against structured thresholds and updates `achieved_percent` as a weighted average of per-category results.

## Rollback/Undo Support

During Reflect, create a git snapshot (WIP commit + lightweight tag `ralph/<task_id>/iter-<N>`). On `rollback --to-iter N --task <id>`, restore file contents from the tagged state. Rollback does NOT delete git history — it restores files only.

## Auto-pause Heuristics

Evaluated during Reflect, after `achieved_percent` is updated. Uses template `auto_pause` config if present; otherwise uses built-in defaults.

**Default heuristics (active even without a template):**

- **Plateau detection:** If `iteration_history` shows no improvement (delta < 0.5 pp) for the last 3 iterations, recommend pausing.
- **Max iterations:** Warn at iteration 15, hard-recommend pause at 20.
- **Recurring-failure escalation:** If the same failure signature (test name, error message, or file:line) recurs across 3+ consecutive iterations, trigger hard auto-pause with `status: blocked` and a clear report. Requires user input to resolve.

**Template-configurable heuristics:**

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `plateau_iterations` | 3 | Flat iterations before plateau trigger |
| `plateau_threshold` | 0.5 pp | Minimum delta to count as improvement |
| `diminishing_returns.enabled` | — | Track average gain over sliding window |
| `diminishing_returns.window` | 3 | Window size |
| `diminishing_returns.min_delta` | 1.0 pp | Minimum average gain per iteration |
| `max_iterations` | 20 | Hard cap |
| `regression_halt` | — | Pause if any category drops by `regression_threshold` |
| `regression_threshold` | 5.0 pp | Drop threshold for regression halt |
| `recurring_failure.enabled` | true | Track consecutive same-failure iterations |
| `recurring_failure.threshold` | 3 | Consecutive failures before escalation |
| `recurring_failure.action` | `block` | `block` or `pause` on trigger |

**Behavior:** Interactive mode: present finding and add "Pause to reassess" to the structured choice prompt. Headless mode: auto-pause and record trigger in `pause_reason`. All evaluations logged in `context.notes` and the JSONL history file.

## Subagent Parallelism in Verify

When the template's `hooks.verify.for_each` is defined, Verify fans out across multiple inputs using subagents.

**Memory-injection predicate at the fan-out site.** Before composing each subagent's brief, evaluate the predicate-and-selector pair documented in `skills/ops/SKILL.md` Phase 3 Step 3 (the canonical predicate table lives there — do NOT duplicate the table here). The short form: fan-out subagents in this site are typically `verifier` or similar agents that are NOT in `MECHANICAL_AGENTS`, so the default branch fires. Call the selector with `enable_agent_type_intersection=true`. If the selector returns non-empty bytes, render a `## Project Knowledge` block from those bytes and place it before the brief contents of each subagent spawn. If the selector returns empty bytes, omit the section and proceed. The override flag (`--memory-inject=off|auto|always`) is honored.

**Wrap-mode interaction.** When `/ops` wraps a Ralph Loop via the `ralph` subcommand (behavior documented in `skills/ops/SKILL.md` § Ralph Loop Integration), the inner Ralph Loop's fan-out sites evaluate the predicate independently using their own dispatch context. There is no double-injection: each evaluator sees its own `agent_type`, `attempt`, and `prior_handoff` values, and the sentinel-marker check in the predicate prevents re-injection if the prior handoff already carried the section.

> If `execution-extras.md` is missing, run the single verify command without fan-out.

## Cleanup Stage — Additional Detail

- **Deslop escalation:** Deslop escalation trigger evaluation: see `cleanup-deslop.md`.
- **On success:** Log results in `context.notes`, append modified files to `context.modified_files`.

## Lightweight Mode

Lightweight mode (`--lightweight`) is a single-pass Execute + Verify cycle for trivial fixes. No Frame, Plan, Reflect, or Cleanup. Implies `deslop_enabled: false` and `loop_mode: strict`. Incompatible with `--template` and `--headless`. Max 2 retries; can upgrade to full loop on failure.

## Work Item Scaffolding

Work items are discrete, ordered deliverables that Frame generates on iteration 1. They live in `progress.work_items` in the state JSON. **When scaffolding happens:** Iteration 1 Frame stage only. Not in lightweight mode (Frame is skipped). Not on resume (work items are already in state).

**Scaffolding rules:**

1. Break the task into the smallest set of independent or sequentially-dependent deliverables that together fulfill the task.
2. **Granularity:** Each item should be completable in 1-2 iterations. If it touches more than 3-5 files or requires more than one conceptual change, split it.
3. **Ordering:** Foundational work first (data models, config, shared utilities), dependent work later (API endpoints, UI, integration). Items that unblock others go earlier.
4. **ID format:** Sequential `WI-001`, `WI-002`, etc. New items discovered during execution continue the sequence.

**Acceptance criteria quality:** Every criterion must be **specific and testable**. The scaffolding step MUST replace any generic criteria with task-specific ones before proceeding.

| Bad (generic) | Good (specific) |
| :--- | :--- |
| "Implementation is complete" | "POST /events returns 201 for valid payload" |
| "Tests pass" | "tests/test_date_parser.py exists and `pytest tests/test_date_parser.py` passes" |

**One-time approval flow:**
- **Interactive mode:** Frame presents the scaffold as a table. User may refine, reorder, add, or remove items. Once confirmed, the loop does not re-ask on subsequent iterations.
- **Headless mode:** Auto-scaffold and proceed immediately. No approval step.

See `work-item-scaffolding.md` for template interaction, discovery, and completion-signal sub-cases.

> *If the companion is missing: template category-metrics and work-item completion are independent signals; discovery adds items via Reflect; use the completion-signal cases table in the companion (or prompt the user) to route target-reached behavior.*

## Continuation and Persistence Across Turns

- **Active task detection:** If previous message had **`Ralph Loop`** badge, user references a task, or state file has `status: active|blocked`, treat message as loop continuation.
- **Re-read on continuation:** Follow Stage Execution Discipline rule 0 before every response. Non-negotiable.
- **User feedback is loop input:** Any user message during `active` or `blocked` status is input to the current iteration.
- **Never silently exit:** Valid exits: user selects "Mark as done"/"Pause", user explicitly says stop, or hard blocker with `status: blocked`. **Exit requires explicit user confirmation** — completing a sub-step or finishing verification does NOT exit the loop; continue to next iteration. When in doubt, use the structured choice prompt.
- **State file is authoritative:** The JSON state file is the single source of truth. Persist after every stage.
- **Context recovery:** Follow Stage Execution Discipline rule 0; recover position from state (`task_id`, `iteration`, `current_stage`, `next_step`, `achieved_percent`), restate to user with badge, continue. Never guess loop state from summarized context.
- **Headless mode exception:** See Headless Gate and Stage Execution Discipline rule 7 for all headless behavior.

## Progress Estimation

`achieved_percent` = overall task progress toward `target_goal` or `target_percent` (0-100). NOT per-iteration or per-stage progress. Base on observable outcomes, not effort. Mandatory reassessment during Reflect (state estimate to user, accept corrections). Optional update during Verify if a measurement is available. Do NOT update during Frame, Plan, or Execute. Must always reflect latest Reflect-stage assessment.

When a template with `acceptance_criteria` is active, `achieved_percent` is computed as the weighted average of per-category measured values relative to their thresholds (all-pass percentage). If all categories meet their thresholds, `achieved_percent` = 100 (or the actual overall metric if higher). Per-category results are stored in `progress.category_results` and displayed in Verify and Reflect outputs.

## Workflow (full detail)

1. Initialize or resume task state. **State directory is `.ralph-state/`** (at the workspace root for project mode, or `~/.ralph-state/` for global mode). Do NOT use `.claude/state/ralph-wiggum-loop/` or `.cursor/state/ralph-wiggum-loop/` for writes — see the **Read-order fallback** below.
   - If `list` is requested, enumerate task JSON files in selected scope and return summary rows sorted by `updated_at` descending.
   - If `--template <id>` is provided, load the template and execute the following resolution steps in order:
     1. Resolve all `{{param}}` placeholders using `--param` values and template defaults. Fail if any `required: true` parameter is missing.
     2. Fill in all schema defaults per the Default-fill semantics table in `template-system.md`. Every field covered by that table must be present with an explicit value (either the author-provided override or the default) before the next step.
     3. Write the fully-expanded resolved copy to `<task_id>.template.yaml` in the state directory. The frozen copy must be self-contained — no implicit defaults to look up at read time.
     4. Store `template_id` in state.
   - If resuming: locate `<task_id>.json` via the **Read-order fallback** (see below). If state has `template_id`, read the resolved `<task_id>.template.yaml` from the same directory as the state file (no re-resolution needed).
   - If `--headless`, validate that a template is provided (headless requires structured verify commands). Set `headless_mode: true` in state.
2. Run loop based on `loop_mode`. Persist state after every completed stage. One iteration = one complete pass through all 6 stages (or 5 if `deslop_enabled` is false). Increment `iteration` only when Reflect completes and the decision is to continue. Stage transitions and turns within a stage do NOT increment the counter. Include iteration number in status updates.
   - Before/after each stage, check `hooks.<stage>.pre` / `.post`; if defined, execute it.
   - Frame:
     - **Iteration 1:** Scaffold work items from the task description with specific, testable criteria. Write to `progress.work_items`. Present as a table for one-time user approval (auto-approve in headless mode). Target `WI-001` in Plan; set `status: in_progress`, `iteration_started: 1`.
     - **Iteration 2+:** Select highest-priority `status: pending` item, set `in_progress`, surface relevant `context.learnings`. If no pending items remain but percent < target, check whether items need splitting or adding.
     - **Lightweight mode:** Frame skipped entirely.
     - See **Work Item Scaffolding** for scaffolding rules, criteria quality, and granularity guidelines.
   - Plan — 1-5 sentences, one approach, numbered steps if multiple, explicit file/function targets.
   - On resume with `auto_advance.frame_plan_combine: true` and actionable `next_step`: combine Frame+Plan into one turn, advance to Execute.
   - Execute — implement planned changes.
   - Verify — if template defines `hooks.verify.command`, run it. If `for_each` defined, use Subagent Parallelism. Extract metrics via `metric_extraction`. Auto-evaluate against `acceptance_criteria`. Update `achieved_percent` if a concrete measurement is available. **Work item verification:** If a work item is `in_progress`, verify each criterion with fresh evidence (run the test, check output, confirm file exists). Report per-criterion pass/fail alongside template-level category results.
   - Cleanup (deslop pass) — skipped if `deslop_enabled` is `false` (show `⏭️ 5) Cleanup (skipped: --no-deslop)`). When enabled, run per the Cleanup Stage section.
   - Reflect — reassess `achieved_percent`; accept corrections. Run auto-pause heuristics. Compute trend from iteration_history. Create git snapshot (tag `ralph/<task_id>/iter-<N>`). Write JSONL log. **Capture and prune learnings:**
     1. Extract actionable insights from this iteration (codebase patterns, gotchas, tool quirks, non-obvious constraints).
     2. Add to `context.learnings` as short, concrete, one-sentence strings. Keep to ≤15 entries; drop oldest/least actionable if over.
     3. Prune stale entries (fixed bugs, resolved constraints). Include new learnings in the `iteration_complete` JSONL event's `learnings` field.
     **Update work items:**
     4. If a work item is `in_progress`: if Verify confirmed all criteria, set `status: done` and record `iteration_completed`; otherwise keep `in_progress`. Add any newly discovered sub-tasks as new work items at the appropriate priority position.
     5. If a work item proved too large, split it for subsequent iterations.
     6. Include a work item status summary in Reflect output (e.g., "WI-001 done, WI-002 in progress (2/3 criteria met), WI-003–WI-005 pending").
     7. **Completion signal:** All items `done` feeds into the target-reached check alongside `achieved_percent`. Either condition alone is sufficient to present the structured options prompt.
     **Track recurring failures:**
     8. Compare this iteration's failures against `auto_pause_state.recurring_failures`. Matching signature from previous iteration: increment `consecutive_count`, update `last_seen_iter`. New failure: add entry with `consecutive_count: 1`. Remove entries not seen in current or previous iteration.
     9. If any entry reaches `consecutive_count >= threshold` (default 3): set `status: blocked` (or `paused`), add to `blockers`, log `recurring_failure_escalated` event, report: "RECURRING FAILURE: [signature] has failed for [N] consecutive iterations. This likely requires user input to resolve."
   - For comparison/data-analysis iterations with >= 2 independent commands or pipelines, spawn one subagent per command/pipeline and run concurrently, then aggregate outputs. Before composing each subagent brief, evaluate the predicate-and-selector pair documented in `skills/ops/SKILL.md` Phase 3 Step 3 (canonical table lives there). Data-analysis agents are NOT in `MECHANICAL_AGENTS` at v1, so the default branch fires: call the selector with `enable_agent_type_intersection=true` and render a `## Project Knowledge` block before the brief contents when bytes are returned. The override flag (`--memory-inject=off|auto|always`) is honored. When `/ops` wraps a Ralph Loop via the `ralph` subcommand (see `skills/ops/SKILL.md` § Ralph Loop Integration), the inner loop's fan-out sites here evaluate the predicate independently — no double-injection.
3. Check pause criteria:
   - target percent reached, hard blocker detected, recurring failure escalated, or auto-pause heuristic triggered (plateau, diminishing returns, regression, max iterations)
   - if target goal reached/exceeded, present structured options: 1) mark `done` and exit, 2) continue with updated goal, 3) continue with same goal + additional details/constraints, 4) pause for now
   - collect follow-up details for options 2 and 3
   - all user-facing questions must use proper sentence case, complete sentence structure, and correct grammar
   - In headless mode, auto-pause triggers are automatic exits (no user prompt); target-reached auto-selects "mark done" if `headless.exit_on_target` is true.
4. Persist JSON state with storage provenance (state is also written after every completed stage, not just here). Keep the `context` block current on every persist: `summary` (rewrite 2-5 sentences on each persist), `modified_files` (cumulative list of changed paths), `comparisons` (structured comparison data if any), `notes` (key decisions, limitations, error patterns if any), `learnings` (updated during Reflect only -- add new, prune stale, cap at 15). Keep `progress.work_items` current: update item statuses during Reflect, add discovered items as needed. Append to the JSONL history log file alongside the state JSON. Storage paths (write):
   - `project` (default): `<workspace>/.ralph-state/<task_id>.json`
   - `global`: Windows `%USERPROFILE%/.ralph-state/<task_id>.json`, macOS/Linux `~/.ralph-state/<task_id>.json`
   - `folder`: `<user_path>/ralph-state/<task_id>.json`
   - **JSONL history log:** Same directory as the state file, named `<task_id>.history.jsonl`.
   - **P5 pruning (before every state write):** Prune `context.modified_files` (cap 50), `progress.per_item_results` (cap 5 iter keys), and `iteration_snapshots` (cap 20) per the Pruning policy in `state-schema.md`. JSONL retains the full history; the state JSON is a working window only.
   - **Read-order fallback:** When reading state (resume / status / list), check `.ralph-state/` first, then `.claude/state/ralph-wiggum-loop/`, then `.cursor/state/ralph-wiggum-loop/`. If found in a fallback, load it but write updates to `.ralph-state/` (effectively migrating on first write). For `list`, merge all locations, deduplicating by `task_id` (primary wins). Applies to global and project modes only; folder mode has no legacy fallback.
5. Continue loop or exit safely.

## History and Analytics

Iteration history is tracked in the state file (`progress.iteration_history`) and a JSONL log file (`<task_id>.history.jsonl`).

**Trend detection (during Reflect):**

1. Read the last N entries from iteration_history (N = `auto_pause.diminishing_returns.window` or 5).
2. Compute: moving average of delta, best iteration, worst iteration, per-category trend direction (improving/flat/regressing).
3. **Regression alert:** If any category's metric dropped compared to the previous iteration, flag it prominently in the Reflect output: "REGRESSION: [category] dropped from X% to Y% (-Z pp)."
4. Include a compact trend summary in the Reflect output (1-2 lines).

**Analytics are advisory.** They inform the Reflect assessment and auto-pause heuristics but do not override user decisions in interactive mode.

## Required state fields

Top-level fields: `task_id`, `title`, `status` (active|paused|blocked|done), `loop_mode`, `template_id`, `headless_mode`, `lightweight_mode`, `deslop_enabled`, `full_deslop_enabled`, `target` {percent, goal}, `iteration`, `progress` {achieved_percent, current_stage, completed_items, remaining_items, category_results, per_item_results, work_items}, `iteration_snapshots`, `auto_pause_state`, `blockers`, `next_step`, `resume_hint`, `context` {summary, modified_files, comparisons, notes, learnings, headless_report}, `storage` {mode, root, resolved_path}, `updated_at`.
