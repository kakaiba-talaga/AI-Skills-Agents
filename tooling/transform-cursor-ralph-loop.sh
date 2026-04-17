#!/usr/bin/env bash
#
# Transform skills/ralph-loop/SKILL.md into the Cursor-compatible SKILL.cursor.md.
#
# Usage:
#   ./tooling/transform-cursor-ralph-loop.sh [options]
#
# Options:
#   -i, --in  <path>    Source SKILL.md (default: skills/ralph-loop/SKILL.md)
#   -o, --out <path>    Output path, or "-" for stdout (default: -)
#   -f, --force         Overwrite output if it already exists
#   -w, --what-if       Preview only — print line count and SHA256
#   -h, --help          Show this help
#
# Examples:
#   ./tooling/transform-cursor-ralph-loop.sh -i skills/ralph-loop/SKILL.md -o _tmp_cursor-from-sh.md -f
#
# The checked-in SKILL.cursor.md is the drift baseline. Re-run this script and
# commit the output whenever SKILL.md is edited.

set -euo pipefail

IN_PATH="skills/ralph-loop/SKILL.md"
OUT_PATH="-"
FORCE=false
WHAT_IF=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--in)       IN_PATH="$2"; shift 2 ;;
        -o|--out)      OUT_PATH="$2"; shift 2 ;;
        -f|--force)    FORCE=true; shift ;;
        -w|--what-if)  WHAT_IF=true; shift ;;
        -h|--help)     head -20 "$0" | tail -18; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ ! -f "$IN_PATH" ]]; then
    echo "Error: Source file not found: $IN_PATH" >&2
    exit 1
fi

if [[ "$OUT_PATH" != "-" && -f "$OUT_PATH" && "$FORCE" != "true" ]]; then
    echo "Error: Output file already exists: $OUT_PATH. Use -f/--force to overwrite." >&2
    exit 1
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
# Run transform via embedded Python script
# ---------------------------------------------------------------------------
"$PYTHON" - "$IN_PATH" "$OUT_PATH" "$WHAT_IF" "$FORCE" <<'PYEOF'
import sys
import hashlib

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
# Output (LF — no CRLF conversion)
# ---------------------------------------------------------------------------
result = text
result_bytes = result.encode("utf-8")

line_count = result.count("\n") + (1 if result and not result.endswith("\n") else 0)
sha = hashlib.sha256(result_bytes).hexdigest()

if what_if:
    print(f"[WhatIf] Lines: {line_count} | SHA256: {sha}")
    sys.exit(0)

import os

if out_path == "-":
    sys.stdout.buffer.write(result_bytes)
else:
    if os.path.exists(out_path) and not force:
        print(f"Error: Output file already exists: {out_path}. Use -f/--force to overwrite.", file=sys.stderr)
        sys.exit(1)
    with open(out_path, "wb") as f:
        f.write(result_bytes)
    print(f"Written: {out_path}")
    print(f"SHA256:  {sha}")
    print(f"Lines:   {line_count}")
PYEOF
