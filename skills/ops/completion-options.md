<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Phase 4 — Completion Options

At the end of a successful run, present a structured decision menu so the next step is explicit. Do not exit Phase 4 until the user has selected an option.

## Decision menu

| # | Option | When to use |
|---|--------|-------------|
| 1 | **Merge locally** | Solo work, linear history preferred |
| 2 | **Push and open PR** | Team work or pre-merge review needed |
| 3 | **Keep branch** | More commits planned before merging |
| 4 | **Discard** | Branch was exploratory; changes unwanted |

---

## Option 1 — Merge locally

Merge the feature branch into main using `--ff-only` to preserve linear history, then delete the local branch.

**Procedure:**

1. Dispatch **git-master** with the merge brief:
   - `git checkout main`
   - `git merge --ff-only <branch>`
   - `git branch -d <branch>`
2. If `--ff-only` fails (branches have diverged), surface the conflict to the user — do not fall back to a merge commit automatically.
3. Confirm the merge landed: verify HEAD on main matches the expected commit.

**Default for:** solo work, fast-forward-eligible branches.

---

## Option 2 — Push and open PR

Push the branch to the remote and open a pull request for team review or pre-merge CI.

**Procedure:**

1. Dispatch **git-master** with the push brief:
   - `git push -u origin <branch>`
2. After push completes, run:
   - `gh pr create --title "<title>" --body "<summary>"`
3. Return the PR URL to the user.

**Default for:** team workflows, branches requiring CI, or when review is desired before merge.

---

## Option 3 — Keep branch

No action required. The branch stays as-is for follow-up work.

**Procedure:** Confirm to the user that the branch is preserved and summarize its current HEAD commit and any open items from the run.

**Recommended when:** the user wants to add more commits before merging, or needs to revisit a deferred task.

---

## Option 4 — Discard

Delete the branch. **This is a destructive operation** — it permanently removes the branch and its unmerged commits.

**Procedure:**

1. **Require explicit confirmation before proceeding.** Two acceptable forms:
   - (a) User types the word `discard` verbatim (word-for-word) in their reply.
   - (b) Present a yes/no prompt; proceed only on an unambiguous "yes".
2. After confirmation, dispatch **git-master**:
   - `git branch -D <branch>` (force-delete — use `-D` because the branch is not merged at discard time; `-d` would refuse the deletion; safe only after the explicit confirmation above)
3. Confirm deletion: verify the branch no longer appears in `git branch`.

**Do not** use `-D` without the confirmation gate. If the user declines confirmation, return to the decision menu.

---

## Worktree cleanup by provenance check

If `--worktree` was set during the run, clean up **only** worktrees that this run created. Do not touch externally-owned worktrees.

**Provenance check procedure:**

1. Read the run's state file (`.ops-state/<run-id>-board.json`).
2. Locate the `worktrees_created` array — each entry records `{path, added_at}` for worktrees this run registered.
3. For each entry in `worktrees_created`:
   a. Confirm the path on disk matches the recorded path exactly.
   b. Confirm the path does not appear in `git worktree list` output as a worktree that existed before this run (i.e., `added_at` is within this run's time window).
   c. Only if both checks pass: `git worktree remove --force <path>`.
4. If the state file has no `worktrees_created` entries, skip worktree cleanup entirely.
5. Never remove a worktree that is not listed in the run's state file, regardless of name or path similarity.

---

## Output Tagging

No output tagging on this sub-file — it is a reference document consumed by the Team Manager. The Team Manager's own **`Team Manager`** badge applies to the turn that invokes this menu.
