<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Work Item Scaffolding — Template Interaction, Discovery, and Completion Signals

This file holds the rarely-needed sub-details of the Work Item Scaffolding section in `SKILL.md`. The core scaffolding rules, acceptance-criteria quality table, and one-time approval flow stay inline in `SKILL.md`. Read this companion when you need the rules below.

## Interaction with templates

When a template with `acceptance_criteria.per_category` is active, categories (quantitative metrics) and work items (qualitative deliverables) are complementary. Both are evaluated during Verify and Reflect. A work item can be `done` even if its category metric hasn't reached threshold, and vice versa — the category metric and the work item are independent completion signals, and either condition alone is sufficient to present the target-reached or continuation structured-choice prompt — see the Completion signal section below for the exact case routing.

## Discovery

During Execute or Verify, if a sub-task or prerequisite is discovered, Reflect adds it as a new work item at the appropriate priority position. The work item list is the single source of truth for "what remains."

## Completion signal

During Reflect's target-reached check:

- All items `done` AND `achieved_percent` >= target: trigger target-reached prompt.
- All items `done` but percent below target: ask whether to add more items or adjust the target.
- Percent reached but items remain: ask whether to continue or mark done.
