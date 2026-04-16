# Pointer Line Format — ops Companion Files

This file documents the standard format for inline pointer lines used in `SKILL.md`
to reference companion files in the same directory.

---

## Template

```
> **Reference:** You MUST Read `~/.claude/skills/ops/<file>.md` for [description]. If the file is missing, proceed using the inline summary above.
```

**Rules for the template fields:**

- `<file>.md` — the companion filename, no spaces, lowercase with hyphens.
- `[description]` — a short phrase (5–10 words) naming what the file contains.
  Start with a noun phrase, not a verb (e.g., "full help card text and formatting rules").
- The fallback sentence is required on every pointer. It keeps the model unblocked
  when the companion file has not been written yet or is unavailable.

---

## When to use "You MUST Read" vs a softer pointer

| Situation | Wording to use |
| :--- | :--- |
| The companion file contains content the model **must act on** (e.g., exact text to emit, required decision logic, exhaustive rule sets) | `You MUST Read` |
| The companion file is **supplementary detail** the model may consult for edge cases or background, but inline summary is sufficient for most runs | `See` or `Refer to` |

For all 21 companion files the content is load-bearing, so all examples below
use `You MUST Read`.

---

## Examples — all 21 companion files

### 1. `help-card.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/help-card.md` for the full help card text. If the file is missing, display a brief usage summary instead.

### 2. `branch-isolation.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/branch-isolation.md` for complete branch handling procedures (uncommitted changes, branch creation, after-completion cleanup, worktree/ralph/resume interaction). If the file is missing, proceed using the decision table above.

### 3. `handoffs.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/handoffs.md` for the full handoff template, run identity rules, naming examples, accumulation rules, and cleanup lifecycle. If the file is missing, proceed using the inline summary above.

### 4. `timing-edge-cases.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/timing-edge-cases.md` for timing edge case rules (retry time, parallel execution, internal tasks, resume timing, model escalation, calibration, idle time). If the file is missing, proceed using the bullet points above.

### 5. `interruption-recovery.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/interruption-recovery.md` for detailed procedures for cancel/abort, reprioritize, inject tasks, remove tasks, and session recovery. If the file is missing, proceed using the summary table below.

### 6. `permissions.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/permissions.md` for the complete permissions reference, always-prompt table, and opt-in instructions. If the file is missing, proceed without permission-specific guidance.

### 7. `ralph-integration.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/ralph-integration.md` for the full Ralph Loop integration protocol, iteration behavior, and when to use/not use ralph mode. If the file is missing, proceed using the inline summary above.

### 8. `deslop-integration.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/deslop-integration.md` for the full deslop procedure, skip conditions, dashboard display rules, and re-verification logic. If the file is missing, proceed using the inline summary above.

### 9. `preflight-validation.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/preflight-validation.md` for the complete preflight validation procedure, check categories, and agent brief template. If the file is missing, proceed without preflight checks.

### 10. `estimation-feedback.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/estimation-feedback.md` for the estimation feedback loop, memory format, and calibration procedure. If the file is missing, proceed without estimation feedback.

### 11. `agent-health-monitoring.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/agent-health-monitoring.md` for timeout budgets, stall detection rules, and health escalation procedures. If the file is missing, proceed without health monitoring.

### 12. `rollback-strategy.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/rollback-strategy.md` for the complete rollback procedure, scope levels, and guardrails. If the file is missing, proceed without automatic rollback.

### 13. `resume-dedup.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/resume-dedup.md` for the resume deduplication procedure and work verification checks. If the file is missing, re-dispatch in_progress tasks without dedup checks.

### 14. `conditional-stage-skip.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/conditional-stage-skip.md` for per-stage skip conditions and evaluation procedure. If the file is missing, use only the trivial-skip logic above.

### 15. `cost-tracking.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/cost-tracking.md` for token estimation heuristics, model pricing, and cost dashboard format. If the file is missing, proceed without cost tracking.

### 16. `ssh-integration.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/ssh-integration.md` for SSH-specific preflight checks, brief template, and handoff format. If the file is missing, proceed without SSH-specific guidance.

### 17. `plan-validation.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/plan-validation.md` for spec clarity evaluation criteria, plan complexity scoring signals, critic verdict handling, scoper/critic output descriptions, execute-skip detection, mode-specific behavior, and adaptation rules. If the file is missing, proceed using the tier table and display format above.

### 18. `state-schema.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/state-schema.md` for the state file JSON structure, field definitions, and directory conventions. If the file is missing, proceed using the State Operations table below.

### 19. `dispatch-policy.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/dispatch-policy.md` for the full foreground/background decision criteria, batch rules, and interaction with health monitoring and worktree isolation. If the file is missing, proceed using the summary above.

### 20. `tool-restrictions.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/tool-restrictions.md` for the full delegate-first table, permitted direct actions, and self-check rules. If the file is missing, proceed using the delegate-first principle above.

### 21. `pointer-format.md`
> **Reference:** You MUST Read `~/.claude/skills/ops/pointer-format.md` for the standard format for pointer lines and usage notes for extraction agents. If the file is missing, follow the inline template above.

---

## Usage notes for extraction agents

- Paste the pointer line immediately after the inline summary block that replaces the
  extracted section — never before it.
- The inline summary stays in `SKILL.md` so the model has a usable fallback without
  needing to read the companion file on every run.
- Do not alter the path prefix `~/.claude/skills/ops/`.
  The `~` shorthand resolves to the user's home directory on any machine,
  making skill files portable across workstations.
- Each companion file should open with a single `# <Title>` heading that matches the
  description phrase used in its pointer line, so the model can confirm it loaded the
  correct file.
