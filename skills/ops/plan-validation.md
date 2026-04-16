<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Plan Validation Details

## Spec Clarity Evaluation

| Signal | Clarity level | Action |
| :--- | :--- | :--- |
| User provides specific requirements, acceptance criteria, or references an existing spec/ticket | **Clear** | Dispatch planner directly. |
| User's input names a goal but leaves key decisions open ("make it better", "add caching", "improve performance") | **Vague** | Dispatch **interviewer** to crystallize: what specifically needs to change, what are the success criteria, what are the constraints? Then dispatch planner with the interviewer's requirements document. |
| User's input is contradictory, references unknown context, or has multiple possible interpretations | **Ambiguous** | Dispatch **interviewer** to resolve the ambiguity before planning. |
| User says "just plan it" or explicitly asks for planning despite vague input | **User override** | Dispatch planner directly — the user wants to see what the planner produces and will refine from there. Log: "Adapted: skipped interviewer — user requested direct planning despite vague spec." |

## Already-Validated Plan Detection

When the user provides a plan via `execute`, check whether it has already been through scoping and/or critique before deciding to skip Phase 1a:
1. A companion scoping document exists on disk at `docs/plan/<plan-name>-scoping.md` alongside the plan file.
2. The plan document itself contains a "Critic Verdict" or "Scoping" section (indicating it was reviewed in a prior session).
3. The conversation context contains a critic verdict or scoper output for this plan.

If **any** of these signals are present, skip Phase 1a. If **none** are present, run Phase 1a normally — the plan needs validation even though it entered via `execute`.

## Plan Complexity Scoring (Step 1)

| Signal | Weight | Triggers when |
| :--- | :--- | :--- |
| **Task count** | High | >5 implementation tasks |
| **Architectural decisions** | High | New agent, new skill, new integration pattern, security model, API design, data model changes |
| **Multi-system scope** | Medium | Plan touches 3+ modules, files across different systems, or external integrations |
| **Ambiguity in spec** | Medium | User's original input was vague, had open questions, or the planner flagged uncertainties |
| **Risk level** | Medium | Touches security, auth, data, infrastructure, or production systems |
| **Time estimate** | Low | Plan estimates >2 hours total work |
| **Novelty** | Low | First time this type of work appears in the project, or no precedent in codebase |

## Critic Verdict Handling (Tier 3)

| Verdict | Action |
| :--- | :--- |
| **ACCEPT** | Proceed to Phase 1.5. |
| **ACCEPT WITH RESERVATIONS** | Display the reservations. In all modes (interactive, autonomous, supervised), **stop and present the reservations to the user**. The user decides: proceed as-is, address the reservations first, or send it back for revision. This is a decision point — autonomous mode stops here per the Autonomy Modes rules. |
| **REVISE** | Route the critic's findings back to a **planner** agent. The planner updates the existing plan document. Re-run Phase 1a. Maximum 2 revision loops — if the planner produces a substantively similar plan after 2 revisions, escalate to the user: "The planner produced a similar plan after 2 revisions. The critic's findings may require rethinking the approach, not just revising the plan." |
| **REJECT** | Escalate to the user with the critic's full findings. Do not proceed to Phase 2. |

## Mode-Specific Behavior

In **interactive mode**, show the tier decision and wait for the user to confirm, override, or skip. The user can say:
- "proceed" — accept the tier decision
- "skip validation" — override to Tier 1 regardless of score
- "scope it" — override to Tier 2
- "scope and critique" — override to Tier 3

In **autonomous mode**, display the tier decision and proceed automatically. The decision is always visible so the user knows what validation level was applied — the team manager never silently skips validation without reporting it.

In **supervised mode**, show the tier decision and wait for approval before each agent dispatch (same as other tasks in supervised mode).

## What the Project-Scoper Adds (Tier 2 and 3)

- **Gap analysis** — what the plan missed (edge cases, error handling, dependencies)
- **Effort estimates** — hours per task, sourced from scoping analysis (these feed into `estimated_minutes` with `estimate_source: "scoping-doc"` in Phase 2)
- **Risk flags** — what could go wrong and how to mitigate
- **Scope boundaries** — what's explicitly out of scope to prevent creep
- **Scoping document** — persisted to `docs/plan/` alongside the plan document

## What the Critic Adds (Tier 3 only)

- **Feasibility review** — can this plan actually be implemented as described?
- **Assumption audit** — what assumptions does the plan make that might not hold?
- **Verdict** — ACCEPT / ACCEPT WITH RESERVATIONS / REVISE / REJECT
- **Revision loop** — if REVISE, findings go back to the planner. The planner updates the plan, and Phase 1a re-evaluates (maximum 2 revision loops before escalating to the user)

## Adaptation

- If past runs show this project type consistently needs critique, upgrade the default tier. Log: "Applied learned pattern: Tier 3 for auth-related work (past run required revision)."
- If the user overrides the tier decision, save the override as a feedback memory for future runs. Example: "User overrode Tier 3 → Tier 1 for config-only changes. Apply Tier 1 default for config changes."
