This fixture is a frozen plan-document excerpt used to simulate Source-4 (plan-doc scan) input for the tag-overlap case. The candidate derived from this plan doc shares 4 tags with the canonical memory entry in `canonical-store/python-toolchain.md` (tags: `python`, `poetry`, `venv`, `dependency-management`). The deterministic filter must drop this candidate because 4+ shared tags trigger the tag-overlap rule, regardless of slug or body similarity.

---

## Frozen plan document — plan-fixture-b.md
## Date: 2026-05-13T12:00:00Z

### Scope

This document scopes a memory entry for the Python toolchain setup used in this project.

### Background

The project uses Python 3.11 with Poetry for dependency management. The virtual environment lives at `.venv` in the project root. Contributors must activate the venv before running any scripts or tests. This convention is not obvious from the repository structure alone, so it warrants a persistent memory entry.

### Proposed memory

**Proposed slug:** `python-toolchain-setup`
**Category:** tooling
**Scope:** project
**Tags:** [python, poetry, venv, dependency-management, python-3.11]
**Body:** This project uses Python 3.11 managed by Poetry. The virtual environment is at `.venv` in the project root. Activate with `poetry shell` or `source .venv/bin/activate`. Run `poetry install` after cloning. Do not install packages with pip directly — use `poetry add`.

---

## Derived candidate (for filter walk)

```
candidate_id:   c-fixture-plan-002
proposed_name:  python-toolchain-setup
category:       tooling
scope:          project
tags:           [python, poetry, venv, dependency-management, python-3.11]
body_preview:   "This project uses Python 3.11 managed by Poetry. The venv is at .venv in the project root. Activate with poetry shell..."
source_evidence: "Source 4 — plan-docs scan, plan-fixture-b.md"
```

**Filter expectation:** tags `python`, `poetry`, `venv`, `dependency-management` are all present in both this candidate and `canonical-store/python-toolchain.md`. That is 4 shared tags, which meets the tag-overlap threshold. The filter drops this candidate. This is the **tag-overlap** case.
