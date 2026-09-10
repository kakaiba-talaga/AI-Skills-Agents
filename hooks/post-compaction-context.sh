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
# Interpreter resolution (shared by sections 2 and 3)
# ---------------------------------------------------------------------------
# Resolved once so each section below spawns a single process instead of one
# per state file. A name resolving on PATH is not proof it runs: on some
# machines python3 resolves to a stub that exits non-zero instead of
# executing anything, so each candidate is probed once before being trusted,
# and its output is discarded either way. python is tried first because it
# avoids spawning that known stub; python3 is kept as the fallback for
# platforms (WSL among them) where python is absent from PATH entirely, in
# which case the failed lookup costs nothing and resolution falls through to
# python3 as before. Trying python first also means an older Python 2 could
# be first in line, so the probe asserts the major version instead of just
# running a no-op, to reject that case rather than silently trusting it.
# Left empty, and skipped by the guards below, if no candidate actually runs.
PYTHON_BIN=""
for candidate in python python3; do
    resolved=$(command -v "$candidate" 2>/dev/null)
    if [ -n "$resolved" ] && "$resolved" -c "import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)" >/dev/null 2>&1; then
        PYTHON_BIN="$resolved"
        break
    fi
done

# ---------------------------------------------------------------------------
# 2. Active Ops Runs
# ---------------------------------------------------------------------------
# A board file older than this many days is left out of the report below.
OPS_STALE_DAYS=14

if [ -d ".ops-state" ] && [ -n "$PYTHON_BIN" ]; then
    "$PYTHON_BIN" -c "
import glob, json, os, sys, time

ops_dir = sys.argv[1]
stale_days = float(sys.argv[2])
cutoff = time.time() - stale_days * 86400
terminal = {'completed', 'failed', 'blocked', 'deleted', 'cancelled'}
lines = []

for path in sorted(glob.glob(os.path.join(ops_dir, '*-board.json'))):
    if not os.path.isfile(path):
        continue
    # A board with every task in a terminal status (completed, failed,
    # blocked, deleted, cancelled) is a finished run, not an active one.
    # Skip it entirely rather than printing a heading over dead work.
    # A malformed board, or one older than the window above, is skipped
    # the same way, so one bad or stale file cannot take the section down.
    try:
        if os.path.getmtime(path) < cutoff:
            continue
        with open(path, encoding='utf-8', errors='replace') as f:
            data = json.load(f)
        run_id = data.get('run_id', 'unknown')
        plan = data.get('plan_file', 'unknown')
        tasks = data.get('tasks', [])
        if not any(t.get('status') not in terminal for t in tasks):
            continue
        lines.append(f'Run: {run_id}  |  Plan: {plan}')
        for t in tasks:
            tid = t.get('id', '?')
            subj = t.get('subject', t.get('title', '?'))
            status = t.get('status', '?')
            agent = t.get('agent_type', t.get('agent', '?'))
            lines.append(f'  [{tid}] {subj} - {status} ({agent})')
    except Exception:
        continue

if lines:
    out = '\n## Active Ops Runs\n' + '\n'.join(lines) + '\n'
    sys.stdout.buffer.write(out.encode('utf-8', 'replace'))
" ".ops-state" "$OPS_STALE_DAYS" 2>/dev/null
fi

# ---------------------------------------------------------------------------
# 3. Active Ralph Loop State
# ---------------------------------------------------------------------------
if [ -d ".ralph-state" ] && [ -n "$PYTHON_BIN" ]; then
    "$PYTHON_BIN" -c "
import glob, json, os, sys

ralph_dir = sys.argv[1]
lines = []

for path in sorted(glob.glob(os.path.join(ralph_dir, '*.json'))):
    if not os.path.isfile(path):
        continue
    # 'done' is the only terminal ralph status; 'paused' and 'blocked' are
    # live state waiting to be resumed and must keep printing. A malformed
    # state file is skipped the same way a done one is, so one bad file
    # cannot take the section down. Summarize instead of dumping the full
    # state object, which is what made this section unreadably large.
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            data = json.load(f)
        status = data.get('status', '?')
        if status == 'done':
            continue
        task_id = data.get('task_id', 'unknown')
        title = data.get('title', 'unknown')
        iteration = data.get('iteration', '?')
        achieved = data.get('progress', {}).get('achieved_percent', '?')
        lines.append(f'[{task_id}] {title} - {status} (iteration {iteration}, {achieved}% achieved)')
    except Exception:
        continue

if lines:
    out = '\n## Active Ralph Loop\n' + '\n'.join(lines) + '\n'
    sys.stdout.buffer.write(out.encode('utf-8', 'replace'))
" ".ralph-state" 2>/dev/null
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

# This hook is advisory context injection; a non-zero exit surfaces to the user as a hook error.
exit 0
