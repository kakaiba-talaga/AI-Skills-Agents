#!/usr/bin/env bash
#
# Transform skills/ralph-loop/SKILL.md into the Cursor-compatible SKILL.cursor.md.
#
# Default behavior: drift-check. If the target SKILL.cursor.md already exists
# and matches what this transform would produce, print "in sync" and exit 0.
# If the target differs, print a drift summary and prompt for regeneration
# (when stdin is a tty) or exit 3 (when stdin is not a tty — CI-friendly).
#
# Usage:
#   ./tooling/transform-cursor-ralph-loop.sh [options]
#
# Options:
#   -i, --in  <path>    Source SKILL.md (default: skills/ralph-loop/SKILL.md)
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
#   ./tooling/transform-cursor-ralph-loop.sh              # drift-check, prompt on drift
#   ./tooling/transform-cursor-ralph-loop.sh -f           # force regenerate
#   ./tooling/transform-cursor-ralph-loop.sh -w           # preview SHA + line count
#   ./tooling/transform-cursor-ralph-loop.sh -o -         # emit to stdout

set -uo pipefail

IN_PATH="skills/ralph-loop/SKILL.md"
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
# PATCH 0 — Prepend YAML frontmatter
# ---------------------------------------------------------------------------
first_line = text.split("\n")[0]
rep(first_line, "---\nname: ralph-loop\ndescription: Run the Ralph Wiggum loop workflow.\n---\n" + first_line)

# ---------------------------------------------------------------------------
# PATCH 1 — /deslop slash-invocation adjusted for Cursor (no Skill tool)
# ---------------------------------------------------------------------------
rep(
    "- `--full-deslop` forces the full `/deslop` skill to run during every Cleanup stage iteration, regardless of escalation triggers. Use when you want comprehensive structural cleanup every iteration, not just when triggers fire.",
    "- `--full-deslop` forces the full deslop pass to run during every Cleanup stage iteration, regardless of escalation triggers. Use when you want comprehensive structural cleanup every iteration, not just when triggers fire. On Cursor: invoked via read-and-dispatch of `~/.cursor/skills/deslop/SKILL.md`.",
)

# ---------------------------------------------------------------------------
# PATCH 2 — Constraints bullet: "No compound Bash commands" → "No compound Shell commands"
# (both Bash occurrences in this bullet line)
# ---------------------------------------------------------------------------
rep(
    "- No compound Bash commands — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls instead — use parallel calls for independent commands.",
    "- No compound Shell commands — never use `&&`, `;`, or `||` to chain commands. Make separate Shell tool calls instead — use parallel calls for independent commands.",
)

# ---------------------------------------------------------------------------
# PATCH 3 — Constraints bullet: "use a separate Bash call for cd" → "use a separate Shell call for cd"
# ---------------------------------------------------------------------------
rep(
    "If a command genuinely requires a different working directory, use a separate Bash call for `cd` first.",
    "If a command genuinely requires a different working directory, use a separate Shell call for `cd` first.",
)

# ---------------------------------------------------------------------------
# PATCH 4 — Constraints bullet: "absolute paths in Bash commands" → "absolute paths in Shell commands"
# ---------------------------------------------------------------------------
rep(
    "never use absolute paths in Bash commands.",
    "never use absolute paths in Shell commands.",
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
