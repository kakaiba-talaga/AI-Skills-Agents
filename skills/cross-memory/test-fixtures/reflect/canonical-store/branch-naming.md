This fixture is a frozen canonical memory entry used to simulate Reference Set A (the canonical store) for the supersede-collision test case. The candidate `branch-naming-convention` from `handoffs/handoff-fixture-b.md` matches both this canonical entry and the decline ledger entry in `reflect_declined.md`. The filter checks the decline ledger first; because the ledger match fires, the candidate is dropped before the supersede path is evaluated. This entry exists to confirm that the supersede path would have been available if the ledger had not taken precedence — i.e., the collision is genuine.

---
name: branch-naming
category: workflow
scope: project
tags: [git, branching, convention, naming]
created_at: 2026-02-20T14:00:00Z
updated_at: 2026-02-20T14:00:00Z
---

Branch names in this repository follow the pattern `<type>/<short-description>`. Recognised types: `feat`, `fix`, `chore`, `docs`, `refactor`. A pre-receive hook enforces the naming convention on push; branches that do not match are rejected with an explanatory error message.
