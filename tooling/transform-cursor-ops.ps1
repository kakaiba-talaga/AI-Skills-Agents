<#
.SYNOPSIS
    Transform skills/ops/SKILL.md into the Cursor-compatible SKILL.cursor.md.

.DESCRIPTION
    Default behavior: drift-check. If the target SKILL.cursor.md already
    exists and matches what this transform would produce, print "in sync"
    and exit 0. If the target differs, print a drift summary and prompt
    for regeneration (when stdin is a tty) or exit 3 (when stdin is not a
    tty — CI-friendly).

    Both this script and the .sh wrapper invoke the same embedded Python
    logic (byte-identical body), so sh↔ps1 parity is guaranteed by
    construction. Output uses LF line endings.

.PARAMETER In
    Source SKILL.md. Default: skills/ops/SKILL.md

.PARAMETER Out
    Destination path, or "-" for stdout.
    Default: sibling SKILL.cursor.md of -In when -In ends in /SKILL.md;
    otherwise "-".

.PARAMETER Force
    Skip drift-check; always regenerate and write.

.PARAMETER WhatIf
    Preview only — print line count and SHA256 of what would be written.
    Takes precedence over -Force if both are set.

.EXAMPLE
    .\tooling\transform-cursor-ops.ps1
    Default: drift-check. Prompts for regeneration on drift, exits 3 on
    non-tty drift (CI-friendly).

.EXAMPLE
    .\tooling\transform-cursor-ops.ps1 -Force
    Force regenerate, no drift-check.

.EXAMPLE
    .\tooling\transform-cursor-ops.ps1 -WhatIf
    Preview SHA256 + line count.

.NOTES
    Exit codes:
      0  Success (in-sync, wrote, what-if preview, stdout)
      1  Input error (bad args, source not found)
      3  Drift detected; non-tty stdin (CI-friendly: no prompt shown)
      4  User declined regeneration at interactive prompt
#>

[CmdletBinding()]
param(
    [string]$In   = "skills/ops/SKILL.md",
    [string]$Out  = "",
    [switch]$Force,
    [switch]$WhatIf,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    exit 0
}

if (-not (Test-Path $In)) {
    Write-Error "Source file not found: $In"
    exit 1
}

# ---------------------------------------------------------------------------
# Derive default Out: sibling SKILL.cursor.md of In when In ends in
# /SKILL.md; otherwise default to stdout ("-").
# ---------------------------------------------------------------------------
if ([string]::IsNullOrEmpty($Out)) {
    $normIn = $In -replace '\\', '/'
    if ($normIn.EndsWith("/SKILL.md")) {
        $Out = $normIn.Substring(0, $normIn.Length - "/SKILL.md".Length) + "/SKILL.cursor.md"
    } else {
        $Out = "-"
    }
}

# ---------------------------------------------------------------------------
# Locate Python (validate each candidate actually runs; Windows Store stubs
# report as found but exit non-zero when invoked without the Store installed)
# ---------------------------------------------------------------------------
$python = $null
$candidates = @(
    "python3", "python",
    "C:\Python311\python.exe", "C:\Python312\python.exe", "C:\Python313\python.exe",
    "C:\Python310\python.exe", "C:\Python39\python.exe"
)
foreach ($candidate in $candidates) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
        try {
            & $candidate -c "import sys; assert sys.version_info >= (3,6)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $python = $candidate
                break
            }
        } catch {
            # skip
        }
    }
}
if (-not $python) {
    Write-Error "Python 3.6+ is required but not found."
    exit 1
}

# ---------------------------------------------------------------------------
# Embedded Python script — byte-identical to the body in transform-cursor-ops.sh.
# ---------------------------------------------------------------------------
$pyScript = @'
import sys
import hashlib
import os
import difflib

in_path   = sys.argv[1]
out_path  = sys.argv[2]
what_if   = sys.argv[3] == "true"
force     = sys.argv[4] == "true"

with open(in_path, "rb") as f:
    raw = f.read()

# Normalise to LF internally
text = raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n").decode("utf-8")

# ---------------------------------------------------------------------------
# Helper: replace first occurrence of old with new
# ---------------------------------------------------------------------------
def rep(old, new):
    global text
    idx = text.find(old)
    if idx < 0:
        first = old.split("\n")[0][:80]
        print(f"WARNING: PATCH NOT FOUND: {first}...", file=sys.stderr)
        return
    text = text[:idx] + new + text[idx + len(old):]

# ---------------------------------------------------------------------------
# PATCH 0 — Prepend YAML frontmatter
# ---------------------------------------------------------------------------
first_line = text.split("\n")[0]
rep(first_line, "---\nname: ops\ndescription: Coordinate a team of agents working on a shared task list.\n---\n" + first_line)

# ---------------------------------------------------------------------------
# PATCH 1 — --worktree flag
# ---------------------------------------------------------------------------
rep(
    "- `--worktree` — spawn parallel agents in isolated git worktrees to eliminate file conflicts.",
    "- `--worktree` — spawn parallel agents in isolated git worktrees using `best-of-n-runner` subagents to eliminate file conflicts.",
)

# ---------------------------------------------------------------------------
# PATCH 2 — help-card reference + inline fallback
# ---------------------------------------------------------------------------
rep(
    "> **Reference:** You MUST Read `~/.claude/skills/ops/help-card.md` for the full help card text. If the file is missing, display a brief usage summary instead.",
    """> **Reference:** You MUST Read `~/.cursor/skills/ops/help-card.md` for the full help card text. If the file is missing, display the quick-reference below instead.

**Inline help fallback:**

```text
Commands: /ops <spec> | plan | execute | status | resume | ralph "<goal>" | help
Flags: --autonomous | --supervised | --parallel N | --agents <list> | --dry-run | --worktree | --no-branch | --no-deslop
Mid-run: stop | pause | status | skip <stage/#N> | drop #N | do #N next | add <task> | reprioritize
Pipeline: executor → verifier → deslop → code-reviewer → documentor
Retry: 3 attempts with narrowed scope and debugger diagnosis, then escalate to user
```""",
)

# ---------------------------------------------------------------------------
# PATCH 3 — State Management opening paragraphs
# ---------------------------------------------------------------------------
rep(
    "The ops skill persists all task data in a JSON state file on disk. This is the source of truth for dependencies, timing, estimates, agent assignments, and adaptation notes.\n\nThe state file on disk is mandatory — see Non-negotiables #1.",
    "The ops skill uses a **dual-layer task board**: a JSON state file on disk for full metadata, and TodoWrite for IDE-visible status display. Both are updated on every state change.\n\nThe state file on disk is mandatory — TodoWrite alone is not sufficient (it cannot store dependencies, timing, or agent metadata). See Non-negotiables #1.",
)

# ---------------------------------------------------------------------------
# PATCH 4 — State File paragraph
# ---------------------------------------------------------------------------
rep(
    "The state file is stored at `.ops-state/<run-id>-board.json`.",
    "The state file is stored at `.ops-state/<run-id>-board.json`. This is the source of truth for all task data — dependencies, timing, estimates, agent assignments, and adaptation notes.",
)

# ---------------------------------------------------------------------------
# PATCH 5 — State Operations intro + table (2-col → 3-col) + TodoWrite section
# ---------------------------------------------------------------------------
rep(
    "All task board operations use the state file as the primary store. **Every mutation must write the state file to disk** — do not rely on in-memory state alone.\n\n| Operation | State file action |\n| :--- | :--- |\n| **Create task** | Append to `tasks` array, write file to disk |\n| **Update status** | Update task's `status`, `started_at`, etc., write file to disk |\n| **Scan for ready** | Read file from disk, filter tasks where `status==\"pending\"` and all `blocked_by` entries are `\"completed\"` |\n| **Complete task** | Update `status`, `completed_at`, `duration_seconds`, write file to disk |\n| **Resume** | Read file from disk — full state recovered |\n| **Report** | Read file from disk, compute timing/estimates/variance |",
    """All task board operations use the state file as the primary store and TodoWrite as the display layer. **Every mutation must write the state file to disk using the `Write` tool** — do not rely on in-memory state alone.

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

The format is `[agent_type][stage] subject`. The ops skill updates both the state file and TodoWrite on every status change.""",
)

# ---------------------------------------------------------------------------
# PATCH 6 — Input table: Spec row
# ---------------------------------------------------------------------------
rep(
    '| Spec or requirement text | Evaluate spec clarity (see below). If clear, dispatch a **planner** agent. If ambiguous, dispatch an **interviewer** agent first, then a **planner** with the crystallized requirements. Wait for the plan, then proceed to Phase 1a (Plan Validation). |',
    '| Spec or requirement text | Evaluate spec clarity (see below). If clear, dispatch **planner** via `Task(subagent_type="planner")`. If ambiguous, dispatch **interviewer** first via `Task(subagent_type="interviewer")`, then **planner** with the crystallized requirements. Wait for the plan, then proceed to Phase 1a (Plan Validation). |',
)

# ---------------------------------------------------------------------------
# PATCH 7 — Input table: resume row
# ---------------------------------------------------------------------------
rep(
    "| `resume` | Read the state file. Treat all `in_progress` tasks as orphaned. Run dedup verification (`resume-dedup.md`), then Phase 2.5 preflight if environment may have changed, then skip to Phase 3. See Interruption Handling → Session Recovery. |",
    "| `resume` | Read the state file from `.ops-state/`. All `in_progress` tasks are treated as orphaned — the previous session's agents are gone. Run the dedup verification procedure (`resume-dedup.md`) to determine actual status before re-dispatching. Run Phase 2.5 preflight if environment may have changed, then skip to Phase 3 (Dispatch Loop). Recreate TodoWrite display from state file via `TodoWrite(merge=false)`. For full recovery procedure, see Interruption Handling → Session Recovery. |",
)

# ---------------------------------------------------------------------------
# PATCH 8 — Input table: status row
# ---------------------------------------------------------------------------
rep(
    "| `status` | Read the state file. Run orphan detection on `in_progress` tasks (`agent-health-monitoring.md` §3b). Display the dashboard (see Status Dashboard), stop. |",
    "| `status` | Read the state file. Before rendering the dashboard, run orphan detection on all `in_progress` tasks (see `agent-health-monitoring.md` Section 3b). Flag suspected orphans in the dashboard. Display the dashboard (see Status Dashboard), stop. |",
)

# ---------------------------------------------------------------------------
# PATCH 9 — Trivial Dispatch step 1
# ---------------------------------------------------------------------------
rep(
    '1. **Create state file (LB1 — mandatory):** Generate a `run-id` (`<slug>-<ISO-date>`). Run `Bash(command="mkdir -p .ops-state")`. Use the Write tool to create `.ops-state/<run-id>-board.json` with one task entry. Use `description_inline` for the task entry (trivial-path runs have no persisted plan doc, so there is no `description_ref` pointer to set). Verify the file exists by reading it back.',
    '1. **Create state file (LB1 — mandatory):** Generate a `run-id` (`<slug>-<ISO-date>`). Run `Shell(command="mkdir -p .ops-state")`. Use the `Write` tool to create `.ops-state/<run-id>-board.json` with one task entry. Use `description_inline` for the task entry (trivial-path runs have no persisted plan doc, so there is no `description_ref` pointer to set). Verify the file exists by reading it back with `Read`. Also call `TodoWrite(merge=false)` with the single task item.',
)

# ---------------------------------------------------------------------------
# PATCH 10 — Trivial Dispatch step 4
# ---------------------------------------------------------------------------
rep(
    "4. **Dispatch:** Spawn the agent via the Agent tool using the same Agent Dispatch Procedure (Phase 3 Step 3) — read frontmatter for `model`, set description/model/prompt (agent reads its own body as first action).",
    '4. **Dispatch:** Spawn the agent via `Task(subagent_type="<agent_type>", prompt=<self-read prompt + brief>)`. For agents not in the Cursor built-in enum, use `Task(subagent_type="generalPurpose", prompt=<self-read prompt + brief>)`. The prompt instructs the agent to read its own definition as its first action (see Agent Dispatch Procedure for the self-read prompt template).',
)

# ---------------------------------------------------------------------------
# PATCH 11 — Trivial Dispatch step 5
# ---------------------------------------------------------------------------
rep(
    "5. **On result:** Mark task `completed` in the state file (record `completed_at`, `duration_seconds`). Run cleanup: `rm _tmp_*`, delete `.ops-state/<run-id>-board.json`. Output one concise summary line: what was done, file(s) changed if any, actual duration.",
    "5. **On result:** Mark task `completed` in the state file (record `completed_at`, `duration_seconds`). Update TodoWrite. Run cleanup: `rm _tmp_*`, delete `.ops-state/<run-id>-board.json`. Output one concise summary line: what was done, file(s) changed if any, actual duration.",
)

# ---------------------------------------------------------------------------
# PATCH 12 — Spec clarity + Architect dispatch reorder
# ---------------------------------------------------------------------------
rep(
    "**Spec clarity evaluation:** If clear, dispatch planner directly. If vague/ambiguous, dispatch **interviewer** first. If user says \"just plan it\", dispatch planner regardless.\n\n**Architect dispatch (optional):** Dispatch an **architect** agent before the planner when the spec involves new subsystems, significant technology choices, competing implementation strategies, or API/data model design. The architect produces an ADD the planner uses as input. Skip for well-understood work.\n\nIn **interactive mode**, prefer asking the user directly for simple ambiguities; use the interviewer for deep ambiguity (multiple unclear dimensions, conflicting requirements). In **autonomous mode**, dispatch the interviewer — the team manager cannot ask interactively.",
    "**Spec clarity evaluation:** Before dispatching the planner, assess whether the user's input is clear enough to plan from. If clear, dispatch planner directly. If vague or ambiguous, dispatch **interviewer** first. If the user says \"just plan it\", dispatch planner regardless.\n\nIn **interactive mode**, prefer asking the user directly for simple ambiguities; use the interviewer for deep ambiguity (multiple unclear dimensions, conflicting requirements). In **autonomous mode**, dispatch the interviewer — the team manager cannot ask interactively.\n\n**Architect dispatch (optional):** Dispatch an **architect** agent via `Task(subagent_type=\"architect\")` before the planner when the spec involves new subsystems, significant technology choices, competing implementation strategies, or API/data model design. The architect produces an ADD the planner uses as input. Skip for well-understood work.",
)

# ---------------------------------------------------------------------------
# PATCH 13 — Plan resume: remove "(see Handoff Documents)"
# ---------------------------------------------------------------------------
rep(
    "The plan doc + state file + handoff files (see Handoff Documents) provide complete state recovery across session boundaries.",
    "The plan doc + state file + handoff files provide complete state recovery across session boundaries.",
)

# ---------------------------------------------------------------------------
# PATCH 14 — ClickUp context enrichment
# ---------------------------------------------------------------------------
rep(
    "**ClickUp context enrichment:** If a ClickUp task ID is referenced, pull task details before planning. Invoke `/clickup Get task <id>` if the skill is available, or fall back to `curl https://api.clickup.com/api/v2/task/<id>` with the token from `~/.claude/config/clickup/config.json`. Extract title, description, status, checklist items, and comments as spec context. Intake-only — does not write back to ClickUp.",
    "**ClickUp context enrichment:** If a ClickUp task ID is referenced, pull task details before planning. Read `~/.cursor/skills/clickup/SKILL.md` and dispatch via `Task(subagent_type=\"generalPurpose\")` if available; otherwise fall back to `curl https://api.clickup.com/api/v2/task/<id>` with token from `~/.cursor/config/clickup/config.json`. Extract title, description, status, checklist items, and comments as spec context. Intake-only — does not write back to ClickUp.",
)

# ---------------------------------------------------------------------------
# PATCH 15 — Phase 1a: insert plan-validation.md ref + rewrite tier table + display section
# ---------------------------------------------------------------------------
rep(
    """**Also skip when:** `resume`, `status`, or user says "just do it" / "skip validation".

**Determine validation tier:**

| Tier | Criteria | Action | Cost |
| :--- | :--- | :--- | :--- |
| **Tier 1 — Skip** | 1-2 tasks, no architectural decisions, mechanical/trivial changes | Proceed directly to Phase 1.5. | None |
| **Tier 2 — Scope only** | 3-5 tasks, OR clear scope but needs estimates/gap analysis, OR medium signals | Dispatch **project-scoper** to produce a scoping doc. Proceed to Phase 1.5 after scoping. | 1 opus agent |
| **Tier 3 — Scope + Critique** | >5 tasks, OR high-weight signal (architectural, security/risk), OR multiple medium signals | Dispatch **project-scoper** then **critic** to review combined plan + scoping doc. | 2 opus agents |

**Display the tier decision:**

```
Plan Validation: Tier [N] — [Skip / Scope only / Scope + Critique]
Signals: [list which signals triggered, e.g., "6 impl tasks (high), new agent architecture (high), security model (medium)"]
Action: [what will happen — "Proceeding to task board" / "Dispatching project-scoper" / "Dispatching project-scoper → critic"]
```

> **Reference:** You MUST Read `~/.claude/skills/ops/plan-validation.md` for spec clarity evaluation criteria, plan complexity scoring signals, critic verdict handling, scoper/critic output descriptions, execute-skip detection, mode-specific behavior, and adaptation rules. If the file is missing, proceed using the tier table and display format above.""",
    """**Also skip when:** `resume`, `status`, or user says "just do it" / "skip validation".

> **Reference:** You MUST Read `~/.cursor/skills/ops/plan-validation.md` for spec clarity evaluation criteria, plan complexity scoring signals, critic verdict handling, scoper/critic output descriptions, execute-skip detection, mode-specific behavior, and adaptation rules. If the file is missing, proceed using the tier table and display format above.

**Determine validation tier:**

| Tier | Criteria | Action | Cost |
| :--- | :--- | :--- | :--- |
| **Tier 1 — Skip** | 1-2 tasks, no architectural decisions, mechanical/trivial changes | Proceed directly to Phase 1.5. | None |
| **Tier 2 — Scope only** | 3-5 tasks, OR clear scope but needs estimates/gap analysis, OR medium signals | Dispatch **project-scoper** via `Task(subagent_type="project-scoper")`. Proceed to Phase 1.5 after scoping. | 1 agent |
| **Tier 3 — Scope + Critique** | >5 tasks, OR high-weight signal (architectural, security/risk), OR multiple medium signals | Dispatch **project-scoper** then **critic** via `Task(subagent_type="critic")`. | 2 agents |

**Display the tier decision:** Always show the tier decision to the user, regardless of autonomy mode:

```text
Plan Validation: Tier [N] — [Skip / Scope only / Scope + Critique]
Signals: [list which signals triggered, e.g., "6 impl tasks (high), new agent architecture (high), security model (medium)"]
Action: [what will happen — "Proceeding to task board" / "Dispatching project-scoper" / "Dispatching project-scoper → critic"]
```

In **interactive mode**, show the tier decision and wait for the user to confirm, override, or skip. The user can say:
- "proceed" — accept the tier decision
- "skip validation" — override to Tier 1 regardless of score
- "scope it" — override to Tier 2
- "scope and critique" — override to Tier 3

In **autonomous mode**, display the tier decision and proceed automatically. The decision is always visible so the user knows what validation level was applied — the team manager never silently skips validation without reporting it.

In **supervised mode**, show the tier decision and wait for approval before each agent dispatch (same as other tasks in supervised mode).""",
)

# ---------------------------------------------------------------------------
# PATCH 16 — Phase 2: header + code block annotation + mkdir + Write tool
# ---------------------------------------------------------------------------
rep(
    "Parse the plan into discrete, assignable tasks. Create the state file.",
    "Parse the plan into discrete, assignable tasks. Create the state file and TodoWrite display.",
)

rep(
    "```\nRun ID: <plan-slug>-<ISO-date>\nState file: .ops-state/<run-id>-board.json\nPlan file: docs/plan/<name>-plan.md (if one was written in Phase 1)\n```",
    "```text\nRun ID: <plan-slug>-<ISO-date>\nState file: .ops-state/<run-id>-board.json\nPlan file: docs/plan/<name>-plan.md (if one was written in Phase 1)\n```",
)

rep(
    '1. Run `Bash(command="mkdir -p .ops-state")`.',
    '1. Run `Shell(command="mkdir -p .ops-state")` (or `mkdir .ops-state` on Windows if it doesn\'t exist — check first with `ls .ops-state` or `dir .ops-state`).',
)

rep(
    '2. Use the Write tool to create `.ops-state/<run-id>-board.json` with the initial structure: `{"run_id": "<run-id>", "state_dir": ".ops-state/", "plan_file": "<path or null>", "tasks": []}`.',
    '2. Use the `Write` tool to create `.ops-state/<run-id>-board.json` with the initial structure: `{"run_id": "<run-id>", "state_dir": ".ops-state/", "plan_file": "<path or null>", "tasks": []}`.',
)

rep(
    "3. Verify the file exists by reading it back. If the read fails, the state file was not created — stop and fix before proceeding.",
    '3. Verify the file exists by reading it back with `Read(path=".ops-state/<run-id>-board.json")`. If the read fails, the state file was not created — stop and fix before proceeding.',
)

# ---------------------------------------------------------------------------
# PATCH 17 — Phase 2 step 4 + 5 reorder: Write→TodoWrite + new Verify block
# ---------------------------------------------------------------------------
rep(
    """**4. Write state file to disk:**

Use the Write tool to overwrite `.ops-state/<run-id>-board.json` with the complete JSON (all tasks populated from steps 2-3).

**5. Verify state file on disk (MANDATORY):**

Before displaying the task board, confirm the state file exists and is valid:

1. Read `.ops-state/<run-id>-board.json` — verify the file contains valid JSON with a non-empty `tasks` array.
2. If the file is missing or empty, **stop and re-create it**. Do not proceed to dispatch without a valid state file on disk.
3. Check whether `.ops-state/` is in `.gitignore`. If not, add it.

**Agent Assignment Rules**""",
    """**4. Write state file and create TodoWrite display:**

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

**Agent Assignment Rules**""",
)

# ---------------------------------------------------------------------------
# PATCH 18 — Domain-specific agents footnote
# ---------------------------------------------------------------------------
rep(
    "**When genuinely in doubt**, dispatch an **interviewer** to clarify — a quick clarification is cheaper than re-doing the work.",
    '**When genuinely in doubt**, dispatch the **interviewer** via `Task(subagent_type="interviewer")` to clarify — a quick clarification is cheaper than re-doing the work.',
)

# ---------------------------------------------------------------------------
# PATCH 19 — Inject step 5 (Verify) before "Display the task board"
# ---------------------------------------------------------------------------
rep(
    "**Display the task board after creation.** After the state file is written and verified, render a Status Dashboard",
    """**5. Verify state file on disk (MANDATORY):**

Before displaying the task board, confirm the state file exists and is valid:

1. `Read(path=".ops-state/<run-id>-board.json")` — verify the file contains valid JSON with a non-empty `tasks` array.
2. If the file is missing or empty, **stop and re-create it** from the in-memory task data. Do not proceed to dispatch without a valid state file on disk.
3. Check whether `.ops-state/` is in `.gitignore`. If not, add it (append `.ops-state/` to `.gitignore`).

**Display the task board after creation.** After the state file is verified and TodoWrite is populated, render a Status Dashboard""",
)

# ---------------------------------------------------------------------------
# PATCH 20 — Preflight dispatch
# ---------------------------------------------------------------------------
rep(
    "Dispatch a **verifier** agent with the preflight checklist.",
    'Dispatch a **verifier** agent via `Task(subagent_type="verifier")` with the preflight checklist.',
)

# ---------------------------------------------------------------------------
# PATCH 21 — Phase 3 Step 3: entire dispatch procedure rewrite
# ---------------------------------------------------------------------------
# MAINTENANCE: this patch's `old_string` is a verbatim copy of the Agent Dispatch
# Procedure block in skills/ops/SKILL.md. If that block changes, update `old_string`
# here AND in the sibling .ps1/.sh script so both wrappers stay in lockstep.
rep(
    """2. **Resolve description_ref (LB2 — mandatory before dispatch):** If the task has a `description_ref`, read the plan doc at the pointer (e.g., `Read("docs/plan/<name>-plan.md")`) and extract the referenced section to obtain the full task description, acceptance criteria, and implementation notes. Use this resolved content to compose the Context, Scope, and Acceptance Criteria sections of the brief. The final agent prompt must be fully self-contained — `description_ref` is resolved here so the agent never receives a bare pointer. If the task has `description_inline` instead, use that directly.
3. Spawn the agent via the **Agent** tool using the task's `agent_type` from the state file. Follow the dispatch procedure below.

**Agent Dispatch Procedure** (applies to ALL agent dispatches throughout the workflow, not just Phase 3):

The Agent tool's `subagent_type` enum is environment-dependent (Claude Code typically includes at least `debugger-build`, `git-master`, `code-reviewer`, `code-reviewer-diff`; Cursor's Task tool may expose more). In Claude Code, the known built-ins are listed in rule (d) below; treat that list as the reference — there is no runtime introspection. For each dispatch:

   a. **Read** `~/.claude/agents/<agent_type>.md` where `<agent_type>` is the task's `agent_type` value from the state file. Extract the `model` from YAML frontmatter **only** — do NOT read or store the agent body in the team manager's context.
   b. **`description`**: If this agent's `agent_type` matches a built-in `subagent_type` (see rule d for the list), set description to just `"<task subject>"`. Otherwise, set it to `"<agent_type>(<task subject>)"`. Rationale: when `subagent_type` is set, the UI shows the built-in name as a prefix — adding the same name again would double-label (e.g., `code-reviewer(code-reviewer(Re-review iter 1))`).
   c. **`model`**: Set from the agent's frontmatter `model` field (e.g., `"sonnet"`, `"opus"`).
   d. **`subagent_type`**: Set when `agent_type` matches a built-in `subagent_type` available in the current environment (Claude Code typically: `debugger-build`, `git-master`, `code-reviewer`, `code-reviewer-diff`). Omit for all other agents — they fall back to `general-purpose` and the agent's definition materializes via the self-read prompt (rule e).
   e. **`prompt`**: Compose using the self-read template below, followed by the task brief (see Agent Briefing Format). The agent reads its full definition as its first action — self-containment is preserved because the agent body materializes in the agent's own context, not the team manager's.

**Self-read prompt template** (use verbatim, substituting `<agent_type>` and `<task brief>`):""",
    """2. Update TodoWrite: `TodoWrite(merge=true, todos=[{id: "task-N", content: "...", status: "in_progress"}])`.
3. **Resolve description_ref (LB2 — mandatory before dispatch):** If the task has a `description_ref`, read the plan doc at the pointer (e.g., `Read(path="docs/plan/<name>-plan.md")`) and extract the referenced section to obtain the full task description, acceptance criteria, and implementation notes. Use this resolved content to compose the Context, Scope, and Acceptance Criteria sections of the brief. The final agent prompt must be fully self-contained — `description_ref` is resolved here so the agent never receives a bare pointer. If the task has `description_inline` instead, use that directly.
4. **Compose the self-read prompt:** Read `~/.cursor/agents/<agent_type>.md` frontmatter **only** (for the `model` field — do NOT store the agent body in the task manager's context). Construct the prompt using the self-read template below, then append the task brief.

**Self-read prompt template** (use verbatim, substituting `<agent_type>` and `<task brief>`):""",
)

# ---------------------------------------------------------------------------
# PATCH 22 — Self-read template: ~/.claude/agents → ~/.cursor/agents
# ---------------------------------------------------------------------------
rep(
    "**Your first action:** Read your full agent definition from `~/.claude/agents/<agent_type>.md`.",
    "**Your first action:** Read your full agent definition from `~/.cursor/agents/<agent_type>.md`.",
)

# ---------------------------------------------------------------------------
# PATCH 23 — Remove Example block + "Use the brief format below." + Foreground section
#            Replace with Cursor steps 5 and 6
# ---------------------------------------------------------------------------
rep(
    """**Example** (executor agent):

```
You are running as agent type: executor.

**Your first action:** Read your full agent definition from `~/.claude/agents/executor.md`. This file contains your workflow, responsibilities, lane boundaries, and constraints. Do not proceed with the task until you have read this file in full.

Once you have read the agent definition, execute the task below following the agent's instructions verbatim.

---

## Task Brief
**Context:** Auth middleware is missing from the API layer.
**Scope:** Implement `src/middleware/auth.py` — JWT validation, 401 on failure, pass claims to request context.
**Acceptance Criteria:** All existing tests pass; `pytest tests/middleware/` green; no Edit outside `src/middleware/`.
```

Use the brief format below.
3. For parallel batches, issue all Agent tool calls in a **single message** so they run concurrently.

**Foreground vs. Background Dispatch Policy**

Default is **foreground**. Use **background** (`run_in_background: true`) for tasks estimated at 8+ minutes when other tasks can advance concurrently. Adapt the threshold based on runtime conditions.

> **Reference:** You MUST Read `~/.claude/skills/ops/dispatch-policy.md` for the full foreground/background decision criteria, batch rules, and interaction with health monitoring and worktree isolation. If the file is missing, proceed using the summary above.""",
    """5. Spawn the agent via `Task(subagent_type="<agent_type>", prompt=<self-read prompt + brief>)` using the brief format below. For agents not in the Cursor built-in enum, use `Task(subagent_type="generalPurpose", prompt=<self-read prompt + brief>)`.
6. For parallel batches, issue all Task calls in a **single message** so they run concurrently.""",
)

# ---------------------------------------------------------------------------
# PATCH 24 — Remove "After updating timing..." paragraph
# ---------------------------------------------------------------------------
rep(
    "After updating timing, evaluate health status for all in-progress background agents (see `agent-health-monitoring.md` Sections 3 and 3a). Emit proactive warnings for any threshold crossings before proceeding to result processing.\n\n| Outcome | Action |",
    "| Outcome | Action |",
)

# ---------------------------------------------------------------------------
# PATCH 25 — Step 4 outcome: Passed row
# ---------------------------------------------------------------------------
rep(
    '| **Passed** — acceptance criteria met | Update state file: `status` → `"completed"`. Write a handoff document (see Handoff Documents). Check for newly unblocked tasks. |',
    '| **Passed** — acceptance criteria met | Update state file: `status` → `"completed"`. Update TodoWrite. Write a handoff document (see Handoff Documents). Check for newly unblocked tasks. |',
)

# ---------------------------------------------------------------------------
# PATCH 26 — Step 4 outcome: Failed 2nd attempt
# ---------------------------------------------------------------------------
rep(
    "| **Failed — 2nd attempt** | Dispatch a **debugger** agent (or **debugger-build** if the failure is a build/import/type error) to diagnose the root cause. Use its findings to re-brief the original agent with a corrected approach. |",
    '| **Failed — 2nd attempt** | Dispatch the **debugger** via `Task(subagent_type="debugger")` (or `Task(subagent_type="debugger-build")` if the failure is a build/import/type error) to diagnose the root cause. Use its findings to re-brief the original agent with a corrected approach. |',
)

# ---------------------------------------------------------------------------
# PATCH 27 — Step 4 outcome: Failed 3rd + remove 4th
# ---------------------------------------------------------------------------
rep(
    "| **Failed — 3rd attempt** | Escalate model (e.g., sonnet → opus) and re-dispatch with full error history. Skip if already on opus. See Model Escalation in Adaptability. |\n| **Failed — 4th attempt** | Escalate to the user with: the task, all attempts, errors, debugger findings, and your diagnosis. Pause this chain; continue other independent chains. |",
    "| **Failed — 3rd attempt** | Escalate to the user with: the task, all attempts, errors, debugger findings, and your diagnosis. Pause this chain; continue other independent chains. |",
)

# ---------------------------------------------------------------------------
# PATCH 28 — Blocked row
# ---------------------------------------------------------------------------
rep(
    "| **Blocked** — agent hit an external dependency or environment issue | Create a new blocker task describing the issue. Pause dependent chain. Flag to user. |",
    "| **Blocked** — agent hit an external dependency or environment issue | Create a new blocker task in the state file and TodoWrite. Pause dependent chain. Flag to user. |",
)

# ---------------------------------------------------------------------------
# PATCH 29 — agent-health-monitoring.md reference
# ---------------------------------------------------------------------------
rep(
    "> **Reference:** You MUST Read `~/.claude/skills/ops/agent-health-monitoring.md` for timeout budgets, stall detection rules, health escalation procedures, proactive health warnings, and orphan detection. If the file is missing, proceed without health monitoring.",
    "> **Reference:** You MUST Read `~/.cursor/skills/ops/agent-health-monitoring.md` for timeout budgets, stall detection rules, and health escalation procedures. If the file is missing, proceed without health monitoring.",
)

# ---------------------------------------------------------------------------
# PATCH 30 — Phase 4 header
# ---------------------------------------------------------------------------
rep(
    "When every task is `completed`:",
    "When every task is `completed` (check state file):",
)

# ---------------------------------------------------------------------------
# PATCH 31 — Phase 4 step 3
# ---------------------------------------------------------------------------
rep(
    "dispatch a **verifier** agent to run the full test suite against the combined changes. This catches integration issues that per-task verification may miss.",
    'dispatch a verifier agent via `Task(subagent_type="verifier")` to run the full test suite against the combined changes. This catches integration issues that per-task verification may miss.',
)

# ---------------------------------------------------------------------------
# PATCH 32 — Estimation accuracy
# ---------------------------------------------------------------------------
rep(
    '   - **Estimation accuracy** — overall ratio of actual to estimated. Feed significant variances into cross-run learning (e.g., "verification tasks in this project consistently take 2x the estimate").',
    "   - **Estimation accuracy** — overall ratio of actual to estimated. Note significant variances for future runs.",
)

# ---------------------------------------------------------------------------
# PATCH 33 — timing-edge-cases.md ref (bullet points context)
# ---------------------------------------------------------------------------
rep(
    "   > **Reference:** You MUST Read `~/.claude/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, model escalation, calibration, idle time). If the file is missing, proceed using the bullet points above.",
    "   > **Reference:** You MUST Read `~/.cursor/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, calibration, idle time). If the file is missing, proceed using the bullet points above.",
)

# ---------------------------------------------------------------------------
# PATCH 34 — estimation-feedback.md ref
# ---------------------------------------------------------------------------
rep(
    "   > **Reference:** You MUST Read `~/.claude/skills/ops/estimation-feedback.md` for the estimation feedback loop, memory format, and calibration procedure. If the file is missing, proceed without estimation feedback.",
    "   > **Reference:** You MUST Read `~/.cursor/skills/ops/estimation-feedback.md` for the estimation feedback loop and calibration procedure. If the file is missing, proceed without estimation feedback.",
)

# ---------------------------------------------------------------------------
# PATCH 35 — Agent Briefing Format: "Agent tool" → "Task tool" + ``` → ```text
# ---------------------------------------------------------------------------
rep(
    "When spawning an agent via the Agent tool, always provide a **complete, self-contained brief**.",
    "When spawning an agent via the Task tool, always provide a **complete, self-contained brief**.",
)

rep(
    "```\n## Task\n[Subject from the task]",
    "```text\n## Task\n[Subject from the task]",
)

# ---------------------------------------------------------------------------
# PATCH 36 — Shared Brief Constraints: Bash → Shell
# ---------------------------------------------------------------------------
rep(
    "- **No compound Bash commands** — never use `&&`, `;`, or `||`. Make separate Bash tool calls; use parallel calls for independent commands.",
    "- **No compound Shell commands** — never use `&&`, `;`, or `||`. Make separate Shell tool calls; use parallel calls for independent commands.",
)

rep(
    "- **Relative paths only** — use absolute paths only for resources outside the project (e.g., `~/.claude/`). Absolute paths break permission matching.",
    "- **Relative paths only** — use absolute paths only for resources outside the project (e.g., `~/.cursor/`). Absolute paths break permission matching.",
)

rep(
    "- **No sub-agent spawning** — do not use the Agent tool. Only the team manager orchestrates.",
    "- **No sub-agent spawning** — do not use the Task tool. Only the team manager orchestrates.",
)

# ---------------------------------------------------------------------------
# PATCH 37 — Constraints section: reorder Bash rules ↔ Team manager
# ---------------------------------------------------------------------------
rep(
    "## Constraints (applies to team manager AND all spawned agents)\n\n### Bash rules\n\nThe Shared Brief Constraints block (see `#shared-brief-constraints` above) defines the canonical bash rules \u2014 no compound commands, no `cd` prefix, relative paths only, `_tmp_` prefix. These apply to the team manager AND all spawned agents.\n\n### Team manager tool restrictions\n\n**Delegate-first:** always dispatch an agent or invoke a skill before using a tool directly. Only use tools directly for reading state or displaying information.\n\n> **Reference:** You MUST Read `~/.claude/skills/ops/tool-restrictions.md` for the full delegate-first table, permitted direct actions, and self-check rules. If the file is missing, proceed using the delegate-first principle above.",
    "## Constraints (applies to team manager AND all spawned agents)\n\n### Team manager tool restrictions\n\n**Delegate-first:** always dispatch an agent or invoke a skill before using a tool directly. Only use tools directly for reading state or displaying information.\n\n> **Reference:** You MUST Read `~/.cursor/skills/ops/tool-restrictions.md` for the full delegate-first table, permitted direct actions, and self-check rules. If the file is missing, proceed using the delegate-first principle above.\n\n### Shell rules\n\nThe Shared Brief Constraints block (see `#shared-brief-constraints` above) defines the canonical Shell rules \u2014 no compound commands, no `cd` prefix, relative paths only, `_tmp_` prefix. These apply to the team manager AND all spawned agents.",
)

# ---------------------------------------------------------------------------
# PATCH 38 — Handoff Chains: reorder + annotate code blocks
# ---------------------------------------------------------------------------
rep(
    """Pre-planning chain (optional, for work requiring design exploration):

```
interviewer → architect → planner → project-scoper → critic → executor → ...
```

Architect dispatches for architectural decisions; otherwise team manager goes directly to planner.

```
executor → verifier → [security-reviewer] → deslop → code-reviewer → documentor
```

Parallelize multiple implementation tasks then converge:

```
executor(task1) ──┐
executor(task2) ──┤→ verifier(all) → [security-reviewer] → deslop(all) → code-reviewer(all) → documentor(all)
executor(task3) ──┘
```

Security-reviewer is optional — dispatched for security-sensitive patterns (auth, secrets, API keys, encryption, external inputs).

> **Reference:** See `~/.claude/skills/ops/ssh-integration.md` for SSH-specific preflight checks, brief template, handoff format, and SSH handoff chains (read only for SSH tasks). If the file is missing, proceed without SSH-specific guidance.""",
    """Pre-planning chain (optional, for work requiring design exploration):

```text
interviewer → architect → planner → project-scoper → critic → executor → ...
```

Architect dispatches for architectural decisions; otherwise team manager goes directly to planner.

```text
executor → verifier → [security-reviewer] → deslop → code-reviewer → documentor
```

Security-reviewer is optional — dispatched for security-sensitive patterns (auth, secrets, API keys, encryption, external inputs).

When a chain has multiple implementation tasks, parallelize then converge:

```text
executor(task1) ──┐
executor(task2) ──┤→ verifier(all) → [security-reviewer] → deslop(all) → code-reviewer(all) → documentor(all)
executor(task3) ──┘
```

> **Reference:** See `~/.cursor/skills/ops/ssh-integration.md` for SSH-specific preflight checks, brief template, and handoff format (read only for SSH tasks). If the file is missing, proceed without SSH-specific guidance.""",
)

# ---------------------------------------------------------------------------
# PATCH 39 — Verify→Fix Loop: ``` → ```text
# ---------------------------------------------------------------------------
rep(
    "## Verify → Fix Loop\n\n```\nexecutor → verifier → [FAIL] → executor (fix) → verifier (re-verify) → [PASS] → code-reviewer\n                                     ↑                    |\n                                     └────── [FAIL] ──────┘\n```",
    "## Verify → Fix Loop\n\n```text\nexecutor → verifier → [FAIL] → executor (fix) → verifier (re-verify) → [PASS] → code-reviewer\n                                     ↑                    |\n                                     └────── [FAIL] ──────┘\n```",
)

# ---------------------------------------------------------------------------
# PATCH 40 — Fix task row: add "in the state file and TodoWrite"
# ---------------------------------------------------------------------------
rep(
    "1. After the verifier reports failures, create a **fix task** assigned to the executor.",
    "1. After the verifier reports failures, create a **fix task** in the state file and TodoWrite assigned to the executor.",
)

# ---------------------------------------------------------------------------
# PATCH 41 — Code review ``` → ```text
# ---------------------------------------------------------------------------
rep(
    "```\ncode-reviewer → [REQUEST CHANGES] → executor (fix) → verifier (re-verify) → code-reviewer (re-review)\n```",
    "```text\ncode-reviewer → [REQUEST CHANGES] → executor (fix) → verifier (re-verify) → code-reviewer (re-review)\n```",
)

# ---------------------------------------------------------------------------
# PATCH 42 — Deslop Integration
# ---------------------------------------------------------------------------
rep(
    "After all verify tasks pass and before code review, run `/deslop --conservative` on files modified during the run. This is enabled by default; use `--no-deslop` to skip.",
    "After all verify tasks pass and before code review, run deslop with `--conservative` on files modified during the run. This is enabled by default; use `--no-deslop` to skip.",
)

rep(
    "**Skip when:** `--no-deslop` set, `/deslop` skill unavailable, run produced no code changes, or all changes are trivial/mechanical.",
    """**How to invoke deslop (read-and-dispatch):** Read `~/.cursor/skills/deslop/SKILL.md`. Dispatch via `Task(subagent_type="generalPurpose", prompt=<deslop skill content + "--conservative" + file list>)`.

**Skip when:** `--no-deslop` set, deslop skill file unavailable, run produced no code changes, or all changes are trivial/mechanical.""",
)

# ---------------------------------------------------------------------------
# PATCH 43 — Failure Handling: blocker + escalation rows
# ---------------------------------------------------------------------------
rep(
    "| Environment/dependency blocker | Create blocker task, pause chain, alert user |",
    "| Environment/dependency blocker | Create blocker task in state file and TodoWrite, pause chain, alert user |",
)

rep(
    "| 3 consecutive failures on same task | Escalate model (see Model Escalation). If already on opus or failure is a blocker, escalate to user with: task, all attempts, errors, your diagnosis |",
    "| 3 consecutive failures on same task | Escalate to user with: task, all attempts, errors, debugger findings, your diagnosis |",
)

# ---------------------------------------------------------------------------
# PATCH 44 — rollback-strategy.md ref: remove "model escalation details"
# ---------------------------------------------------------------------------
rep(
    "> **Reference:** See `~/.claude/skills/ops/rollback-strategy.md` for the complete rollback procedure, scope levels, guardrails, and model escalation details (read only on failure escalation). If the file is missing, proceed without automatic rollback.",
    "> **Reference:** See `~/.cursor/skills/ops/rollback-strategy.md` for the complete rollback procedure, scope levels, and guardrails (read only on failure escalation). If the file is missing, proceed without automatic rollback.",
)

# ---------------------------------------------------------------------------
# PATCH 45 — Status Dashboard: ``` → ```text + remove health indicators
# ---------------------------------------------------------------------------
rep(
    "```\n## Team Manager — Status\n\n### Active\n- <agent> → Task #N: \"<subject>\" (in_progress, Xs elapsed) [health indicator]\n\nHealth indicators: ✓ ON TRACK, ⚠️ SLOW, 🔴 OVERRUN, 👻 ORPHAN? (defined in `agent-health-monitoring.md` §6)",
    "```text\n## Team Manager — Status\n\n### Active\n- <agent> → Task #N: \"<subject>\" (in_progress, Xs elapsed)",
)

# ---------------------------------------------------------------------------
# PATCH 46 — timing-edge-cases.md ref in Status Dashboard
# ---------------------------------------------------------------------------
rep(
    "> **Reference:** You MUST Read `~/.claude/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, model escalation, calibration, idle time). If the file is missing, proceed using the dashboard template above.",
    "> **Reference:** You MUST Read `~/.cursor/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, calibration, idle time). If the file is missing, proceed using the dashboard template above.",
)

# ---------------------------------------------------------------------------
# PATCH 47 — Adaptability: "task board metadata" → "state file"
# ---------------------------------------------------------------------------
rep(
    "Every adaptation is logged in the task board metadata and reported in the dashboard.",
    "Every adaptation is logged in the state file and reported in the dashboard.",
)

# ---------------------------------------------------------------------------
# PATCH 48 — Mid-run plan adjustment table rows
# ---------------------------------------------------------------------------
rep(
    "| **Missing task** — agent finds work the plan didn't account for | Create the task, wire dependencies, slot it into the board. Log it as an adaptation. In interactive mode, mention it at the next checkpoint. |",
    "| **Missing task** — agent finds work the plan didn't account for | Create the task in the state file and TodoWrite, wire dependencies, slot it into the board. Log it as an adaptation. In interactive mode, mention it at the next checkpoint. |",
)

rep(
    "| **Wrong sequencing** — a task's dependency was incorrect | Update the dependency graph. Re-order the dispatch queue. Log the change. |",
    "| **Wrong sequencing** — a task's dependency was incorrect | Update the dependency graph in the state file. Re-order the dispatch queue. Log the change. |",
)

rep(
    "| **Task too large** — agent reports the task needs splitting | Pause the task. Dispatch a **planner** agent to break it into subtasks. Replace the original task with the subtasks. Resume. |",
    '| **Task too large** — agent reports the task needs splitting | Pause the task. Dispatch the **planner** via `Task(subagent_type="planner")` to break it into subtasks. Replace the original task with the subtasks in the state file and TodoWrite. Resume. |',
)

# ---------------------------------------------------------------------------
# PATCH 49 — Model escalation → Retry strategy
# ---------------------------------------------------------------------------
rep(
    "### Model escalation\n\n```\n1st attempt: assigned model (from frontmatter)\n2nd attempt: same model, with error context and narrowed scope\n3rd attempt: escalate model (sonnet → opus), with full error history\n4th attempt: escalate to user\n```\n\n> **Reference:** You MUST Read `~/.claude/skills/ops/rollback-strategy.md` for model escalation metadata format, skip conditions, and the complete rollback procedure. If the file is missing, proceed using the escalation ladder above.",
    """### Retry strategy

When an agent fails, the team-manager retries with increasing context before escalating:

```text
1st attempt: assigned agent with original brief
2nd attempt: same agent, with error context and narrowed scope
3rd attempt: dispatch debugger/debugger-build for diagnosis, then re-brief with findings
4th attempt: escalate to user
```

Note: Cursor does not support model escalation (changing the model between attempts). All subagents run on the session model or `model="fast"`. The retry strategy focuses on improving the brief quality and using diagnostic agents instead.""",
)

# ---------------------------------------------------------------------------
# PATCH 50 — Remove "Learning across runs" section
# ---------------------------------------------------------------------------
rep(
    "### Learning across runs\n\nUses the memory system (`~/.claude/projects/<project>/memory/`). Check memory at run start, apply as soft defaults, log when applied.\n\n> **Reference:** You MUST Read `~/.claude/skills/ops/estimation-feedback.md` for the estimation feedback loop, memory format, calibration procedure, and cross-run learning patterns. If the file is missing, proceed without estimation feedback.\n\n### Adaptation log",
    "### Adaptation log",
)

# ---------------------------------------------------------------------------
# PATCH 51 — Inject Skill Invocation section after "### Adaptation log" block
# ---------------------------------------------------------------------------
rep(
    """### Adaptation log

Every adaptation is tracked, reported in the dashboard's **Adaptations** section, and summarized at Phase 4 completion. User feedback on adaptations is saved as project memory for future runs.

---

## Ralph Loop Integration""",
    """### Adaptation log

Every adaptation is tracked, reported in the dashboard's **Adaptations** section, and summarized at Phase 4 completion. User feedback on adaptations is saved as project memory for future runs.

---

## Skill Invocation (Read-and-Dispatch)

Since Cursor has no `Skill` tool, the ops skill invokes other skills by reading their skill file and dispatching:

1. **Read** the target skill file from `~/.cursor/skills/<name>/SKILL.md`
2. **Dispatch** via `Task(subagent_type="generalPurpose", prompt=<skill content + arguments>)` for heavier skills, or follow the instructions inline for lightweight ones

**Mapping:**

| Skill | Read from | Dispatch method |
| :--- | :--- | :--- |
| deslop | `~/.cursor/skills/deslop/SKILL.md` | `Task(subagent_type="generalPurpose")` with `--conservative` flag |
| linter | `~/.cursor/skills/linter/SKILL.md` | `Task(subagent_type="generalPurpose")` or follow inline |
| clickup | `~/.cursor/skills/clickup/SKILL.md` | `Task(subagent_type="generalPurpose")` with task ID |
| deploy | `~/.cursor/skills/deploy/SKILL.md` | `Task(subagent_type="generalPurpose")` with deployment spec |

---

## Ralph Loop Integration""",
)

# ---------------------------------------------------------------------------
# PATCH 52 — Ralph Loop Integration paragraph
# ---------------------------------------------------------------------------
rep(
    "With `ralph`, wraps the workflow in a `/ralph-loop` persistence loop (plan → implement → verify → review per iteration).\n\n> **Reference:** See `~/.claude/skills/ops/integrations.md` (Ralph Loop Integration section) for the full integration protocol (read only when `ralph` flag is set). If the file is missing, proceed using the inline summary above.",
    "When invoked with `ralph`, the team manager wraps its entire workflow inside a `/ralph-loop` persistence loop. Each loop pass runs one full team-manager cycle (plan → implement → verify → review).\n\n> **Reference:** See `~/.cursor/skills/ops/integrations.md` (Ralph Loop Integration section) for the full Ralph Loop integration protocol, iteration behavior, and when to use/not use ralph mode (read only when `ralph` flag is set). If the file is missing, proceed using the inline summary above.",
)

# ---------------------------------------------------------------------------
# PATCH 53 — Interruption Handling: add TodoWrite to commands
# ---------------------------------------------------------------------------
rep(
    '| "add [task]" | Add task to state file, wire dependencies, slot into dispatch loop |',
    '| "add [task]" | Add task to state file and TodoWrite, wire dependencies, slot into dispatch loop |',
)

rep(
    '| "drop #N" | Remove task from state file, clear downstream blockers, resume |',
    '| "drop #N" | Remove task from state file, update TodoWrite, clear downstream blockers, resume |',
)

rep(
    '| "resume" | Read state file from disk, verify in-progress tasks, continue |',
    '| "resume" | Read state file from disk, recreate TodoWrite, verify in-progress tasks, continue |',
)

# ---------------------------------------------------------------------------
# PATCH 54 — Permission Notes: replace entire section
# ---------------------------------------------------------------------------
rep(
    "## Permission Notes\n\nThe team manager and its agents require a broad set of permissions to run without prompts. See the **Permissions Reference** in [`~/.claude/agents/README.md`](../agents/README.md) for the complete list.\n\nSome operations **always prompt** even in autonomous mode:\n\n| Command / Tool | Risk | When it comes up |\n| :--- | :--- | :--- |\n| `RemoteTrigger` | Spins up remote agents that consume API credits unattended. | Ralph integration with remote scheduling. |\n| `Bash(npx *)` | Executes arbitrary npm packages. | Node.js agents running tooling not installed globally. |\n| `Bash(make *)` / `Bash(cmake *)` | Runs arbitrary Makefile targets. | Build steps, `make test`, native compilation. |\n\nIf a dispatched agent needs one of these, warn the user before dispatch. In autonomous mode, pause the affected task and continue other chains. To opt in per project, add to `.claude/settings.json`: `{\"permissions\": {\"allow\": [\"RemoteTrigger\", \"Bash(npx *)\", \"Bash(make *)\", \"Bash(cmake *)\"]}}`. Detailed permission guidance is rarely needed beyond this.",
    """## Permission Notes

Cursor does not have a permission enforcement system like Claude Code's `settings.json` allowlists. All spawned agents have full access to all tools available in the session. Tool restriction constraints in agent briefs are advisory only — agents are instructed not to use certain tools but enforcement is not guaranteed. There is no equivalent of Claude Code's `RemoteTrigger` permission prompt. The team manager should still include tool constraint instructions in briefs (see Agent-specific rules under Constraints) to guide agent behavior.""",
)

# ---------------------------------------------------------------------------
# PATCH 55 — Inject Cursor-Specific Limitations after Output Tagging
# ---------------------------------------------------------------------------
rep(
    "The **first line** of each assistant turn MUST begin with **`Team Manager`** (bold backtick-wrapped). Apply on turns containing dashboards, dispatch notifications, stage transitions, escalations, and completion summaries. Do **not** repeat on continuation lines (bullets, sub-items, tables) within the same turn.",
    """The **first line** of each assistant turn MUST begin with **`Team Manager`** (bold backtick-wrapped). Apply on turns containing dashboards, dispatch notifications, stage transitions, escalations, and completion summaries. Do **not** repeat on continuation lines (bullets, sub-items, tables) within the same turn.

---

## Cursor-Specific Limitations

These limitations are inherent to the Cursor platform and cannot be worked around:

- **No model escalation** — All subagents run on the session model (or `model="fast"`). The retry-escalate pattern (sonnet → opus) is not available. The retry strategy compensates by using diagnostic agents (debugger/debugger-build) to improve brief quality instead.
- **No tool enforcement** — Agent tool restrictions in briefs are advisory only. A critic *could* still call StrReplace; it's just instructed not to. The deploy script's agent hardening adds explicit constraint sections to mitigate this.
- **No custom agent definitions** — Cursor's `Task(subagent_type=...)` uses a fixed enum of built-in agent types. Custom agent `.md` definitions are not loadable as subagent prompts.
- **TodoWrite limitations** — TodoWrite items only have `id`, `content`, and `status` fields. All rich metadata (dependencies, timing, estimates) lives in the state file on disk.""",
)

# ---------------------------------------------------------------------------
# Global substitution: any remaining ~/.claude/ → ~/.cursor/
# ---------------------------------------------------------------------------
text = text.replace("~/.claude/", "~/.cursor/")

# ---------------------------------------------------------------------------
# Output / drift-check decision
# ---------------------------------------------------------------------------
result_bytes = text.encode("utf-8")
new_sha = hashlib.sha256(result_bytes).hexdigest()
new_lines = text.count("\n") + (1 if text and not text.endswith("\n") else 0)

if what_if:
    print(f"[WhatIf] Lines: {new_lines} | SHA256: {new_sha}")
    sys.exit(0)

if out_path == "-":
    sys.stdout.buffer.write(result_bytes)
    sys.exit(0)

target_exists = os.path.exists(out_path)

if force or not target_exists:
    with open(out_path, "wb") as f:
        f.write(result_bytes)
    print(f"Written: {out_path}")
    print(f"SHA256:  {new_sha}")
    print(f"Lines:   {new_lines}")
    sys.exit(0)

# drift-check path: target exists, not forced
with open(out_path, "rb") as f:
    existing_bytes = f.read()
existing_sha = hashlib.sha256(existing_bytes).hexdigest()
existing_lines = existing_bytes.decode("utf-8", errors="replace").count("\n") + (1 if existing_bytes and not existing_bytes.endswith(b"\n") else 0)

if existing_sha == new_sha:
    print(f"No drift — {out_path} is in sync.")
    sys.exit(0)

# drift detected
print(f"Drift detected: {out_path}", file=sys.stderr)
print(f"  Old SHA: {existing_sha} ({existing_lines} lines)", file=sys.stderr)
print(f"  New SHA: {new_sha} ({new_lines} lines)", file=sys.stderr)
existing_text = existing_bytes.decode("utf-8", errors="replace").splitlines(keepends=True)
new_text = text.splitlines(keepends=True)
diff_lines = list(difflib.unified_diff(existing_text, new_text, fromfile="existing", tofile="new", n=2))
if diff_lines:
    print("  First differences:", file=sys.stderr)
    for line in diff_lines[:20]:
        print(f"    {line.rstrip()}", file=sys.stderr)

sys.exit(3)
'@

# ---------------------------------------------------------------------------
# Invoke Python. Write the embedded script to a temp file as UTF-8 (no BOM)
# to avoid PowerShell stdin pipeline re-encoding corrupting non-ASCII bytes.
# ---------------------------------------------------------------------------
$whatIfArg = if ($WhatIf) { "true" } else { "false" }
$forceArg  = if ($Force)  { "true" } else { "false" }

$tmpPy = "_tmp_transform-cursor-ops.py"
$code = 1
try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tmpPy, $pyScript, $utf8NoBom)
    & $python $tmpPy $In $Out $whatIfArg $forceArg
    $code = $LASTEXITCODE

    # -----------------------------------------------------------------------
    # Wrapper drift-check prompt: on exit 3 with stdin tty, offer regeneration.
    # Non-tty stdin → propagate 3 (CI-friendly).
    # -----------------------------------------------------------------------
    if ($code -eq 3 -and -not $Force) {
        if (-not [Console]::IsInputRedirected) {
            $response = Read-Host -Prompt "Regenerate $Out? [y/N]"
            if ($response -match '^(y|Y|yes|Yes|YES)$') {
                & $python $tmpPy $In $Out $whatIfArg "true"
                $code = $LASTEXITCODE
            } else {
                [Console]::Error.WriteLine("Aborted — no changes written.")
                $code = 4
            }
        }
    }
} finally {
    if (Test-Path $tmpPy) { Remove-Item $tmpPy -Force }
}
exit $code
