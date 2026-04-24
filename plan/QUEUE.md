# Execution Queue

> **Updated:** <!-- Replace with the date this file was last updated, e.g., 2026-01-15 -->
> **Current Position:** <!-- Name of the next phase to execute and its status, e.g., Phase 1.1 (Project Scaffold) — ready -->

---

## Legend

- `[ ]` — Pending, ready to execute
- `[B]` — Blocked by dependency
- `[H]` — Blocked by human action required
- `[x]` — Completed
- `[~]` — In progress

---

## Queue

<!-- Organize phases into milestones. Each milestone is a shippable checkpoint.
     Add one row per phase. Keep entries in execution order within each milestone.

     Column guide:
       #           — sequential queue position (use "a", "b" suffixes for sub-entries, e.g., 2a, 2b)
       Phase       — phase number from the plan document (e.g., 1.1, 2.3)
       Plan        — link to the plan document file
       Status      — one of the status markers from the Legend above (wrap in backticks: `[ ]`)
       Blocked By  — queue # of the blocking entry, or "—" if none
       Effort      — Small / Med / Large (or a range, e.g., Small–Med)
       Notes       — brief description; add completion date when marking `[x]`

     QUEUE.md Current Position rule (enforced by /next):
     The "Current Position" line in the header above MUST name the next phase to execute.
     Update it every time a phase is marked [x]. -->

### Milestone v0.1 — <Milestone Name>

<!-- Replace <Milestone Name> with a short description, e.g., "Foundation" or "Core Feature" -->

| # | Phase | Plan | Status | Blocked By | Effort | Notes |
|---|-------|------|--------|------------|--------|-------|
| 1 | 1.1 | [Phase Name](./01-plan-name.md) | `[ ]` | — | Small | Brief description of what this phase delivers |
| 2 | 1.2 | [Phase Name](./01-plan-name.md) | `[B]` | 1 | Med | Blocked until phase 1.1 completes |
| 3 | 2.1 | [Phase Name](./02-plan-name.md) | `[H]` | — | Small | Requires human action — see BLOCKERS.md |

### Milestone v1.0 — <Milestone Name>

| # | Phase | Plan | Status | Blocked By | Effort | Notes |
|---|-------|------|--------|------------|--------|-------|
| 4 | 3.1 | [Phase Name](./03-plan-name.md) | `[ ]` | — | Large | Brief description |
