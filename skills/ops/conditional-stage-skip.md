<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Conditional Stage Skipping

## 1. Relationship to Existing Skip Logic

The existing trivial/mechanical skip in the Edge Cases section of `SKILL.md` handles the obvious case: all changes are trivial, skip everything. This file handles the nuanced cases — some stages are worth skipping for certain kinds of changes, even when the changes are not trivial overall.

Both systems coexist and are evaluated in order:

- **Trivial skip (existing, SKILL.md Edge Cases):** all-or-nothing; applies when ALL changes in the run are trivial (rename, reformat, config-only, doc-only). If this fires, stop — all stages are skipped.
- **Conditional skip (this file):** per-stage; applies based on change characteristics when the trivial skip does not fire. Each stage is evaluated independently.

The trivial skip always takes precedence. Only proceed to conditional evaluation if the trivial skip did not apply.

---

## 2. Per-Stage Skip Conditions

### Verify Stage

**Skip when ALL of the following are true:**
- Total diff is < 10 lines across all files, OR
- All changes are in configuration files (YAML, JSON, TOML, .env), OR
- All changes are in documentation files (.md, .rst, .txt), OR
- Changes are purely additive (no existing behavior modified) AND total diff is < 20 lines, OR
- Changes are import reordering or formatting-only (no logic touched)

**NEVER skip when ANY of the following is true:**
- Any logic was modified (conditionals, loops, function bodies)
- Any function signature changed
- Any test file was modified (tests must be verified to still pass)
- Changes affect pipeline stages that have downstream consumers
- Changes touch pipeline orchestration files (job runners, CLI entry points, pipeline coordinators) — these have implicit ordering and state dependencies

---

### Deslop Stage

**Skip when ALL of the following are true:**
- Total diff is < 20 lines, OR
- Changes are confined to a single file, OR
- No new functions, classes, or methods were added, OR
- Changes are to configuration or documentation only, OR
- The executor was given a very specific, narrow brief (low risk of over-engineering or padding)

**NEVER skip when ANY of the following is true:**
- Multiple new functions were added
- Agent used model escalation (higher-tier models tend to over-engineer)
- Changes span 3 or more files
- The task involved refactoring or restructuring existing code

---

### Review Stage

**Skip when ALL of the following are true:**
- Total diff is < 10 lines AND changes are in test files only, OR
- Changes are purely mechanical (rename, move, reformat — no logic change), OR
- Changes are to documentation only, OR
- The change was a direct copy from user-provided code (the user already reviewed it)

**NEVER skip when ANY of the following is true:**
- Changes affect security-sensitive code (auth, crypto, permissions)
- Changes modify public APIs or interfaces
- Changes affect error handling or validation logic
- Changes touch pipeline orchestration files (job runners, CLI entry points, pipeline coordinators) — these files have implicit ordering dependencies and state management that small diffs can mask. A reviewer examining the surrounding code catches bugs that the executor's narrow scope misses.
- Total diff exceeds 50 lines

---

## 3. Evaluation Procedure

At each stage transition, before dispatching the next stage's tasks:

1. Compute the total diff against the pre-run baseline: `git diff --stat`
2. Categorize the changed files into: code, config, docs, tests
3. Check the change characteristics against the skip conditions for the upcoming stage
4. If ALL skip conditions for the stage are met AND none of the NEVER-skip conditions apply → skip the stage
5. Log the skip as an adaptation: `"Adapted: skipped [stage] — [reason]"`
6. Move to the next stage in the pipeline

Evaluation is done independently for each stage. Skipping verify does not imply skipping deslop or review.

---

## 4. Override Mechanisms

- **`--full-pipeline` flag (future):** when implemented, forces all stages to run with no skipping
- **User override at checkpoint:** if the user says "don't skip review" or similar at any checkpoint, honor it and do not skip that stage for the remainder of the run
- **Estimation feedback memory:** if historical data (from `estimation-feedback.md`) shows that a given stage has caught real issues for this type of change in previous runs, treat that stage as NEVER-skip for this run. Be conservative — a past miss outweighs the efficiency gain.

---

## 5. Logging Requirements

Every skip MUST be logged with the following information:
- Which stage was skipped
- Which specific condition(s) triggered the skip
- The diff stats that informed the decision

Example log entry:

```
Adapted: skipped deslop — single file changed, 8-line diff, no new functions added
```

```
Adapted: skipped verify — documentation-only changes (2 .md files, +14/-3 lines)
```

Skips are reported in three places:

1. **Stage transition checkpoint** (interactive mode) — shown before moving to the next stage, so the user can override
2. **Dashboard Adaptations section** — listed alongside other run adaptations
3. **Completion summary** — included in the final run report under "Stages skipped"

---

## 6. Interaction with Other Features

- **Trivial skip:** if the trivial skip fires (all changes are trivial), it takes precedence and all stages are skipped. Conditional evaluation does not run.
- **Estimation feedback:** if `estimation-feedback.md` historical data shows a stage catches issues for this type of change, do not skip — defer to the historical signal over the diff-size heuristic.
- **Worktrees:** when running with branch isolation, skip conditions are evaluated per-worktree using that worktree's diff, not the aggregate diff across all worktrees. A 5-line diff in one worktree and a 60-line diff in another are evaluated independently.
- **Ralph loop:** skip conditions are re-evaluated at each loop iteration because the diff changes between iterations. A stage skipped in iteration N may not be skipped in iteration N+1 if the diff has grown or changed character.
