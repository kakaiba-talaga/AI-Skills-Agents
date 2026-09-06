#!/bin/bash
# security-pattern-warn.sh
# PostToolUse advisory hook — scans freshly edited files for high-signal
# dangerous patterns and emits a one-line reminder per match.
# NEVER blocks: exits 0 on every code path.
# Called by the PostToolUse hook in ~/.claude/settings.json.

TAG="[security-pattern-warn] advisory — not blocking:"

# ---------------------------------------------------------------------------
# Per-session dedup directory — keyed by <file>-<rule>
# Uses $PPID (the Claude Code process that invoked us) so the same
# session dir is shared across multiple hook invocations within one
# Claude Code session. Created lazily, only once we know there is a
# real file to scan — see below. If we cannot create it, dedup is
# silently skipped; we still exit 0.
# ---------------------------------------------------------------------------
SESSION_DIR="${TMPDIR:-/tmp}/security-pattern-warn-${PPID:-0}"

# ---------------------------------------------------------------------------
# Read stdin (the PostToolUse JSON event). Tolerate empty / malformed input.
# Extract the file path from tool_input.file_path or tool_input.path.
# ---------------------------------------------------------------------------
INPUT="$(cat 2>/dev/null)"
if [ -z "$INPUT" ]; then
    exit 0
fi

# Extract file path — try .tool_input.file_path then .tool_input.path
FILE_PATH=""
if command -v jq >/dev/null 2>&1; then
    FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"
else
    # Fallback: grep for common JSON key patterns (tolerant, not exhaustive)
    FILE_PATH="$(printf '%s' "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]+"' | head -1 | grep -oE '"[^"]+"$' | tr -d '"' 2>/dev/null)"
    if [ -z "$FILE_PATH" ]; then
        FILE_PATH="$(printf '%s' "$INPUT" | grep -oE '"path"\s*:\s*"[^"]+"' | head -1 | grep -oE '"[^"]+"$' | tr -d '"' 2>/dev/null)"
    fi
fi

# If we still have no file path, nothing to scan
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# File must exist and be readable
if [ ! -f "$FILE_PATH" ] || [ ! -r "$FILE_PATH" ]; then
    exit 0
fi

mkdir -p "$SESSION_DIR" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Rule set — small, high-signal, low false-positive
# Format: "RULE_KEY|GREP_PATTERN"
# ---------------------------------------------------------------------------
RULES=(
    "eval-call|eval\("
    "child-process-exec|child_process\.exec\("
    "subprocess-shell-true|shell=True"
    "pickle-loads|pickle\.loads\("
    "yaml-load-unsafe|yaml\.load\("
    "ssl-verify-false|verify=False"
    "hardcoded-password|^[[:space:]]*password[[:space:]]*=[[:space:]]*[\"']"
    "hardcoded-api-key|api_key[[:space:]]*=[[:space:]]*[\"']"
    "aws-access-key|AKIA[0-9A-Z]{16}"
)

# ---------------------------------------------------------------------------
# Combined pre-filter — one alternation grep covering every rule pattern,
# derived from RULES so the two never drift apart. On the common case
# (no rule matches) this replaces nine separate grep spawns with one. Only
# when it hits do we fall through to the per-rule loop, which decides
# exactly which rules matched and emits the same advisories as before.
# ---------------------------------------------------------------------------
PREFILTER=""
for entry in "${RULES[@]}"; do
    PATTERN="${entry#*|}"
    if [ -z "$PREFILTER" ]; then
        PREFILTER="$PATTERN"
    else
        PREFILTER="$PREFILTER|$PATTERN"
    fi
done

if grep -qE "$PREFILTER" "$FILE_PATH" 2>/dev/null; then
    # ---------------------------------------------------------------------
    # Scan the file against each rule; emit advisory on match (with dedup)
    # ---------------------------------------------------------------------
    for entry in "${RULES[@]}"; do
        RULE_KEY="${entry%%|*}"
        PATTERN="${entry#*|}"

        if grep -qE "$PATTERN" "$FILE_PATH" 2>/dev/null; then
            DEDUP_KEY="$(printf '%s--%s' "$FILE_PATH" "$RULE_KEY" | tr '/' '_' | tr '\\' '_' | tr ':' '_')"
            MARKER="$SESSION_DIR/$DEDUP_KEY"

            if [ ! -f "$MARKER" ]; then
                touch "$MARKER" 2>/dev/null || true
                echo "$TAG file=\"$FILE_PATH\" pattern=\"$RULE_KEY\""
            fi
        fi
    done
fi

exit 0
