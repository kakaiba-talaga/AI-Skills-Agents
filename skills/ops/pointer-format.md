# Pointer Line Format — ops Companion Files

A **pointer** is a one-line blockquote in `SKILL.md` that tells the model where to find extended reference content. Pointers keep the core file lean — the model reads the companion only when that workflow branch is active. Every pointer must include a fallback sentence so the model stays unblocked if the companion file is missing.

## Templates

**Strong pointer** (use when the companion contains content the model must act on — exact logic, required decision trees, exhaustive rule sets):

```
> **Reference:** You MUST Read `~/.claude/skills/ops/<file>.md` for [short description]. If the file is missing, [fallback instruction].
```

**Soft pointer** (use when the companion is supplementary detail the model may consult for edge cases, but the inline summary is sufficient for most runs):

```
> **Reference:** See `~/.claude/skills/ops/<file>.md` for [short description]. If the file is missing, proceed using the inline summary above.
```

## When to downgrade from MUST to softer

Downgrade to `See` / `Refer to` when the companion is only needed for a specific, rarely-fired condition: SSH-only tasks, ralph-mode runs, `resume` command, failure escalation, or opt-in features like cost tracking. Keep `You MUST Read` for always-hot companions: `state-schema.md`, `handoffs.md`, `dispatch-policy.md`, `tool-restrictions.md`, `plan-validation.md`.
