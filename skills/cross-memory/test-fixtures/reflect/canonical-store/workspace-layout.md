This fixture is a frozen canonical memory entry used to simulate Reference Set A (the canonical store) for the slug-collision test case. Candidates with a proposed slug that overlaps >= 0.85 with the slug `workspace-layout` should be dropped by the deterministic anti-redundancy filter. The two slug-collision candidates are `workspace-layout-convention` (from `git-log.md`) and `workspace-layout-guide` (from `plan-docs/plan-fixture-a.md`).

---
name: workspace-layout
category: tooling
scope: project
tags: [workspace, layout, monorepo, structure]
created_at: 2026-04-01T09:00:00Z
updated_at: 2026-04-01T09:00:00Z
---

This project follows a flat-root monorepo layout. The top-level directories are: `/src` for application source code, `/tests` for all automated tests, `/docs` for documentation, and `/tooling` for build and deployment scripts. Do not create nested package manifests or independent sub-project tooling without explicit approval from the architecture review.
