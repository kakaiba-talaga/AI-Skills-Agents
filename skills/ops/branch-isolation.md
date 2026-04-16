<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Branch Isolation — Detailed Procedures

**3. Handle uncommitted changes (if branching):**

If there are uncommitted changes before branching:

- In **interactive** mode — show the changes and ask: stash, WIP commit, or include in the new branch.
- In **autonomous** mode — stash automatically with a descriptive message. Record the stash in the task board metadata for later recovery.

**4. Create the working branch (if needed):**

Delegate to the **git-master** agent (or use git directly) to create the branch. Follow the project's existing naming convention detected from `git log`:

- If Conventional Commits style: `feature/<task-description>`, `fix/<task-description>`, `chore/<task-description>`
- If no convention detected: `team/<short-task-description>`
- Base the branch on the current HEAD.

Record the branch name and base branch in task board metadata so `resume` knows which branch to switch to.

**5. After completion:**

When Phase 4 (Completion) finishes:

- If no branch was created, note which branch the work was committed to.
- If a working branch was created and the work has been committed to the target branch (e.g., via merge, cherry-pick, or direct commit), **delete the working branch** — it is stale once its commits are reachable from the target. Use `git branch -d <branch>` (safe delete, only works if fully merged).
- If the work is still only on the working branch, remind the user of the branch name and suggest next steps: create a PR (`gh pr create`), merge locally, or continue with more work.
- Do **not** auto-merge or auto-push — that requires explicit user action.

**Interaction with other features:**

- **`--worktree`** — worktree branches fork from the working branch (or current branch if no working branch was created), not the base branch.
- **Ralph loop** — ralph snapshot tags (`ralph/<task_id>/iter-<N>`) are branch-independent. No conflict.
- **Git-master pause/resume** — WIP commits and stashes happen on the working branch. Resuming restores to the same branch.
- **`resume` command** — checks task board metadata for the working branch name and switches to it before resuming dispatch.

## Git Worktree Isolation

When `--worktree` is set (or when parallel agents are likely to touch overlapping files), spawn agents with `isolation: "worktree"`. This gives each agent its own copy of the repo on an isolated branch, eliminating file conflicts entirely.

**When to use worktrees:**

- 2+ executor agents running in parallel on code that might share imports or config files
- Any parallel work where file independence is uncertain
- High-risk changes where you want easy rollback per agent

**Merge strategy:** After all worktree agents complete, their branches must be merged. Dispatch a **git-master** agent to merge branches sequentially, resolving conflicts if any. If conflicts exist, flag to the user before force-merging.

**When NOT to use worktrees:**

- Single-agent dispatch (no conflict risk)
- Read-only agents (verifier, code-reviewer running checks without edits)
- Tasks that intentionally modify the same files in sequence
