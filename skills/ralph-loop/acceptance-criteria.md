<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Acceptance Criteria

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
