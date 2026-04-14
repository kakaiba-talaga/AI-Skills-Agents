<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

## Ralph Loop Integration

When invoked with `ralph` (e.g., `/ops ralph "improve test coverage to 80%"`), the team manager wraps its entire workflow inside a `/ralph-loop` persistence loop:

1. The ralph loop provides the outer iteration — each loop pass runs one full team-manager cycle (plan → implement → verify → review).
2. After each cycle, the ralph loop's **Reflect** stage evaluates whether the acceptance criteria (e.g., 80% coverage) have been met.
3. If not met, the ralph loop starts a new iteration — the team manager re-plans based on what's still missing, creates new tasks, and dispatches again.
4. The team manager's task board is reset between ralph iterations. Handoff files from the previous iteration persist on disk in `docs/plan/.handoffs/` and carry forward as context — the team manager reads them when planning the next iteration.

**When to use ralph mode:**

- The goal is metric-driven (accuracy %, test coverage %, performance targets)
- The work requires iterative refinement that can't be fully planned upfront
- You want persistence across potential interruptions

**When NOT to use ralph mode:**

- The work is a one-shot implementation with clear tasks
- The plan is already complete and won't need iteration
