<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Reflect decline ledger

## File path and lazy-create

Path: `~/.cross-memory/projects/<slug>/reflect_declined.md`, where `<slug>` is the active-project slug — the same slug used for `state.toml` and project-scope memory storage.

This file is created on the **first decline** within a project. A project that has never declined a reflect candidate has no ledger file; that is normal and expected. The file is not created at `init` time and is not pre-provisioned by any other subcommand.

## Entry format

Each declined candidate appends one `---`-delimited markdown entry to the file. Example:

```markdown
---
declined_at: 2026-05-13T12:00:00Z
candidate_id: c-2026-05-13-001
proposed_name: poetry-virtual-env-convention
category: conventions-implicit-in-code
scope: project:example-project
tags: [poetry, python, venv]
body_preview: "Project uses poetry for dependency management; venv lives at .venv at project root..."
source_evidence: "Source 3 — git log scan of pyproject.toml at <sha>"
run_id: reflect-2026-05-13-abcd
---
```

## Schema fields

| Field | Description |
| :--- | :--- |
| `declined_at` | ISO-8601 UTC timestamp of when the user declined the candidate. |
| `candidate_id` | Stable identifier the agent assigned to the candidate during distillation. |
| `proposed_name` | The slug the agent proposed for the would-be memory. |
| `category` | One of the four locked taxonomy categories. |
| `scope` | The scope the candidate would have been saved under (e.g., `user-global`, `project:<slug>`, `harness:<name>`). |
| `tags` | Array of tag strings. |
| `body_preview` | The first ~160 characters of the candidate body (with `…` truncation if longer). Used by the body-token Jaccard filter in subsequent runs. |
| `source_evidence` | A free-text pointer to the source artifact that surfaced the candidate (e.g., `"Source 3 — git log scan of pyproject.toml"`). |
| `run_id` | The reflect run identifier that surfaced the candidate. |

## Append-only contract

Each decline appends one new entry. The file grows monotonically — there is **no on-disk deduplication**. The reflect filter handles deduplication at read time by parsing the file as a list of tuples; no entry is ever removed or modified.

## Write ownership

The skill (the `/cross-memory` command implementation) writes this file when the user declines a candidate during a reflect run. The cross-memory agent reads the ledger as part of its distillation reference set, but does **not** append to it.

## Matching strategy

At the start of each reflect run, the ledger is parsed as a list of `(proposed_name, category, scope, tags, body_preview)` tuples. These tuples are fed into the deterministic anti-redundancy filter to drop candidates that repeat a previously declined entry. The filter signals are the same as those used for the canonical-store filter: slug overlap, tag overlap, and body-token Jaccard similarity.

## Test fixtures

Test fixtures for the deterministic filter live at `skills/cross-memory/test-fixtures/reflect/`; M3 verify tasks consume them to reproduce the slug-collision, tag-overlap, body-Jaccard threshold, and supersede-collision cases.
