#!/usr/bin/env bash
#
# Transform skills/ops/SKILL.md into the Cursor-compatible SKILL.cursor.md.
#
# Default behavior: drift-check. If the target SKILL.cursor.md already exists
# and matches what this transform would produce, print "in sync" and exit 0.
# If the target differs, print a drift summary and prompt for regeneration
# (when stdin is a tty) or exit 3 (when stdin is not a tty — CI-friendly).
#
# Usage:
#   ./tooling/transform-cursor-ops.sh [options]
#
# Options:
#   -i, --in  <path>    Source SKILL.md (default: skills/ops/SKILL.md)
#   -o, --out <path>    Output path, or "-" for stdout
#                       (default: sibling SKILL.cursor.md of -i, or "-" if
#                       -i doesn't match a skills/<name>/SKILL.md pattern)
#   -f, --force         Skip drift-check; always regenerate and write
#   -w, --what-if       Preview only — print line count and SHA256, no write
#                       (takes precedence over --force if both are set)
#   -h, --help          Show this help
#
# Exit codes:
#   0  Success (in sync, wrote file, what-if printed, or stdout printed)
#   1  Input error (missing file, bad args)
#   3  Drift detected and no prompt was available (non-tty stdin)
#   4  User declined regeneration at the prompt
#
# Examples:
#   ./tooling/transform-cursor-ops.sh                  # drift-check, prompt on drift
#   ./tooling/transform-cursor-ops.sh -f               # force regenerate
#   ./tooling/transform-cursor-ops.sh -w               # preview SHA + line count
#   ./tooling/transform-cursor-ops.sh -o -             # emit to stdout

set -uo pipefail

IN_PATH="skills/ops/SKILL.md"
OUT_PATH=""
FORCE=false
WHAT_IF=false

print_help() {
    sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--in)       IN_PATH="$2"; shift 2 ;;
        -o|--out)      OUT_PATH="$2"; shift 2 ;;
        -f|--force)    FORCE=true; shift ;;
        -w|--what-if)  WHAT_IF=true; shift ;;
        -h|--help)     print_help; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ ! -f "$IN_PATH" ]]; then
    echo "Error: Source file not found: $IN_PATH" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Derive default OUT_PATH: sibling SKILL.cursor.md of IN_PATH when IN_PATH
# ends in /SKILL.md; otherwise default to stdout ("-").
# ---------------------------------------------------------------------------
if [[ -z "$OUT_PATH" ]]; then
    IN_PATH_NORM="${IN_PATH//\\//}"
    if [[ "$IN_PATH_NORM" == */SKILL.md ]]; then
        OUT_PATH="${IN_PATH_NORM%/SKILL.md}/SKILL.cursor.md"
    else
        OUT_PATH="-"
    fi
fi

# ---------------------------------------------------------------------------
# Locate Python (validate each candidate actually runs; Windows Store stubs
# report as found but exit non-zero when invoked without the Store installed)
# ---------------------------------------------------------------------------
PYTHON=""
for _candidate in python3 python \
    /c/Python311/python.exe /c/Python312/python.exe /c/Python313/python.exe \
    /c/Python310/python.exe /c/Python39/python.exe; do
    if command -v "$_candidate" &>/dev/null 2>&1; then
        if "$_candidate" -c "import sys; assert sys.version_info >= (3,6)" &>/dev/null 2>&1; then
            PYTHON="$_candidate"
            break
        fi
    fi
done
if [[ -z "$PYTHON" ]]; then
    echo "Error: Python 3.6+ is required but not found." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Run transform via embedded Python script.
# Args: in_path out_path what_if force
# Python exit codes: 0 (success/sync), 3 (drift). Wrapper adds 1 (bad args/no Python) and 4 (user declined).
# The wrapper below converts exit 3 into a prompt (tty) or propagates it (non-tty).
# ---------------------------------------------------------------------------
run_python() {
    local force_arg="$1"
    "$PYTHON" - "$IN_PATH" "$OUT_PATH" "$WHAT_IF" "$force_arg" <<'PYEOF'
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
# Post-B1: many anchors moved to skills/ops/phase-*.md companions.
# ---------------------------------------------------------------------------
def _companion_patch(old):
    """Return True when the anchor lives in phase companions, not the hub."""
    first = old.split("\n", 1)[0]
    return first.startswith((
        "| Spec or requirement text |",
        "| `resume` |",
        "| `status` |",
        "1. **Create state file (LB1",
        "4. **Dispatch:** Spawn the agent via the Agent tool",
        "5. **On result:** Mark task `completed`",
        "**Spec clarity evaluation (default path",
        "The plan doc + state file + handoff files (see Handoff Documents)",
        "**ClickUp context enrichment:**",
        "**Also skip when:** `resume`, `status`",
        "Parse the plan into discrete, assignable tasks. Create the state file.",
        "1. Run `Bash(command=\"mkdir -p .ops-state\")`.",
        "2. Use the Write tool to create `.ops-state/<run-id>-board.json`",
        "3. Verify the file exists by reading it back. If the read fails",
        "**4. Write state file to disk:**",
        "**When genuinely in doubt**, dispatch an **interviewer**",
        "**Display the task board after creation.** After the state file is written",
        "Dispatch a **preflight** agent (see `~/.claude/agents/preflight.md`)",
        "2. **Resolve description_ref (LB2",
        "**Your first action:** Read your full agent definition",
        "**Dispatch example:**",
        "After updating timing, check elapsed time of all in-progress background agents",
        "| **Passed**",
        "| **Failed — 2nd attempt**",
        "| **Failed — 3rd attempt**",
        "| **Blocked**",
        "Orphan detection is handled by the **work-verifier** agent",
        "When every task is `completed`:",
        "dispatch a **verifier** agent to run the full test suite",
        "   - **Estimation accuracy**",
        "   > **Reference:** You MUST Read `~/.claude/skills/ops/timing-edge-cases.md` fo",
        "> **Reference:** You MUST Read `~/.claude/skills/ops/timing-edge-cases.md` for t",
        "   > **Reference:** Invoke the `/timing-calibrator capture` skill",
        "## Team Manager — Status",
    ))

def rep(old, new):
    global text
    idx = text.find(old)
    if idx < 0:
        if not _companion_patch(old):
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
Commands: /ops <spec> | plan | execute | status | resume | save | ralph "<goal>" | help
Flags: --autonomous | --supervised | --parallel N | --agents <list> | --dry-run | --worktree | --no-branch | --no-deslop | --cost | --brainstorm | --dispatch-log
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

The format is `[agent_type][stage] subject`. The ops skill updates both the state file and TodoWrite on every status change.

> **Cursor dispatch ritual:** Before Phase 3, read `~/.cursor/skills/ops/phase-dispatch.md` § **Cursor: state file sync (mandatory)**. Never call `TodoWrite` until the board file `Write` + `Read` verify succeed in the same turn.""",
)

# ---------------------------------------------------------------------------
# PATCH 6 — Input table: Spec row
# ---------------------------------------------------------------------------
rep(
    '| Spec or requirement text | If `--brainstorm` is set (or the user explicitly asks to brainstorm/design first), run the **Brainstorm Gate** below: `interviewer → architect → user approval checkpoint → planner`. Otherwise evaluate spec clarity (see below). If clear, dispatch a **planner** agent. If ambiguous, dispatch an **interviewer** agent first, then a **planner** with the crystallized requirements. Wait for the plan, then proceed to Phase 1a (Plan Validation). |',
    '| Spec or requirement text | If `--brainstorm` is set (or the user explicitly asks to brainstorm/design first), run the **Brainstorm Gate** below: `interviewer → architect → user approval checkpoint → planner`. Otherwise evaluate spec clarity (see below). If clear, dispatch **planner** via `Task(subagent_type="planner")`. If ambiguous, dispatch **interviewer** first via `Task(subagent_type="interviewer")`, then **planner** with the crystallized requirements. Wait for the plan, then proceed to Phase 1a (Plan Validation). |',
)

# ---------------------------------------------------------------------------
# PATCH 7 — Input table: resume row
# ---------------------------------------------------------------------------
rep(
    "| `resume` | Read the state file. **Check `pending_nested_skill` before dedup** — if non-null, escalate to the user per `interruption-recovery.md` §Session Recovery step 2; do not auto-re-invoke. Treat all `in_progress` tasks as orphaned. Dispatch a **work-verifier** agent (see `~/.claude/agents/work-verifier.md`) per in-progress task to determine actual completion status. Then run Phase 2.5 preflight if environment may have changed, then skip to Phase 3. See Interruption Handling → Session Recovery. |",
    "| `resume` | Read the state file from `.ops-state/`. **Check `pending_nested_skill` before dedup** — if non-null, escalate to the user per `interruption-recovery.md` §Session Recovery step 2; do not auto-re-invoke. All `in_progress` tasks are treated as orphaned — the previous session's agents are gone. Dispatch a **work-verifier** agent (see `~/.cursor/agents/work-verifier.md`) per in-progress task to determine actual completion status. Run Phase 2.5 preflight if environment may have changed, then skip to Phase 3 (Dispatch Loop). Recreate TodoWrite display from state file via `TodoWrite(merge=false)`. For full recovery procedure, see Interruption Handling → Session Recovery. |",
)

# ---------------------------------------------------------------------------
# PATCH 8 — Input table: status row
# ---------------------------------------------------------------------------
rep(
    "| `status` | Read the state file. For any `in_progress` tasks, dispatch a **work-verifier** agent with orphan detection enabled. Display the dashboard (see Status Dashboard), stop. |",
    '| `status` | Read the state file. For any `in_progress` tasks, dispatch a **work-verifier** agent (see `~/.cursor/agents/work-verifier.md`) via `Task(subagent_type="generalPurpose")` with orphan detection enabled. Display the dashboard (see Status Dashboard), stop. |',
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
    "**Spec clarity evaluation (default path, skip when Brainstorm Gate is active):** If clear, dispatch planner directly. If vague/ambiguous, dispatch **interviewer** first. If user says \"just plan it\", dispatch planner regardless.\n\n**Architect dispatch (optional, default path only):** Dispatch an **architect** agent before the planner when the spec involves new subsystems, significant technology choices, competing implementation strategies, or API/data model design. The architect produces an ADD the planner uses as input. Skip for well-understood work.\n\nIn **interactive mode**, prefer asking the user directly for simple ambiguities; use the interviewer for deep ambiguity (multiple unclear dimensions, conflicting requirements). In **autonomous mode**, dispatch the interviewer — the team manager cannot ask interactively.",
    "**Spec clarity evaluation (default path, skip when Brainstorm Gate is active):** Before dispatching the planner, assess whether the user's input is clear enough to plan from. If clear, dispatch planner directly. If vague or ambiguous, dispatch **interviewer** first. If the user says \"just plan it\", dispatch planner regardless.\n\nIn **interactive mode**, prefer asking the user directly for simple ambiguities; use the interviewer for deep ambiguity (multiple unclear dimensions, conflicting requirements). In **autonomous mode**, dispatch the interviewer — the team manager cannot ask interactively.\n\n**Architect dispatch (optional, default path only):** Dispatch an **architect** agent via `Task(subagent_type=\"architect\")` before the planner when the spec involves new subsystems, significant technology choices, competing implementation strategies, or API/data model design. The architect produces an ADD the planner uses as input. Skip for well-understood work.",
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

Task counts below use the 2-5 minute granularity standard (per `agents/planner.md` — Task Granularity Standard).

| Tier | Criteria | Action | Cost |
| :--- | :--- | :--- | :--- |
| **Tier 1 — Skip** | 1-3 tasks of finer granularity, no architectural decisions, mechanical/trivial changes | Proceed directly to Phase 1.5. | None |
| **Tier 2 — Scope only** | 4-8 tasks, OR clear scope but needs estimates/gap analysis, OR medium signals | Dispatch **project-scoper** to produce a scoping doc. Proceed to Phase 1.5 after scoping. | 1 opus agent |
| **Tier 3 — Scope + Critique** | >8 tasks, OR high-weight signal (architectural, security/risk), OR multiple medium signals | Dispatch **project-scoper** then **critic** to review combined plan + scoping doc. | 2 opus agents |

**Display the tier decision:**

Render this tier-decision block as plain Markdown, not inside a fence. Output the lines directly into chat so the UI renders them as formatted text.

**Plan Validation: Tier [N] — [Skip / Scope only / Scope + Critique]**
**Signals:** [list which signals triggered, e.g., "6 impl tasks (high), new agent architecture (high), security model (medium)"]
**Action:** [what will happen — "Proceeding to task board" / "Dispatching project-scoper" / "Dispatching project-scoper → critic"]

> **Reference:** You MUST Read `~/.claude/skills/ops/plan-validation.md` for spec clarity evaluation criteria, plan complexity scoring signals, critic verdict handling, scoper/critic output descriptions, execute-skip detection, mode-specific behavior, and adaptation rules. If the file is missing, proceed using the tier table and display format above.""",
    """**Also skip when:** `resume`, `status`, or user says "just do it" / "skip validation".

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
    "Dispatch a **preflight** agent (see `~/.claude/agents/preflight.md`).",
    'Dispatch a **preflight** agent (see `~/.cursor/agents/preflight.md`) via `Task(subagent_type="generalPurpose")`.',
)

# PATCH 21 — REMOVED: Phase 3 dispatch steps live in phase-dispatch.md (B1 companions).
# Cursor state sync ritual is in phase-dispatch.md § "Cursor: state file sync (mandatory)".
# Do not re-insert TodoWrite-only steps into SKILL.cursor.md — they never applied here.

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
    """**Dispatch example:**

> **Code invocation example — keep fenced.** The block below is a code-style invocation example, not a user-facing UI output. Do not unfence it.

```
Agent(
  description: "Implement auth middleware",
  model: "sonnet",
  subagent_type: "executor",
  prompt: <self-read template + task brief>
)
UI renders: executor(Implement auth middleware)
```

DO NOT set `description: "executor(Implement auth middleware)"` when `subagent_type: "executor"` is set.
This produces `executor(executor(Implement auth middleware))` in the UI.

Use the brief format below.
3. For parallel batches, issue all Agent tool calls in a **single message** so they run concurrently.

**Dispatch Log Append (opt-in via `--dispatch-log`)** — when the `--dispatch-log` flag is set, append a one-line entry to `docs/ops-dispatch-log.md` after each dispatch (or direct-tool choice governed by the Subagent Dispatch Decision Framework), capturing kind, framework row, and short description. This applies universally when enabled: Phase 3 dispatch loop, Trivial Dispatch, Brainstorm Gate, Phase 1a scoper/critic, Phase 2.5 preflight, and every other agent dispatch. When the flag is not set, skip entirely — do not touch the log file. The log is persistent across runs and serves as the audit trail for framework adherence.

> **Reference:** You MUST Read `~/.claude/skills/ops/dispatch-log.md` for the file location, append procedure, entry format, kinds table, and audit usage. If the file is missing, proceed using the summary above. Read only when `--dispatch-log` is set.

**Foreground vs. Background Dispatch Policy**

Default is **foreground**. Use **background** (`run_in_background: true`) for tasks estimated at 8+ minutes when other tasks can advance concurrently. Adapt the threshold based on runtime conditions.

> **Reference:** You MUST Read `~/.claude/skills/ops/dispatch-policy.md` for the full foreground/background decision criteria, batch rules, and interaction with health monitoring and worktree isolation. If the file is missing, proceed using the summary above.""",
    """5. Spawn the agent via `Task(subagent_type="<agent_type>", prompt=<self-read prompt + brief>)` using the brief format below. For agents not in the Cursor built-in enum, use `Task(subagent_type="generalPurpose", prompt=<self-read prompt + brief>)`.
6. For parallel batches, issue all Task calls in a **single message** so they run concurrently.

**Dispatch Log Append (opt-in via `--dispatch-log`)** — when the `--dispatch-log` flag is set, append a one-line entry to `docs/ops-dispatch-log.md` after each dispatch (or direct-tool choice governed by the Subagent Dispatch Decision Framework), capturing kind, framework row, and short description. This applies universally when enabled: Phase 3 dispatch loop, Trivial Dispatch, Brainstorm Gate, Phase 1a scoper/critic, Phase 2.5 preflight, and every other agent dispatch. When the flag is not set, skip entirely — do not touch the log file. The log is persistent across runs and serves as the audit trail for framework adherence.

> **Reference:** You MUST Read `~/.cursor/skills/ops/dispatch-log.md` for the file location, append procedure, entry format, kinds table, and audit usage. If the file is missing, proceed using the summary above. Read only when `--dispatch-log` is set.""",
)

# ---------------------------------------------------------------------------
# PATCH 24 — Remove "After updating timing..." paragraph
# ---------------------------------------------------------------------------
rep(
    "After updating timing, check elapsed time of all in-progress background agents against their estimates. Emit a `⚠️ SLOW` warning when elapsed exceeds 1.5× estimate, or `🔴 OVERRUN` when elapsed exceeds 2.5× estimate. Warnings are emitted once per threshold crossing per task. For tasks with `estimate_source: \"ops\"` (rough estimates), suppress SLOW and emit OVERRUN only.\n\n| Outcome | Action |",
    "After updating timing, check elapsed time of all in-progress background agents against their estimates. Emit a `⚠️ SLOW` warning when elapsed exceeds 1.5× estimate, or `🔴 OVERRUN` when elapsed exceeds 2.5× estimate. Warnings are emitted once per threshold crossing per task. For tasks with `estimate_source: \"ops\"` (rough estimates), suppress SLOW and emit OVERRUN only.\n\n| Outcome | Action |",
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
# PATCH 29 — work-verifier orphan detection reference (replaces agent-health-monitoring.md)
# ---------------------------------------------------------------------------
rep(
    "Orphan detection is handled by the **work-verifier** agent (see `~/.claude/agents/work-verifier.md`), which includes timeout budgets per agent type and orphan detection heuristics.",
    "Orphan detection is handled by the **work-verifier** agent (see `~/.cursor/agents/work-verifier.md`), which includes timeout budgets per agent type and orphan detection heuristics.",
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
# PATCH 34 — timing-calibrator ref (replaces estimation-feedback.md)
# ---------------------------------------------------------------------------
rep(
    "   > **Reference:** Invoke the `/timing-calibrator capture` skill (see `~/.claude/skills/timing-calibrator/SKILL.md`) with the run's task metadata to persist timing patterns.",
    "   > **Reference:** Invoke the `/timing-calibrator capture` skill (see `~/.cursor/skills/timing-calibrator/SKILL.md`) with the run's task metadata to persist timing patterns.",
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
    "## Constraints (applies to team manager AND all spawned agents)\n\n### Bash rules\n\nThe Shared Brief Constraints block (see `#shared-brief-constraints` above) defines the canonical bash rules \u2014 no compound commands, no `cd` prefix, relative paths only, `_tmp_` prefix. These apply to the team manager AND all spawned agents.\n\n### Team manager tool restrictions\n\n**Delegate-first:** always dispatch an agent or invoke a skill before using a tool directly. Only use tools directly for reading state or displaying information.\n\n> **Reference:** You MUST Read `~/.claude/skills/ops/tool-restrictions.md` for the full delegate-first table, permitted direct actions, self-check rules, and the subagent dispatch decision framework. If the file is missing, proceed using the delegate-first principle above.",
    "## Constraints (applies to team manager AND all spawned agents)\n\n### Team manager tool restrictions\n\n**Delegate-first:** always dispatch an agent or invoke a skill before using a tool directly. Only use tools directly for reading state or displaying information.\n\n> **Reference:** You MUST Read `~/.cursor/skills/ops/tool-restrictions.md` for the full delegate-first table, permitted direct actions, self-check rules, and the subagent dispatch decision framework. If the file is missing, proceed using the delegate-first principle above.\n\n### Shell rules\n\nThe Shared Brief Constraints block (see `#shared-brief-constraints` above) defines the canonical Shell rules \u2014 no compound commands, no `cd` prefix, relative paths only, `_tmp_` prefix. These apply to the team manager AND all spawned agents.",
)

# ---------------------------------------------------------------------------
# PATCH 38 — Handoff Chains: reorder + annotate code blocks
# ---------------------------------------------------------------------------
rep(
    """Pre-planning chain (optional, for work requiring design exploration):

```
interviewer → architect → planner → project-scoper → critic → executor → ...
```

With `--brainstorm`, treat this as a strict gate:

```
interviewer → architect → user approval checkpoint → planner
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

> **Reference:** The **ssh-executor** agent (see `~/.claude/agents/ssh-executor.md`) handles its own preflight checks (host validation, connectivity, key, source files, remote directory) and includes SSH-specific handoff fields in its output format. No separate preflight dispatch is needed for SSH tasks.""",
    """Pre-planning chain (optional, for work requiring design exploration):

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

Security-reviewer is optional — dispatched for security-sensitive patterns (auth, secrets, API keys, encryption, external inputs).

When a chain has multiple implementation tasks, parallelize then converge:

```text
executor(task1) ──┐
executor(task2) ──┤→ verifier(all) → [security-reviewer] → deslop(all) → code-reviewer(all) → documentor(all)
executor(task3) ──┘
```

> **Reference:** The **ssh-executor** agent (see `~/.cursor/agents/ssh-executor.md`) handles its own preflight checks (host validation, connectivity, key, source files, remote directory) and includes SSH-specific handoff fields in its output format. No separate preflight dispatch is needed for SSH tasks.""",
)

# ---------------------------------------------------------------------------
# PATCH 39 — Verify→Fix Loop: ``` → ```text
# ---------------------------------------------------------------------------
rep(
    "## Verify → Fix Loop\n\n> **ASCII flow diagram — keep fenced.** The blocks below are loop diagrams for reference, not user-facing UI output. Do not unfence them.\n\n```\nexecutor → verifier → [FAIL] → executor (fix) → verifier (re-verify) → [PASS] → code-reviewer\n                                     ↑                    |\n                                     └────── [FAIL] ──────┘\n```",
    "## Verify → Fix Loop\n\n> **ASCII flow diagram — keep fenced.** The blocks below are loop diagrams for reference, not user-facing UI output. Do not unfence them.\n\n```text\nexecutor → verifier → [FAIL] → executor (fix) → verifier (re-verify) → [PASS] → code-reviewer\n                                     ↑                    |\n                                     └────── [FAIL] ──────┘\n```",
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
# PATCH 44 — rollback agent ref (replaces rollback-strategy.md)
# ---------------------------------------------------------------------------
rep(
    "> **Reference:** When rollback is needed, dispatch a **rollback** agent (see `~/.claude/agents/rollback.md`) with the affected file list, scope level, and run ID.",
    "> **Reference:** When rollback is needed, dispatch a **rollback** agent (see `~/.cursor/agents/rollback.md`) via `Task(subagent_type=\"generalPurpose\")` with the affected file list, scope level, and run ID.",
)

# ---------------------------------------------------------------------------
# PATCH 45 — Status Dashboard: ``` → ```text + remove health indicators
# ---------------------------------------------------------------------------
rep(
    "## Team Manager — Status\n\n### Active\n- <agent> → Task #N: \"<subject>\" (in_progress, Xs elapsed) [health indicator]\n\nHealth indicators: ✓ ON TRACK (elapsed < 1.5× estimate), ⚠️ SLOW (1.5–2.5×), 🔴 OVERRUN (> 2.5×), 👻 ORPHAN? (elapsed > agent-type timeout, no completion received)",
    "## Team Manager — Status\n\n### Active\n- <agent> → Task #N: \"<subject>\" (in_progress, Xs elapsed)",
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
    "### Model escalation\n\n> **Algorithm steps — keep fenced.** The block below is a reference enumeration for internal logic, not a user-facing UI output. Do not unfence it.\n\n```\n1st attempt: assigned model (from frontmatter)\n2nd attempt: same model, with error context and narrowed scope\n3rd attempt: escalate model (sonnet → opus), with full error history\n4th attempt: escalate to user\n```\n\n> **Reference:** The **rollback** agent (see `~/.claude/agents/rollback.md`) handles the rollback procedure. See Failure Handling above for dispatch details.",
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
    "### Learning across runs\n\nUses the memory system (`~/.claude/projects/<project>/memory/`). Check memory at run start, apply as soft defaults, log when applied.\n\n> **Reference:** The `/timing-calibrator` skill (see `~/.claude/skills/timing-calibrator/SKILL.md`) manages estimation calibration, model escalation patterns, and cross-run learning. Invoke `/timing-calibrator read` at run start and `/timing-calibrator capture` at completion.\n\n### Adaptation log",
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
- **TodoWrite limitations** — TodoWrite items only have `id`, `content`, and `status` fields. All rich metadata (dependencies, timing, estimates) lives in the state file on disk.
- **TodoWrite drift** — Models often update TodoWrite without writing `.ops-state/<run-id>-board.json`. The board file is mandatory on every status change; see `phase-dispatch.md` § **Cursor: state file sync (mandatory)**.""",
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
PYEOF
}

run_python "$FORCE"
code=$?

# ---------------------------------------------------------------------------
# Wrapper drift-check prompt: on exit 3 with stdin tty, offer regeneration.
# Non-tty stdin → propagate 3 (CI-friendly).
# ---------------------------------------------------------------------------
if [ "$code" -eq 3 ] && [ "$FORCE" != "true" ]; then
    if [ -t 0 ]; then
        printf "Regenerate %s? [y/N]: " "$OUT_PATH" >&2
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                run_python "true"
                code=$?
                ;;
            *)
                echo "Aborted — no changes written." >&2
                code=4
                ;;
        esac
    fi
fi

exit $code
