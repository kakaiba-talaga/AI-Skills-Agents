This fixture is a frozen handoff document used to simulate Source-4 (handoff scan) input for the supersede-collision case. The candidate derived from this handoff matches both an entry in `reflect_declined.md` (the decline ledger) and an entry in `canonical-store/branch-naming.md` (the canonical store). Per the filter's precedence rule, the decline-ledger check runs first; because the ledger entry matches, the candidate is dropped at the filter stage and the supersede path is never reached. This verifies that the ledger takes precedence over the supersede logic.

---

## Frozen handoff document — handoff-fixture-b.md
## Date: 2026-05-13T12:00:00Z

### Observation — Branch naming convention

This project enforces a branch naming convention of `<type>/<short-description>` where `<type>` is one of `feat`, `fix`, `chore`, `docs`, or `refactor`. Examples: `feat/add-reflect-subcommand`, `fix/slug-collision-edge-case`, `chore/update-dependencies`. Branches that do not follow this format are rejected by the pre-receive hook.

---

## Derived candidate (for filter walk)

```
candidate_id:   c-fixture-handoff-b1
proposed_name:  branch-naming-convention
category:       workflow
scope:          project
tags:           [git, branching, convention, naming, workflow]
body_preview:   "Branch names follow <type>/<short-description>. Types: feat, fix, chore, docs, refactor. Non-conforming branches are rejected by the pre-receive hook."
source_evidence: "Source 4 — handoff scan, handoff-fixture-b.md"
```

**Filter expectation:**
1. The filter checks the decline ledger (`reflect_declined.md`) first. The ledger contains an entry with `proposed_name: branch-naming-convention`, `category: workflow`, `scope: project`. The slug overlap, tag overlap, and body-token Jaccard all match the threshold — this candidate matches the ledger.
2. Because the ledger match fires, the candidate is dropped immediately. The filter does not proceed to check the canonical store.
3. The canonical store (`canonical-store/branch-naming.md`) also contains a matching entry. However, the supersede path (which would flag the canonical entry for update) is never evaluated because the ledger match already terminated the filter for this candidate.

This is the **supersede-collision** case: the decline-ledger-takes-precedence rule is exercised.
