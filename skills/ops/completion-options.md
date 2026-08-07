<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Phase 4 — Completion Options

At the end of any run that reaches Phase 4 — whether every task completed cleanly or the run ended with a terminal failure — present a structured decision menu so the next step is explicit. Do not exit Phase 4 until the user has selected an option.

## Decision menu

| # | Option | When to use |
|---|--------|-------------|
| 1 | **Merge locally** | Solo work, linear history preferred |
| 2 | **Push and open PR** | Team work or pre-merge review needed |
| 3 | **Keep branch** | More commits planned before merging |
| 4 | **Discard** | Branch was exploratory; changes unwanted |

---

## Foreground dispatch

Every git-master dispatch in this menu, Merge locally, Push and open PR, and Discard, runs in the foreground: each procedure consumes that dispatch's result in the step right after it fires. Merge locally confirms the merge landed at step 3; Push and open PR runs `gh pr create` at step 2, after the push completes; Discard confirms the branch deletion at step 3. A detached dispatch would let those steps run before the git operation finishes. The push case fails most visibly, since the PR command would target a ref not yet on the remote. This mirrors the canonical foreground list in `skills/ops/dispatch-policy.md`.

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
   > The `<title>` and `<summary>` must be authored fresh from the human-readable outcome — what changed and why. Never copy them from the task board, dashboard, plan doc, or handoff files: those carry ops-internal IDs (e.g. `task-N`), stage labels, and planning-doc references that must not appear in a PR a human will read. This is the "No internal references in user-facing output" shared brief constraint (`skills/ops/SKILL.md#shared-brief-constraints`).
   - If `gh pr create` fails (gh not installed, not authenticated, or no remote configured), surface the error message verbatim and tell the user: "Please push the branch and open the PR manually via the repository's web UI." Do not proceed silently.
3. Return the PR URL to the user.

**Default for:** team workflows, branches requiring CI, or when review is desired before merge.

---

## Option 3 — Keep branch

No action required. The branch stays as-is for follow-up work.

**Procedure:** Confirm to the user that the branch is preserved and summarize its current HEAD commit and any open items from the run, drawing the open-items summary from the relocation report the Cleanup block rendered immediately before this menu (`skills/ops/phase-completion.md`'s Phase 4 completion section, step 9c).

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

1. Read the `worktrees_created` array from the cleanup record file, `.ops-state/<run-id>-cleanup.json`, which 9a wrote before 9b deleted the board file (`skills/ops/phase-completion.md`'s Phase 4 completion section, step 9a); by the time this procedure runs, in step 10, the board file itself no longer exists, so the cleanup record is the only surviving source for this array.
2. That array's entries each record `{path, added_at}` for worktrees this run registered.
3. For each entry in `worktrees_created`:
   a. Confirm the path on disk matches the recorded path exactly.
   b. Confirm the path does not appear in `git worktree list` output as a worktree that existed before this run (i.e., `added_at` is within this run's time window).
   c. Only if both checks pass: `git worktree remove --force <path>` — this step runs on the quiescence guarantee established by the re-entrant guard immediately before step 9b in `skills/ops/phase-completion.md`, and does not re-derive it.
4. **Distinguish an empty array from a missing record.** If the cleanup record file exists and its `worktrees_created` array has no entries, this genuinely means the run created no worktrees: skip worktree cleanup silently, a normal outcome. If the cleanup record file itself is missing, that is a failure the empty-array case cannot stand in for: surface it to the user with the path (`.ops-state/<run-id>-cleanup.json`) rather than skipping silently, since a run that should have this file but doesn't leaves no signal that any worktrees it created were ever cleaned up.
5. Never remove a worktree that is not listed in the `worktrees_created` array read from the cleanup record, regardless of name or path similarity.

---

## Output Tagging

No output tagging on this sub-file — it is a reference document consumed by the Team Manager. The Team Manager's own **`Team Manager`** badge applies to the turn that invokes this menu.
