# Plan <!-- KICKOFF:PLAN_NUMBER --> — <!-- KICKOFF:PLAN_NAME -->

<!-- The title above follows the convention: "Plan NN — Short Name".
     KICKOFF:PLAN_NUMBER is replaced with the zero-padded plan number (e.g., 01, 02).
     KICKOFF:PLAN_NAME is replaced with the human-readable plan name (e.g., Project Scaffold). -->

> **Status:** <!-- KICKOFF:PLAN_STATUS -->
> **Created:** <!-- KICKOFF:CREATED_DATE -->

<!-- Status values (update in place as work progresses):
       PENDING     — not yet started
       IN PROGRESS — at least one phase is executing
       COMPLETE    — all phases done and acceptance criteria met

     Created date is set once when the plan doc is first generated (YYYY-MM-DD).
     Never backfill or modify it. -->

---

## Overview

<!-- KICKOFF:PLAN_OVERVIEW -->

<!-- Write 2–4 sentences describing what this plan covers, what it delivers, and why it matters.
     Be specific enough that anyone reading this understands the scope without needing the INDEX.md. -->

---

## Phases

<!-- KICKOFF:PHASES -->

<!-- Each phase below follows the same structure. Duplicate this block for each phase in this plan.
     Phase numbers are hierarchical: the first number is the plan number, the second is the phase
     sequence within the plan (e.g., Phase 1.1 is the first phase in Plan 01).

     Task status values (use in the Status column of the Tasks table):
       [ ]  — Pending, not yet started
       [~]  — In progress
       [x]  — Completed
       [B]  — Blocked by a dependency (see BLOCKERS.md for details)

     Effort labels: Tiny / Small / Small–Med / Med / Med–Large / Large -->

---

### Phase <!-- KICKOFF:PLAN_NUMBER -->.1 — <!-- Phase Name -->

**Effort:** <!-- Tiny / Small / Small–Med / Med / Med–Large / Large -->
**Status:** PENDING

<!-- Replace the phase name and effort above. Update Status as work progresses:
     PENDING → IN PROGRESS → COMPLETE -->

#### Tasks

<!-- One row per task. Keep descriptions concise — one clause, not a paragraph.
     Acceptance criteria in this column are the specific, verifiable conditions for that task.
     The phase-level Acceptance Criteria section below covers the phase as a whole. -->

| # | Task | Description | Acceptance Criteria | Status |
|---|------|-------------|---------------------|--------|
| 1 | <!-- Task name --> | <!-- What to do --> | <!-- How to verify it's done --> | `[ ]` |
| 2 | <!-- Task name --> | <!-- What to do --> | <!-- How to verify it's done --> | `[ ]` |

#### Acceptance Criteria

<!-- List the conditions that must ALL be true before this phase is marked COMPLETE.
     These are higher-level than per-task criteria — they cover the phase outcome.
     Write them as verifiable assertions, not aspirations. -->

- [ ] <!-- Criterion 1 -->
- [ ] <!-- Criterion 2 -->

---

### Phase <!-- KICKOFF:PLAN_NUMBER -->.2 — <!-- Phase Name -->

**Effort:** <!-- Tiny / Small / Small–Med / Med / Med–Large / Large -->
**Status:** PENDING

#### Tasks

| # | Task | Description | Acceptance Criteria | Status |
| :--- | :--- | :--- | :--- | :--- |
| 1 | <!-- Task name --> | <!-- What to do --> | <!-- How to verify it's done --> | `[ ]` |
| 2 | <!-- Task name --> | <!-- What to do --> | <!-- How to verify it's done --> | `[ ]` |

#### Acceptance Criteria

- [ ] <!-- Criterion 1 -->
- [ ] <!-- Criterion 2 -->

---

<!-- Add more Phase blocks by copying one of the blocks above.
     Keep phases in sequential order (N.1, N.2, N.3, ...).
     Remove placeholder phases that are not needed for this plan. -->

## Deferred Items

<!-- KICKOFF:DEFERRED_ITEMS -->

<!-- Track anything explicitly deferred out of this plan — scope cuts, known limitations,
     out-of-scope findings discovered during execution. Every deferred item MUST have a
     concrete assigned phase number; "Backlog" or "TBD" are not valid assignment targets.
     When the assigned phase completes and the item is resolved, remove the row. -->

| Item | Reason | Assigned Phase | Added |
| :--- | :--- | :--- | :--- |
| <!-- What was deferred --> | <!-- Why it was deferred --> | <!-- Phase X.X --> | <!-- YYYY-MM-DD --> |
