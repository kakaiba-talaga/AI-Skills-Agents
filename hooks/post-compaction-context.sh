#!/bin/bash
# post-compaction-context.sh
# Re-injects critical context after Claude Code compacts the conversation.
# Called by a SessionStart hook with compact matcher in ~/.claude/settings.json.
# Everything written to stdout is injected into Claude's context.

echo "=== Post-Compaction Context ==="

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
        echo ""
        echo "## Active Ops Runs"
        for board in $BOARD_FILES; do
            python -c "
import json, sys
try:
    with open('$board') as f:
        data = json.load(f)
    run_id   = data.get('run_id', 'unknown')
    plan     = data.get('plan_file', 'unknown')
    tasks    = data.get('tasks', [])
    print(f'Run: {run_id}  |  Plan: {plan}')
    for t in tasks:
        tid    = t.get('id', '?')
        subj   = t.get('subject', t.get('title', '?'))
        status = t.get('status', '?')
        agent  = t.get('agent_type', t.get('agent', '?'))
        print(f'  [{tid}] {subj} — {status} ({agent})')
except Exception as e:
    sys.exit(0)
" 2>/dev/null
        done
    fi
fi

# ---------------------------------------------------------------------------
# 3. Active Ralph Loop State
# ---------------------------------------------------------------------------
if [ -d ".ralph-state" ]; then
    RALPH_FILES=$(find .ralph-state -maxdepth 1 -name "*.json" -type f 2>/dev/null)
    if [ -n "$RALPH_FILES" ]; then
        echo ""
        echo "## Active Ralph Loop"
        for state_file in $RALPH_FILES; do
            python -c "
import json, sys
try:
    with open('$state_file') as f:
        data = json.load(f)
    print(json.dumps(data, indent=2))
except Exception:
    sys.exit(0)
" 2>/dev/null
        done
    fi
fi

# ---------------------------------------------------------------------------
# 4. Recently Modified Files (last 60 minutes)
# ---------------------------------------------------------------------------
RECENT=$(find . -maxdepth 3 -type f -mmin -60 \
    -not -path "./.git/*" \
    -not -path "./node_modules/*" \
    -not -path "./.ops-state/*" \
    -not -path "./.ralph-state/*" \
    2>/dev/null)

if [ -n "$RECENT" ]; then
    echo ""
    echo "## Recently Modified Files"
    echo "$RECENT"
fi
