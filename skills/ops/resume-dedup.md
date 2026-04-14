<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Resume Deduplication

A companion helper for the `/ops` team manager skill. This procedure runs during `resume` to avoid re-dispatching work that an interrupted agent already completed.

---

## 1. When This Applies

- **On `resume` command only** — not during normal dispatch.
- **For tasks with status `in_progress`** at the time of resume — these are the ambiguous cases where work may or may not have finished before the interruption.
- **Does NOT apply to `pending` tasks** — they were never started; dispatch normally.
- **Does NOT apply to `completed` tasks** — already done; skip as usual.

---

## 2. Verification Checks

For each `in_progress` task, run these checks in order. Collect all results before making a decision.

### Check A — File Existence

If the task's acceptance criteria mention specific files to create or modify:

1. Check whether those files exist.
2. Compare their modification timestamps against the run start time (stored in the run state file).
3. A file that exists and was modified after the run started is positive evidence the agent wrote it.

### Check B — Git Diff

Run the following two commands (separately — do not chain):

```
git diff --name-only
git diff --cached --name-only
```

Compare the list of changed files against the task's scope — the files the agent was assigned to modify. Overlap indicates the agent made changes. No overlap (and no committed files) indicates the agent did not start, or its changes were lost.

### Check C — Handoff File

Check whether a handoff file exists for this task in the run's handoff directory. Note the asymmetry:

- If the team manager writes handoffs **after** marking a task complete, the handoff will be absent even when the agent finished successfully — because the team manager crashed before writing it.
- Therefore: absence of a handoff file does **not** mean the agent didn't finish. It may mean the team manager crashed after the agent finished but before the handoff was written.
- Presence of a handoff file is strong evidence of completion. Absence is a neutral signal — use Checks A, B, and D to resolve.

### Check D — Content Validation

Read the output files and assess whether the content is substantive and complete:

- **Documentation tasks**: file is not empty, not a stub (e.g., not just headings with no body), and covers the topics listed in the acceptance criteria.
- **Code tasks**: functions are not half-written (no dangling `def`, `class`, or `{` with no body), no obvious placeholder text (`TODO`, `FIXME`, `HACK`, `pass` where logic is expected), imports match what the code uses.
- **Config tasks**: YAML/JSON/TOML is valid and contains the expected keys.

If the file looks complete and meets the acceptance criteria, this check passes.

---

## 3. Decision Matrix

| Check A (files) | Check B (diff) | Check C (handoff) | Check D (content) | Decision |
|:---:|:---:|:---:|:---:|:---|
| All expected files exist | Diff matches scope | Handoff exists | Content is complete | **Mark completed** — skip re-dispatch |
| All expected files exist | Diff matches scope | No handoff | Content is complete | **Mark completed** — write the missing handoff |
| Some files exist | Partial diff | No handoff | Content is partial | **Re-dispatch with context** — tell the agent what's already done |
| No files changed | No relevant diff | No handoff | N/A | **Re-dispatch normally** — agent didn't get to do anything |
| Files exist but look wrong | Diff exists but doesn't match scope | No handoff | Content is broken | **Rollback then re-dispatch** — agent produced bad output |

**Rollback procedure**: use `git checkout -- <files>` (or `git restore <files>`) to revert the affected files to their pre-run state, then re-dispatch the task normally. Do not re-dispatch on top of broken output.

---

## 4. Re-dispatch with Context

When a task is partially complete (third row of the decision matrix), the re-dispatch brief must include the following, in addition to the original task brief:

> "This task was previously attempted but interrupted before completion."

Then list:

- Files already modified and a brief description of their current state (e.g., "section 1 and 2 are written; section 3 is a stub").
- What appears to be done based on Checks A–D.
- What still appears to be missing or incomplete.

Close with:

> "Continue from where the previous agent left off — do NOT start over or re-write sections that are already complete."

This prevents the agent from duplicating work or overwriting good output with a fresh rewrite.

---

## 5. Integration with Resume Flow

This dedup step slots in between the existing steps in `interruption-recovery.md`:

1. Recover task list (existing — load run state, identify `in_progress` tasks)
2. **For each `in_progress` task: run dedup verification** (NEW — this file)
3. **Mark verified-complete tasks as `completed`** (NEW — update state file, write any missing handoffs)
4. Re-dispatch remaining `in_progress` tasks, with context briefs where applicable (existing dispatch loop, now context-aware)
5. Continue dispatch loop for any remaining `pending` tasks (existing)

Step 3 must write the updated task status back to the run state file before Step 4 begins, so the dispatch loop sees accurate status and does not re-dispatch already-completed tasks.

---

## 6. Edge Cases

### Multiple in_progress Tasks

Verify each independently. Do not make a blanket decision for the group. One task may be fully complete while another was not started.

### Parallel Tasks That Were in_progress

Before re-dispatching, check for file conflicts between the parallel tasks. If two in_progress tasks were supposed to write different files and both wrote the same file, inspect the content carefully before deciding which (if any) to keep. Resolve conflicts before re-dispatching either task.

### Task Had Retries Before Interruption

Check the task metadata for `attempt_count`. When re-dispatching, continue from that count — do not reset to attempt 1. This prevents the retry limit from being consumed by a phantom "first" attempt.

### Worktree Tasks

If the task used a git worktree:

- Check whether the worktree still exists (`git worktree list`).
- If it exists, inspect its state — files, diff, and content — before deciding.
- If it has been cleaned up since the interruption, fall back to the main working tree diff and re-dispatch normally.

### Time Gap Since Interruption

If significant time has passed since the interruption (days rather than hours), other commits or manual changes may have been made to the same files. In this case:

1. Run the standard preflight check before dedup (check for uncommitted changes, merge conflicts, and branch freshness).
2. Then run dedup as normal, but treat git diff results with extra caution — changes in the diff may not belong to the interrupted task.
3. When in doubt, prefer **re-dispatch with context** over silently marking complete.
