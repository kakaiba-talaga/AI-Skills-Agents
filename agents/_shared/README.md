# Agent shared snippets (`agents/_shared/`)

**Module version:** 1.2.0 (add code-review-contract.md shared contract, 2026-06-06)

## Purpose

Deployable markdown companions shared across multiple agent contracts. Each snippet holds prose that would otherwise be duplicated in every agent `## Brief Format` subsection. Agents keep a **one-line `See` pointer** plus **agent-specific overrides** only (required-section lists, file-class allowlists, mode handling, and similar).

Canonical brief grammar and file-class tables remain in `~/.claude/skills/ops/brief-contract.md`. Snippets capture cross-agent defaults that repeat in the 14 brief-contract agents; they do not replace the contract.

## Pointer contract

| Tier | When | Template |
| :--- | :--- | :--- |
| **`See` (snippet)** | Agent self-read or brief validation needs shared defaults | `> **Reference:** See \`~/.claude/agents/_shared/<snippet>.md\` for …` |
| **`You MUST Read` (contract)** | Composing or validating full briefs | `You MUST Read \`~/.claude/skills/ops/brief-contract.md\` when composing or validating briefs.` |

Tiering matches [`skills/ops/pointer-format.md`](../../skills/ops/pointer-format.md): the snippet is loaded on demand; the contract is mandatory when authoring briefs.

**Repo paths:** Use `~/.claude/agents/_shared/…` in source. Cursor deploy rewrites to `~/.cursor/agents/_shared/…`. Do not hardcode `~/.cursor/` in repo agent or snippet files.

## Snippets

| File | Version | Contents |
| :--- | :--- | :--- |
| [`brief-format-snippet.md`](brief-format-snippet.md) | 1.0.0 | Default required/optional sections, Project Knowledge precedence, missing `## Acceptance Criteria`, internal inconsistency |
| [`code-intel-orchestrator-brief.md`](code-intel-orchestrator-brief.md) | 1.0.0 | JSON-fenced orchestrator brief schema, validation pseudocode, Constraints exemption, strict-cap rules |
| [`corpus-search-orchestrator-brief.md`](corpus-search-orchestrator-brief.md) | 1.0.0 | JSON-fenced orchestrator brief schema, validation pseudocode, Constraints exemption, strict-cap rules |
| [`code-review-contract.md`](code-review-contract.md) | 1.0.0 | Shared classification contract — exclusion list, scope-guardrail thresholds, severity tiers, verdict criteria, output template, language-specific checks; consumed by the `/code-review` skill and both code-reviewer agents |

Bump the **module version** in this README when adding snippets or making breaking semantic changes to shared defaults. Bump the per-snippet version column when only one file changes.

## Agents that include `brief-format-snippet.md`

These 14 pipeline/utility agents point at `~/.claude/agents/_shared/brief-format-snippet.md` from `## Brief Format` (grep `brief-format-snippet` to audit):

| Agent | Agent-specific overrides (examples) |
| :--- | :--- |
| `code-reviewer.md` | Read-only file-class; no `## Acceptance Criteria` required |
| `code-reviewer-diff.md` | Same as code-reviewer |
| `cross-memory.md` | Subcommand-specific brief shapes elsewhere in contract |
| `debugger.md` | Custom required/optional sections; missing `## Task` refuse |
| `debugger-build.md` | Build-error lane; inherits shared defaults via pointer |
| `documentor.md` | `docs` file-class; missing AC proceeds |
| `executor.md` | TDD mode; file-class allowlist; strict missing AC |
| `git-master.md` | Git operations scope |
| `project-scoper.md` | `plan-doc` file-class; mode ignored |
| `research.md` | Web-research lane; trust-boundary / URL-source rules; no Edit tool; missing AC proceeds |
| `security-reviewer.md` | Security-weighted Project Knowledge |
| `ssh-executor.md` | Deploy JSON brief + preamble PK |
| `verifier.md` | AC source priority; TDD commit-order check |
| `work-verifier.md` | Deliverable verdicts; missing AC proceeds |

## Agents that include JSON orchestrator brief companions

These agents use labeled-prose for humans and JSON-fenced blocks for orchestrators. The full schema lives in `_shared/`; the agent contract keeps format precedence, a `See` pointer, and a two-line orchestrator invariant:

| Agent | Companion |
| :--- | :--- |
| `code-intel.md` | [`code-intel-orchestrator-brief.md`](code-intel-orchestrator-brief.md) |
| `corpus-search.md` | [`corpus-search-orchestrator-brief.md`](corpus-search-orchestrator-brief.md) |

Agents without `## Brief Format` (e.g. architect, planner) do not include `brief-format-snippet.md` or orchestrator companions.

## Deploy manifest

[`tooling/deploy-manifest.json`](../../tooling/deploy-manifest.json) — agents category for Claude Code and Cursor:

```json
"include": ["**/*.md"],
"exclude": ["**/*_tmp_*"]
```

- All `.md` files under `agents/` deploy, including both `agents/README.md` and `agents/_shared/README.md`.
- Nested markdown under `_shared/` deploys to `~/.claude/agents/_shared/` (and `~/.cursor/agents/_shared/` on Cursor transform).

Dry-run check: `.\tooling\deploy.ps1 -Target cursor -Category agents -DryRun` — expect `brief-format-snippet.md`, orchestrator brief companions, and this file in the upsert set.

## Adding a snippet or contract

1. Add `agents/_shared/<name>.md` (a `-snippet.md` brief-format companion or a `-contract.md` shared contract) with `~/.claude/` paths.
2. Document it in the table above; list consuming agents.
3. Replace duplicated paragraphs in agents with one `See` line; keep overrides only.
4. Confirm manifest still uses `**/*.md` (no top-level-only regression).
5. Update [`agents/README.md`](../README.md) § Shared snippets if the pointer pattern changes.
