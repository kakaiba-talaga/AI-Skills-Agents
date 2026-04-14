<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Subagent Parallelism in Verify

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
