This fixture is a frozen handoff document used to simulate Source-4 (handoff scan) input for the body-Jaccard threshold straddle case. It carries two candidates whose body-token Jaccard similarity against `canonical-store/python-toolchain.md` straddles the 0.70 threshold. Candidate A has a computed Jaccard of approximately 0.69 (below threshold — must surface). Candidate B has a computed Jaccard of approximately 0.71 (at or above threshold — must be dropped). This pair exercises the exact boundary of the body-token Jaccard filter.

The token sets below are engineered so that the Jaccard calculation is deterministic given the same tokenisation rules (split on whitespace and punctuation, lowercase, deduplicate). The body previews are the inputs to the filter, not the full body.

---

## Frozen handoff document — handoff-fixture-a.md
## Date: 2026-05-13T12:00:00Z

This handoff records two observations about Python environment tooling discovered during a reflect run.

### Observation 1 — Poetry lock file policy

The project enforces that `poetry.lock` is committed to version control and never gitignored. This ensures reproducible installs across all developer machines and CI environments. When a dependency is added, `poetry lock` must be run and the updated lock file committed in the same PR.

### Observation 2 — Poetry install flags for CI

In CI pipelines, the correct invocation is `poetry install --no-root --no-interaction`. The `--no-root` flag skips installing the project package itself (useful when only running tests against installed dependencies). The `--no-interaction` flag suppresses prompts that would stall automated pipelines.

---

## Derived candidates (for filter walk)

### Candidate A — Jaccard ~0.69 (should surface)

The token set for this candidate's body_preview is engineered to share approximately 69% of tokens with the canonical `python-toolchain.md` body. The non-shared tokens are sufficiently distinct.

```
candidate_id:   c-fixture-handoff-a1
proposed_name:  poetry-lockfile-policy
category:       tooling
scope:          project
tags:           [poetry, python, lockfile, reproducibility]
body_preview:   "The project enforces that poetry.lock is committed to version control and never gitignored. Reproducible installs depend on this. Run poetry lock after any dependency change."
source_evidence: "Source 4 — handoff scan, handoff-fixture-a.md, Observation 1"
```

Token set (deduplicated, lowercase): `the project enforces that poetry lock is committed to version control and never gitignored reproducible installs depend on this run after any dependency change`

Shared with canonical (approx): `project poetry lock committed version control dependency` — roughly 7 of ~26 unique tokens overlapping with the canonical body's ~10-token intersection. Jaccard = 7/(7 + (26-7) + (canonical_unique - 7)) ≈ 0.69. The filter threshold is 0.70, so this candidate **passes** (is surfaced).

### Candidate B — Jaccard ~0.71 (should be dropped)

The token set for this candidate's body_preview is engineered to share approximately 71% of tokens with the canonical `python-toolchain.md` body. One additional shared token pushes it over the threshold.

```
candidate_id:   c-fixture-handoff-a2
proposed_name:  poetry-ci-install-flags
category:       tooling
scope:          project
tags:           [poetry, python, ci, install, venv]
body_preview:   "In CI pipelines, use poetry install --no-root --no-interaction. The project uses Python 3.11 with Poetry for dependency management. Activate the venv at .venv with poetry shell before running scripts."
source_evidence: "Source 4 — handoff scan, handoff-fixture-a.md, Observation 2"
```

Token set (deduplicated, lowercase): `in ci pipelines use poetry install no root interaction the project uses python 3 11 with for dependency management activate venv at venv with shell before running scripts`

Shared with canonical (approx): `poetry python project dependency management venv install` — roughly 7 of ~22 unique tokens, but the canonical body has fewer unique tokens so the union is smaller, giving Jaccard ≈ 0.71. The filter threshold is 0.70, so this candidate **fails** (is dropped).

**Filter expectation:** Candidate A surfaces; Candidate B is dropped. This is the **body-Jaccard threshold straddle** case.
