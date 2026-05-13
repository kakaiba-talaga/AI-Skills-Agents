This fixture is a frozen canonical memory entry used to simulate Reference Set A (the canonical store) for the tag-overlap test case. Any candidate that shares 4 or more tags with this entry should be dropped by the deterministic anti-redundancy filter. The tag-overlap candidate is `python-toolchain-setup` from `plan-docs/plan-fixture-b.md`, which shares the tags `python`, `poetry`, `venv`, and `dependency-management` with this entry. It also serves as the body-token Jaccard reference for the threshold straddle case in `handoffs/handoff-fixture-a.md`.

---
name: python-toolchain
category: tooling
scope: project
tags: [python, poetry, venv, dependency-management, python-3.11]
created_at: 2026-03-15T10:00:00Z
updated_at: 2026-03-15T10:00:00Z
---

This project uses Python 3.11 managed by Poetry. The virtual environment is located at `.venv` in the project root. To activate: `poetry shell` or `source .venv/bin/activate`. To install all dependencies: `poetry install`. Always use `poetry add` to add new packages — never install directly with pip. The `poetry.lock` file is committed and must be kept up to date.
