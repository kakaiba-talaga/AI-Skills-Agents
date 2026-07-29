# Brief format — shared agent snippet

Agents include this file by pointer from their `## Brief Format` subsection. Paths in agent contracts use `~/.claude/agents/_shared/brief-format-snippet.md`.

> **Canonical contract:** Read `~/.claude/skills/ops/brief-contract.md` when composing or validating briefs. The team manager produces briefs in that universal format; each agent's `## Brief Format` subsection states agent-specific overrides only.

## Required and optional sections (default)

Unless an agent's contract lists different required/optional sections:

- **Required:** `## Task`, `## Scope`, `## Acceptance Criteria`, `## Constraints`
- **Optional:** `## Context`, `## Mode`, `## Handoff Artifacts`, `## Code Intelligence Context`, `## Corpus Search Context`, `## Library Docs Context`, `## Project Knowledge`

## Project Knowledge precedence

**`## Project Knowledge`:** The section informs but does not override `## Acceptance Criteria` or `## Scope`. The agent honors the mandatory `NEEDS-INPUT` escalation when a `## Constraints` bullet contradicts a security/correctness/safety-flagged durable rule in `## Project Knowledge` (keyword heuristic per `~/.claude/skills/ops/brief-contract.md` `## Section Precedence`).

## Missing `## Acceptance Criteria` (default)

Unless an agent's contract states otherwise: refuse the dispatch — do not infer criteria from `## Scope`, `## Task`, or any other section. Return a `NEEDS-INPUT` verdict and ask for an explicit numbered criteria list or a plan-doc reference. See `~/.claude/skills/ops/brief-contract.md` `## Missing-Section Behavior` for the full missing-section table.

## Internal inconsistency (default)

When sections conflict (e.g., `## Scope` cites file A and `## Acceptance Criteria` requires changes in file B): escalate rather than silently picking one side. Return a `NEEDS-INPUT` verdict naming which sections conflict. See `~/.claude/skills/ops/brief-contract.md` `## Section Precedence` for precedence rules.

## Premise accuracy (default)

When a brief's stated premise contradicts the artifact, the artifact governs: report the contradiction, then correct or escalate rather than comply. Confirming a premise you were handed is part of the task, not scope expansion. The agent honors the mandatory `NEEDS-INPUT` escalation when the correction to a disproved premise touches a security, correctness, or safety surface (keyword heuristic per `~/.claude/skills/ops/brief-contract.md` `## Section Precedence`). See `~/.claude/skills/ops/brief-contract.md` `## Premise Accuracy` for the full rule.
