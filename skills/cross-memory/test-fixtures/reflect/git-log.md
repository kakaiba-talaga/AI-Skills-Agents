This fixture is a frozen git log snapshot used to simulate Source-3 (git history scan) input for the deterministic anti-redundancy filter. It carries one candidate whose proposed slug (`workspace-layout-convention`) has >= 0.85 overlap with the slug of `canonical-store/workspace-layout.md` (`workspace-layout`). The filter must drop this candidate on any run, regardless of body content or tags.

---

## Frozen git log — 2026-05-13T12:00:00Z

```
commit a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
Author: Dev User <dev@example.internal>
Date:   2026-05-13T10:00:00Z

    chore: normalize workspace layout to monorepo convention

    All projects under this repository follow a flat-root monorepo layout:
    - /src for application source
    - /tests for test suites
    - /docs for documentation
    - /tooling for build and deploy scripts

    The root-level README.md is the canonical entry point.
    No nested package.json or pyproject.toml at sub-directory level.

 tooling/setup.sh | 12 ++++++++++++
 docs/layout.md   |  8 ++++++++
 2 files changed, 20 insertions(+)

commit b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3
Author: Dev User <dev@example.internal>
Date:   2026-05-13T08:30:00Z

    docs: add workspace layout reference in onboarding guide

    Onboarding guide now links to docs/layout.md as the authoritative
    reference for workspace structure. New contributors should read
    this before creating sub-directories or adding tooling scripts.

 docs/onboarding.md | 4 ++++
 1 file changed, 4 insertions(+)
```

## Derived candidate (for filter walk)

The above git log scan yields the following candidate:

```
candidate_id:   c-fixture-git-001
proposed_name:  workspace-layout-convention
category:       tooling
scope:          project
tags:           [workspace, layout, monorepo, convention]
body_preview:   "Projects follow a flat-root monorepo layout: /src for source, /tests for tests, /docs for docs, /tooling for build scripts..."
source_evidence: "Source 3 — git log scan, commits a1b2c3d and b2c3d4e"
```

**Filter expectation:** slug `workspace-layout-convention` has >= 0.85 character overlap with canonical slug `workspace-layout` (the six-character prefix `workspace-layout` is common). The filter drops this candidate. This is the **slug-collision** case.
