<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Execution Extras

This companion bundles three execution-support topics: rollback/undo, subagent-parallel Verify, and acceptance-criteria auto-evaluation. Read on any of these triggers: `rollback` sub-command; template defines `acceptance_criteria`; template defines `hooks.verify.for_each` (fan-out Verify).

## Rollback/Undo Support

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

## Subagent Parallelism in Verify

When the template's `hooks.verify.for_each` is defined, Verify fans out across multiple inputs using subagents.

**Execution:**

1. Evaluate `for_each.source` to get a list of items (e.g., file paths from a glob or command).
2. If `parallel: true`, spawn one subagent per item (up to `max_concurrency`, default 4). Each runs `per_item_command` with `{{item}}` replaced by the current item.
3. If `parallel: false`, run sequentially.
4. Each subagent returns its metric extraction result.
5. Aggregate using `aggregation` strategy:
   - `average`: arithmetic mean of per-item metrics.
   - `min`: worst-case across items.
   - `max`: best-case across items.
   - `sum`: total (for count-based metrics).
6. Store per-item results in state under `progress.per_item_results` for trend analysis.
7. Feed aggregated result into acceptance criteria evaluation.

**Without `for_each`:** Verify runs the single `hooks.verify.command` or relies on manual user verification as before. Existing subagent behavior for comparison/data-analysis iterations (>= 2 independent commands) remains unchanged for non-template usage.

**Error handling:** If a subagent fails for one item, record the failure, continue with remaining items, and note the partial result in the Verify output. Do not fail the entire Verify stage for one item's failure.

## Acceptance Criteria

When the state file has a `template_id` pointing to a template with `acceptance_criteria`, Verify auto-evaluates results against structured thresholds.

**Modes:**

- `overall`: A single overall metric must meet `overall_threshold`.
- `per_category`: Each category must independently meet its `threshold`. The task is not done until ALL categories pass.
- `all_pass`: Like `per_category`, plus the overall metric must also meet `overall_threshold`.

**Auto-evaluation during Verify:**

1. Run the verify command (or `for_each` fan-out).
2. Extract metrics using `metric_extraction` paths.
3. Compare each extracted metric to its category threshold.
4. Report per-category pass/fail in the stage output as a table:

   | Category | Measured | Threshold | Status |
   |----------|----------|-----------|--------|
   | walls    | 96.8%    | 96%       | PASS   |
   | doors    | 90.8%    | 90%       | PASS   |
   | windows  | 79.8%    | 90%       | FAIL   |

5. Update `achieved_percent` as the weighted average (using `weight` fields) or simple average of (measured/threshold * 100) per category, capped at 100.
6. If all categories pass, trigger the target-reached structured options prompt.
7. Store per-category results in `progress.category_results` in the state file.

**Without a template:** Acceptance criteria work as before (freeform goal/percent comparison).
