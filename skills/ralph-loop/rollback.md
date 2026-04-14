<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Rollback/Undo Support

Each iteration's Reflect stage creates a git snapshot before proceeding to the next iteration.

**Snapshot creation (during Reflect, after state persist):**

Dispatch the **git-master** agent with the following brief: "Create a WIP commit for any uncommitted changes (message: `wip(ralph): iter-<N> snapshot for <task_id>`), then create a lightweight git tag `ralph/<task_id>/iter-<N>`. If the worktree is clean (nothing to commit), just create the tag. Report back: commit SHA (or 'clean'), tag name, and success/failure."

**Fallback:** If the git-master agent is unavailable (e.g., not in the agent registry, spawn fails, or the agent errors out), execute the steps directly via Bash:

1. **Commit uncommitted changes first.** Run `git status`. If there are staged or unstaged changes to tracked files, create a WIP commit: `git add -A` then `git commit -m "wip(ralph): iter-<N> snapshot for <task_id>"`. This ensures the tag captures the actual code state, not a stale prior commit. In headless mode, always auto-commit. In interactive mode, auto-commit without prompting (the tag is the rollback mechanism, not the commit).
2. **Check for dirty worktree.** If the commit failed (e.g., pre-commit hook rejected, unresolvable state), check whether the worktree is still dirty. If dirty, log a warning in `context.notes` ("Snapshot skipped: worktree dirty after commit attempt") and **skip tagging entirely** — a tag on a stale commit is worse than no tag, because rollback would restore the wrong files. Do not block the loop.
3. **Create the tag.** Create a lightweight git tag: `ralph/<task_id>/iter-<N>` (e.g., `ralph/per-element-accuracy-80/iter-9`).

**After either path (git-master or fallback):**

4. Record in state: `iteration_snapshots` array gains `{"iter": N, "git_ref": "ralph/<task_id>/iter-<N>", "timestamp": "<ISO-8601>"}`.
5. If tagging itself fails (no git, permission error), log a warning in `context.notes` but do not block the loop.

**Rollback command:**
`/ralph-loop rollback --to-iter N --task <id>`

1. Validate that `iteration_snapshots` contains iter N.
2. Show the user what will change: `git diff HEAD ralph/<task_id>/iter-<N> --stat`.
3. Require explicit user confirmation (skip in headless mode).
4. Execute: `git checkout ralph/<task_id>/iter-<N> -- .` (file-level restore, not HEAD detach).
5. Update state: set `iteration` to N, `current_stage` to Reflect, `next_step` to describe re-evaluation, remove snapshot entries for iterations > N.
6. Log a `rollback` event to the JSONL history file.
7. The loop resumes from Reflect of iteration N.

**Safety:** Rollback does NOT delete git history. It restores file contents to the tagged state. Original commits remain reachable.
