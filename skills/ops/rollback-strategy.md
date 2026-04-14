<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Rollback Strategy

This document defines when and how the `/ops` skill rolls back changes after chain failures, user cancellations, or scope issues. It is a companion to `SKILL.md`.

---

## 1. When Rollback is Needed

- **3x task failure escalation** — the executor made changes that don't pass verification after three attempts. The working tree contains partial or broken changes.
- **User cancels mid-chain** — partial changes from completed tasks remain and may need reverting depending on user intent.
- **Scope issue discovered** — the approach is fundamentally wrong (e.g., planner or critic flags a design problem mid-run). All changes from the current run should be undone before replanning.
- **Conflicting parallel agent changes** — two worktree agents modified overlapping files and their changes cannot be cleanly reconciled.

---

## 2. Rollback Scope Levels

| Level | When | Method |
|-------|------|--------|
| **Single task** | One task failed, others in the chain are fine | `git checkout -- <files>` for the specific files that task modified |
| **Task chain** | Entire chain failed (executor + its verifier retries) | Revert all files modified by tasks in the chain |
| **Full run** | User cancels or scope is fundamentally wrong | `git stash` all uncommitted changes from the run |
| **Worktree** | Worktree agent produced bad changes | Delete the worktree branch — changes never merged |

---

## 3. Rollback Methods

### For uncommitted changes (most common)

- Identify files modified by the failed task(s) using `git diff --name-only`
- `git checkout -- <file1> <file2> ...` to restore to last committed state
- If changes were staged: `git restore --staged <files>` first, then checkout

### For committed changes (rare — only if agents committed during the run)

- `git revert <commit-hash>` for specific commits
- Never use `git reset --hard` without explicit user approval

### For worktree isolation

- Simply delete the worktree: the changes are on an isolated branch
- No merge = no damage to the main working tree

### For stashed changes

- `git stash push -m "ops-rollback: <run_id>"` to preserve changes in case the user wants them later
- Stash before checkout so nothing is permanently lost

---

## 4. Rollback Procedure (Step by Step)

1. Identify the rollback scope (single task, chain, or full run)
2. List all files modified by the affected task(s) — read from task metadata or handoff docs
3. Check if any of those files were also modified by successful tasks (overlap check)
4. If overlap exists: warn user, do NOT auto-rollback — require manual decision
5. If no overlap: stash the changes first (`git stash push -m "ops-rollback: <run_id>"`)
6. Then restore: `git checkout -- <files>`
7. Log the rollback in the dashboard: "Rolled back task #N: reverted changes to [files]"
8. Update task status to reflect the rollback

---

## 5. Guardrails

- NEVER rollback committed changes without explicit user approval
- NEVER rollback changes from tasks that are NOT in the failed chain
- ALWAYS stash before checkout — preserves changes in case the user wants to recover them
- ALWAYS check for file overlap between failed and successful tasks before rolling back
- If the user has uncommitted changes that predate the run, do NOT touch those files
- On `--worktree` runs, rollback is trivial: just don't merge the worktree branch

---

## 6. Interaction with Other Features

- **Resume**: after rollback, the task can be re-dispatched with a clean slate
- **Worktrees**: rollback is automatic — failed worktree branches are simply abandoned
- **Handoff docs**: rollback should update the handoff to note the rollback occurred
- **Estimation feedback**: rolled-back tasks should still count toward timing data (the time was spent, even if the work was reverted)

---

## 7. When NOT to Rollback

- User explicitly says "keep the changes, I'll fix it manually"
- Changes are partially correct and the user wants to build on them
- The failure is in verification (test setup), not in the code itself
- Documentation-only changes — these are never risky enough to warrant rollback
