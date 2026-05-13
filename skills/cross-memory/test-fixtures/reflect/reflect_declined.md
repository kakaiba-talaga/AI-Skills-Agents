This fixture is a frozen decline ledger used to simulate Reference Set C (the per-project `reflect_declined.md` file) for the deterministic anti-redundancy filter. It contains one entry that covers the supersede-collision case: the `branch-naming-convention` candidate in `handoffs/handoff-fixture-b.md` matches this ledger entry, causing the filter to drop that candidate before it can reach the supersede path. The ledger format follows the append-only `---`-delimited markdown convention documented in the `## Reflect decline ledger` section of SKILL.md.

---
declined_at: 2026-05-13T12:00:00Z
candidate_id: c-fixture-ledger-001
proposed_name: branch-naming-convention
category: workflow
scope: project
tags: [git, branching, convention, naming, workflow]
body_preview: "Branch names follow <type>/<short-description>. Types: feat, fix, chore, docs, refactor. Non-conforming branches are rejected by the pre-receive hook."
source_evidence: "Source 4 — handoff scan, prior-run-handoff.md"
run_id: reflect-2026-05-13-fixture
---
