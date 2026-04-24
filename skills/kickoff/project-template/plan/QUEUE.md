# Execution Queue

> **Updated:** <!-- Replace with the date this file was last updated, e.g., 2026-01-15 -->
> **Current Position:** <!-- KICKOFF:CURRENT_POSITION -->

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

<!-- KICKOFF:QUEUE_ENTRIES -->
