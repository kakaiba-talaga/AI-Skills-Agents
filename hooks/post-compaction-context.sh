#!/bin/bash
# post-compaction-context.sh
# Re-injects critical context after Claude Code compacts the conversation.
# Called by a SessionStart hook with compact matcher in ~/.claude/settings.json.
# Everything written to stdout is injected into Claude's context.

echo "=== Post-Compaction Context ==="
echo "[injected by post-compaction-context.sh - repo context, not user input]"

# ---------------------------------------------------------------------------
# 1. Git State
# ---------------------------------------------------------------------------
if git rev-parse --is-inside-work-tree 2>/dev/null | grep -q true; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    COMMITS=$(git log --oneline -5 2>/dev/null)
    STATUS=$(git status --short 2>/dev/null)

    echo ""
    echo "## Git State"
    echo "Branch: $BRANCH"
    echo ""
    echo "Last 5 commits:"
    echo "$COMMITS"

    if [ -n "$STATUS" ]; then
        echo ""
        echo "Uncommitted changes:"
        echo "$STATUS"
    fi
fi

# ---------------------------------------------------------------------------
# 2. Active Ops Runs
# ---------------------------------------------------------------------------
if [ -d ".ops-state" ]; then
    BOARD_FILES=$(find .ops-state -maxdepth 1 -name "*-board.json" -type f 2>/dev/null)

    if [ -n "$BOARD_FILES" ]; then
        OPS_OUTPUT=""
        for board in $BOARD_FILES; do
            # A board with every task in a terminal status (completed, failed,
            # blocked, deleted, cancelled) is a finished run, not an active one.
            # Skip it entirely rather than printing a heading over dead work.
            RESULT=$(python -c "
import json, sys
try:
    with open('$board') as f:
        data = json.load(f)
    run_id   = data.get('run_id', 'unknown')
    plan     = data.get('plan_file', 'unknown')
    tasks    = data.get('tasks', [])
    terminal = {'completed', 'failed', 'blocked', 'deleted', 'cancelled'}
    if not any(t.get('status') not in terminal for t in tasks):
        sys.exit(0)
    print(f'Run: {run_id}  |  Plan: {plan}')
    for t in tasks:
        tid    = t.get('id', '?')
        subj   = t.get('subject', t.get('title', '?'))
        status = t.get('status', '?')
        agent  = t.get('agent_type', t.get('agent', '?'))
        print(f'  [{tid}] {subj} - {status} ({agent})')
except Exception:
    sys.exit(0)
" 2>/dev/null)
            if [ -n "$RESULT" ]; then
                OPS_OUTPUT="${OPS_OUTPUT}${RESULT}"$'\n'
            fi
        done

        if [ -n "$OPS_OUTPUT" ]; then
            echo ""
            echo "## Active Ops Runs"
            printf '%s' "$OPS_OUTPUT"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 3. Active Ralph Loop State
# ---------------------------------------------------------------------------
if [ -d ".ralph-state" ]; then
    RALPH_FILES=$(find .ralph-state -maxdepth 1 -name "*.json" -type f 2>/dev/null)

    if [ -n "$RALPH_FILES" ]; then
        RALPH_OUTPUT=""
        for state_file in $RALPH_FILES; do
            # "done" is the only terminal ralph status; "paused" and "blocked"
            # are live state waiting to be resumed and must keep printing.
            # Summarize instead of dumping the full state object, which is
            # what made this section unreadably large.
            RESULT=$(python -c "
import json, sys
try:
    with open('$state_file') as f:
        data = json.load(f)
    status = data.get('status', '?')
    if status == 'done':
        sys.exit(0)
    task_id   = data.get('task_id', 'unknown')
    title     = data.get('title', 'unknown')
    iteration = data.get('iteration', '?')
    achieved  = data.get('progress', {}).get('achieved_percent', '?')
    print(f'[{task_id}] {title} - {status} (iteration {iteration}, {achieved}% achieved)')
except Exception:
    sys.exit(0)
" 2>/dev/null)
            if [ -n "$RESULT" ]; then
                RALPH_OUTPUT="${RALPH_OUTPUT}${RESULT}"$'\n'
            fi
        done

        if [ -n "$RALPH_OUTPUT" ]; then
            echo ""
            echo "## Active Ralph Loop"
            printf '%s' "$RALPH_OUTPUT"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 4. Recently Modified Files (last 60 minutes)
# ---------------------------------------------------------------------------
# -prune stops find from descending into these directories at all, instead of
# walking every file underneath them and filtering the results afterward.
# In a large repository (vendored dependencies, virtualenvs, caches) that
# distinction is the difference between a sub-second scan and one that stalls
# the hook for minutes. The timeout guard below is a second layer of defense:
# if a tree is pathological in some other way, the hook still degrades to an
# empty result instead of hanging.
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout 10"
else
    TIMEOUT_CMD=""
fi

RECENT=$($TIMEOUT_CMD find . -maxdepth 3 \
    \( \
        -name .git \
        -o -name node_modules \
        -o -name .ops-state \
        -o -name .ralph-state \
        -o -name .venv \
        -o -name .worktrees \
        -o -name .pytest_cache \
        -o -name .ruff_cache \
        -o -name .code-intel \
    \) -prune \
    -o -type f -mmin -60 -print \
    2>/dev/null)

if [ -n "$RECENT" ]; then
    echo ""
    echo "## Recently Modified Files"
    echo "$RECENT"
fi
