Frozen-input fixtures for the deterministic anti-redundancy filter in `/cross-memory reflect`. The M3 verify tasks consume these fixtures to walk the four reproducibility cases: slug-collision, tag-overlap, body-Jaccard threshold straddle, and supersede-collision.

## Directory layout

```
reflect/
├── README.md                 — this file
├── git-log.md                — frozen git log snapshot (Source-3 simulation)
├── plan-docs/                — frozen plan-doc slice (Source-4 simulation)
│   ├── plan-fixture-a.md     — plan doc for slug-collision candidate
│   └── plan-fixture-b.md     — plan doc for tag-overlap candidate
├── handoffs/                 — frozen handoff slice (Source-4 simulation)
│   ├── handoff-fixture-a.md  — handoff for body-Jaccard straddle candidates
│   └── handoff-fixture-b.md  — handoff for supersede-collision candidate
├── reflect_declined.md       — frozen ledger (Reference Set C simulation)
└── canonical-store/          — frozen canonical-store slice (Reference Set A simulation)
    ├── workspace-layout.md   — canonical memory: target for slug-collision
    ├── python-toolchain.md   — canonical memory: target for tag-overlap
    └── branch-naming.md      — canonical memory: target for supersede-collision
```

## Test cases covered

Each fixture file documents which case it serves in its opening paragraph. The four cases are:

1. **Slug-collision** — two candidates in `git-log.md` and `plan-docs/plan-fixture-a.md` have slug overlap >= 0.85 against `canonical-store/workspace-layout.md`. The deterministic filter drops them.
2. **Tag-overlap** — one candidate in `plan-docs/plan-fixture-b.md` shares 4+ tags with `canonical-store/python-toolchain.md`. The deterministic filter drops it.
3. **Body-Jaccard threshold straddle** — `handoffs/handoff-fixture-a.md` carries two candidates: one with a body-token Jaccard of ~0.69 (below the 0.70 threshold — should surface) and one at ~0.71 (at or above threshold — should be dropped). This pair exercises the exact threshold boundary.
4. **Supersede-collision** — one candidate in `handoffs/handoff-fixture-b.md` matches both `reflect_declined.md` (ledger entry) and `canonical-store/branch-naming.md` (canonical store). The decline-ledger rule takes precedence; the supersede flag never fires.

## Usage

These fixtures are stable and frozen. All dates are fixed to `2026-05-13`. All identifiers are stable string literals. Do not add time-relative references, live URLs, or content that changes between runs. Any modification that makes two consecutive verifier runs produce different filter output is a breaking change.
