This fixture is a frozen plan-document excerpt used to simulate Source-4 (plan-doc scan) input. It carries a second slug-collision candidate (`workspace-layout-guide`) whose slug overlaps >= 0.85 with the canonical slug `workspace-layout` in `canonical-store/workspace-layout.md`. Together with `git-log.md`, this fixture ensures the slug-collision case is covered by two independent candidates, demonstrating that the filter applies the check for every candidate independently.

---

## Frozen plan document — plan-fixture-a.md
## Date: 2026-05-13T12:00:00Z

### Scope

This document scopes the workspace layout guide for new contributors joining the project.

### Background

Repositories in this organisation use a consistent monorepo layout. The layout has been stable since 2026-01-01. New contributors need a concise guide explaining the top-level directory structure so they can orient quickly without reading the full architecture documentation.

### Proposed memory

A project-scoped memory entry should be created to surface the workspace layout guide to any agent context that involves creating or moving files.

**Proposed slug:** `workspace-layout-guide`
**Category:** tooling
**Scope:** project
**Tags:** [workspace, layout, monorepo, guide, onboarding]
**Body:** This project follows a flat-root monorepo layout. Top-level directories: `/src` for application source, `/tests` for automated tests, `/docs` for documentation, `/tooling` for deployment and build scripts. Do not create nested package manifests or sub-directory tooling without approval.

---

## Derived candidate (for filter walk)

```
candidate_id:   c-fixture-plan-001
proposed_name:  workspace-layout-guide
category:       tooling
scope:          project
tags:           [workspace, layout, monorepo, guide, onboarding]
body_preview:   "This project follows a flat-root monorepo layout. Top-level directories: /src for source, /tests for tests, /docs for docs..."
source_evidence: "Source 4 — plan-docs scan, plan-fixture-a.md"
```

**Filter expectation:** slug `workspace-layout-guide` has >= 0.85 overlap with canonical slug `workspace-layout`. The filter drops this candidate. This is the **slug-collision** case (second candidate).
