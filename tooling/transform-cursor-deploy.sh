#!/usr/bin/env bash
#
# Transform skills/deploy/SKILL.md into the Cursor-compatible SKILL.cursor.md.
#
# Default behavior: drift-check. If the target SKILL.cursor.md already exists
# and matches what this transform would produce, print "in sync" and exit 0.
# If the target differs, print a drift summary and prompt for regeneration
# (when stdin is a tty) or exit 3 (when stdin is not a tty — CI-friendly).
#
# Usage:
#   ./tooling/transform-cursor-deploy.sh [options]
#
# Options:
#   -i, --in  <path>    Source SKILL.md (default: skills/deploy/SKILL.md)
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
#   ./tooling/transform-cursor-deploy.sh              # drift-check, prompt on drift
#   ./tooling/transform-cursor-deploy.sh -f           # force regenerate
#   ./tooling/transform-cursor-deploy.sh -w           # preview SHA + line count
#   ./tooling/transform-cursor-deploy.sh -o -         # emit to stdout

set -uo pipefail

IN_PATH="skills/deploy/SKILL.md"
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
# PATCH 1 — Prepend YAML frontmatter
# ---------------------------------------------------------------------------
first_line = text.split("\n")[0]
rep(first_line, "---\nname: deploy\ndescription: Orchestrate deployments to remote servers via ssh-executor.\n---\n" + first_line)

# ---------------------------------------------------------------------------
# PATCH 2 — Remove /deploy slash reference in argument-parsing prose
# ---------------------------------------------------------------------------
rep(
    "Free-form text after `/deploy` is the deployment description",
    "Free-form text is the deployment description",
)

# ---------------------------------------------------------------------------
# PATCH 3 — Replace the multi-line ssh-executor Dispatch Procedure block with
# the Task-tool one-liner (must precede global ~/.claude/ substitution so the
# ~/.claude/agents/ssh-executor.md reference is deleted, not translated)
# ---------------------------------------------------------------------------
rep(
    "Dispatch the ssh-executor via the Agent tool. The Agent tool's `subagent_type` parameter does not accept custom agent types — `ssh-executor` is not a built-in type. You must read the agent file and include its instructions in the prompt.\n\n**Memory-injection predicate and selector (Lever 1 / Lever 2).**\n\nBefore constructing the prompt, evaluate the memory-injection predicate. The canonical procedure lives in `skills/ops/SKILL.md` Phase 3 Step 3 — follow it verbatim for the full predicate decision tree, `MECHANICAL_AGENTS` list, override flag behavior, sentinel marker detection, and selector call shape. Key points for this dispatch:\n\n- `ssh-executor` is **not** in `MECHANICAL_AGENTS` — default behavior is **inject**.\n- The override flag `--memory-inject=off|auto|always` is honored. `auto` is the default.\n- If the selector (see `skills/cross-memory/brief-injector.md`) returns non-empty bytes, render them as the `## Project Knowledge` section and prepend it to the prompt **before** the inlined ssh-executor body — the agent sees the project knowledge block first, then its own instructions.\n- If the selector returns empty bytes, omit `## Project Knowledge` and proceed with the prompt as constructed below.\n\n**ssh-executor Dispatch Procedure** (applies to ALL ssh-executor dispatches in this skill — deployment, rollback, state-check, and monitoring):\n\n1. **Read** `~/.claude/agents/ssh-executor.md`. Extract the `model` from YAML frontmatter and the full instruction body (everything after the closing `---`).\n2. **`description`**: Set to `\"ssh-executor(<target_host>: <action>)\"` — e.g., `\"ssh-executor(prod-web-01: deploy v1.4.2)\"` or `\"ssh-executor(prod-web-01: rollback)\"`. Always include the host and action so the user can identify which dispatch targets which server.\n3. **`model`**: Set from the agent's frontmatter `model` field.\n4. **`subagent_type`**: **Omit** — `ssh-executor` is not a built-in type.\n5. **`prompt`**: Concatenate the `## Project Knowledge` block (if the selector returned non-empty bytes) + `\\n\\n` + the agent definition body + `\\n\\n---\\n\\n` + the deployment brief (JSON). The agent has no conversation history — the prompt must be fully self-contained.\n\nThe dispatch pattern depends on the deployment pattern selected in Phase 1.",
    "**Memory-injection predicate and selector (Lever 1 / Lever 2).**\n\nBefore constructing the prompt, evaluate the memory-injection predicate. The canonical procedure lives in `skills/ops/SKILL.cursor.md` Phase 3 Step 3 — follow it verbatim for the full predicate decision tree, `MECHANICAL_AGENTS` list, override flag behavior, sentinel marker detection, and selector call shape. Key points for this dispatch:\n\n- `ssh-executor` is **not** in `MECHANICAL_AGENTS` — default behavior is **inject**.\n- The override flag `--memory-inject=off|auto|always` is honored. `auto` is the default.\n- If the selector (see `skills/cross-memory/brief-injector.md`) returns non-empty bytes, render them as the `## Project Knowledge` section and prepend it to the prompt **before** the ssh-executor brief body — the agent sees the project knowledge block first, then its own instructions.\n- If the selector returns empty bytes, omit `## Project Knowledge` and proceed with the prompt as constructed below.\n\nDispatch the ssh-executor via the Task tool with `subagent_type: \"ssh-executor\"`. Pass the brief as the task prompt. The dispatch pattern depends on the deployment pattern selected in Phase 1.",
)

# ---------------------------------------------------------------------------
# PATCH 4 — Core Concept paragraph: Agent tool -> Task tool
# ---------------------------------------------------------------------------
rep(
    "dispatch it via the Agent tool, interpret its responses",
    "dispatch it via the Task tool, interpret its responses",
)

# ---------------------------------------------------------------------------
# PATCH 5 — JSON config-file shape: replace placeholders with empty containers
# ---------------------------------------------------------------------------
rep(
    '  "commands": [...],\n  "rollback_commands": {...},\n  "health_check": {...},\n  "sudo_authorization": ["stop_service", "start_service"],\n  "pre_hooks": [...],\n  "pre_hook_rollback": {...},\n  "post_hooks": [...]',
    '  "commands": [],\n  "rollback_commands": {},\n  "health_check": {},\n  "sudo_authorization": ["stop_service", "start_service"],\n  "pre_hooks": [],\n  "pre_hook_rollback": {},\n  "post_hooks": []',
)

# ---------------------------------------------------------------------------
# PATCH 6 — Simple-push bullet: Agent tool call -> explicit Task(...) call
# ---------------------------------------------------------------------------
rep(
    "Make a single Agent tool call to ssh-executor with the brief.",
    "Make a single `Task(subagent_type=\"ssh-executor\", prompt=<brief>)` call.",
)

# ---------------------------------------------------------------------------
# PATCH 7 — Rolling bullet: Agent tool call -> explicit Task(...) call
# ---------------------------------------------------------------------------
rep(
    "Dispatch the first host's brief via Agent tool call.",
    "Dispatch the first host's brief via `Task(subagent_type=\"ssh-executor\", prompt=<brief>)`.",
)

# ---------------------------------------------------------------------------
# PATCH 8 — Rollback step 6: Agent tool -> explicit Task(...) call
# ---------------------------------------------------------------------------
rep(
    "Dispatch the rollback ssh-executor via the Agent tool.",
    "Dispatch the rollback ssh-executor via `Task(subagent_type=\"ssh-executor\", prompt=<rollback brief>)`.",
)

# ---------------------------------------------------------------------------
# PATCH 9 — Opening fence for single-host report code block: add text language tag
# ---------------------------------------------------------------------------
rep(
    "```\n## Deploy Result",
    "```text\n## Deploy Result",
)

# ---------------------------------------------------------------------------
# PATCH 10 — Parallel-dispatch sentence: insert explicit Task(...) directive
# ---------------------------------------------------------------------------
rep(
    "multiple ssh-executor dispatches can run simultaneously when hosts are independent. Never dispatch two ssh-executors targeting the same host in parallel.",
    "multiple ssh-executor dispatches can run simultaneously when hosts are independent. Issue multiple `Task(subagent_type=\"ssh-executor\")` calls in a single message to dispatch in parallel. Never dispatch two ssh-executors targeting the same host in parallel.",
)

# ---------------------------------------------------------------------------
# PATCH 11 — Ops Integration section: replace entire block
# ---------------------------------------------------------------------------
rep(
    "**When invoked from `/ops`:**\n- The team manager dispatches the deploy skill as part of a larger workflow and manages the task board.\n- The deploy skill constructs briefs, dispatches ssh-executors via the Agent tool, handles rollback, and reports results back to the team manager.\n- The deploy skill does not manage the task board — that is the team manager's responsibility.\n- Report completion back to the team manager with: deployment status, per-host summary, rollback status (if applicable), total duration.\n- When ops invokes deploy as a task, the deploy skill's Phase 7 report becomes the task's output. The team manager reads this output to update the task board and determine whether to proceed to the next stage.\n\n**When invoked standalone (direct `/deploy` invocation):**\n- The deploy skill handles its own dispatch loop via the Agent tool.\n- It manages its own rollback decisions and reporting directly to the user.\n- No task board. Progress is communicated through inline status updates and the Phase 7 report.\n\n**Badge behavior under ops:**\nWhen `/ops` invokes `/deploy`, the **`Deploy`** badge appears on turns where the deploy skill is actively doing work (constructing the brief, dispatching, reporting results). When the deploy skill finishes and control returns to `/ops`, the **`Team Manager`** badge resumes. This is expected — the badge reflects the currently active skill context, not the outermost caller.",
    "**When invoked from ops:**\n- The ops skill dispatches the deploy skill as part of a larger workflow and manages the task board.\n- The deploy skill constructs briefs, dispatches ssh-executors via the Task tool, handles rollback, and reports results back to ops.\n- The deploy skill does not manage the task board — that is ops's responsibility.\n- Report completion back to ops with: deployment status, per-host summary, rollback status (if applicable), total duration.\n\n**When invoked standalone:**\n- The deploy skill handles its own dispatch loop via the Task tool.\n- It manages its own rollback decisions and reporting directly to the user.\n- Progress is communicated through inline status updates and the Phase 7 report.",
)

# ---------------------------------------------------------------------------
# PATCH 12 — Constraints bullet: Bash -> Shell
# ---------------------------------------------------------------------------
rep(
    "No compound Bash commands — never use `&&`, `;`, or `||`. Make separate tool calls instead.",
    "No compound Shell commands — never use `&&`, `;`, or `||`. Make separate tool calls instead.",
)

# ---------------------------------------------------------------------------
# PATCH 13 — Deploy-specific bullet: Agent tool -> explicit Task tool description
# ---------------------------------------------------------------------------
rep(
    "**Never SSH directly** — always dispatch the ssh-executor via the Agent tool. Do not run `ssh` or `scp` commands yourself.",
    "**Never SSH directly** — always dispatch the ssh-executor via the Task tool with `subagent_type: \"ssh-executor\"`. Do not run `ssh` or `scp` commands yourself.",
)

# ---------------------------------------------------------------------------
# APPEND — Cursor-Specific Notes section (does not exist in SKILL.md)
# ---------------------------------------------------------------------------
text = text + "\n## Cursor-Specific Notes\n\n- The ssh-executor is dispatched via `Task(subagent_type=\"ssh-executor\", prompt=<brief>)`. Cursor's Task tool does not support custom model selection or tool restrictions for the dispatched agent.\n- For parallel dispatch (blue-green, independent hosts), issue multiple Task calls in a single message.\n- The `Task(run_in_background=true)` option is available for long-running deployments but is generally not needed since deployments are sequential and gated.\n"

# ---------------------------------------------------------------------------
# Global substitution: any remaining ~/.claude/ -> ~/.cursor/
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
