<!-- SKILL.cursor.additions.md — Human-readable documentation mirror of the Cursor transform.
     READ-ONLY DOCUMENTATION. This file is NOT consumed by any tool. The executable
     transform (tooling/transform-cursor-ops.{ps1,sh}) hard-codes its entire patch list
     in an embedded Python body (a series of rep(old, new) calls, PATCH 0 .. PATCH 55,
     plus a final global "~/.claude/" -> "~/.cursor/" substitution). The .ps1 and .sh
     Python bodies are byte-identical by construction.

     PURPOSE: give a reviewer a block-by-block, anchor-by-anchor view of what the
     transform does to skills/ops/SKILL.md when it generates skills/ops/SKILL.cursor.md,
     without having to read the embedded Python. Each @@PATCH block below documents one
     transform operation and mirrors a numbered PATCH in the script.

     SOURCE OF TRUTH: tooling/transform-cursor-ops.ps1 / .sh. If this file and the script
     disagree, the script wins — update this file to match, never the reverse. Editing a
     block here changes nothing about the generated hub; only editing the script does.

     NOT DEPLOYED: tooling/deploy-manifest.json excludes **/SKILL.cursor.additions.md from
     every target. It lives in the repo for review/audit only.

     Block format (documentation convention — sentinels are NOT executed):
       @@PATCH
       ACTION: <replace | replace_line | prepend>   (see note)
       ANCHOR: <the script's rep() `old` first line, or "(file-start)" for the prepend>
       @@STOP   <optional: last line of a multi-line `old`, for replace blocks>
       @@CONTENT
       <the script's rep() `new` value>
       @@END

     NOTE ON ACTIONS: the transform itself only has one primitive — rep(old, new), a
     first-occurrence string replace (tooling/transform-cursor-ops.ps1:179-187) — plus the
     trailing global substitution. The ACTION labels above are descriptive shorthand for how
     a given rep() behaves (a single-line old reads as "replace_line"; a multi-line old reads
     as "replace"; PATCH 0's prepend is rep(first_line, frontmatter+first_line)). There is no
     delete_line, insert_before, insert_after, or ANCHOR_CONTEXT primitive in the script; do
     not document patches using those.

     COMPANION-SUPPRESSED PATCHES: ~16 patches (PATCH 6-20, 22-34, 45-46) target anchors
     that moved to skills/ops/phase-*.md companion files during the B1 extraction. Their
     anchors are absent from the current hub, so they silently no-op (suppressed via
     _companion_patch(), tooling/transform-cursor-ops.ps1:139-177). They are retained in the
     script — and documented here — so they reactivate if the hub re-absorbs that content.
-->

@@PATCH
ACTION: prepend
ANCHOR: (file-start)
@@CONTENT
---
name: ops
description: Coordinate a team of agents working on a shared task list.
---
@@END

@@PATCH
ACTION: replace_line
ANCHOR: - `--worktree` — spawn parallel agents in isolated git worktrees to eliminate file conflicts.
@@CONTENT
- `--worktree` — spawn parallel agents in isolated git worktrees using `best-of-n-runner` subagents to eliminate file conflicts.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: > **Reference:** You MUST Read `~/.claude/skills/ops/help-card.md` for the full help card text. If the file is missing, display a brief usage summary instead.
@@CONTENT
> **Reference:** You MUST Read `~/.cursor/skills/ops/help-card.md` for the full help card text. If the file is missing, display the quick-reference below instead.

**Inline help fallback:**

```text
Commands: /ops <spec> | plan | execute | status | resume | save | ralph "<goal>" | help
Flags: --autonomous | --supervised | --parallel N | --agents <list> | --dry-run | --worktree | --no-branch | --no-deslop | --cost | --budget=<N> | --brainstorm | --dispatch-log | --security-review=off|always | --no-adaptation-memory
Mid-run: stop | pause | status | skip <stage/#N> | drop #N | do #N next | add <task> | reprioritize
Pipeline: executor → verifier → deslop → code-reviewer → documentor
Retry: 3 attempts with narrowed scope and debugger diagnosis, then escalate to user
```
@@END

@@PATCH
ACTION: replace
ANCHOR: The ops skill persists all task data in a JSON state file on disk. This is the source of truth for dependencies, timing, estimates, agent assignments, and adaptation notes.
@@STOP
The state file on disk is mandatory — see Non-negotiables #1.
@@CONTENT
The ops skill uses a **dual-layer task board**: a JSON state file on disk for full metadata, and TodoWrite for IDE-visible status display. Both are updated on every state change.

The state file on disk is mandatory — TodoWrite alone is not sufficient (it cannot store dependencies, timing, or agent metadata). See Non-negotiables #1.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: The state file is stored at `.ops-state/<run-id>-board.json`.
@@CONTENT
The state file is stored at `.ops-state/<run-id>-board.json`. This is the source of truth for all task data — dependencies, timing, estimates, agent assignments, and adaptation notes.
@@END

@@PATCH
ACTION: replace
ANCHOR: All task board operations use the state file as the primary store. **Every mutation must write the state file to disk** — do not rely on in-memory state alone.
@@STOP
| **Report** | Read file from disk, compute timing/estimates/variance |
@@CONTENT
All task board operations use the state file as the primary store and TodoWrite as the display layer. **Every mutation must write the state file to disk using the `Write` tool** — do not rely on in-memory state alone.

| Operation | State file action (via `Write` tool) | TodoWrite action |
| :--- | :--- | :--- |
| **Create task** | Append to `tasks` array, `Write` file to disk | `TodoWrite(merge=false)` with full task list |
| **Update status** | Update task's `status`, `started_at`, etc., `Write` file to disk | `TodoWrite(merge=true)` with `[{id, content, status}]` |
| **Scan for ready** | `Read` file from disk, filter tasks where `status=="pending"` and all `blocked_by` entries are `"completed"` | — (read-only) |
| **Complete task** | Update `status`, `completed_at`, `duration_seconds`, `Write` file to disk | `TodoWrite(merge=true)` with `[{id, status: "completed"}]` |
| **Resume** | `Read` file from disk — full state recovered | `TodoWrite(merge=false)` to recreate display from state file |
| **Report** | `Read` file from disk, compute timing/estimates/variance | — (read-only) |

### TodoWrite Display Format

TodoWrite items encode key metadata in the content string for at-a-glance visibility:

```text
id: "task-1"
content: "[executor][implement] Implement auth middleware"
status: "pending"
```

The format is `[agent_type][stage] subject`. The ops skill updates both the state file and TodoWrite on every status change.

> **Cursor dispatch ritual:** Before Phase 3, read `~/.cursor/skills/ops/phase-dispatch.md` § **Cursor: state file sync (mandatory)**. Never call `TodoWrite` until the board file `Write` + `Read` verify succeed in the same turn.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | Spec or requirement text | If `--brainstorm` is set (or the user explicitly asks to brainstorm/design first), run the **Brainstorm Gate** below: `interviewer → architect → user approval checkpoint → planner`. Otherwise evaluate spec clarity (see below). If clear, dispatch a **planner** agent. If ambiguous, dispatch an **interviewer** agent first, then a **planner** with the crystallized requirements. Wait for the plan, then proceed to Phase 1a (Plan Validation). |
@@CONTENT
| Spec or requirement text | If `--brainstorm` is set (or the user explicitly asks to brainstorm/design first), run the **Brainstorm Gate** below: `interviewer → architect → user approval checkpoint → planner`. Otherwise evaluate spec clarity (see below). If clear, dispatch **planner** via `Task(subagent_type="planner")`. If ambiguous, dispatch **interviewer** first via `Task(subagent_type="interviewer")`, then **planner** with the crystallized requirements. Wait for the plan, then proceed to Phase 1a (Plan Validation). |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | `resume` | Read the state file. **Check `pending_nested_skill` before dedup** — if non-null, escalate to the user per `interruption-recovery.md` §Session Recovery step 2; do not auto-re-invoke. Treat all `in_progress` tasks as orphaned. Dispatch a **work-verifier** agent (see `~/.claude/agents/work-verifier.md`) per in-progress task to determine actual completion status. Then run Phase 2.5 preflight if environment may have changed, then skip to Phase 3. See Interruption Handling → Session Recovery. |
@@CONTENT
| `resume` | Read the state file from `.ops-state/`. **Check `pending_nested_skill` before dedup** — if non-null, escalate to the user per `interruption-recovery.md` §Session Recovery step 2; do not auto-re-invoke. All `in_progress` tasks are treated as orphaned — the previous session's agents are gone. Dispatch a **work-verifier** agent (see `~/.cursor/agents/work-verifier.md`) per in-progress task to determine actual completion status. Run Phase 2.5 preflight if environment may have changed, then skip to Phase 3 (Dispatch Loop). Recreate TodoWrite display from state file via `TodoWrite(merge=false)`. For full recovery procedure, see Interruption Handling → Session Recovery. |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | `status` | Read the state file. For any `in_progress` tasks, dispatch a **work-verifier** agent with orphan detection enabled. Display the dashboard (see Status Dashboard), stop. |
@@CONTENT
| `status` | Read the state file. For any `in_progress` tasks, dispatch a **work-verifier** agent (see `~/.cursor/agents/work-verifier.md`) via `Task(subagent_type="generalPurpose")` with orphan detection enabled. Display the dashboard (see Status Dashboard), stop. |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: 1. **Create state file (LB1 — mandatory):** Generate a `run-id` (`<slug>-<ISO-date>`). Run `Bash(command="mkdir -p .ops-state")`. Use the Write tool to create `.ops-state/<run-id>-board.json` with one task entry. Use `description_inline` for the task entry (trivial-path runs have no persisted plan doc, so there is no `description_ref` pointer to set). Verify the file exists by reading it back.
@@CONTENT
1. **Create state file (LB1 — mandatory):** Generate a `run-id` (`<slug>-<ISO-date>`). Run `Shell(command="mkdir -p .ops-state")`. Use the `Write` tool to create `.ops-state/<run-id>-board.json` with one task entry. Use `description_inline` for the task entry (trivial-path runs have no persisted plan doc, so there is no `description_ref` pointer to set). Verify the file exists by reading it back with `Read`. Also call `TodoWrite(merge=false)` with the single task item.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: 4. **Dispatch:** Spawn the agent via the Agent tool using the same Agent Dispatch Procedure (Phase 3 Step 3) — read frontmatter for `model`, set description/model/prompt (agent reads its own body as first action).
@@CONTENT
4. **Dispatch:** Spawn the agent via `Task(subagent_type="<agent_type>", prompt=<self-read prompt + brief>)`. For agents not in the Cursor built-in enum, use `Task(subagent_type="generalPurpose", prompt=<self-read prompt + brief>)`. The prompt instructs the agent to read its own definition as its first action (see Agent Dispatch Procedure for the self-read prompt template).
@@END

@@PATCH
ACTION: replace_line
ANCHOR: 5. **On result:** Mark task `completed` in the state file (record `completed_at`, `duration_seconds`). Run cleanup: `rm _tmp_*`, delete `.ops-state/<run-id>-board.json`. Output one concise summary line: what was done, file(s) changed if any, actual duration.
@@CONTENT
5. **On result:** Mark task `completed` in the state file (record `completed_at`, `duration_seconds`). Update TodoWrite. Run cleanup: `rm _tmp_*`, delete `.ops-state/<run-id>-board.json`. Output one concise summary line: what was done, file(s) changed if any, actual duration.
@@END

@@PATCH
ACTION: replace
ANCHOR: **Spec clarity evaluation (default path, skip when Brainstorm Gate is active):** If clear, dispatch planner directly. If vague/ambiguous, dispatch **interviewer** first. If user says "just plan it", dispatch planner regardless.
@@STOP
In **interactive mode**, prefer asking the user directly for simple ambiguities; use the interviewer for deep ambiguity (multiple unclear dimensions, conflicting requirements). In **autonomous mode**, dispatch the interviewer — the team manager cannot ask interactively.
@@CONTENT
**Spec clarity evaluation (default path, skip when Brainstorm Gate is active):** Before dispatching the planner, assess whether the user's input is clear enough to plan from. If clear, dispatch planner directly. If vague or ambiguous, dispatch **interviewer** first. If the user says "just plan it", dispatch planner regardless.

In **interactive mode**, prefer asking the user directly for simple ambiguities; use the interviewer for deep ambiguity (multiple unclear dimensions, conflicting requirements). In **autonomous mode**, dispatch the interviewer — the team manager cannot ask interactively.

**Architect dispatch (optional, default path only):** Dispatch an **architect** agent via `Task(subagent_type="architect")` before the planner when the spec involves new subsystems, significant technology choices, competing implementation strategies, or API/data model design. The architect produces an ADD the planner uses as input. Skip for well-understood work.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: The plan doc + state file + handoff files (see Handoff Documents) provide complete state recovery across session boundaries.
@@CONTENT
The plan doc + state file + handoff files provide complete state recovery across session boundaries.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: **ClickUp context enrichment:** If a ClickUp task ID is referenced, pull task details before planning. Invoke `/clickup Get task <id>` if the skill is available, or fall back to `curl https://api.clickup.com/api/v2/task/<id>` with the token from `~/.claude/config/clickup/config.json`. Extract title, description, status, checklist items, and comments as spec context. Intake-only — does not write back to ClickUp.
@@CONTENT
**ClickUp context enrichment:** If a ClickUp task ID is referenced, pull task details before planning. Read `~/.cursor/skills/clickup/SKILL.md` and dispatch via `Task(subagent_type="generalPurpose")` if available; otherwise fall back to `curl https://api.clickup.com/api/v2/task/<id>` with token from `~/.cursor/config/clickup/config.json`. Extract title, description, status, checklist items, and comments as spec context. Intake-only — does not write back to ClickUp.
@@END

@@PATCH
ACTION: replace
ANCHOR: **Also skip when:** `resume`, `status`, or user says "just do it" / "skip validation".
@@STOP
> **Reference:** You MUST Read `~/.claude/skills/ops/plan-validation.md` for spec clarity evaluation criteria, plan complexity scoring signals, critic verdict handling, scoper/critic output descriptions, execute-skip detection, mode-specific behavior, and adaptation rules. If the file is missing, proceed using the tier table and display format above.
@@CONTENT
**Also skip when:** `resume`, `status`, or user says "just do it" / "skip validation".

> **Reference:** You MUST Read `~/.cursor/skills/ops/plan-validation.md` for spec clarity evaluation criteria, plan complexity scoring signals, critic verdict handling, scoper/critic output descriptions, execute-skip detection, mode-specific behavior, and adaptation rules. If the file is missing, proceed using the tier table and display format above.

**Determine validation tier:**

Task counts below use the 2-5 minute granularity standard (per `agents/planner.md` — Task Granularity Standard).

| Tier | Criteria | Action | Cost |
| :--- | :--- | :--- | :--- |
| **Tier 1 — Skip** | 1-3 tasks of finer granularity, no architectural decisions, mechanical/trivial changes | Proceed directly to Phase 1.5. | None |
| **Tier 2 — Scope only** | 4-8 tasks, OR clear scope but needs estimates/gap analysis, OR medium signals | Dispatch **project-scoper** via `Task(subagent_type="project-scoper")`. Proceed to Phase 1.5 after scoping. | 1 agent |
| **Tier 3 — Scope + Critique** | >8 tasks, OR high-weight signal (architectural, security/risk), OR multiple medium signals | Dispatch **project-scoper** then **critic** via `Task(subagent_type="critic")`. | 2 agents |

**Display the tier decision:** Always show the tier decision to the user, regardless of autonomy mode:

Render this tier-decision block as plain Markdown, not inside a fence. Output the lines directly into chat so the UI renders them as formatted text.

**Plan Validation: Tier [N] — [Skip / Scope only / Scope + Critique]**
**Signals:** [list which signals triggered, e.g., "6 impl tasks (high), new agent architecture (high), security model (medium)"]
**Action:** [what will happen — "Proceeding to task board" / "Dispatching project-scoper" / "Dispatching project-scoper → critic"]

In **interactive mode**, show the tier decision and wait for the user to confirm, override, or skip. The user can say:
- "proceed" — accept the tier decision
- "skip validation" — override to Tier 1 regardless of score
- "scope it" — override to Tier 2
- "scope and critique" — override to Tier 3

In **autonomous mode**, display the tier decision and proceed automatically. The decision is always visible so the user knows what validation level was applied — the team manager never silently skips validation without reporting it.

In **supervised mode**, show the tier decision and wait for approval before each agent dispatch (same as other tasks in supervised mode).
@@END

@@PATCH
ACTION: replace_line
ANCHOR: Parse the plan into discrete, assignable tasks. Create the state file.
@@CONTENT
Parse the plan into discrete, assignable tasks. Create the state file and TodoWrite display.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: 1. Run `Bash(command="mkdir -p .ops-state")`.
@@CONTENT
1. Run `Shell(command="mkdir -p .ops-state")` (or `mkdir .ops-state` on Windows if it doesn't exist — check first with `ls .ops-state` or `dir .ops-state`).
@@END

@@PATCH
ACTION: replace_line
ANCHOR: 2. Use the Write tool to create `.ops-state/<run-id>-board.json` with the initial structure: `{"run_id": "<run-id>", "state_dir": ".ops-state/", "plan_file": "<path or null>", "tasks": []}`.
@@CONTENT
2. Use the `Write` tool to create `.ops-state/<run-id>-board.json` with the initial structure: `{"run_id": "<run-id>", "state_dir": ".ops-state/", "plan_file": "<path or null>", "tasks": []}`.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: 3. Verify the file exists by reading it back. If the read fails, the state file was not created — stop and fix before proceeding.
@@CONTENT
3. Verify the file exists by reading it back with `Read(path=".ops-state/<run-id>-board.json")`. If the read fails, the state file was not created — stop and fix before proceeding.
@@END

@@PATCH
ACTION: replace
ANCHOR: **4. Write state file to disk:**
@@STOP
**Agent Assignment Rules**
@@CONTENT
**4. Write state file and create TodoWrite display:**

Use the `Write` tool to overwrite `.ops-state/<run-id>-board.json` with the complete JSON (all tasks populated from steps 2-3). Then call `TodoWrite(merge=false)` with all tasks. **Both writes are mandatory** — the state file is the source of truth, TodoWrite is the display layer.

```text
TodoWrite items (one per task):
  id: "task-0"
  content: "[executor][implement] Implement auth middleware"
  status: "pending"

  id: "task-1"
  content: "[verifier][verify] Verify auth middleware"
  status: "pending"

  ...
```

**Agent Assignment Rules**
@@END

@@PATCH
ACTION: replace_line
ANCHOR: **Display the task board after creation.** After the state file is written and verified, render a Status Dashboard
@@CONTENT
**5. Verify state file on disk (MANDATORY):**

Before displaying the task board, confirm the state file exists and is valid:

1. `Read(path=".ops-state/<run-id>-board.json")` — verify the file contains valid JSON with a non-empty `tasks` array.
2. If the file is missing or empty, **stop and re-create it** from the in-memory task data. Do not proceed to dispatch without a valid state file on disk.
3. Check whether `.ops-state/` is in `.gitignore`. If not, add it (append `.ops-state/` to `.gitignore`).

**Display the task board after creation.** After the state file is verified and TodoWrite is populated, render a Status Dashboard
@@END

@@PATCH
ACTION: replace_line
ANCHOR: Dispatch a **preflight** agent (see `~/.claude/agents/preflight.md`).
@@CONTENT
Dispatch a **preflight** agent (see `~/.cursor/agents/preflight.md`) via `Task(subagent_type="generalPurpose")`.
@@END

<!-- PATCH 21 issues no rep(): it is a comment-only "REMOVED" marker in the script (transform-cursor-ops.ps1:490-492). Phase 3 dispatch + Cursor state sync live in phase-dispatch.md (B1 companions). Do not re-insert TodoWrite-only hub steps here. -->

@@PATCH
ACTION: replace_line
ANCHOR: **When genuinely in doubt**, dispatch an **interviewer** to clarify — a quick clarification is cheaper than re-doing the work.
@@CONTENT
**When genuinely in doubt**, dispatch the **interviewer** via `Task(subagent_type="interviewer")` to clarify — a quick clarification is cheaper than re-doing the work.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: **Your first action:** Read your full agent definition from `~/.claude/agents/<agent_type>.md`.
@@CONTENT
**Your first action:** Read your full agent definition from `~/.cursor/agents/<agent_type>.md`.
@@END

@@PATCH
ACTION: replace
ANCHOR: **Dispatch example:**
@@STOP
> **Reference:** You MUST Read `~/.claude/skills/ops/dispatch-policy.md` for the full foreground/background decision criteria, batch rules, and interaction with health monitoring and worktree isolation. If the file is missing, proceed using the summary above.
@@CONTENT
5. Spawn the agent via `Task(subagent_type="<agent_type>", prompt=<self-read prompt + brief>)` using the brief format below. For agents not in the Cursor built-in enum, use `Task(subagent_type="generalPurpose", prompt=<self-read prompt + brief>)`.
6. For parallel batches, issue all Task calls in a **single message** so they run concurrently.

**Dispatch Log Append (opt-in via `--dispatch-log`)** — when the `--dispatch-log` flag is set, append a one-line entry to `docs/ops-dispatch-log.md` after each dispatch (or direct-tool choice governed by the Subagent Dispatch Decision Framework), capturing kind, framework row, and short description. This applies universally when enabled: Phase 3 dispatch loop, Trivial Dispatch, Brainstorm Gate, Phase 1a scoper/critic, Phase 2.5 preflight, and every other agent dispatch. When the flag is not set, skip entirely — do not touch the log file. The log is persistent across runs and serves as the audit trail for framework adherence.

> **Reference:** You MUST Read `~/.cursor/skills/ops/dispatch-log.md` for the file location, append procedure, entry format, kinds table, and audit usage. If the file is missing, proceed using the summary above. Read only when `--dispatch-log` is set.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | **Passed** — acceptance criteria met | Update state file: `status` → `"completed"`. Write a handoff document (see Handoff Documents). Check for newly unblocked tasks. |
@@CONTENT
| **Passed** — acceptance criteria met | Update state file: `status` → `"completed"`. Update TodoWrite. Write a handoff document (see Handoff Documents). Check for newly unblocked tasks. |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | **Failed — 2nd attempt** | Dispatch a **debugger** agent (or **debugger-build** if the failure is a build/import/type error) to diagnose the root cause. Use its findings to re-brief the original agent with a corrected approach. |
@@CONTENT
| **Failed — 2nd attempt** | Dispatch the **debugger** via `Task(subagent_type="debugger")` (or `Task(subagent_type="debugger-build")` if the failure is a build/import/type error) to diagnose the root cause. Use its findings to re-brief the original agent with a corrected approach. |
@@END

@@PATCH
ACTION: replace
ANCHOR: | **Failed — 3rd attempt** | Escalate model (sonnet → opus, opus → fable) and re-dispatch with full error history. Skip if already on fable; security-reviewer caps at opus and never escalates to fable. See Model Escalation in Adaptability. |
@@STOP
| **Failed — 4th attempt** | Escalate to the user with: the task, all attempts, errors, debugger findings, and your diagnosis. Pause this chain; continue other independent chains. |
@@CONTENT
| **Failed — 3rd attempt** | Escalate to the user with: the task, all attempts, errors, debugger findings, and your diagnosis. Pause this chain; continue other independent chains. |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | **Blocked** — agent hit an external dependency or environment issue | Create a new blocker task describing the issue. Pause dependent chain. Flag to user. |
@@CONTENT
| **Blocked** — agent hit an external dependency or environment issue | Create a new blocker task in the state file and TodoWrite. Pause dependent chain. Flag to user. |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: Orphan detection is handled by the **work-verifier** agent (see `~/.claude/agents/work-verifier.md`), which includes timeout budgets per agent type and orphan detection heuristics.
@@CONTENT
Orphan detection is handled by the **work-verifier** agent (see `~/.cursor/agents/work-verifier.md`), which includes timeout budgets per agent type and orphan detection heuristics.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: When every task is `completed`:
@@CONTENT
When every task is `completed` (check state file):
@@END

@@PATCH
ACTION: replace_line
ANCHOR: dispatch a **verifier** agent to run the full test suite against the combined changes. This catches integration issues that per-task verification may miss.
@@CONTENT
dispatch a verifier agent via `Task(subagent_type="verifier")` to run the full test suite against the combined changes. This catches integration issues that per-task verification may miss.
@@END

@@PATCH
ACTION: replace_line
ANCHOR:    - **Estimation accuracy** — overall ratio of actual to estimated. Feed significant variances into cross-run learning (e.g., "verification tasks in this project consistently take 2x the estimate").
@@CONTENT
   - **Estimation accuracy** — overall ratio of actual to estimated. Note significant variances for future runs.
@@END

@@PATCH
ACTION: replace_line
ANCHOR:    > **Reference:** You MUST Read `~/.claude/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, model escalation, calibration, idle time). If the file is missing, proceed using the bullet points above.
@@CONTENT
   > **Reference:** You MUST Read `~/.cursor/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, calibration, idle time). If the file is missing, proceed using the bullet points above.
@@END

@@PATCH
ACTION: replace_line
ANCHOR:    > **Reference:** Invoke the `/timing-calibrator capture` skill (see `~/.claude/skills/timing-calibrator/SKILL.md`) with the run's task metadata to persist timing patterns.
@@CONTENT
   > **Reference:** Invoke the `/timing-calibrator capture` skill (see `~/.cursor/skills/timing-calibrator/SKILL.md`) with the run's task metadata to persist timing patterns.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: When spawning an agent via the Agent tool, always provide a **complete, self-contained brief**. The agent has no conversation history — it only sees what you give it.
@@CONTENT
When spawning an agent via the Task tool, always provide a **complete, self-contained brief**. The agent has no conversation history — it only sees what you give it.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: - **No compound Bash commands** — never use `&&`, `;`, or `||`. Make separate Bash tool calls; use parallel calls for independent commands.
@@CONTENT
- **No compound Shell commands** — never use `&&`, `;`, or `||`. Make separate Shell tool calls; use parallel calls for independent commands.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: - **No sub-agent spawning** — do not use the Agent tool. Only the team manager orchestrates.
@@CONTENT
- **No sub-agent spawning** — do not use the Task tool. Only the team manager orchestrates.
@@END

@@PATCH
ACTION: replace
ANCHOR: ## Constraints (applies to team manager AND all spawned agents)
@@STOP
> **Reference:** You MUST Read `~/.claude/skills/ops/tool-restrictions.md` for the full delegate-first table, permitted direct actions, self-check rules, and the subagent dispatch decision framework. If the file is missing, proceed using the delegate-first principle above.
@@CONTENT
## Constraints (applies to team manager AND all spawned agents)

### Team manager tool restrictions

**Delegate-first:** always dispatch an agent or invoke a skill before using a tool directly. Only use tools directly for reading state or displaying information.

> **Reference:** You MUST Read `~/.cursor/skills/ops/tool-restrictions.md` for the full delegate-first table, permitted direct actions, self-check rules, and the subagent dispatch decision framework. If the file is missing, proceed using the delegate-first principle above.

### Shell rules

The Shared Brief Constraints block (see `#shared-brief-constraints` above) defines the canonical Shell rules — no compound commands, no `cd` prefix, relative paths only, `_tmp_` prefix. These apply to the team manager AND all spawned agents.
@@END

@@PATCH
ACTION: replace
ANCHOR: Pre-planning chain (optional, for work requiring design exploration):
@@STOP
> **Reference:** The **ssh-executor** agent (see `~/.claude/agents/ssh-executor.md`) handles its own preflight checks (host validation, connectivity, key, source files, remote directory) and includes SSH-specific handoff fields in its output format. No separate preflight dispatch is needed for SSH tasks.
@@CONTENT
Pre-planning chain (optional, for work requiring design exploration):

```text
interviewer → architect → planner → project-scoper → critic → executor → ...
```

With `--brainstorm`, treat this as a strict gate:

```text
interviewer → architect → user approval checkpoint → planner
```

Architect dispatches for architectural decisions; otherwise team manager goes directly to planner.

```text
executor → verifier → [security-reviewer] → deslop → code-reviewer → documentor
```

Security-reviewer is scheduled by **either** a security content signal in the task brief **or** a `security-review: run` recommendation from `change-analyzer` evaluated against the real post-executor diff at the `[security-reviewer]` stage transition. It fires **at most once** per run/stage regardless of which input triggers it — if it is already scheduled by the content-signal path, a `change-analyzer` recommendation does not schedule a second instance, and vice versa. Dedup is keyed by run + stage transition. `--security-review=off` suppresses both inputs; `--security-review=always` fires unconditionally on every stage transition.

When a chain has multiple implementation tasks, parallelize then converge:

```text
executor(task1) ──┐
executor(task2) ──┤→ verifier(all) → [security-reviewer] → deslop(all) → code-reviewer(all) → documentor(all)
executor(task3) ──┘
```

> **Reference:** The **ssh-executor** agent (see `~/.cursor/agents/ssh-executor.md`) handles its own preflight checks (host validation, connectivity, key, source files, remote directory) and includes SSH-specific handoff fields in its output format. No separate preflight dispatch is needed for SSH tasks.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: 1. After the verifier reports failures, create a **fix task** assigned to the executor. Include the verifier's specific findings (not just "it failed").
@@CONTENT
1. After the verifier reports failures, create a **fix task** in the state file and TodoWrite assigned to the executor. Include the verifier's specific findings (not just "it failed").
@@END

@@PATCH
ACTION: replace_line
ANCHOR: After all verify tasks pass and before code review, run `/deslop --conservative` on files modified during the run. This is enabled by default; use `--no-deslop` to skip.
@@CONTENT
After all verify tasks pass and before code review, run deslop with `--conservative` on files modified during the run. This is enabled by default; use `--no-deslop` to skip.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: **Skip when:** `--no-deslop` set, `/deslop` skill unavailable, run produced no code changes, or all changes are trivial/mechanical.
@@CONTENT
**How to invoke deslop (read-and-dispatch):** Read `~/.cursor/skills/deslop/SKILL.md`. Dispatch via `Task(subagent_type="generalPurpose", prompt=<deslop skill content + "--conservative" + file list>)`.

**Skip when:** `--no-deslop` set, deslop skill file unavailable, run produced no code changes, or all changes are trivial/mechanical.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | Environment/dependency blocker | Create blocker task, pause chain, alert user |
@@CONTENT
| Environment/dependency blocker | Create blocker task in state file and TodoWrite, pause chain, alert user |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | 3 consecutive failures on same task | Escalate model (see Model Escalation). If already on fable — or on opus for security-reviewer (see the escalation ceiling exception) — or failure is a blocker, escalate to user with: task, all attempts, errors, your diagnosis |
@@CONTENT
| 3 consecutive failures on same task | Escalate to user with: task, all attempts, errors, debugger findings, your diagnosis |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: > **Reference:** When rollback is needed, dispatch a **rollback** agent (see `~/.claude/agents/rollback.md`) with the affected file list, scope level, and run ID.
@@CONTENT
> **Reference:** When rollback is needed, dispatch a **rollback** agent (see `~/.cursor/agents/rollback.md`) via `Task(subagent_type="generalPurpose")` with the affected file list, scope level, and run ID.
@@END

@@PATCH
ACTION: replace
ANCHOR: - <agent> → Task #N: "<subject>" (in_progress, Xs elapsed) [health indicator]
@@STOP
Health indicators: ✓ ON TRACK (elapsed < 1.5× estimate), ⚠️ SLOW (1.5–2.5×), 🔴 OVERRUN (> 2.5×), 👻 ORPHAN? (elapsed > agent-type timeout, no completion received)
@@CONTENT
- <agent> → Task #N: "<subject>" (in_progress, Xs elapsed)
@@END

@@PATCH
ACTION: replace_line
ANCHOR: Every adaptation is logged in the task board metadata and reported in the dashboard.
@@CONTENT
Every adaptation is logged in the state file and reported in the dashboard.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | **Missing task** — agent finds work the plan didn't account for | Create the task, wire dependencies, slot it into the board. Log it as an adaptation. In interactive mode, mention it at the next checkpoint. |
@@CONTENT
| **Missing task** — agent finds work the plan didn't account for | Create the task in the state file and TodoWrite, wire dependencies, slot it into the board. Log it as an adaptation. In interactive mode, mention it at the next checkpoint. |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | **Wrong sequencing** — a task's dependency was incorrect | Update the dependency graph. Re-order the dispatch queue. Log the change. |
@@CONTENT
| **Wrong sequencing** — a task's dependency was incorrect | Update the dependency graph in the state file. Re-order the dispatch queue. Log the change. |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | **Task too large** — agent reports the task needs splitting | Pause the task. Dispatch a **planner** agent to break it into subtasks. Replace the original task with the subtasks. Resume. |
@@CONTENT
| **Task too large** — agent reports the task needs splitting | Pause the task. Dispatch the **planner** via `Task(subagent_type="planner")` to break it into subtasks. Replace the original task with the subtasks in the state file and TodoWrite. Resume. |
@@END

@@PATCH
ACTION: replace
ANCHOR: ### Model escalation
@@STOP
> **Reference:** The **rollback** agent (see `~/.claude/agents/rollback.md`) handles the rollback procedure. See Failure Handling above for dispatch details.
@@CONTENT
### Retry strategy

When an agent fails, the team-manager retries with increasing context before escalating:

```text
1st attempt: assigned agent with original brief
2nd attempt: same agent, with error context and narrowed scope
3rd attempt: dispatch debugger/debugger-build for diagnosis, then re-brief with findings
4th attempt: escalate to user
```

Note: Cursor does not support model escalation (changing the model between attempts). All subagents run on the session model or `model="fast"`. The retry strategy focuses on improving the brief quality and using diagnostic agents instead.
@@END

@@PATCH
ACTION: replace
ANCHOR: ### Learning across runs
@@STOP
> **Reference:** The `/timing-calibrator` skill (see `~/.claude/skills/timing-calibrator/SKILL.md`) manages estimation calibration, model escalation patterns, and cross-run learning. Invoke `/timing-calibrator read` at run start and `/timing-calibrator capture` at completion.
@@CONTENT
@@END

@@PATCH
ACTION: replace
ANCHOR: With `ralph`, wraps the workflow in a `/ralph-loop` persistence loop (plan → implement → verify → review per iteration).
@@STOP
> **Reference:** See `~/.claude/skills/ops/integrations.md` (Ralph Loop Integration section) for the full integration protocol (read only when `ralph` flag is set). If the file is missing, proceed using the inline summary above.
@@CONTENT
When invoked with `ralph`, the team manager wraps its entire workflow inside a `/ralph-loop` persistence loop. Each loop pass runs one full team-manager cycle (plan → implement → verify → review).

> **Reference:** See `~/.cursor/skills/ops/integrations.md` (Ralph Loop Integration section) for the full Ralph Loop integration protocol, iteration behavior, and when to use/not use ralph mode (read only when `ralph` flag is set). If the file is missing, proceed using the inline summary above.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | "add [task]" | Add task to state file, wire dependencies, slot into dispatch loop |
@@CONTENT
| "add [task]" | Add task to state file and TodoWrite, wire dependencies, slot into dispatch loop |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | "drop #N" | Remove task from state file, clear downstream blockers, resume |
@@CONTENT
| "drop #N" | Remove task from state file, update TodoWrite, clear downstream blockers, resume |
@@END

@@PATCH
ACTION: replace_line
ANCHOR: | "resume" | Read state file from disk, verify in-progress tasks, continue |
@@CONTENT
| "resume" | Read state file from disk, recreate TodoWrite, verify in-progress tasks, continue |
@@END

@@PATCH
ACTION: replace
ANCHOR: ## Permission Notes
@@STOP
If a dispatched agent needs one of these, warn the user before dispatch. In autonomous mode, pause the affected task and continue other chains. To opt in per project, add to `.claude/settings.json`: `{"permissions": {"allow": ["RemoteTrigger", "Bash(npx *)", "Bash(make *)", "Bash(cmake *)"]}}`. Detailed permission guidance is rarely needed beyond this.
@@CONTENT
## Permission Notes

Cursor does not have a permission enforcement system like Claude Code's `settings.json` allowlists. All spawned agents have full access to all tools available in the session. Tool restriction constraints in agent briefs are advisory only — agents are instructed not to use certain tools but enforcement is not guaranteed. There is no equivalent of Claude Code's `RemoteTrigger` permission prompt. The team manager should still include tool constraint instructions in briefs (see Agent-specific rules under Constraints) to guide agent behavior.
@@END

@@PATCH
ACTION: replace_line
ANCHOR: The **first line** of each assistant turn MUST begin with **`Team Manager`** (bold backtick-wrapped). Apply on turns containing dashboards, dispatch notifications, stage transitions, escalations, and completion summaries. Do **not** repeat on continuation lines (bullets, sub-items, tables) within the same turn.
@@CONTENT
The **first line** of each assistant turn MUST begin with **`Team Manager`** (bold backtick-wrapped). Apply on turns containing dashboards, dispatch notifications, stage transitions, escalations, and completion summaries. Do **not** repeat on continuation lines (bullets, sub-items, tables) within the same turn.

---

## Cursor-Specific Limitations

These limitations are inherent to the Cursor platform and cannot be worked around:

- **No model escalation** — All subagents run on the session model (or `model="fast"`). The retry-escalate pattern (sonnet → opus) is not available. The retry strategy compensates by using diagnostic agents (debugger/debugger-build) to improve brief quality instead.
- **No tool enforcement** — Agent tool restrictions in briefs are advisory only. A critic *could* still call StrReplace; it's just instructed not to. The deploy script's agent hardening adds explicit constraint sections to mitigate this.
- **No agent-definition injection at dispatch** — Cursor's `Task(subagent_type=...)` covers all pipeline agent types natively plus utility types (`generalPurpose`, `explore`, `shell`, `best-of-n-runner`, etc.), so dispatch by role name works directly. Setting `subagent_type` provides the role label but does NOT inject the agent's `.md` body into its context — the spawned agent must self-read `~/.cursor/agents/<agent_type>.md` as its first action (Non-negotiable #2). Agents outside the enum (`work-verifier`, `preflight`, `change-analyzer`, `rollback`) dispatch via `Task(subagent_type="generalPurpose")`.
- **TodoWrite limitations** — TodoWrite items only have `id`, `content`, and `status` fields. All rich metadata (dependencies, timing, estimates) lives in the state file on disk.
- **TodoWrite drift** — Models often update TodoWrite without writing `.ops-state/<run-id>-board.json`. The board file is mandatory on every status change; see `phase-dispatch.md` § **Cursor: state file sync (mandatory)**.
@@END
