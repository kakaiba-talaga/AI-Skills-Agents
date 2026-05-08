# Architecture Decision Document: Cross-Memory Skill and Agent

> **Authoritative input:** `docs/cross-memory/requirements.md` (12 settled decisions, SC-1 through SC-14, OQ-1 through OQ-9). The settled decisions are out-of-bounds for re-litigation. This ADD resolves OQ-1, OQ-2, OQ-3, OQ-4, OQ-7, OQ-8, OQ-9 and justifies why OQ-5 and OQ-6 stay open.

---

## Revision History

| Date | Revision | Origin |
| :--- | :--- | :--- |
| 2026-05-08 | Inline `<private>` tags as a privacy complement (Decision 14, §9 + §12 + §14 + SC-15) | User feedback after reviewing the original ADD; concept adapted from `supermemoryai/opencode-supermemory` README |
| 2026-05-08 | Concrete `[CROSS-MEMORY]` injection format (Decision 15, §4 + §12 + SC-16) | Same — format adapted from `supermemoryai/opencode-supermemory` README; confidence scores deferred to post-v1 |
| 2026-05-08 | Optional `category` frontmatter alongside `type` (Decision 16, §3 + §4 + §10 + SC-17) | Same — semantic typing adapted from `supermemoryai/opencode-supermemory` memory taxonomy |
| 2026-05-08 | Non-goal wording clarified — project-fact distillation IS in scope (Decision 17, §1 + §14 + SC-18) | Same — boundary clarified after `/supermemory-init` precedent surfaced; codebase-exploration command deferred to post-v1 |
| 2026-05-08 | Critic-driven revisions (Findings 1–5): mirror landing path resolved via sentinel-bounded MEMORY.md region (Decision 18); slug rule rewritten against observed filesystem (Decision 19, supersedes Decision 1); audit reports declared chat-only (Decision 20, removes `audit-reports/` from §8); deploy-manifest globs corrected against `tooling/deploy-manifest.json` (Decision 21, §11); cross-memory-specific lane allowlist replaces "verbatim from code-intel" claim (Decision 22, §8). New SCs SC-19 / SC-20 / SC-21 added. | `docs/cross-memory/critic-review.md` Findings 1–5 |
| 2026-05-08 | Decision 19 re-derivation (critic R2 Finding 2 residual): slug rule expanded to replace `:`, `\`, `/`, space, and `.` — derived from the complete `~/.claude/projects/` listing (nine entries) and tested against every entry. Worked-examples table corrected; the prior pass's hypothetical `C:\Users\Maris\Reyes\.claude` footnote refuted with `ls` output. New sub-decision documents the bail-and-route operational behavior when the heuristic disagrees with the live filesystem. | `docs/cross-memory/critic-review-r2.md` Finding 2 (NOT RESOLVED, CRITICAL) |

The six revisions above are the user-approved post-review additions. The original 13 decisions are unchanged in intent; Decision 1's contradictory wording is corrected in place and superseded by the evidence-grounded Decision 19. The first Decision 19 revision (row 5) introduced a fresh defect — its rule contradicted one of the observed slugs because the architect dismissed the contradiction with a hypothetical path; row 6 corrects that defect. OQ-5 and OQ-6 remain open; OQ-6's wording is lightly refined in §16 to reflect Decision 17.

### Verification log (2026-05-08, critic-driven revisions)

Every claim added or corrected in this revision was checked against the live host before being written. Two of the five claims below were honest at the time of writing; the third (slug-rule derivation) was incomplete and produced a rule one observed entry refutes — corrected in the supplementary log below.

- `ls ~/.claude/projects/` returned `D--Repositories-Personal-Git-AI-Skills-Agents` and eight peers (nine entries total). The peer set is fully enumerated in the Decision 19 re-derivation log below; treat the supplementary log as authoritative for any rule reasoning.
- `Glob "*.md"` inside `~/.claude/projects/D--Repositories-Personal-Git-AI-Skills-Agents/memory/` returned 16 files: a `MEMORY.md` plus 15 separate `<type>_<slug>.md` files. Confirms the dual pattern (index file + per-memory files).
- The active session's `# auto-memory` block injected the literal contents of `MEMORY.md` (15 bullet lines, link-formatted) as a single contiguous block. The per-memory `.md` files are referenced from `MEMORY.md` but not auto-prepended individually. Confirms the index-as-injection-source mechanism.
- `Read("tooling/deploy-manifest.json")` returned: claude-code `skills.include = ["**/*.md","**/*.yaml"]`, `skills.exclude = ["**/SKILL.cursor.additions.md"]`; cursor `skills.include = ["**/*"]`, `skills.exclude = ["kickoff/**"]`, `transform: true`; cursor `agents.include = ["*.md"]`, `agents.exclude = ["README.md"]`, `transform: true`. Used verbatim in §11.
- `Read("agents/code-intel.md")` lines 126–145 confirmed three write-allowlist globs (`.code-intel/**`, `docs/code-intel/**`, `_tmp_*`) and an explicit Bash allow/deny list. The "verbatim" claim from the prior ADD is contradicted; cross-memory's allowlist is now derived from cross-memory's actual write surface.

### Verification log (2026-05-08, Decision 19 re-derivation)

Critic R2 Finding 2 (NOT RESOLVED, CRITICAL) reopened Decision 19. The prior pass's rule replaced only `{:, \, /}` and explicitly preserved spaces — but the observed slug `C--Users-Maris-Reyes--claude` could not be produced from `C:\Users\Maris Reyes\.claude` under that rule. The architect's prior-pass footnote dismissed the contradiction by citing a non-existent path `C:\Users\Maris\Reyes\.claude`. This re-derivation tests every observed slug against the candidate rule and reproduces verbatim the Bash output that grounds each claim.

**Command 1.** `ls ~/.claude/projects/` (live host, 2026-05-08, nine entries):

```text
C--Users-Maris-Reyes
C--Users-Maris-Reyes--claude
D--Repositories-Alivate-Git-claude-code
D--Repositories-Alivate-Git-formula-quote
D--Repositories-Alivate-Git-majic-web
D--Repositories-Alivate-Git-pdf-to-ifc
D--Repositories-Devinium-pasta
D--Repositories-Personal-Git-AI-Skills-Agents
D--Repositories-Personal-Git-DBA
```

**Command 2.** `ls 'C:/Users/Maris Reyes/.claude' 2>&1` — confirms the path with the literal space exists (truncated to load-bearing entries):

```text
CLAUDE.md
agents
commands
projects
settings.json
skills
...
```

**Command 3.** `ls 'C:/Users/Maris\Reyes' 2>&1` — confirms the prior pass's hypothetical path does NOT exist:

```text
ls: cannot access 'C:/Users/Maris\Reyes': No such file or directory
```

The prior pass's worked-example footnote is therefore filesystem-falsified: there is no `Maris\Reyes\` subdirectory; the slug `C--Users-Maris-Reyes--claude` originates from `C:\Users\Maris Reyes\.claude` (a single user-folder path containing a literal space).

**9-row test table** (every observed slug must be reproducible by the candidate rule). Candidate rule: replace each occurrence of any character in the set `{:, \, /, space, .}` with a single `-`; case preserved; no leading-dash trim; consecutive separators each contribute one `-` (no collapsing).

| # | Observed slug | Candidate path | Separators replaced | Derived slug | Match? |
| :- | :--- | :--- | :--- | :--- | :--- |
| 1 | `C--Users-Maris-Reyes` | `C:\Users\Maris Reyes` | `:`, `\`(×2), space | `C--Users-Maris-Reyes` | yes |
| 2 | `C--Users-Maris-Reyes--claude` | `C:\Users\Maris Reyes\.claude` | `:`, `\`(×3), space, `.` | `C--Users-Maris-Reyes--claude` | yes |
| 3 | `D--Repositories-Alivate-Git-claude-code` | `D:\Repositories\Alivate\Git\claude-code` | `:`, `\`(×4) | `D--Repositories-Alivate-Git-claude-code` | yes |
| 4 | `D--Repositories-Alivate-Git-formula-quote` | `D:\Repositories\Alivate\Git\formula-quote` | `:`, `\`(×4) | `D--Repositories-Alivate-Git-formula-quote` | yes |
| 5 | `D--Repositories-Alivate-Git-majic-web` | `D:\Repositories\Alivate\Git\majic-web` | `:`, `\`(×4) | `D--Repositories-Alivate-Git-majic-web` | yes |
| 6 | `D--Repositories-Alivate-Git-pdf-to-ifc` | `D:\Repositories\Alivate\Git\pdf-to-ifc` | `:`, `\`(×4) | `D--Repositories-Alivate-Git-pdf-to-ifc` | yes |
| 7 | `D--Repositories-Devinium-pasta` | `D:\Repositories\Devinium\pasta` | `:`, `\`(×3) | `D--Repositories-Devinium-pasta` | yes |
| 8 | `D--Repositories-Personal-Git-AI-Skills-Agents` | `D:\Repositories\Personal\Git\AI-Skills-Agents` | `:`, `\`(×4) | `D--Repositories-Personal-Git-AI-Skills-Agents` | yes |
| 9 | `D--Repositories-Personal-Git-DBA` | `D:\Repositories\Personal\Git\DBA` | `:`, `\`(×4) | `D--Repositories-Personal-Git-DBA` | yes |

All nine match. **Falsification checks against narrower rules:** removing `.` from the set fails row 2 (would derive `C--Users-Maris-Reyes-.claude`, single dash before `claude`); removing space fails rows 1 and 2 (would preserve `Maris Reyes` literally); removing both is the prior-pass rule that the critic falsified. The set must include all five characters.

**Spot-checks of three project paths on disk** (verification protocol step 4):

- `ls 'D:/Repositories/Personal/Git/AI-Skills-Agents'` returned the project root contents (`CLAUDE.md`, `README.md`, `agents`, `docs`, `hooks`, `settings.json`, `skills`, `tooling`). Path exists.
- `ls 'D:/Repositories/Personal/Git/DBA'` returned `CLAUDE.md`, `PostgreSQL`, `SQL_Server`, `docs`. Path exists.
- `ls 'D:/Repositories/Devinium/pasta'` returned the multi-crate Rust workspace contents. Path exists.
- `ls 'D:/Repositories/Alivate/Git/claude-code'` returned `No such file or directory`. The slug remains in `~/.claude/projects/` from a session whose `cwd` previously pointed there; the directory has since been removed or renamed. This does not refute the rule — the slug is consistent with the rule applied to the historical path.

**Rule adopted.** Replace each occurrence of any character in `{:, \, /, space, .}` with a single `-`; case preserved; no leading-dash trim. Reason: this is the smallest character set that reproduces every observed slug from its corresponding live-host path with no contradictions.

---

## Context

Cross-memory introduces a harness-portable memory layer that turns the assistant from stateless-per-session into a continuing collaborator across sessions, projects, and harnesses. The core design challenge is that the canonical store at `~/.cross-memory/` must coexist with — and feed into — Claude Code's existing per-project memory at `~/.claude/projects/<slug>/memory/` without breaking auto-injection or duplicating conventions. If implementation proceeds without this ADD, the planner will face open structural questions on every milestone: how harness identity is detected, where the redaction logic lives, how mirrors stay one-way, and whether the agent or the skill owns each write. That ambiguity would either stall planning or — worse — produce a plan with implicit answers that the executor would then bake into code.

This document gives the planner crisp boundaries: the canonical store is the single source of truth; the skill owns user-facing flow control and redaction; the agent owns synthesis and audit; adapters are thin sidecars per harness. Every architecturally significant decision is recorded with options, recommendation, justification, and at least one rejected alternative.

---

## Decision Drivers

The drivers below are the constraints every option below is graded against. They derive from the requirements doc plus this repo's established conventions.

1. **Extend, never replace.** Per Decision 1 in the requirements interview log, cross-memory layers a sibling tier on top of Claude Code's existing memory. SC-14 demands that pre-existing files at `~/.claude/projects/<slug>/memory/` are byte-identical post-install. Any design that touches those files is rejected.
2. **Harness-agnostic canonical store.** Per Decision 7 and Goal G4, `~/.cross-memory/` is the only canonical path. Adapters mirror outward; mirrors are derived and never canonical.
3. **No silent writes.** Per Decision 5 and Goal G6, every persisted memory either originates from `/cross-memory save` or from a user-confirmed auto-proposal. Background workflows cannot persist memory without user authorization in the same conversation.
4. **Privacy by default.** Per Decision 6 and Goal G7, redaction runs before any user confirmation prompt for auto-proposed writes. The unredacted form is never persisted.
5. **Portability via the existing deploy pipeline.** This repo already deploys to Claude Code (`~/.claude/`), Claude Code WSL, and Cursor (`~/.cursor/`) via `tooling/deploy.{ps1,sh}` driven by `tooling/deploy-manifest.json`. Cross-memory must plug into this pipeline rather than introduce a separate installer.
6. **Match existing schema/index conventions.** The existing per-project memory format (`<type>_<slug>.md`, `MEMORY.md` index, frontmatter with `name`/`description`/`type`/`originSessionId`) is reused verbatim where possible (Decision 8, requirements §2-3) so mirroring is a copy, not a translation.
7. **Lane discipline.** Per the project's standing memory `feedback_strict_lane_boundaries.md` and `feedback_agent_contracts_are_code.md`, agents have narrow tool allowlists and review-type agents never write. The `cross-memory` agent gets `Write` only because synthesis-as-write doesn't apply — its writes are scoped to the canonical store and to the sentinel-bounded `MEMORY.md` region the adapter manages, never to source code or agent contracts.
8. **Brownfield-aware.** This repo has 19 existing agents and 11 skills. The new agent and skill must follow the same naming, deployment, and brief-contract conventions established by `skills/ops/brief-contract.md`, `agents/code-intel.md` (the precedent for JSON-fenced briefs), and the manifest at `tooling/deploy-manifest.json`.

---

## Existing Architecture

The relevant existing structure the planner needs in cache when reading the rest of this document:

### Repo layout

- `agents/*.md` — 19 agent definitions with YAML frontmatter (`name`, `model`, `description`, `tools`). Auto-deployed to `~/.claude/agents/` and `~/.cursor/agents/` (with transforms). README excluded from deploy.
- `skills/<name>/SKILL.md` + companions — 11 multi-file skills. Skills with Cursor-incompatible primitives carry a `SKILL.cursor.md` companion. **Skill READMEs (`skills/<name>/README.md`) DO deploy** to all three targets — only `agents/README.md` is excluded (via the agents block). See §11 (Decision 21).
- `tooling/deploy-manifest.json` — drives `deploy.ps1` and `deploy.sh`. Three targets (`claude-code`, `claude-code-wsl`, `cursor`); each has `agents`, `skills`, and (for Claude Code) `hooks` + `settings` blocks with `source`/`target`/`include`/`exclude`/`transform`. **The cursor `skills` block intentionally widens to `**/*` (not `**/*.md`) and excludes `kickoff/**` — see §11.**
- `tooling/transform-cursor-{ops,ralph-loop}.{ps1,sh}` — per-skill Cursor transforms invoked by the deploy script for skills that have a `SKILL.cursor.md` companion.

### Existing memory layout (Claude Code)

- Root: `~/.claude/projects/<slug>/memory/`.
- **Slug derivation: see Decision 19** (evidence-based rule). Verified against `~/.claude/projects/` on 2026-05-08; the directory for this project is `D--Repositories-Personal-Git-AI-Skills-Agents`.
- File-naming: `<type>_<slug>.md`. Frontmatter required: `name`, `description`, `type`, `originSessionId`. Body convention: lead sentence + `**Why:**` + `**How to apply:**`.
- **Index: `MEMORY.md`** with one line per memory in the format `- [Name](file.md) — <description>`. **The `MEMORY.md` index is the auto-injection source** — Claude Code reads `MEMORY.md` at session start and injects its contents verbatim into the session's context (visible in this very session as the `# auto-memory` block). The per-memory `.md` files are *referenced* from `MEMORY.md` but are not individually auto-prepended; they are loadable on demand via the link.
- This dual pattern (index file + separate per-memory files) is the canonical Claude Code shape. Cross-memory mirrors **into** this layout; it does not invent a new one.

### Brief contract conventions

- `skills/ops/brief-contract.md` — canonical four-section brief grammar (`## Task`, `## Scope`, `## Acceptance Criteria`, `## Constraints`) with optional `## Context`, `## Mode`, `## Handoff Artifacts`, `## Code Intelligence Context`. Universal across the dispatched-agent fleet.
- `agents/code-intel.md` (lines 57-117) — the precedent for JSON-fenced briefs with strict schema validation, used when the consumer is an orchestrator. Format precedence: JSON-fenced wins when present; labeled-prose only when no schema-matching JSON.
- The cross-memory agent will use **labeled-prose only** at v1 (it is never dispatched by the JSON-fenced orchestrator path; consumers are skills and agents that already produce prose briefs). See §8.

---

## 1. Component Map

The system has nine components. Each owns a single responsibility; none own more than one. The boundaries map directly to file-class segregation per the brief contract: skills and agents are `agent-contract`; the canonical store and config are runtime data, never `agent-contract`.

| # | Component | Repo path | Deployed path | Purpose |
| :-- | :--- | :--- | :--- | :--- |
| 1 | **Canonical store** | (runtime data — not in repo) | `~/.cross-memory/` | Single source of truth. Three scope subdirs + `archive/` + `config.yaml`. |
| 2 | **`/cross-memory` skill** | `skills/cross-memory/SKILL.md` (+ companions) | `~/.claude/skills/cross-memory/`, `~/.cursor/skills/cross-memory/` | User-facing slash command. Owns subcommand routing, argument parsing, redaction pipeline, confirmation UX, write flow. |
| 3 | **`cross-memory` agent** | `agents/cross-memory.md` | `~/.claude/agents/cross-memory.md`, `~/.cursor/agents/cross-memory.md` | Synthesis (curated context blocks) and audit (staleness/duplicate/contradiction/redaction-miss scan). Read-only on most paths; `Write` allowlisted per Decision 22 (§8). |
| 4 | **Redaction module** | `skills/cross-memory/redaction.md` | `~/.claude/skills/cross-memory/redaction.md`, `~/.cursor/skills/cross-memory/redaction.md` | Single source of denylist patterns. Consumed by both the skill (write-time redaction) and the agent (audit-time redaction-miss detection). Plain markdown — patterns expressed as labeled regex tables, not executable code. |
| 5 | **Adapter — Claude Code** | `skills/cross-memory/adapter-claude-code.md` | Same as skill | Mirrors `project:<slug>` canonical memories into `~/.claude/projects/<slug>/memory/` as separate `.md` files; manages the sentinel-bounded `[CROSS-MEMORY]` region inside `MEMORY.md` for always-on injection (Decision 18). Detects collisions. Reports harness identity as `claude-code`. |
| 6 | **Adapter — Cursor** | `skills/cross-memory/adapter-cursor.md` | Same as skill (post-transform) | Mirrors per Cursor's memory layout (TBD by adapter logic — not by this ADD). Reports harness identity as `cursor`. |
| 7 | **Adapter — generic** | `skills/cross-memory/adapter-generic.md` | Same as skill | No mirroring. Recall and explicit save are the only read/write paths. Reports harness identity as `generic`. |
| 8 | **Index module** | `skills/cross-memory/indexing.md` | Same as skill | Owns `MEMORY.md` line-format generation and read for each scope. v1 is per-scope only (see Decision 2 below). |
| 9 | **Audit/curation logic** | Inside the agent (`agents/cross-memory.md`) — not a separate file | Same as agent | Detects staleness, duplicates, contradictions, redaction misses. Returns a structured report **rendered to chat** (Decision 20). The skill orchestrates user confirmations on resolution actions. |

**Deployment.** Components 2-8 are picked up by the existing manifest entries. The exact globs differ between targets — see §11 (Decision 21) for the verified shapes. Components 2–8 ship as markdown only; the cross-memory skill writes no non-markdown files into `skills/cross-memory/` so the cursor target's wider `**/*` glob does not over-deploy.

Component 1 (the canonical store) is **not deployed** — it's user data. The skill provisions `~/.cross-memory/` lazily on first use (see §11, Decision 13).

### Scope boundary — clarified non-goal — Decision

> **Decision 17.** Cross-memory's non-goal is **external-knowledge RAG** — documents, books, third-party reference material. **Project-fact distillation** (build commands, architecture decisions, codebase conventions, error-solutions specific to a given project) IS in scope and is stored as `project:<slug>`-scoped memories with appropriate `category` values (see Decision 16). However, an explicit `init`-style codebase-exploration command (analogous to `/supermemory-init` in `supermemoryai/opencode-supermemory`) is **deferred to post-v1**. v1 ships the storage, schema, and skill commands needed for project facts; v1 users save those facts manually via `/cross-memory save --scope project --category project-config` (or any other appropriate `category`).

**Why this clarification matters.** The original requirements doc (§1) declares "not a general knowledge base / RAG system" as a non-goal. Read literally, that wording could be interpreted as forbidding all codebase facts — which would gut a major use case. The user clarified intent: external-knowledge RAG is the boundary; project-fact distillation lives inside the boundary because those facts ARE user/project facts about the work in front of them.

**Options considered:**

| Option | Description | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- | :--- |
| A — Clarify scope; defer init command (recommended) | Project-fact distillation is in scope; v1 supports manual save; codebase-exploration command (`/cross-memory init`) is post-v1. | Boundary stays meaningful; v1 ships sooner; gives the planner a concrete deferred item. | Power users who want one-shot codebase ingestion at install time wait for v2. |  High — adding an init command later is pure-add. |
| B — Remove the non-goal entirely | Maximally permissive; cross-memory could absorb any persisted text. | Simplest UX. | Real risk of cross-memory drifting into doc/book/RAG territory; conflicts with Decision 13 (non-goal: not a transcript archive); makes audit harder because "what belongs here" is undefined. | Medium — narrowing later means deprecating user data. |
| C — Forbid all project facts | Maximally restrictive; only user preferences and rules. | Trivial mental model; nothing to interpret. | Defeats SC-2 (per-project memory persists across harness changes); breaks the existing `feedback`/`project` types in the schema. | Low — would force schema rework. |

**Rationale.** Option A wins on all three counts: it preserves the original boundary where the boundary mattered (external-knowledge RAG out of scope), expands scope where the user explicitly said scope should expand (project facts in scope), and keeps v1 small by deferring the bulk-ingestion command. **Rejected:** Option B because cross-memory would lose its discipline — the entire point of the schema's `type` enum is to keep stored content small, framed, and durable; a permissive scope undoes that. **Rejected:** Option C because `project:<slug>` scope and `type: project` already exist in the requirements; forbidding project facts would mean retrofitting the requirements rather than refining a non-goal.

**Where the clarified wording surfaces in the ADD.** The §14 risk row "Cross-memory becomes a knowledge base" is updated to reflect the refined boundary. OQ-6 in §16 is lightly refined to reflect this clarification. No requirements doc edit is needed — the requirements doc's non-goal stands; this ADD is the architect's gloss on what it means in practice.

---

## 2. Storage Layout (Concrete)

### Directory tree

```text
~/.cross-memory/
├── config.yaml                              # User config; see §10
├── user-global/
│   ├── MEMORY.md                            # Per-scope index
│   ├── preference_python_pytest.md
│   ├── rule_no_commit_trailers.md
│   └── fact_user_email.md
├── projects/
│   ├── D--Repositories-Personal-Git-AI-Skills-Agents/
│   │   ├── MEMORY.md                        # Per-scope index
│   │   ├── feedback_strict_lane_boundaries.md
│   │   └── project_kickoff_design_principles.md
│   └── D--Repositories-Devinium-pasta/
│       ├── MEMORY.md
│       └── project_data_pipeline_layout.md
├── harnesses/
│   ├── claude-code/
│   │   ├── MEMORY.md
│   │   └── rule_no_compound_bash.md
│   ├── cursor/
│   │   ├── MEMORY.md
│   │   └── rule_use_strreplace.md
│   └── generic/
│       └── MEMORY.md
└── archive/
    ├── feedback_strict_lane_boundaries-20260301T143022Z.md
    └── project_kickoff_design_principles-20260415T091205Z.md
```

### Slug derivation — Decision

> **Decision 1 (original wording).** Project slugs in `~/.cross-memory/projects/<slug>/` are derived **identically** to Claude Code's slug derivation: take the absolute project path, replace path separators (`/`, `\`, `:`) with `-`, drop leading `-`. Example: `D:\Repositories\Personal\Git\AI-Skills-Agents` → `D--Repositories-Personal-Git-AI-Skills-Agents`.

**Correction (per critic Finding 2, 2026-05-08).** The "drop leading `-`" clause contradicts the example and the live filesystem. The example produces a leading double-dash (`D--`) because `D` + `-` (from `:`) + `-` (from `\`) yields `D--`; the actual slug on disk for this project at `~/.claude/projects/D--Repositories-Personal-Git-AI-Skills-Agents` keeps both leading dashes. Decision 1's "drop leading `-`" clause is **withdrawn** and superseded by Decision 19 below, which states the correct rule against observed evidence.

**Options considered (preserved for history):**

| Option | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- |
| A — Mirror Claude Code's exact scheme (recommended) | Mirroring is a literal copy; no translation step; same slug works in `~/.claude/projects/<slug>/memory/` and `~/.cross-memory/projects/<slug>/`. | Inherits any quirks of Claude Code's scheme (e.g., Windows drive letters produce `D--`). | High — slug is recoverable from path. |
| B — Hash the absolute path (e.g., SHA1 short) | Stable across path-format quirks; uniform length. | Slug is not human-readable; mirroring requires translation; harder to debug. | High — precomputed table can recover. |
| C — User-supplied project name | Human-readable. | Requires user input for every project; collision risk if two projects pick the same name; breaks the "no friction" default. | Medium — would need a migration. |

**Rationale (still holds).** Option A is the right shape — mirror Claude Code's scheme verbatim; the only correction is the rule itself, not the option choice. **Rejected:** Option B because the lack of human readability defeats the audit story (users browsing `~/.cross-memory/projects/` to find a project's memories).

### Slug derivation — Decision (re-derived against complete live listing, R2-corrected)

> **Decision 19 (supersedes Decision 1's rule wording; R2-corrected, per critic R2 Finding 2 residual).** Project slugs in `~/.cross-memory/projects/<slug>/` are derived from the absolute project path by **replacing each occurrence of any character in the set `{:, \, /, space, .}` with a single `-`, with no further transformation**. Letter case is preserved. Leading dashes are preserved. Consecutive separators each contribute one `-` (there is no collapsing — `\.` becomes `--`, `:\` becomes `--`).

The set was derived by enumerating all nine entries in `~/.claude/projects/` on the live host (2026-05-08) and finding the smallest character set that reproduces every observed slug from its corresponding absolute path. The full nine-row test is in the supplementary verification log under Revision History above.

**Worked examples (executor verifies their implementation against these):**

| Input absolute path | Derived slug | Match against `~/.claude/projects/` listing |
| :--- | :--- | :--- |
| `D:\Repositories\Personal\Git\AI-Skills-Agents` | `D--Repositories-Personal-Git-AI-Skills-Agents` | matches observed slug |
| `C:\Users\Maris Reyes` | `C--Users-Maris-Reyes` | matches observed slug (the literal space becomes `-`) |
| `C:\Users\Maris Reyes\.claude` | `C--Users-Maris-Reyes--claude` | matches observed slug (space → `-`, then `\` → `-`, then `.` → `-`, yielding `--` before `claude`) |
| `D:\Repositories\Devinium\pasta` | `D--Repositories-Devinium-pasta` | matches observed slug |
| `/home/ubuntu/Projects/AI-Skills-Agents` (Unix illustrative; not in the live listing) | `-home-ubuntu-Projects-AI-Skills-Agents` | leading-dash preservation illustrated |

**Refutation of the prior pass's footnote.** The first Decision 19 (revision row 5) claimed the slug `C--Users-Maris-Reyes--claude` came from a path containing a `\` between `Maris` and `Reyes` (i.e., `C:\Users\Maris\Reyes\.claude`). That path does not exist on the live host: `ls 'C:/Users/Maris\Reyes' 2>&1` returns `No such file or directory`, while `ls 'C:/Users/Maris Reyes/.claude' 2>&1` returns the directory's contents. The slug originates from a single user-folder path containing a literal space, not from a hypothetical subdirectory layout. The prior footnote is withdrawn.

The key invariants:

1. The set of characters replaced is exactly `{:, \, /, space, .}` — five characters. Hyphens, alphanumerics, and underscores are kept.
2. Each occurrence becomes a single `-` (not a sequence). Adjacent separators each contribute one `-` — for example, `\.` produces `--` and `D:\` produces `D--`.
3. **No leading-dash trimming.** The output may start with one or more `-` and that is correct (Unix paths produce a leading `-` from the leading `/`).
4. Letter case is preserved.
5. The rule is grounded in observation, not theory. If the live `~/.claude/projects/` listing on a future host does not match the rule's output for the active project, halt — see the operational sub-decision below.

**Verification against the live host (2026-05-08).** `ls ~/.claude/projects/` returned nine entries; the rule above produces every one of them exactly from the corresponding absolute project path. The 9-row test table in the supplementary verification log under Revision History is the canonical evidence — every entry passes. Cross-memory's `~/.cross-memory/projects/<slug>/` MUST match this scheme exactly so canonical files can be mirrored to the harness path with no translation step (driver 1, driver 2, driver 6).

**Options considered (R2-corrected):**

| Option | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- |
| A — Replace `{:, \, /, space, .}` with `-`; preserve leading dashes (recommended) | Reproduces every observed slug from its live-host path with zero exceptions; zero translation between canonical and mirror paths; rule fits in one sentence. | Slug starts with `-` on Unix paths; spaces and dots inside path components both contribute to slug length (visually unusual on `Maris Reyes` style folder names but accurate). | High — derived from the path. |
| B — Replace `{:, \, /}` only (the prior-pass rule) | Smaller character set; spaces and dots preserved verbatim. | Falsified by the live filesystem: produces `C--Users-Maris Reyes-.claude` for `C:\Users\Maris Reyes\.claude` while the observed slug is `C--Users-Maris-Reyes--claude`. Every Windows user-folder path containing a space mirrors to the wrong directory. SC-4 / SC-9 / SC-14 / SC-16 / SC-19 / SC-20 fail silently for those users. | Low — would force a re-mirror across every affected user. |
| C — Hash the path (e.g., SHA1 short) | Uniform length; no separator concerns. | Loses human readability; loses zero-translation property; defeats Decision 1's original rationale; would diverge from Claude Code's actual on-disk slug. | High but pointless. |

**Rationale.** Option A wins on driver 1 (extend, never replace) and driver 6 (match conventions). The reason Decision 1 originally chose mirror-Claude-Code's-scheme was correct; the rule wording is what was wrong twice — first because of the spurious leading-dash-trim clause (corrected in revision row 5), then because the character set was too narrow (corrected in this revision). **Rejected:** Option B because the live filesystem refutes it. **Rejected:** Option C because matching Claude Code's actual on-disk behavior is non-negotiable.

### Decision 19 sub-decision — operational behavior on heuristic disagreement

> **Decision 19a (per critic R2 R3).** When the rule above produces a slug that does not match an entry in `~/.claude/projects/` for the active project, the Claude Code adapter halts. It does not write a mirror; it does not write to any sentinel-bounded region; it returns a structured violation report to the calling skill or agent.

**Operational flow.** Before any Claude Code mirror write, the adapter runs a pre-flight: enumerate `~/.claude/projects/` (`ls`), derive the rule-based slug for the active project's absolute path, and confirm the derived slug matches one of the enumerated entries. If the rule-derived slug does not match an observed entry, the adapter halts with the message: `cross-memory pre-flight: rule-derived slug \`<X>\` does not match observed entry \`<Y>\` at ~/.claude/projects/; route to architect for rule re-derivation`. The adapter writes nothing on a halt — neither the per-memory mirror file nor the sentinel-bounded region of `MEMORY.md`.

**Why bail rather than guess.** Decision 19's rule is grounded in observation. The character set was chosen because it reproduces every observed slug exactly. If a future Claude Code release changes the scheme — adds a new separator, collapses consecutive dashes, lower-cases the input, etc. — the rule will silently produce wrong slugs and SC-4 / SC-9 / SC-14 / SC-16 / SC-19 / SC-20 will fail across every affected user. A halt-and-route-to-architect path makes the recovery deterministic: the user sees the violation, the architect re-derives the rule against the new evidence, and Decision 19 gets a third revision. M3.implement.1 already implements this pre-flight; this sub-decision documents it as part of Decision 19 itself so the recovery path is discoverable from the decision rather than buried in a task acceptance criterion. SC-20 covers verifier evidence that the pre-flight halts on a synthetic mismatch.

### MEMORY.md index granularity — Decision (resolves OQ-2)

> **Decision 2.** v1 ships **per-scope `MEMORY.md` only**. No global aggregate. Defer aggregate index to v2 alongside OQ-5 (post-v1 indexing).

**Options considered:**

| Option | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- |
| A — Per-scope only (recommended) | Mirrors existing convention; cheap to inject; no rebuild step; one-write-one-index-update. | Cross-scope search is `Glob` + `Grep` over the tree (`/cross-memory search` does this anyway). | High — adding an aggregate later is a pure-add. |
| B — Per-scope + rebuilt aggregate | Faster cross-scope search via single read. | Aggregate goes stale on every write; rebuild cadence becomes a design problem; adds a build step. | High — aggregate is a derived artifact. |
| C — Single global index | Cheapest cross-scope read. | Grows unbounded; mirrors fewer existing conventions; hard to inject selectively for the always-on tier. | Low — would require splitting later. |

**Rationale.** Option A wins on driver 6 (match conventions). v1's `/cross-memory search` is grep-style; `recall` substring-matches against tree contents directly; the always-on tier injects per-scope. The aggregate would only earn its keep alongside a real keyword/embedding index (OQ-5), so they should land together post-v1.

### Archive

Per requirements §6, archive filename pattern is `<original-stem>-<YYYYMMDDTHHMMSSZ>.md`. The timestamp is **UTC at the moment of archive write**. Archived files retain their original frontmatter but gain `superseded_by: <new-filename>` (only set on supersede; absent on plain `forget`). Archived files are **never** indexed in any `MEMORY.md`.

---

## 3. Schema (Concrete)

### Frontmatter — final

```yaml
# Required
name:           string                       # Human-readable title; matches the file's slug
description:    string                       # One-line summary
type:           feedback | project | preference | fact | rule
scope:          user-global | project:<slug> | harness:<name>
tags:           []                           # Array of strings; may be empty; never absent
created_at:     2026-05-08T14:32:01Z         # ISO-8601 UTC; immutable after first write
updated_at:     2026-05-08T14:32:01Z         # ISO-8601 UTC; refreshed on every supersede

# Optional
category:               project-config | architecture | error-solution | preference | learned-pattern | conversation | other
                                             # Semantic typing — see Decision 16; defaults to `other` when omitted
originSessionId:        string               # Session ID at time of capture (existing convention)
redacted:               true | false         # True if any auto-redaction rule fired
harness:                claude-code | cursor | generic    # Set automatically when known
superseded_by:          string               # Filename of the replacement (archived copies only)
verified_at:            ISO-8601 UTC         # Last user-confirmed-still-accurate timestamp
mirrored_from:          string               # Adapter-set; canonical filename for mirror collision detection (see §6, OQ-7)
redaction_overridden_at: ISO-8601 UTC        # Set when --no-redact was used; see §9, OQ-9
```

### Validation rules

- `type` must be one of the enumerated values. Other values are rejected at write time.
- `scope` must match one of the three forms; the `<slug>` / `<name>` portion is required when applicable.
- `tags` is required-but-may-be-empty (`tags: []`). Absent `tags` rejects the write.
- `created_at` is set on first write and never modified. Supersede writes preserve it from the predecessor.
- `mirrored_from` is **never** set on canonical files. It exists only on mirrored copies in harness-native paths.
- `superseded_by` is **never** set on canonical files. It exists only on archived copies after a supersede.
- `category`, when present, must be one of the seven enumerated values. Absent `category` defaults to `other` at read time. The skill MUST NOT auto-write `category: other` — absence is the canonical "uncategorized" signal.

### Body conventions

Per requirements §3, every memory body should lead with the rule/fact in one sentence, followed by `**Why:**` and `**How to apply:**` sections. The audit MAY warn when these are missing; it MUST NOT auto-rewrite. v1 enforces no body validation beyond non-emptiness.

### Optional `category` field — Decision

> **Decision 16.** Add an **optional `category`** frontmatter field alongside the existing required `type` field. `type` is origin-based (where this memory came from); `category` is semantic (what this memory represents). The two are orthogonal: a `type: feedback` memory might carry `category: preference` or `category: error-solution`. Defaults to `other` when omitted. The seven enumerated values — `project-config | architecture | error-solution | preference | learned-pattern | conversation | other` — are adapted from `supermemoryai/opencode-supermemory`'s memory taxonomy and chosen because they map cleanly onto the kinds of facts users actually persist.

**Why both `type` and `category`.** The existing `type` field (`feedback | project | preference | fact | rule`) was set in requirements §3 and is consumed by the always-on inclusion rules in requirements §5. Removing or renaming it would break the existing per-project memory files that Claude Code already auto-injects from `~/.claude/projects/<slug>/memory/` — a hard-stop violation of driver 1 (extend, never replace) and SC-14 (byte-identical pre-existing files). Adding `category` as an optional sibling preserves backwards compatibility while giving the always-on injection logic (Decision 15) a richer signal for filtering.

**Options considered:**

| Option | Description | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- | :--- |
| A — Add `category` alongside `type` (recommended) | Both fields exist; `type` required, `category` optional; orthogonal. | Backwards-compatible; richer semantic filtering; lets the User Profile / Project Knowledge sub-sections in Decision 15 filter by intent rather than origin. | Two enums to document; users must learn the distinction. | High — `category` is purely additive. |
| B — Replace `type` with `category` outright | One enum, semantic. | Cleaner schema. | Breaks every existing per-project memory file Claude Code auto-injects; violates driver 1 and SC-14; would force a migration the requirements doc explicitly rules out. | Low — would force schema-wide rework. |
| C — Skip `category`; reuse `tags` for semantic intent | No new field. | No schema change. | Tags are flat and case-insensitive (requirements §2); they don't carry the validation guarantees an enum gives; recall filtering by category becomes a string match against an unbounded set. | High — could add later. |

**Rationale.** Option A wins on driver 1 (extend, never replace) and driver 6 (match conventions). The existing per-project memory files keep working unchanged; new memories can carry richer signal; the always-on injection filter (§4) gets a cleaner predicate than "type heuristics." **Rejected:** Option B because it directly conflicts with the requirements' Extend mode and SC-14 (byte-identical pre-existing files). **Rejected:** Option C because tags are intentionally flat and don't enforce enumeration; we'd lose the validation that prevents typos like `category: error-soln` from creating ghost categories.

**Filter behavior:**

- `/cross-memory list --category <name>` — restrict listing to memories with the given category.
- `/cross-memory recall <topic> --category <name>` — restrict recall to memories with the given category. Composes with existing `--scope`, `--type`, `--tag` flags.
- Always-on tier (§4): when filtering for the User Profile sub-section, prefer `category: preference` (when present) over `type` heuristics. When filtering for Project Knowledge, prefer `category ∈ {project-config, architecture, learned-pattern}`.

**Migration / backfill.** Existing per-project memory files at `~/.claude/projects/<slug>/memory/` do not have `category`. They are treated as `category: other` until the user (or a future `/cross-memory audit` pass) backfills them. The audit subcommand flags missing `category` fields as a **curation opportunity, not an error** — the file is fully valid without it.

### Sample memory files

**`~/.cross-memory/user-global/preference_python_pytest.md`** (scope `user-global`, category `preference`):

```markdown
---
name: Python preference — pytest over unittest
description: Use pytest for all new Python tests; avoid unittest unless extending an existing unittest suite
type: preference
category: preference
scope: user-global
tags: [python, testing]
created_at: 2026-04-12T10:14:33Z
updated_at: 2026-04-12T10:14:33Z
originSessionId: 9c8d2a1f-2b4a-4f8c-9d3a-7e5b1f2c3d4e
redacted: false
verified_at: 2026-04-12T10:14:33Z
---

Use pytest for all new Python test code; reach for unittest only when extending an existing unittest suite.

**Why:** User stated this preference during the testing-conventions discussion on 2026-04-12. Pytest's fixtures and parametrization are the user's preferred default.

**How to apply:** When generating new test files, use `def test_*` functions, `pytest.fixture`, and `pytest.mark.parametrize`. Use `unittest.TestCase` only when adding tests to an existing TestCase class.
```

**`~/.cross-memory/projects/D--Repositories-Personal-Git-AI-Skills-Agents/feedback_no_silent_agent_writes.md`** (scope `project:<slug>`, category `architecture`):

```markdown
---
name: No silent agent writes to cross-memory
description: The cross-memory agent must never write to ~/.cross-memory/** without a user-confirmed message in the same conversation
type: feedback
category: architecture
scope: project:D--Repositories-Personal-Git-AI-Skills-Agents
tags: [cross-memory, lane-boundaries]
created_at: 2026-05-08T11:00:00Z
updated_at: 2026-05-08T11:00:00Z
originSessionId: 4e2f1a89-7c3d-44b1-8f9e-0a2c5d6e7f80
redacted: false
verified_at: 2026-05-08T11:00:00Z
---

The cross-memory agent must never write to `~/.cross-memory/**` without a user-confirmed message in the same conversation authorizing the write.

**Why:** Per Decision 5 in the requirements doc and Goal G6, no silent writes is a hard rule. Background workflows cannot persist memory unprompted.

**How to apply:** The agent's audit flow surfaces recommended actions but never applies them. The skill orchestrates the confirmation prompt; the agent only writes after the skill hands it an explicit `apply: true` directive in a follow-up dispatch.
```

**`~/.cross-memory/projects/D--Repositories-Personal-Git-AI-Skills-Agents/project_build_command.md`** (scope `project:<slug>`, category `project-config`) — illustrates the project-fact distillation use case clarified by Decision 17:

```markdown
---
name: Build command for AI-Skills-Agents
description: Project deploys via tooling/deploy.{ps1,sh}; no separate build step
type: project
category: project-config
scope: project:D--Repositories-Personal-Git-AI-Skills-Agents
tags: [build, deployment]
created_at: 2026-05-08T12:00:00Z
updated_at: 2026-05-08T12:00:00Z
originSessionId: 5f3c1a9b-8d4e-45c2-9f0a-1b3d5e7f9a0b
redacted: false
verified_at: 2026-05-08T12:00:00Z
---

Deploy command: `pwsh tooling/deploy.ps1` (Windows) or `bash tooling/deploy.sh` (Linux/macOS/WSL). There is no compile step — agents and skills are markdown shipped to harness paths.

**Why:** This project distributes prompt-engineered agent and skill definitions; the "build" is a file-copy with optional Cursor transforms.

**How to apply:** When the user asks "how do I deploy", point at `tooling/deploy.{ps1,sh}`. Do not suggest `npm run build` or `cargo build` — they don't exist here.
```

**`~/.cross-memory/harnesses/claude-code/rule_no_compound_bash.md`** (scope `harness:<name>`, category `learned-pattern`):

```markdown
---
name: No compound Bash on Claude Code
description: Never use &&, ;, or || to chain Bash commands; make separate Bash tool calls instead
type: rule
category: learned-pattern
scope: harness:claude-code
tags: [bash, tooling]
created_at: 2026-04-01T08:00:00Z
updated_at: 2026-04-01T08:00:00Z
originSessionId: 3a1c5e7f-9b2d-4f6a-8c1e-5d7f9a0b1c2d
redacted: false
verified_at: 2026-04-01T08:00:00Z
harness: claude-code
---

Never chain Bash commands with `&&`, `;`, or `||`. Make separate Bash tool calls; use parallel calls when independent.

**Why:** Claude Code's Bash tool runs each call in a fresh shell. Compound commands obscure failure isolation and make tool-call review harder.

**How to apply:** When two commands are independent, issue them as parallel Bash tool calls in the same message. When dependent, issue sequentially across messages or use a single shell script written to a `_tmp_*` file.
```

---

## 4. Read-Path Design

There are three read paths per requirements §5: always-on auto-inject, explicit recall, and on-demand agent synthesis.

### Always-on tier (auto-inject)

The always-on tier is computed at session start by the active adapter. Its inclusion rules in code-shaped pseudocode:

```python
def compute_always_on_tier(harness: str, project_slug: str | None) -> list[Memory]:
    """
    Returns the set of memories to inject at session start for the active harness.
    Order: user-global first, project second, harness-specific third, escape-hatch tagged last.
    """
    out = []

    # Identity and hard preferences belong in every session.
    out += load_scope("user-global").filter(type__in=["preference", "rule", "fact"])

    # Current-project context — bounded to the active project.
    if project_slug:
        out += load_scope(f"project:{project_slug}").filter(type__in=["feedback", "project", "rule"])

    # Harness-specific rules apply on every session in that harness.
    if harness:
        out += load_scope(f"harness:{harness}").filter(type__in=["rule", "feedback"])

    # Escape hatch — anything tagged `always-on` regardless of type/scope.
    out += load_all_scopes().filter(tags__contains="always-on")

    # De-dup (a memory tagged always-on may also match an inclusion rule).
    out = unique_by_canonical_path(out)

    # Render staleness banner inline; do NOT exclude stale memories.
    return [render_staleness_banner_if_due(m, today_utc()) for m in out]
```

**Injection mechanism per harness:**

- **Claude Code:** the adapter mirrors per-project memories as **separate `.md` files** into `~/.claude/projects/<slug>/memory/` (one mirror file per canonical project memory), then **renders the cross-session always-on tier as a single `[CROSS-MEMORY]` block written into a sentinel-bounded region inside `~/.claude/projects/<slug>/memory/MEMORY.md`** — see Decision 18 below. Claude Code's native auto-injection reads `MEMORY.md` at session start and injects its contents verbatim, so the sentinel-bounded `[CROSS-MEMORY]` block surfaces automatically. **Mirroring (the per-memory files) plus the sentinel-block update (in `MEMORY.md`) together comprise the injection path.** No new injection mechanism is added; cross-memory composes with Claude Code's existing index-as-source behavior.
- **Cursor:** the adapter writes harness-native files per Cursor's memory layout. The exact target path is delegated to the adapter (it's not a v1 architecture decision; it's an integration test).
- **Generic:** no auto-injection. The user runs `/cross-memory recall` explicitly.

### Mirror landing path on Claude Code — Decision (resolves Finding 1)

> **Decision 18 (per critic Finding 1).** On Claude Code, the always-on `[CROSS-MEMORY]` block lives **inside** `~/.claude/projects/<slug>/memory/MEMORY.md`, bounded by stable HTML-comment sentinel markers. The adapter manages only the bytes between the sentinels; everything else in `MEMORY.md` is preserved untouched.

**Sentinel format (literal):**

```text
<!-- cross-memory:begin -->
[CROSS-MEMORY]

User Profile:
- Prefers concise responses
- Uses pytest, not unittest, for new Python tests

Project Knowledge:
- Build command: bash tooling/deploy.sh — no separate compile step
- Strict lane boundaries: review-type agents never have Edit/Write
<!-- cross-memory:end -->
```

The two sentinel lines (`<!-- cross-memory:begin -->` / `<!-- cross-memory:end -->`) are the only on-disk markers the adapter looks for. They are HTML comments so any markdown renderer that processes `MEMORY.md` ignores them — but Claude Code's auto-injection treats `MEMORY.md` as raw text and injects everything verbatim, so the `[CROSS-MEMORY]` block surfaces in session context.

**Adapter behavior:**

1. **Bootstrap.** If `~/.claude/projects/<slug>/memory/MEMORY.md` does not exist, the adapter creates it as an empty file and writes only `<!-- cross-memory:begin -->` / `<!-- cross-memory:end -->` (with one blank line between them). It does NOT add native index entries.
2. **Read.** The adapter looks for the two sentinel lines. If both are present, the region between them is the cross-memory-managed content. If only one is present, the adapter treats this as a corrupted state and refuses-and-halts with a violation report (it will not guess where the region ends).
3. **Update.** When the always-on tier changes (canonical write, canonical forget, audit refresh), the adapter rewrites only the bytes between the sentinels. The pre-sentinel and post-sentinel content of `MEMORY.md` is read once and written back byte-identically.
4. **Coexistence with native entries.** Claude Code's existing per-project `MEMORY.md` index lines (like `- [No commit message trailers](feedback_no_commit_trailers.md) — ...`) remain wherever the user or Claude Code put them. The adapter never reorders or rewrites those lines. New per-memory mirror files written by the adapter (one `.md` per mirrored memory) DO get an index line added to `MEMORY.md` — but **outside** the sentinel block, in the normal Claude Code style. Those index lines are append-only from the adapter's perspective; the adapter never deletes a line it didn't create (and it tracks what it created via the sidecar manifest from Decision 6, not by re-parsing `MEMORY.md`).
5. **SC-14 composition.** The byte-identical guarantee in SC-14 protects pre-existing per-memory `.md` files at `~/.claude/projects/<slug>/memory/`. `MEMORY.md` is **not** a pre-existing per-memory file — it is the index. The byte-identical guarantee is therefore re-stated for the index: bytes outside the sentinel-bounded region are byte-identical pre- and post-install; bytes inside the region are managed by the adapter and may change on every always-on tier recompute. SC-19 below verifies this distinction.

**Options considered:**

| Option | Description | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- | :--- |
| A — Sentinel-bounded region inside `MEMORY.md` (recommended) | Adapter rewrites only the bytes between two HTML-comment markers; everything else preserved. Bootstrap creates `MEMORY.md` if absent. | Composes with Claude Code's existing auto-injection mechanism (no new path needed); lets the native entries and the cross-memory block coexist; SC-14's byte-identical guarantee adapts cleanly (apply it outside the sentinels). | Adapter must read+rewrite `MEMORY.md` on every always-on tier change; risk of corrupting native content if the rewrite logic is buggy. | High — region-only rewriting is reversible; restore from backup leaves only the cross-memory region missing. |
| B — Separate file (e.g., `cross-memory.md`) referenced from `MEMORY.md` via an index line | Adapter writes its own file; only adds one line to `MEMORY.md`. | Looks cleaner (one file, one purpose). | Empirical evidence (this very session's `# auto-memory` injection) shows Claude Code injects the **content** of `MEMORY.md` verbatim — it does NOT auto-load the linked-to files as separate context blocks. The `[CROSS-MEMORY]` block in a sibling file would not surface as auto-injection at all; only its index line would. The block would still need to live inside `MEMORY.md` to be injected. | Low — would have to migrate to Option A to restore auto-injection. |
| C — Rely on undocumented Claude Code behavior | Hope that Claude Code auto-loads linked files as separate blocks. | Zero adapter complexity. | No evidence supports this. The auto-injection observed in this session is `MEMORY.md`-content-only. Any v1 implementation depending on Option C would silently fail SC-4 and SC-16. | Low — discovered too late, real damage. |

**Rationale.** Option A wins on driver 1 (extend, never replace — the adapter only edits a sentinel-bounded region it owns; native entries are preserved) and driver 6 (match conventions — `MEMORY.md` is already the auto-injection source, so we use it). **Rejected:** Option B because the empirical evidence is unambiguous: the auto-memory block in this session is the literal contents of `MEMORY.md`, not a recursive injection of the linked files. A sibling file's content would not appear at session start. **Rejected:** Option C because shipping v1 against an undocumented hope is a Finding-1 repeat.

**Why HTML-comment sentinels.** They are inert in markdown rendering, easy to scan for in a string match, unambiguous (no chance of colliding with native content), and survive editor round-trips. Plain text markers like `### CROSS-MEMORY ###` would render as headings in some viewers and confuse the user; YAML frontmatter is reserved for the file's actual frontmatter; alternative comment forms (e.g., `<!--{cross-memory}-->`) add complexity for no gain.

### `[CROSS-MEMORY]` injection block format — Decision

> **Decision 15.** The always-on tier renders as a single `[CROSS-MEMORY]`-headed block with up to three named sub-sections — **User Profile**, **Project Knowledge**, **Relevant Memories** — followed by the rendered memories themselves. Bullets are unscored at v1; confidence percentages are deferred to post-v1 alongside indexing (OQ-5). The block has a configurable size budget; sections drop in priority order when over budget. Format adapted from `supermemoryai/opencode-supermemory` README. **Decision 18 (above) specifies where this block lives on disk** — inside the sentinel-bounded region of `MEMORY.md` on Claude Code.

**Why a concrete format.** Without a fixed block grammar, every adapter ends up rendering the always-on tier slightly differently and downstream agents can't reliably grep for it in transcripts or logs. The header `[CROSS-MEMORY]` is square-bracketed (distinct from any markdown the harness might render as bold or heading) and easy to scan in plain-text logs. The sub-section names are stable so agents can pattern-match on them.

**Concrete shape (as it appears between the sentinels):**

```text
[CROSS-MEMORY]

User Profile:
- Prefers concise responses
- Expert in TypeScript
- Uses pytest, not unittest, for new Python tests

Project Knowledge:
- Build command: bash tooling/deploy.sh — no separate compile step
- Existing per-project memory at ~/.claude/projects/<slug>/memory/ stays byte-identical
- Strict lane boundaries: review-type agents never have Edit/Write

Relevant Memories:
(empty at v1 — semantic similarity deferred to post-v1)
```

**Sub-section sourcing:**

| Sub-section | Source filter | v1 category preference (Decision 16) |
| :--- | :--- | :--- |
| **User Profile** | `scope: user-global` AND `type ∈ {user, preference, feedback}` | Prefer `category: preference` when present |
| **Project Knowledge** | `scope: project:<current-slug>` AND matches always-on inclusion rules in §4 pseudocode | Prefer `category ∈ {project-config, architecture, learned-pattern}` when present |
| **Relevant Memories** | Reserved for post-v1 semantic-similarity match against the active session's query | Empty at v1 — see "Relevant Memories at v1" below |

Each sub-section is rendered only if it has at least one matching memory. Empty sub-sections are **omitted** rather than shown with a "(none)" placeholder, except for **Relevant Memories** at v1 — see below.

**Per-bullet format.** Each memory renders as a single bullet:

```text
- <description>
```

The bullet text is the memory's `description` frontmatter field. Cap each bullet at **120 characters**; truncate longer descriptions with `…` (single Unicode ellipsis). The full memory body remains available via `/cross-memory recall <topic>`. Bullets are **unscored** at v1 — see "Confidence scores at v1" below.

**Relevant Memories at v1 — sub-decision.** v1 OMITS the entire `Relevant Memories:` sub-section header rather than rendering it as empty. Justification: an empty section header is cognitive noise; a future v1.x or v2 release that adds semantic similarity (OQ-5) reintroduces the header naturally as a pure-add. Rejected alternative: keeping the header rendered as `Relevant Memories: (none)` — costs four lines of prompt budget every session for no v1 signal.

**Confidence scores at v1 — sub-decision.** `supermemoryai/opencode-supermemory` renders bullets with `[NN%]` similarity scores. v1 omits the scores entirely. Justification: confidence requires semantic similarity, which requires indexing, which is OQ-5 (post-v1 by user decision). Faking a score (e.g., always 100%) is worse than omitting it — it teaches the model and the user to ignore the number, which devalues the field when real scores arrive in v2. Rejected alternative: ship `[100%]` on every bullet as a placeholder — rejected because dishonest UI compounds over time.

**Size budget.** Configurable via `~/.cross-memory/config.yaml` `max_inject_chars:` (default **2048**). When the rendered block exceeds the budget, drop in this priority order until it fits:

1. **Relevant Memories** — drop entire section (it's already empty at v1; this slot is reserved for v2 when scores exist).
2. **Project Knowledge** — drop oldest memory by `updated_at` first; iterate.
3. **User Profile** — drop oldest memory by `updated_at` first; iterate.
4. **Header `[CROSS-MEMORY]`** — never dropped. If the budget is below the header's footprint, log a warning and inject only the header with no body (the header remains a stable signal that cross-memory is active).

**Options considered:**

| Option | Description | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- | :--- |
| A — Three-section bulleted prose block (recommended) | `[CROSS-MEMORY]` header, three named sub-sections, prose bullets sourced from memory `description` field. | Adapted from a working precedent (supermemoryai/opencode-supermemory); easy for both humans and models to consume; size-budget drop order is straightforward; sub-sections give the model semantic grouping. | Slightly more rendering logic than a flat list. | High — format can evolve; the header tag protects compatibility. |
| B — Flat list, no sub-sections | One header, all memories as bullets. | Simplest renderer. | Loses the grouping; the model can't tell user-global from project-scope without reading each line; size-budget drop order is arbitrary. | High. |
| C — JSON block | Structured payload with explicit fields. | Programmatic consumption is unambiguous. | Humans and models both find prose-style bullets easier to consume; JSON adds noise without adding precision; the harness's prompt formatter may render JSON inconsistently. | High. |
| D — Inline natural-language summary (no block) | The adapter writes a paragraph: "The user prefers pytest, expects concise responses, and..." | Most natural. | Loses grep-ability; no stable structure for downstream tools to parse; the LLM has to re-derive structure on every read. | Medium. |

**Rationale.** Option A wins on driver 6 (match existing conventions — `supermemoryai/opencode-supermemory` is a well-trodden precedent for this exact pattern) and on driver 8 (brownfield-aware — a stable header tag means agents and skills can confidently grep for `[CROSS-MEMORY]` in logs and transcripts). **Rejected:** Option C (JSON) for the reasons in the table — humans and models read prose better than JSON in this context. **Rejected:** Option D (inline natural-language summary) because it makes the always-on tier invisible to downstream tooling; the audit needs a structured signal it can verify ran.

**Rendering pipeline.** The Section 12(b) read-flow diagram is updated to show the rendering order: scope query → always-on filter → format pipeline → size-budget enforcement → sentinel-bounded write into `MEMORY.md` → Claude Code's native auto-injection picks it up.

### `/cross-memory recall <topic>`

Topic-targeted retrieval per requirements §5. v1 implementation: case-insensitive substring match against `name`, `description`, `tags`, and body content. No ranking, no fuzzy match. Optional flags: `--scope`, `--type`, `--tag`, `--category` (Decision 16), `--include-stale` (no-op at v1; reserved). Output: matching memories rendered with full body, ordered by `updated_at` descending. Staleness banner rendered inline when due.

### `/cross-memory search <query>`

Distinct from `recall`. Grep-style: returns `<path>:<line>: <matched-line>` triples. No body rendering, no synthesis, no ranking. Use case: "show me every memory mentioning `pytest`". Implementation is a single `Grep` invocation across `~/.cross-memory/**` (excluding `archive/`).

### Agent synthesis (`cross-memory` agent, `intent: synthesize`)

When a calling agent or skill wants a curated context block instead of a raw match list, it dispatches the `cross-memory` agent with a labeled-prose brief. The agent reads the relevant scope subdirectories, filters by query relevance, and returns a markdown block with sections **User preferences**, **Project context**, **Harness rules**, **Notes / staleness warnings**. Inline citations: each memory's filename appears in parentheses after the relevant claim. Default size budget: 4000 characters. See §8 for the full input/output contract.

### Indexing — Decision

> **Decision 3.** v1 ships **no indexing**. `recall` and `search` use `Glob` + `Grep` against the tree directly. Defer keyword/embedding indexing to v2 (OQ-5 stays open).

**Options considered:**

| Option | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- |
| A — No index, grep on demand (recommended) | Zero build step; zero staleness; matches existing `MEMORY.md`-driven convention. | Linear in store size — fine while stores stay under a few hundred memories. | High — adding an index is pure-add. |
| B — Lightweight tag/keyword index | Faster filter for tag-heavy workloads. | Adds a build step that must run on every write; staleness becomes a design problem; v1 doesn't have a workload that needs it yet. | High — index is a derived artifact. |
| C — Embedding index (sqlite-vss or similar) | Best recall quality; fuzzy semantic match. | Heavy dependency footprint; massive overkill for v1; introduces a new runtime dep. | Medium — model migration is non-trivial. |

**Rationale.** Option A wins on simplicity and on driver 5 (portability — no new runtime dep). The user already accepted in OQ-5 that indexing is post-v1. **Rejected:** Option B because a half-step index that we'll throw out for embeddings later isn't worth the carry cost.

---

## 5. Write-Path Design

Per requirements §4, two paths: explicit save and auto-propose-with-confirmation. Both run through the same redaction and confirmation pipeline; only the trigger differs.

### Explicit save flow (`/cross-memory save`)

```text
1. User invokes:
     /cross-memory save --scope user-global --type preference --tags python,testing \
                        --name "Prefer pytest" "Use pytest for all new Python tests."

2. Skill parses args. Missing scope/type/name? → derive from context, ask user to confirm.

3. Skill builds candidate frontmatter + body.

4. Redaction pass runs on body (see §9). Layered: <private> strip first, then regex denylist.
     a. If no pattern fires → skip warning, proceed to step 6.
     b. If pattern fires → step 5.

5. WARN UX (explicit save with detected pattern):
     ┌─────────────────────────────────────────────────────┐
     │ Sensitive pattern detected: api-key                 │
     │                                                     │
     │ Redacted candidate:                                  │
     │ ─────                                               │
     │ [frontmatter]                                       │
     │ [body with [REDACTED:api-key] in place of secret]   │
     │ ─────                                               │
     │                                                     │
     │ Save anyway? [y/N]                                  │
     │ Or pass --no-redact to save the unredacted form     │
     │ (requires typed confirmation; see §9, OQ-9).        │
     └─────────────────────────────────────────────────────┘

   Default: no.

6. SAVE:
     a. Write `<type>_<slug>.md` to ~/.cross-memory/<scope-dir>/.
     b. Append entry to that scope's MEMORY.md.
     c. Hand off to the active adapter for mirroring (one-way canonical→mirror; see §6).

7. ECHO:
     Wrote ~/.cross-memory/user-global/preference_prefer_pytest.md
     Mirrored to ~/.claude/projects/D--.../memory/preference_prefer_pytest.md (claude-code adapter).
```

### Auto-propose-with-confirmation flow

The trigger is "the assistant detects something memorable during a session." Detection strategy is intentionally **explicit-trigger-only at v1**, not heuristic.

> **Decision 4.** v1 auto-propose triggers on **explicit signals only** — no NLP heuristic to detect "memorable" content. The triggers are:
>
> 1. **User explicit cue.** User says some variation of "remember that...", "save this preference...", "make a note that...". The skill detects the cue, drafts a candidate, and runs the auto-propose flow.
> 2. **Cross-skill dispatch.** Another skill (e.g., `/ops`, `/kickoff`) decides a fact is worth persisting and dispatches the auto-propose flow on the user's behalf. The dispatching skill provides the candidate content; cross-memory runs redaction + confirmation.

**Options considered:**

| Option | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- |
| A — Explicit triggers only (recommended) | Predictable; no false positives surprising the user; aligns with Decision 5 (no silent writes). | Misses memorable content the user didn't explicitly mark. | High — heuristic detection can be added later. |
| B — Heuristic detection (LLM-based) | Captures more memories without user effort. | Surprises the user with proposals on noise; risks over-prompting; failure mode of "the model thinks every preference is memorable" is bad. | Medium — would need a deprecation path if rolled back. |
| C — Hybrid — heuristic with user opt-in flag | Best of both worlds. | Doubles the design surface for v1; complicates testing. | Medium — feature-flag removal is doable. |

**Rationale.** Option A wins on driver 3 (no silent writes) and on the principle that the assistant should not initiate persistence without an explicit signal. The assistant's confirmation prompt protects against bad writes, but proactive proposals on every interesting-sounding sentence become noise. Heuristic detection earns its keep only after the explicit-trigger flow is shaken out and the false-positive rate of a heuristic can be measured against a real corpus. **Rejected:** Option B because the v1 user experience risks "every conversation interrupted by save proposals."

The auto-propose flow itself is identical to the explicit save flow above, except the user is presented with the **CONFIRM UX (auto-proposed save, new memory)**:

```text
┌─────────────────────────────────────────────────────────────┐
│ I'd like to save this as a memory. Confirm?                 │
│                                                             │
│ Scope: user-global    Type: preference    Tags: [python]    │
│ Name:  Prefer pytest                                        │
│                                                             │
│ Body (redacted candidate):                                   │
│ ─────                                                       │
│ Use pytest for all new Python tests; avoid unittest.        │
│                                                             │
│ **Why:** User stated preference 2026-05-08.                 │
│ **How to apply:** Generate `def test_*` + pytest fixtures.  │
│ ─────                                                       │
│                                                             │
│ Save this memory? [y/N]                                     │
└─────────────────────────────────────────────────────────────┘
```

### Supersede flow

Triggered when a write proposes a `name` that already exists in the same scope.

```text
1. Skill detects collision (existing file with matching `name` slug).

2. Skill builds the new candidate, runs redaction, then renders a unified diff
   between the redacted-existing and redacted-new bodies.

3. CONFIRM UX (auto-proposed save, supersede):
     ┌─────────────────────────────────────────────────────────────┐
     │ This would replace an existing memory:                      │
     │                                                             │
     │ ~/.cross-memory/user-global/preference_prefer_pytest.md     │
     │ Created: 2026-04-12  Updated: 2026-04-12                    │
     │                                                             │
     │ Diff (existing → proposed):                                 │
     │ ─────                                                       │
     │ - Use pytest for all new tests; avoid unittest.             │
     │ + Use pytest for all new tests; reach for unittest only     │
     │ + when extending an existing unittest suite.                │
     │ ─────                                                       │
     │                                                             │
     │ Replace existing memory with this version? [y/N]            │
     └─────────────────────────────────────────────────────────────┘

4. On confirm:
     a. Move existing → ~/.cross-memory/archive/<stem>-<UTC-timestamp>.md.
        Set `superseded_by: <new-filename>` on the archived copy.
     b. Write new file to canonical path. Preserve `created_at` from predecessor;
        set `updated_at` to now.
     c. Update scope's MEMORY.md entry.
     d. Re-run adapter mirroring (one-way canonical→mirror).
```

### No silent writes — enforcement

Per Decision 5 and SC-13, the agent's `Write` tool is allowlisted per Decision 22 (§8). The skill is the only component that runs the confirmation UX. Adapters write to harness-native paths but **never** to `~/.cross-memory/**` — they're consumers of the canonical store, not producers. This three-way split means a missing confirmation gate leaks no writes to the canonical store.

---

## 6. Adapter Design

Adapters are thin per-harness shims. Each adapter is a single markdown file in `skills/cross-memory/` with sections describing detection, mirroring, and collision-handling. The skill loads the active adapter at session start and dispatches mirror operations to it after every canonical write.

### Adapter interface (logical)

Each adapter exposes four conceptual operations, expressed in the skill's prose-driven flow control:

| Operation | When called | Output |
| :--- | :--- | :--- |
| `detect_harness()` | Session start, by the skill | Returns `claude-code` \| `cursor` \| `generic`, or refuses |
| `mirror_write(canonical_path, content)` | After every canonical write/supersede | Writes to harness-native path, sets `mirrored_from` frontmatter on the mirror |
| `mirror_remove(canonical_path)` | After every `forget` | Deletes the harness-native mirror |
| `detect_collisions(harness_path)` | During audit | Returns list of files in harness-native path that are NOT mirrors |

The Claude Code adapter has a fifth operation specific to Decision 18: `update_sentinel_block(content)` rewrites the bytes between `<!-- cross-memory:begin -->` and `<!-- cross-memory:end -->` inside `~/.claude/projects/<slug>/memory/MEMORY.md`. It is invoked whenever the always-on tier is recomputed (canonical write, canonical forget, audit refresh).

### Harness detection — Decision (resolves OQ-1)

> **Decision 5.** Hybrid detection with explicit precedence:
>
> 1. **CLI flag** (`/cross-memory --harness <name>`) — highest priority. Wins for the current session only.
> 2. **`~/.cross-memory/config.yaml` `current_harness:` field** — second priority. Stable per-user setting.
> 3. **Environment variable** `CROSS_MEMORY_HARNESS` — third priority. Useful for shell-aliased aware launchers.
> 4. **Adapter manifest probe** — last resort. Each adapter declares a self-identification check (e.g., Claude Code adapter checks for `CLAUDE_CODE_*` env vars or a Claude Code-specific marker file). Probed in deterministic order: `claude-code` → `cursor` → `generic`. First adapter to claim ownership wins.
> 5. **Generic fallback** — if all four above produce no answer, the harness is `generic`.

**Options considered:**

| Option | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- |
| A — Hybrid with explicit precedence (recommended) | Deterministic; auditable; works across platforms; degrades gracefully to generic. | Three configuration surfaces to document; the planner must specify precedence for the executor. | High — change precedence later via skill update. |
| B — Env-var only | One place to set; trivial. | Fragile across shells; no per-session override; doesn't work in IDEs that don't propagate env. | High. |
| C — Per-harness manifest probe only | Self-contained per adapter; no user config burden. | Probe results can ambiguous (both Claude Code and Cursor markers present on a dev machine); unauditable when wrong. | Medium — probes are baked into adapters. |
| D — Hand-off via the calling skill/agent | The dispatcher names the harness explicitly. | Doesn't work for the adapter's session-start always-on tier — there's no calling skill at session start. | Low — would force re-architecture. |

**Rationale.** Option A wins on driver 5 (portability — explicit precedence is documentable in the deploy guide) and the requirements' explicit constraint that detection be "deterministic, repeatable, and auditable." The CLI flag handles power users; the config file handles steady state; the env var handles automation; the manifest probe handles "I just installed and haven't configured yet." **Rejected:** Option C alone because ambiguous probe results (both Claude Code and Cursor markers present) leave users with no recourse short of editing skill code.

### Mirror direction and collision detection — Decision (resolves OQ-7)

> **Decision 6.** Mirroring is **strictly one-way: canonical → mirror**. Mirrored copies carry a `mirrored_from: <canonical-filename>` frontmatter field, plus a sidecar manifest `~/.<harness>/cross-memory-mirrors.json` (or harness-equivalent) tracking what the adapter wrote. The audit checks both signals and refuses to clobber files that have neither.

**Options considered:**

| Option | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- |
| A — Frontmatter marker only (`mirrored_from`) | Self-describing; no sidecar to maintain. | A user who edits a mirror by hand might strip the frontmatter; collision check would then false-negative. | High. |
| B — Sidecar manifest only | One file lists all mirrors; easy to enumerate. | Sidecar can drift from filesystem state; recovery story if sidecar is deleted. | High. |
| C — Frontmatter + sidecar (recommended) | Defense in depth — either signal is sufficient to identify a mirror; if one is corrupted, the other still works. Audit reports both states. | Two write surfaces per mirror operation. | High. |

**Rationale.** Option C wins on driver 7 (lane discipline — the audit must be able to confidently report what's a mirror vs what's native, and a single signal that can be edited away is brittle). The frontmatter marker handles the "user edits the mirror" case; the sidecar handles the "user strips frontmatter" case. **Rejected:** Option A alone because Claude Code's existing memory files do not have `mirrored_from` set, and the adapter must be able to distinguish "this file existed before cross-memory was installed" from "this is a stale mirror I wrote last month."

The audit's collision report (when a non-mirror file occupies a mirror-target path) flags the file with one of three states:

- **Native — leave alone.** No `mirrored_from`; not in sidecar; pre-existing per requirements §8.
- **Stale mirror — orphaned.** In sidecar but no canonical source. Audit suggests removing.
- **User-edited mirror — diverged.** Has `mirrored_from` matching a canonical file but content differs. Audit flags; user resolves (re-mirror or promote-to-canonical).

### Sync conflict model — Decision (resolves OQ-4)

> **Decision 7.** **Canonical-store-is-truth.** When the same memory is written via two different harnesses, the canonical store is the only authoritative source. Mirrors are derived; they are overwritten on every adapter mirror pass. There is no "edit a mirror" path — the skill always writes to the canonical path first, then propagates.

**Options considered:**

| Option | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- |
| A — Canonical wins (recommended) | Eliminates conflict by construction; mirrors are always derived. | A user who edits a mirror in Claude Code's UI loses the edit on next mirror pass. The audit catches and warns about user-edited mirrors so this loss is visible. | High — model is enforced by adapter logic. |
| B — Last-writer-wins-with-supersede | Treats mirrors as first-class; supports mirror-side edits. | Massive complexity for v1 — needs conflict markers, merge UX, divergence tracking; defeats the "extend, never replace" driver because Claude Code's editing surface is now part of cross-memory's write path. | Low — model-level change. |
| C — Read-only mirrors at the filesystem level | Hard guarantee against mirror edits. | Filesystem ACLs are platform-specific; doesn't work uniformly across Windows/macOS/Linux. | Medium. |

**Rationale.** Option A wins on driver 1 (extend, never replace) and driver 2 (canonical is canonical). The UX cost of "mirrors are not editable" is captured in the audit's user-edited-mirror flag — the user is warned, not silently overwritten. **Rejected:** Option B because the conflict surface area for v1 is too large; the user explicitly deferred conflict-handling-as-a-feature to OQ-4 with the expectation that the architect would simplify rather than expand.

---

## 7. Skill Design

### File location and structure

```text
skills/cross-memory/
├── SKILL.md                          # Subcommand router; parses args; orchestrates flows
├── README.md                         # User-facing documentation; excluded from deploy
├── redaction.md                      # Denylist patterns; consumed by SKILL.md and the agent
├── indexing.md                       # MEMORY.md line-format conventions
├── adapter-claude-code.md            # Claude Code mirror logic
├── adapter-cursor.md                 # Cursor mirror logic
├── adapter-generic.md                # No-op adapter
└── SKILL.cursor.md                   # Cursor-native variant (if needed; see §11)
```

### Subcommand routing — `SKILL.md`

The skill's `SKILL.md` is the entry point and follows the same pattern as `skills/clickup/SKILL.md` and `skills/commit-message/SKILL.md`: parse `$ARGUMENTS`, dispatch to the matching subcommand handler, and return the result.

```text
/cross-memory <subcommand> [args]

Subcommands (six at v1, per requirements §10):
  save     [--scope <s>] [--type <t>] [--category <c>] [--tags <t1,t2>] [--name <n>] [<body>]
           [--no-redact]                # See §9, OQ-9
  recall   <topic> [--scope <s>] [--type <t>] [--category <c>] [--tag <t>]
  list     [--scope <s>] [--type <t>] [--category <c>] [--tag <t>] [--stale-only]
  forget   <name>
  search   <query>
  audit                                  # Dispatches the cross-memory agent
```

### Output format

- All subcommands print markdown to chat.
- `recall` and `list` render full memories with staleness banner if applicable.
- `search` returns `<path>:<line>: <matched-line>` triples.
- `save` and `forget` echo the affected canonical path plus any archived predecessor and any mirror written/removed.
- `audit` returns the agent's structured report rendered to chat (Decision 20).

### Output tagging

The skill produces a `**Cross-Memory**` badge on the opening line of each assistant turn, matching the convention from `skills/commit-message/SKILL.md` and `skills/doc-sync/SKILL.md`. The maintenance note in `~/.claude/CLAUDE.md` will need to add this skill's row to the active-skill detection table — that's a documentor task, flagged for the planner.

### Manifest registration

See §11 (Decision 21) for the verified manifest globs. No structural manifest changes are required for cross-memory's markdown files; the existing globs cover them on every target. The Cursor target's wider `**/*` skill glob means cross-memory must ship markdown only — see §11 for the constraint and the verification path.

---

## 8. Agent Design

### File location and frontmatter

`agents/cross-memory.md`:

```yaml
---
name: cross-memory
model: opus
description: Synthesizes curated context blocks from the cross-memory store and audits the store for staleness, duplicates, contradictions, and redaction misses. Reads canonical store; writes only to ~/.cross-memory/** and to the sentinel-bounded region of harness-native MEMORY.md files.
tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
---
```

**Why opus.** Synthesis (filtering relevance, judging staleness, detecting contradictions) and audit (semantic clustering for duplicate detection) require the same nuanced judgment as the planner, critic, and code-intel agents. Sonnet would be cheaper but the audit's contradiction-detection step in particular benefits from opus's reasoning depth.

**Why these tools.** `Read`, `Glob`, `Grep` are the read primitives the audit needs. `Bash` is restricted to read-only file ops (see Decision 22) — no shell execution beyond directory listing, file inspection, and copy-to-`_tmp_*` for diff staging. `Write` is allowlisted per Decision 22 below. No `Agent` tool — per requirements §11, "agent dispatches the agent" is explicitly forbidden.

### Lane boundaries — Decision (per critic Finding 5)

> **Decision 22 (per critic Finding 5).** The cross-memory agent's lane-boundary section reuses the **structural pattern** from `agents/code-intel.md` (refuse-and-halt, three numbered violation steps, structured violation report). The **allowlist globs and Bash allow/deny lists are cross-memory-specific** and listed below. The prior ADD's "verbatim from `agents/code-intel.md`" claim is withdrawn — code-intel allowlists three globs (`.code-intel/**`, `docs/code-intel/**`, `_tmp_*`) and a code-intel-specific Bash list; copying those literally would let cross-memory write to code-intel's territory.

**Cross-memory write allowlist (verbatim text to embed in the agent definition):**

```text
Write allowed only to paths matching one of these globs (canonical-store ownership and adapter sentinel-block ownership). Glob matching is canonical — NOT a literal-path allow-list:

1. ~/.cross-memory/**
   Covers the entire canonical store: user-global/, projects/, harnesses/, archive/, config.yaml,
   and any future top-level subdirectory. Both Markdown memory files and YAML config land here.

2. ~/.claude/projects/*/memory/MEMORY.md  AND  ~/.cursor/<harness-equivalent>/MEMORY.md
   ONLY when the rewrite is bounded by the cross-memory sentinel markers (Decision 18):
   <!-- cross-memory:begin --> ... <!-- cross-memory:end -->
   The agent rewrites bytes BETWEEN the markers; bytes outside the markers MUST NOT be modified.
   If the markers are absent, the agent's first write to MEMORY.md is the bootstrap write
   (per Decision 18 step 1) and adds the markers framing an empty region.
   The agent NEVER writes a per-memory <type>_<slug>.md file under ~/.claude/projects/*/memory/
   — that path is the Claude Code adapter's territory (a skill component, not the agent).

3. _tmp_*  (project-relative)
   Covers staging files the agent writes during the audit (e.g., diff fixtures, sidecar
   reconciliation logs). Same convention as the rest of the fleet — _tmp_ prefix at the
   project root, batch-cleaned.

Refuse-and-halt on first Write violation:
  1. Refuse the operation.
  2. Emit a structured violation report containing: path attempted, reason for refusal,
     requester context (which intent — synthesize or audit; which calling skill or agent;
     which brief).
  3. Halt the run. No further Write or Bash operations execute in the same dispatch.
     In-flight read-only operations (Read, Glob, Grep, read-only Bash) may complete.

There is no sticky sentinel between dispatches. A fresh run starts with a clean slate.
```

**Cross-memory Bash scope (verbatim text to embed in the agent definition):**

```text
Permitted:
  - File inspection: ls, cat, head, tail, file, stat, wc (read-only).
  - Path resolution: realpath, readlink, dirname, basename.
  - Existence checks: test -e, test -d, test -f.
  - Copy to staging: cp <source> _tmp_<staging>  (target MUST match the _tmp_* allowlist).
  - Read-only diff: diff -u <a> <b>  (no -i, no in-place edits).

Forbidden:
  - Network: curl, wget, nc, ssh, scp, rsync, ftp.
  - Package installs: npm install, pip install, cargo, gem, apt, brew, winget, choco, etc.
  - Code-modifying shell: sed -i, awk writing back to files, any shell redirect (>, >>, tee)
    — all writes must go through the Write tool so the glob-allowlist enforcement runs.
    This applies even for _tmp_* targets: a Bash redirect bypasses the enforcement layer.
  - Process management: kill, pkill, systemctl, service, taskkill.
  - Git mutations: git commit, git push, git checkout (modifying), git stash, git reset,
    git rebase, git merge.
  - Filesystem mutations: rm, rmdir, mv (except as the Write tool's atomic-move
    implementation), chmod, chown, ln.

Refuse-and-halt per Lane Boundaries applies uniformly to any forbidden invocation.
```

**Why these specific globs.** The cross-memory agent writes (a) canonical memories, audit-state staging, and config under `~/.cross-memory/**`; (b) the sentinel-bounded `[CROSS-MEMORY]` block inside harness-native `MEMORY.md` files when the adapter is dispatched as the agent's helper; (c) staging files under `_tmp_*` for diff-style audit reconciliation. The agent does NOT write per-memory mirror files at `~/.claude/projects/*/memory/<type>_<slug>.md` — that surface is owned by the Claude Code adapter (a skill component), per the same lane-discipline principle that keeps source-code editing out of code-intel.

**Why this is *not* "verbatim from code-intel".** The structural pattern (refuse-and-halt, three numbered steps, structured violation report, sticky-sentinel-free fresh-run semantics) is identical to `agents/code-intel.md` lines 138–145. The actual allowlist globs are different by necessity: code-intel writes to `.code-intel/**` and `docs/code-intel/**` and `_tmp_*`; cross-memory writes to `~/.cross-memory/**` and the sentinel-bounded MEMORY.md region and `_tmp_*`. The Bash lists are different too — code-intel needs `python -c`, `tsc`, and `sqlite3`; cross-memory needs only basic file ops. Replicating code-intel's text literally would let cross-memory write to `.code-intel/**` (a different agent's territory) and would fail to allow the sentinel-block rewrite that Decision 18 requires.

**Verification scenario for the allowlist.** SC-21 (added in §15) covers: cross-memory agent attempts to write outside its allowlist; the attempt is refused-and-halted with an explicit lane-violation message in the agent's output. This is in addition to SC-13's existing scope (write to `~/.cross-memory/**` succeeds; write to `src/auth/handler.py` refuses).

### Brief contract — input shape

The agent uses the **labeled-prose brief format** per `skills/ops/brief-contract.md`. The skill's `audit` subcommand and any other agent-dispatcher build this brief.

```text
## Task
<one-line statement, e.g., "Synthesize Python and security context for the current task" OR "Audit the cross-memory store for staleness, duplicates, contradictions, and redaction misses">

## Scope
- ~/.cross-memory/** (read)
- ~/.claude/projects/<active-slug>/memory/MEMORY.md (read; for sentinel-block refresh during audit)
- ~/.claude/projects/<active-slug>/memory/<type>_<slug>.md (read; for mirror collision detection)

## Acceptance Criteria
1. <For synthesize: a markdown block under <size_budget> chars matching the query>
2. <For audit: a structured report with the four categories rendered to chat (no on-disk artifact)>

## Constraints
[Shared Brief Constraints — see skills/ops/SKILL.md#shared-brief-constraints]
- intent: synthesize | audit
- query: <free-text> (synthesize only)
- scope_filter: <optional scope/tag/type/category filter> (synthesize only)
- current_project_slug: <optional> (synthesize only)
- current_harness: <optional> (synthesize only)
- size_budget: <integer chars> (synthesize only; default 4000)
```

The `intent`, `query`, and other fields per requirements §11 live under `## Constraints` because they're parameters to the dispatch, not acceptance criteria. This matches how `code-intel`'s labeled-prose brief carries `Query:`, `Symbol:`, `Scope:` lines. A future revision could promote them to a dedicated `## Synthesis Parameters` section, but at v1 piggybacking on `## Constraints` keeps the brief contract surface area unchanged.

**Note on audit output destination.** Per Decision 20 below, the audit's output is the agent's return value — a markdown block rendered into chat by the skill. The agent does **not** write an audit report to disk; there is no `audit-reports/` directory and no `## Scope` line claiming write access to one. The previous ADD revision listed `~/.cross-memory/audit-reports/ (write — for audit reports only)` here; that line is removed.

### Output contract — `intent: synthesize`

Returns a single markdown block under the configured size budget (default 4000 chars). Section structure:

```markdown
## Cross-Memory Context — synthesized for: <query>

### User preferences
- <claim 1> (`preference_python_pytest.md`)
- <claim 2> (`preference_python_typed.md`)

### Project context
- <claim 1> (`project_kickoff_design_principles.md`)
- <claim 2> (`feedback_strict_lane_boundaries.md`)

### Harness rules
- <claim 1> (`rule_no_compound_bash.md`)

### Notes / staleness warnings
- `feedback_some_outdated_thing.md` was last verified 124 days ago — consider /cross-memory audit refresh.
```

### Output contract — `intent: audit`

Returns a structured markdown report with five sections, **rendered to chat by the calling skill**. The agent emits the report as its return value; nothing is written to disk by the agent for the audit flow (Decision 20).

```markdown
## Cross-Memory Audit Report — <UTC timestamp>

### Stale memories (N)
| Memory | Days unverified | Suggested action |
| :--- | :--- | :--- |
| `feedback_x.md` (user-global) | 124 | refresh \| archive \| forget |
...

### Duplicates (N groups)
**Group 1** — same `name` slug:
- `feedback_no_commit_trailers.md` (project:A)
- `feedback_no_commit_trailers.md` (user-global)
Suggested: promote project-scoped to user-global; forget project-scoped.

### Contradictions (N pairs)
**Pair 1** — overlapping tag `[git]`, conflicting body:
- `preference_always_rebase.md`: "Always rebase before merging"
- `preference_always_merge.md`: "Always merge — never rebase"
Suggested: user resolves (cross-memory does not auto-resolve).

### Redaction misses (N)
| Memory | Pattern category | Match preview |
| :--- | :--- | :--- |
| `project_some_memo.md` | api-key | `sk-abc...` (partial) |
Suggested: re-redact via /cross-memory save --scope ... (supersede) and confirm.

### Recommended actions
Each requires user confirmation before any change is applied.
```

The agent **never** applies these actions. The skill orchestrates the user's resolution choices and dispatches the agent again with `intent: apply` (deferred — not v1) or runs the appropriate `save` / `forget` directly.

### Audit output destination — Decision (per critic Finding 3)

> **Decision 20 (per critic Finding 3).** The audit's structured report is rendered **to chat only** at v1. There is no on-disk audit artifact. The agent returns the report as its return value; the calling skill renders it directly to the user's terminal. The `audit-reports/` directory referenced in the prior ADD is removed.

**Why chat-only.** Three reasons:

1. **Consistent with v1's "not a transcript archive" non-goal.** Persisting audit output to disk creates an artifact that grows unbounded over time; the audit is a diagnostic, not a record of progress.
2. **Simplifies lazy provisioning (Decision 13).** The provisioned subdirs are exactly the ones the canonical store needs (`user-global/`, `projects/`, `harnesses/{claude-code,cursor,generic}/`, `archive/`); no `audit-reports/` to provision, no retention/rotation rule to define.
3. **Lets the user re-run audit cheaply.** If the user wants a saved snapshot of an audit, they save the chat output via their harness's standard transcript save, the same way they would save any other assistant response.

**Options considered:**

| Option | Description | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- | :--- |
| A — Chat-only at v1 (recommended) | Agent returns the report as its return value; skill renders it; nothing on disk. | Smallest surface; nothing to provision; no retention/rotation rule; matches v1 non-goal "not a transcript archive". | Re-running audit reproduces the report from scratch (no cached prior runs to diff against). | High — adding disk persistence later is pure-add. |
| B — Persist to `~/.cross-memory/audit-reports/<UTC-timestamp>.md` | Adapter writes a timestamped report on every audit run. | Diff-able audit history; user can review past audits. | Storage grows linearly with audit cadence; needs a retention policy (rotate at N reports? prune by age?); adds a write target to Decision 13's lazy provisioning; adds a manifest entry for the directory. | Medium — would have to define a migration if dropped. |
| C — Persist on user opt-in only (CLI flag `--save-report <path>`) | User explicitly asks for a disk artifact when they want one. | Power-user feature without imposing storage growth on everyone. | Two write paths to document; UX inconsistency between "I ran audit" and "I ran audit and got a file"; introduces a fifth write surface to the lane boundaries. | High. |

**Rationale.** Option A wins on driver 5 (portability — fewer moving parts to deploy) and on simplicity (no retention rule, no provisioning entry). The audit is a diagnostic; the user's question is "what's stale right now?", not "show me audit history." If post-v1 use surfaces a real need for audit history, Option B is a pure-add — Decision 13's lazy provisioning gets one more directory, the cross-memory agent's allowlist gets one more glob, and a retention rule lands at the same time. **Rejected:** Option B because the storage-growth + retention-rule cost is meaningful for v1 and there is no concrete v1 use case that needs it. **Rejected:** Option C because the inconsistency (sometimes file, sometimes not) is harder to explain than either always-no or always-yes.

**Where this surfaces in the ADD.** §8 brief template's `## Scope` no longer lists `~/.cross-memory/audit-reports/`. §10's flow-diagram is unchanged in structure (the report has always been chat-rendered there) and is reaffirmed as the canonical source of truth. The cross-memory agent's lane allowlist (Decision 22) has no `audit-reports/` glob.

### Dispatch triggers (verbatim from requirements §11)

1. `/cross-memory audit` dispatches the agent with `intent: audit`.
2. Other skills/agents (`/ops`, `/kickoff`, planner, executor) dispatch with `intent: synthesize` when they need a curated context block.

**Explicit non-triggers.** Not auto-dispatched at session start (always-on tier injection is the adapter's job). Not dispatched on every auto-proposed write (the skill handles drafting and redaction directly).

---

## 9. Privacy / Redaction Engine

### Where redaction lives — Decision

> **Decision 8.** Redaction lives in **`skills/cross-memory/redaction.md`**, a single shared module consumed by both the skill (write-time enforcement) and the agent (audit-time miss detection). Patterns are expressed as labeled regex tables — markdown, not executable code.

**Rationale.** A single module per driver 6 (one source of truth for the denylist). The skill loads it at write time; the agent loads it at audit time. Updating the denylist means editing one file; both consumers pick up the new rules on next dispatch. **Rejected:** duplicating the denylist between skill and agent because divergence is inevitable and dangerous (audit thinks file is clean; skill would have flagged it).

### v1 starter denylist — Decision (resolves OQ-3)

> **Decision 9.** v1 ships the starter denylist below, **flagged as starter, expandable**. The skill MUST NOT treat the denylist as exhaustive — the warning UX is paranoid by default.

| Category | Pattern (regex; case-sensitive unless noted) | Example match |
| :--- | :--- | :--- |
| `api-key` | `\b(sk-\|pk_\|ghp_\|gho_\|github_pat_\|xoxb-\|xoxp-\|AIza[0-9A-Za-z_-]{35}\|AKIA[0-9A-Z]{16})[A-Za-z0-9_-]{16,}` | `sk-abc123def456...`, `ghp_abcdef0123...` |
| `password` | `(?i)\b(password\|passwd\|pwd)\s*[:=]\s*['"]?[^\s'"]+` | `password = secret123`, `pwd: foo` |
| `bearer-token` | `(?i)\b(bearer\|authorization)\s*[:=]?\s*['"]?[A-Za-z0-9+/_-]{20,}\.[A-Za-z0-9+/_-]{20,}\.[A-Za-z0-9+/_-]{20,}` | `Authorization: Bearer eyJ...` (JWT-shape) |
| `jwt` | `\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}` | Standalone JWT string |
| `aws-secret` | `\b[A-Za-z0-9+/]{40}\b` (with proximity to `aws_secret_access_key` or `AKIA*`) | AWS secret access key |
| `env-block` | Multiline match of 2+ consecutive lines matching `(?m)^\s*[A-Z_][A-Z0-9_]*\s*=\s*['"]?[^\s]+['"]?\s*$` | `.env`-style multi-line block |
| `private-key-header` | `-----BEGIN (RSA \|EC \|DSA \|OPENSSH \|PGP )?PRIVATE KEY-----` | PEM/SSH/PGP private keys |
| `user-tagged-secret` | Triggered by user explicitly tagging content as secret in the same session, or content read from a path identified as `.env` / `*.key` / `secrets/*` | (no regex — context-driven) |

Each match is replaced with `[REDACTED:<category>]` in the candidate body. The `redacted: true` frontmatter field is set if any pattern fired.

**Why these patterns.** They cover the high-confidence shapes for the categories named in requirements §7 (API keys, passwords, tokens, .env contents, private keys). False-positive risk is non-zero (e.g., a 40-char base64 string that isn't an AWS secret), which is why the warning UX shows the redacted candidate and asks for confirmation rather than silently rewriting.

**Why "starter."** OQ-3 explicitly defers the full pattern library to the architect, noting that "exact regex/pattern set" depends on a security review. v1 ships the starter so the planner has something concrete to implement; v2 (or a security-reviewer audit pass post-v1) refines it.

### Inline `<private>` markup — Decision

> **Decision 14.** Privacy redaction is **layered**: (a) the **regex denylist** (Decision 9) auto-detects known sensitive patterns; (b) **inline `<private>...</private>` markup** lets the user explicitly mark anything else; (c) the **confirmation gate** (per requirements §4 and §5) displays the post-redaction candidate before save. Both signals run on every write; either signal triggers redaction. Concept adapted from `supermemoryai/opencode-supermemory` README.

**Why a second layer.** The regex denylist catches what the user *forgot* — known credential shapes the user pasted without thinking. Inline `<private>` markup catches what regex *can't* — unusual credentials, sensitive PII, internal project names, anything the user knows is sensitive but doesn't match a pattern. The two signals are complementary; they cover different failure modes.

**Parser behavior:**

- **Tag syntax:** `<private>...</private>`. Case-sensitive. Tag content may span multiple lines.
- **Multiple occurrences:** A single body may contain multiple `<private>...</private>` blocks. All are stripped.
- **Nesting:** Nested `<private>` tags are flattened — the outermost `<private>` opens the redaction; the first matching `</private>` closes it. Inner tags are absorbed into the outer redaction. Justification: nested `<private>` is unusual and the safe default (treat the whole region as one redaction) is the conservative read.
- **Replacement placeholder:** Each redacted region is replaced with the literal string `[REDACTED:private]`. The placeholder is **stable** — every match produces the same placeholder text, mirroring the regex denylist categories.
- **Recoverability:** The original content inside the tags is **never persisted** — the placeholder is irreversible, mirroring the regex denylist behavior. There is no "show me what was inside" path.
- **Display in recall output:** When a memory is rendered in the `[CROSS-MEMORY]` block, in `/cross-memory recall`, or in agent synthesis output, the `[REDACTED:private]` placeholder is **stripped cosmetically** — the placeholder string itself does not leak into rendered output. The body shows a single `…` (ellipsis) where the redaction happened, signaling "content elided" without parading the placeholder. The on-disk frontmatter and body retain the placeholder so the audit and supersede paths can reason about it.
- **Unmatched open tag:** A `<private>` tag without a matching `</private>` is a parser warning. The parser treats everything from the open tag to the **next blank line** as redacted, then stops; the confirmation gate shows the user the actual stored result so they can correct the typo before persisting. Justification: silently treating "no close tag" as "redact to end of body" risks unbounded redaction; silently treating it as "no redaction" risks silently leaking the user's intended-private content. A bounded fallback plus a visible warning on the confirmation gate is the safe middle ground.

**Interaction with `--no-redact` (Decision 10).** `--no-redact` only bypasses the **regex denylist**. Inline `<private>` markup is **always honored** — it's the user's explicit, in-band intent to redact. The flag exists for false-positive override on the regex layer; it does not exist to override the user's own typed-out intent. Sub-decision: `<private>` redaction runs **before** `--no-redact` consultation, so the `redacted: true` flag is set whenever `<private>` fires regardless of the flag.

**Options considered:**

| Option | Description | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- | :--- |
| A — Layered: regex denylist + `<private>` markup + confirmation gate (recommended) | Both signals run; either fires; user sees the post-redaction candidate before save. | Defense in depth; gives the user agency for cases regex can't catch; no new threat surface (never persists original). | Two redaction paths to document; users must learn the markup. | High — adding more layers later is pure-add. |
| B — Regex denylist only (status quo before this revision) | Regex is the only redaction signal. | One thing to document. | Misses anything regex can't recognize (unusual credentials, names, PII). | High — adding `<private>` later is pure-add. |
| C — `<private>` markup only, no regex | User must manually mark every secret. | No false positives. | Users will forget; the regex catches what users forget. Defeats Goal G7 (privacy by default). | Medium. |
| D — Confirmation gate only, no programmatic redaction | User reviews every save; flags anything sensitive manually. | No engineering investment. | Tedious; users will rubber-stamp; defeats the redaction goal entirely. | Medium. |

**Rationale.** Option A wins on driver 4 (privacy by default) and goal G7 — the two signals cover complementary failure modes (forgot vs. unusual), and the confirmation gate catches the residual risk. **Rejected:** Option B because it under-protects against unusual sensitive content. **Rejected:** Option C because users cannot be trusted to remember to mark every secret; the entire point of the regex denylist is to catch the forgotten-secret case. **Rejected:** Option D because manual review of every save is a known anti-pattern — users habituate to clicking through.

**Updated write-flow stages.** The redaction pipeline now runs in this order, captured in §12(a) below:

```text
input body
  → <private> strip pass     (replaces <private>...</private> with [REDACTED:private])
  → regex denylist pass      (replaces matching patterns with [REDACTED:<category>])
  → confirmation gate         (shows the post-redaction candidate; user confirms or edits)
  → store
```

### `--no-redact` escape hatch — Decision (resolves OQ-9)

> **Decision 10.** Keep `--no-redact`, but require **typed-phrase confirmation**, not `[y/N]`. The flag persists `redacted: false` (only when `<private>` did not fire — see Decision 14) and stamps `redaction_overridden_at: <UTC timestamp>` for audit traceability. The flag bypasses the **regex denylist only**; inline `<private>` markup is always honored regardless of the flag.

**Options considered:**

| Option | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- |
| A — Drop the flag entirely | Maximum safety; no override path. | Forces the user into surgery (paste the unredacted form into a separate non-cross-memory note) when they need to capture a fact that triggered a false positive. | High — adding back is pure-add. |
| B — Keep flag, simple `[y/N]` | Easy. | One typo and the user persists a real secret. | High. |
| C — Keep flag with typed-phrase confirmation (recommended) | Safety wall against typos; full audit trail via `redaction_overridden_at`. | Slightly more friction. | High. |

**Rationale.** Option C wins on driver 4 (privacy by default — the override path exists but is intentionally awkward). The typed phrase is `save unredacted` — case-sensitive, exact match, no shortcut. **Rejected:** Option A because false positives in the starter denylist are real; users need an escape hatch. **Rejected:** Option B because the friction asymmetry is wrong: pressing `y` after a sensitive-pattern warning is too easy.

The typed-confirmation UX:

```text
WARNING: --no-redact will save the UNREDACTED form. The detected pattern was:
  api-key

To proceed, type the exact phrase: save unredacted
> _

[Anything else, including "y" or "yes" or empty, cancels.]
```

### Archive policy

Archived copies retain `redacted: true` (or `redacted: false` if `--no-redact` was used and `<private>` did not fire) and the `[REDACTED:...]` placeholders. The unredacted form was never persisted to disk in any path under cross-memory's control, so it cannot be recovered from the archive.

---

## 10. Audit / Curation Engine

### `/cross-memory audit` flow end-to-end

```text
1. User invokes /cross-memory audit.

2. Skill builds a labeled-prose brief:
     ## Task
     Audit the cross-memory store for staleness, duplicates, contradictions, redaction misses, and curation opportunities (missing categories).

     ## Scope
     - ~/.cross-memory/** (read)

     ## Acceptance Criteria
     1. Stale memories list (verified_at > threshold)
     2. Duplicate memories list (same name slug or overlapping content)
     3. Contradiction list (overlapping tags + conflicting body claims)
     4. Redaction-miss list (frontmatter redacted: false but body matches denylist)
     5. Curation-opportunity list (memories missing optional `category` — Decision 16)

     ## Constraints
     [Shared Brief Constraints]
     - intent: audit
     - staleness_threshold_days: <from config.yaml or CLI flag; see Decision 11>

3. Skill dispatches the cross-memory agent with the brief.

4. Agent reads the canonical store, generates the structured report (see §8 output contract).

5. Skill receives the report as the agent's return value and renders it to chat with PER-FINDING action buttons:
     - refresh   → user re-confirms verified_at = now (no body change)
     - archive   → /cross-memory forget <name> (no replacement)
     - forget    → /cross-memory forget <name> (same as archive at v1)
     - redact-now → re-runs redaction on the candidate body, supersede flow
     - categorize → user picks a `category` value; supersede with frontmatter-only diff

6. User selects actions per finding. Skill executes each as a separate write
   per the Write-Path Design in §5 (every write goes through confirmation).

7. Skill echoes a final summary: N findings, M resolved, K deferred.
```

The audit's curation-opportunity list (item 5) is a **soft warning, not a defect**. A memory without `category` is fully valid; the audit surfaces it as a chance to add semantic richness. The user may accept, decline, or batch-categorize.

**No on-disk audit artifact.** Per Decision 20, the audit produces no file under `~/.cross-memory/audit-reports/` or anywhere else. The structured report is the agent's return value, rendered to chat by the skill in step 5. Users who want a saved snapshot use their harness's standard transcript save.

### Staleness threshold configuration — Decision (resolves OQ-8)

> **Decision 11.** Staleness threshold is configured via `~/.cross-memory/config.yaml` `staleness_threshold_days:` field. Default: 90. The `/cross-memory audit` command accepts `--staleness-days <n>` to override per invocation. CLI flag wins when both are present.

**Options considered:**

| Option | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- |
| A — Config file only | Single config surface (same vehicle as harness detection — see Decision 5). | No way to do a one-off audit with a different threshold. | High. |
| B — CLI flag only | Always explicit. | User has to remember to pass it every time; can't set a per-user default. | High. |
| C — Both, CLI wins (recommended) | Flexible; matches Decision 5's hybrid approach. | Two surfaces to document. | High. |

**Rationale.** Option C wins on driver 5 (portability — single config file is documentable across harnesses) and on consistency with Decision 5 (harness detection also uses the config file with override paths). **Rejected:** Option A because the user explicitly noted in OQ-8 that "a CLI flag on /cross-memory audit" was a candidate, and one-off audits with tighter thresholds are useful (e.g., "show me anything stale in the last 30 days").

### Audit cadence

Per requirements §6, audit is **manual cadence — the user runs it on demand**. Cross-memory does **not** schedule audits. v1 does not expose a CronCreate hook or a session-start audit trigger. The user's `/cross-memory audit` invocation is the only entry point.

### Resolution action constraints

- **Every resolution action** goes through the standard write-path confirmation (§5). The audit cannot bypass the confirmation gate.
- **`redact-now`** runs the redaction engine on the existing body and proposes a supersede. The user sees the diff and confirms or rejects.
- **`refresh`** writes a new `verified_at: <now>` to the existing memory's frontmatter. This is a frontmatter-only change — body content is untouched. It still goes through a one-line confirmation prompt to honor "no silent writes."
- **`categorize`** writes a `category: <value>` to the existing memory's frontmatter. Frontmatter-only diff; body untouched. Still goes through the one-line confirmation per "no silent writes."

---

## 11. Portability Transforms

### Deploy-manifest integration — Decision (per critic Finding 4)

> **Decision 21 (per critic Finding 4).** Cross-memory's files are picked up by the existing deploy-manifest globs in `tooling/deploy-manifest.json`. **No structural manifest change is required for v1.** However, the prior ADD's claim that all three targets share the same skill glob (`["**/*.md"]`) is wrong: the cursor target's skill block uses the wider glob `["**/*"]` with `["kickoff/**"]` excluded. Cross-memory must therefore ship markdown only — any non-markdown file dropped into `skills/cross-memory/` would deploy to Cursor unintentionally.

**Verified manifest entries (`tooling/deploy-manifest.json`, 2026-05-08):**

| Target | Block | `source` | `target` | `include` | `exclude` | `transform` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `claude-code` | agents | `agents/` | `~/.claude/agents/` | `["*.md"]` | `["README.md"]` | (none) |
| `claude-code` | skills | `skills/` | `~/.claude/skills/` | `["**/*.md", "**/*.yaml"]` | `["**/SKILL.cursor.additions.md"]` | (none) |
| `claude-code-wsl` | agents | `agents/` | `//wsl.localhost/Ubuntu-24.04/home/ubuntu/.claude/agents/` | `["*.md"]` | `["README.md"]` | (none) |
| `claude-code-wsl` | skills | `skills/` | `//wsl.localhost/Ubuntu-24.04/home/ubuntu/.claude/skills/` | `["**/*.md", "**/*.yaml"]` | `["**/SKILL.cursor.additions.md"]` | (none) |
| `cursor` | agents | `agents/` | `~/.cursor/agents/` | `["*.md"]` | `["README.md"]` | `true` |
| `cursor` | skills | `skills/` | `~/.cursor/skills/` | `["**/*"]` | `["kickoff/**"]` | `true` |

**Coverage for cross-memory's files:**

- `agents/cross-memory.md` — picked up by every target's `agents.include: ["*.md"]`. The `README.md` exclude does not apply (the file is named `cross-memory.md`).
- `skills/cross-memory/SKILL.md`, `redaction.md`, `indexing.md`, `adapter-claude-code.md`, `adapter-cursor.md`, `adapter-generic.md`, `SKILL.cursor.md` (if present) — picked up on Claude Code and WSL by `skills.include: ["**/*.md","**/*.yaml"]`. Picked up on Cursor by the wider `skills.include: ["**/*"]`. The `SKILL.cursor.additions.md` exclude (Claude Code targets) and `kickoff/**` exclude (Cursor target) do not apply.
- `skills/cross-memory/README.md` — also picked up on Cursor's `**/*` glob (no README exclude on the skills block), but not on the Claude Code targets' `**/*.md` (because `**/*.md` matches `README.md` too and there's no README exclude on the skills block either). The repo's existing convention for skill READMEs (`skills/clickup/README.md`, `skills/code-review/README.md`, etc.) is that they DO get deployed to harness paths. This matches existing precedent — no change needed.

**Cursor-side constraint (the one that bit the prior ADD).** The cursor `skills.include: ["**/*"]` glob deploys **every file**, not only markdown. Cross-memory must therefore ship markdown only into `skills/cross-memory/`. If a future implementation drops a `state.yaml`, a `_tmp_*` test fixture, a `config.example.json`, or any other non-markdown artifact into the skill directory, it will deploy to `~/.cursor/skills/cross-memory/` even though Claude Code targets would skip it (their globs are markdown-only). Two enforcement paths:

1. **Discipline.** The skill's design is prose-driven (Decision 12) — there are no executable scripts, no fixtures, no compiled artifacts shipped in the skill dir. Document this as a constraint in `skills/cross-memory/SKILL.md`.
2. **Manifest exclusion (only if needed).** If a non-markdown file ends up in the skill dir for a real reason, add a `cross-memory/<pattern>` entry to the cursor target's `skills.exclude` array — the precedent is `kickoff/**`, which excludes the entire kickoff skill from Cursor deployment.

For v1, path 1 is sufficient. Path 2 is the escape hatch the planner can reach for if a real need surfaces.

**Why no new manifest entry.** Adding `agents.include` or `skills.include` lines for cross-memory specifically would be redundant with the existing `*.md` and `**/*.md` / `**/*` globs, and would introduce per-skill manifest entries that the rest of the repo doesn't have. The existing manifest scales by directory layout, not by per-skill enumeration. Cross-memory follows that pattern.

**Options considered:**

| Option | Description | Pros | Cons | Reversibility |
| :--- | :--- | :--- | :--- | :--- |
| A — Rely on existing globs; ship markdown-only (recommended) | No manifest edits; cross-memory follows the existing skill-deploy pattern. | Zero structural change; matches every other skill in the repo. | Cursor deploys cross-memory's `README.md` (existing precedent — every other skill's README also deploys). | High — manifest is the lever. |
| B — Add a `cross-memory/**` exclude to cursor's `skills.exclude` | Symmetric with `kickoff/**` precedent. | Lets cross-memory ship non-markdown without leaking to Cursor. | Adds a manifest line for a need that does not exist at v1. | High. |
| C — Tighten the cursor `skills.include` glob to `**/*.md` | Removes the wider-than-Claude-Code asymmetry. | Symmetry across all three targets. | Breaks `kickoff/**` and any other skill that ships non-markdown to Cursor today; out of scope for cross-memory. | Low. |

**Rationale.** Option A wins on driver 5 (portability — match the existing deploy machinery) and on driver 8 (brownfield-aware — do not introduce a manifest pattern the rest of the repo does not use). **Rejected:** Option B because the protective exclude is unneeded at v1 (cross-memory ships markdown only by design); adding it later is a one-line patch. **Rejected:** Option C because tightening the cursor glob is a project-wide change the cross-memory feature should not own.

### Cursor transforms — Decision

> **Decision 12.** v1 ships **without** a custom `tooling/transform-cursor-cross-memory.{ps1,sh}`. The default Cursor transform (path remapping `~/.claude/` → `~/.cursor/`, tool name remapping, frontmatter stripping) is sufficient for cross-memory because the skill's flow control is text-driven, not tool-driven.

**Why no custom transform is needed.**

- The skill does not invoke harness-specific tools by name. It uses `Read`, `Write`, `Glob`, `Grep`, `Bash` — all of which the deploy script's default tool-name remapper handles.
- The skill's adapter selection is harness-aware at runtime (Decision 5), not at deploy time. Cursor users running `/cross-memory` will see the Cursor adapter selected by detection precedence.
- The path-remap rule (`~/.claude/` → `~/.cursor/`) does not break cross-memory because **`~/.cross-memory/` is harness-agnostic** and not touched by the remap.

**Caveat.** If during implementation the planner finds Cursor-specific syntax requirements (e.g., the `Skill` tool name remapping, or Cursor-specific command-line argument conventions), a `SKILL.cursor.md` companion file can be added. The cursor `skills.include: ["**/*"]` glob will pick it up automatically, and the Claude Code targets' `**/*.md` glob will too.

### Canonical store provisioning

> **Decision 13.** `~/.cross-memory/` is **provisioned lazily on first use** by the skill, not by the deploy script.

The skill's first action on every dispatch is:

```text
1. Check if ~/.cross-memory/ exists.
2. If not, create the directory tree (user-global/, projects/, harnesses/{claude-code,cursor,generic}/, archive/) and write a default config.yaml.
3. Proceed with the requested subcommand.
```

Per Decision 20, no `audit-reports/` subdirectory is provisioned — the audit is chat-only at v1.

This keeps the deploy script focused on deploying agent/skill contracts (which are immutable per-version) and not on managing user data (which evolves over time).

**Rejected:** putting `~/.cross-memory/` provisioning in the deploy script. The deploy script is meant to be re-runnable without side-effects on user data; provisioning user data via deploy violates that contract.

---

## 12. Component Interaction Diagrams

### (a) Write flow — `/cross-memory save` (auto-propose path shown, layered redaction)

```text
┌─────────┐                     ┌──────────┐
│  User   │  shares preference  │ Skill    │
└────┬────┘  ──────────────────▶│ (SKILL.md│
     │                          │  router) │
     │                          └────┬─────┘
     │                               │
     │                               │ explicit-cue detected
     │                               │ ("remember that...")
     │                               ▼
     │                          ┌─────────────────────────┐
     │                          │ Redaction pipeline      │
     │                          │ (redaction.md)          │
     │                          │  1. <private> strip     │
     │                          │     ↓                   │
     │                          │  2. regex denylist scan │
     │                          │     ↓                   │
     │                          │  candidate (redacted)   │
     │                          └────┬────────────────────┘
     │                               │
     │                               │ candidate (redacted)
     │                               ▼
     │   ┌──────────────────────────────────────────┐
     │   │  CONFIRM UX                              │
     │◀──│  "Save this memory? [y/N]"               │
     │   │  Frontmatter + body shown                │
     │   │  (post-redaction, what gets stored)      │
     │   └────┬─────────────────────────────────────┘
     │        │ y
     │        ▼
     │   ┌──────────────────────────────────────────┐
     │   │  Skill writes canonical file:            │
     │   │  ~/.cross-memory/<scope>/<type>_<slug>.md│
     │   └────┬─────────────────────────────────────┘
     │        │
     │        ▼
     │   ┌──────────────────────────────────────────┐
     │   │  Skill updates per-scope MEMORY.md       │
     │   └────┬─────────────────────────────────────┘
     │        │
     │        ▼
     │   ┌──────────────────────────────────────────┐
     │   │  Skill calls active adapter:             │
     │   │  adapter.mirror_write(path, content)     │
     │   │                                          │
     │   │  Claude Code adapter writes mirror to    │
     │   │  ~/.claude/projects/<slug>/memory/...    │
     │   │  with mirrored_from: <canonical-name>    │
     │   │  + sidecar manifest entry                │
     │   │  + sentinel-block update inside          │
     │   │    ~/.claude/projects/<slug>/memory/     │
     │   │    MEMORY.md (Decision 18)               │
     │   └────┬─────────────────────────────────────┘
     │        │
     │        ▼
     │   ┌──────────────────────────────────────────┐
     │◀──│  ECHO: "Wrote <canonical-path>;          │
     │   │         mirrored to <harness-path>"      │
     │   └──────────────────────────────────────────┘
     ▼
```

**Layered redaction.** The redaction pipeline now runs `<private>` strip first (Decision 14), then the regex denylist (Decision 9). `[REDACTED:private]` placeholders coexist with `[REDACTED:<category>]` placeholders in the candidate body the user sees before confirming.

### (b) Read flow — Session start with always-on tier injection

```text
┌─────────────┐
│  Session    │
│  start      │
└──────┬──────┘
       │
       ▼
┌─────────────────────────┐
│  Active adapter         │
│  (selected per Decision │
│   5: CLI > config >     │
│   env > probe > generic)│
└──────┬──────────────────┘
       │
       │ adapter.detect_harness()
       │ → "claude-code"
       │
       ▼
┌──────────────────────────────────────────┐
│  Adapter computes always-on tier         │
│  (per pseudocode in §4):                 │
│   - user-global (preference|rule|fact)   │
│   - project:<current-slug>               │
│       (feedback|project|rule)            │
│   - harness:claude-code (rule|feedback)  │
│   - any tag=always-on                    │
└──────┬───────────────────────────────────┘
       │
       │ for each memory in the tier:
       │   render staleness banner if due
       │
       ▼
┌──────────────────────────────────────────────┐
│  Format pipeline (Decision 15):              │
│   - Group memories into User Profile,        │
│     Project Knowledge, Relevant Memories     │
│     (the last is empty/omitted at v1)        │
│   - Render each as a single bullet           │
│     (description, capped at 120 chars)       │
│   - No confidence scores at v1               │
└──────┬───────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│  Size-budget enforcement                     │
│  (max_inject_chars from config; default 2048)│
│  Drop priority:                              │
│   1. Relevant Memories                       │
│   2. Project Knowledge (oldest first)        │
│   3. User Profile (oldest first)             │
│   4. NEVER drop [CROSS-MEMORY] header        │
└──────┬───────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│  Render as [CROSS-MEMORY] block              │
│  (between sentinel markers, Decision 18):    │
│                                              │
│  <!-- cross-memory:begin -->                 │
│  [CROSS-MEMORY]                              │
│                                              │
│  User Profile:                               │
│  - Prefers concise responses                 │
│  - Uses pytest, not unittest                 │
│                                              │
│  Project Knowledge:                          │
│  - Build: bash tooling/deploy.sh             │
│  - Strict lane boundaries enforced           │
│  <!-- cross-memory:end -->                   │
└──────┬───────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│  Claude Code adapter                         │
│  ─────────────────                           │
│  Writes mirror files (one .md per canonical  │
│  project memory) to                          │
│  ~/.claude/projects/<slug>/memory/           │
│  with mirrored_from + sidecar.               │
│                                              │
│  Rewrites the sentinel-bounded region of     │
│  ~/.claude/projects/<slug>/memory/MEMORY.md  │
│  with the [CROSS-MEMORY] block above.        │
│  Bytes outside the sentinels are preserved   │
│  byte-identically — including all native     │
│  Claude Code index entries.                  │
└──────┬───────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│  Claude Code's NATIVE auto-injection         │
│  reads ~/.claude/projects/<slug>/memory/     │
│  MEMORY.md and injects its contents          │
│  verbatim — including everything between     │
│  the sentinel markers — UNCHANGED by         │
│  cross-memory                                │
└──────┬───────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│  Assistant has the [CROSS-MEMORY] block      │
│  in context for the session                   │
└──────────────────────────────────────────────┘
```

For Cursor and generic harnesses, the bottom half differs: Cursor uses its native session-start mechanism (whatever it is — TBD by the Cursor adapter); generic does no auto-injection at all (the user runs `/cross-memory recall` explicitly). The `[CROSS-MEMORY]` block format and size-budget enforcement are harness-agnostic and run in all three. The sentinel-marker pattern is Claude Code-specific because the index-file-as-injection-source is Claude Code-specific; the Cursor adapter chooses its own equivalent surface.

---

## 13. Alternatives Considered & Rejected

This section gathers the rejected alternatives that aren't already documented inline above.

### Storing the canonical store as a SQLite database

**Considered:** A single `~/.cross-memory/store.sqlite` rather than markdown files in directories.

**Rejected:** Three reasons. (1) Loses the trivial mirroring story — Claude Code's existing memory is markdown files; adapters would need to materialize SQLite rows into markdown on every mirror pass, which is a translation step we're explicitly trying to avoid (driver 6). (2) Loses the human-readability story — users browsing `~/.cross-memory/projects/<slug>/` to see what's stored is a feature, not an inconvenience. (3) Adds a runtime dependency where none is needed; v1 doesn't have a query workload that benefits from SQL.

The `code-intel` agent uses SQLite because it has a recursive-CTE query workload that can't be done well with grep. Cross-memory does not.

### A separate `cross-memory-adapter-claude-code` skill

**Considered:** Promoting each adapter to its own top-level skill (`/cross-memory-adapter-claude-code`, etc.).

**Rejected:** Adapters are not user-facing. They have no slash-command surface; they're called by the cross-memory skill internally. Promoting them to skills inflates the user-visible skill count without adding capability. They live as companion `.md` files in `skills/cross-memory/` per the existing multi-file-skill pattern (e.g., `skills/ops/handoffs.md`, `skills/ops/state-schema.md`).

### Auto-dispatching the cross-memory agent at session start

**Considered:** Wiring the cross-memory agent to fire automatically on every new session for synthesis.

**Rejected:** Per requirements §11, this is an **explicit non-trigger**. The always-on tier handles session-start context; the agent is reserved for explicit synthesis requests and audit. Auto-dispatch at session start would slow every session and consume opus tokens for no marginal gain over the always-on tier.

### Separate `forget` and `archive` semantics

**Considered:** v1 ships separate behaviors — `forget` deletes; `archive` preserves.

**Rejected:** Per requirements §6, `forget` archives. There is no "permanently delete" operation at v1. This simplifies the user model (every removal is recoverable from `~/.cross-memory/archive/`) and matches the safety-first stance.

### Inline always-on tier in chat versus mirroring to harness paths

**Considered:** The skill prepends the always-on tier directly to its output on every dispatch, rather than relying on harness-native auto-injection.

**Rejected:** This would mean `/cross-memory` is the only way for the always-on tier to surface — every other agent's session would lack it. The whole point of mirroring is that **all** session-start contexts get the always-on tier, not just cross-memory's own outputs. Inline tier is incompatible with goal G2 (cross-project memory surfaces in any session).

### Separate `cross-memory.md` file in the harness memory dir (not sentinel-bounded MEMORY.md)

**Considered:** Have the adapter write a separate `cross-memory.md` file at `~/.claude/projects/<slug>/memory/` and add an index line to `MEMORY.md` pointing at it, instead of embedding the block inside `MEMORY.md`.

**Rejected:** Per Decision 18's evidence section. Empirical observation in this session shows Claude Code's auto-injection injects `MEMORY.md`'s contents verbatim and does NOT recursively load the linked-to per-memory files as separate context blocks. A sibling `cross-memory.md` would not surface as auto-injection — only its index line in `MEMORY.md` would. Sentinel-bounded embedding inside `MEMORY.md` is the only approach that uses the existing auto-injection mechanism without inventing a new one.

---

## 14. Risks & Mitigations

| Risk | Specific failure mode | Mitigation in design |
| :--- | :--- | :--- |
| **Silent capture surprises the user** | Auto-propose flow proposes a save the user didn't intend, user clicks `y` reflexively, unwanted memory persists. | Decision 4 — auto-propose triggers on **explicit cues only**, not heuristics. Confirmation UX shows full frontmatter + body before write. Default answer is **No**. |
| **Redaction false negatives leak secrets to disk** | A novel API-key shape not in the starter denylist (Decision 9) lands in a memory body. | Three layers: (1) inline `<private>...</private>` markup (Decision 14) lets the user explicitly mark anything regex misses; (2) audit's redaction-miss detection re-runs the denylist over existing memories at user-initiated cadence; (3) the starter denylist is flagged "starter, expandable" and the planner is expected to leave a hook for adding patterns post-v1. The `redaction_overridden_at` audit field surfaces explicit overrides. |
| **Unmatched `<private>` open tag** | User types `<private>` but forgets `</private>`; the parser must decide what to redact. | Decision 14 — bounded fallback: redact from open tag to next blank line, then stop. Confirmation gate displays the actual stored result so the user can correct the typo before persisting. The parser also emits a "warning: unmatched `<private>` tag" line in the confirmation UX. |
| **Mirror collisions corrupt Claude Code state** | Adapter writes to `~/.claude/projects/<slug>/memory/<name>.md` without realizing the path is occupied by a pre-existing native file. | Decision 6 — frontmatter `mirrored_from` + sidecar manifest. The adapter checks both before writing and refuses to overwrite a file with neither signal (i.e., a native file). Decision 18 adds a second-order rule: the adapter only edits the sentinel-bounded region of `MEMORY.md`; bytes outside the sentinels are read-only from the adapter's perspective. The audit's collision report surfaces all three states (native, stale-mirror, user-edited-mirror). SC-14 guards per-memory files; SC-19 guards `MEMORY.md` outside the sentinels. |
| **Harness misdetection** | On a machine where both Claude Code and Cursor markers are present, the wrong adapter activates and mirrors to the wrong harness path. | Decision 5 — explicit precedence. CLI flag and config file are deterministic; only the manifest probe is heuristic, and probe order is documented. Users can override via `~/.cross-memory/config.yaml` `current_harness:`. |
| **Store growth** | Over months, `~/.cross-memory/` accumulates thousands of memories. Audit becomes slow; recall becomes noisy. | Audit's staleness flag + manual prune flow handles natural decay. Forget moves to archive; archive is never injected. v2 indexing (OQ-5) is the next step if growth becomes a real performance problem. |
| **Contradiction supersede loses important context** | A user supersedes "always rebase" with "always merge," but later realizes "always rebase" was right for one specific project. | Per requirements §6, every supersede archives the predecessor with `superseded_by: <new-name>`. The full prior content is recoverable from `~/.cross-memory/archive/`. Audit's contradiction detector flags **before** supersede; the diff-confirmation UX shows what's being replaced. |
| **`--no-redact` typo accidentally persists secrets** | User intends `[y/N]: n` but types `y`. | Decision 10 — typed-phrase confirmation (`save unredacted`). Anything else cancels. Decision 14 — `<private>` markup is always honored even when `--no-redact` is in effect, so explicit user-marked content is never persisted unredacted. |
| **Adapter writes to wrong project on slug ambiguity** | (a) Two projects with paths that differ only in case land at the same slug on case-insensitive filesystems. (b) An executor implements Decision 1's stale rule wording instead of Decision 19's evidence-based rule, and every Claude Code mirror lands in a wrong directory. | (a) The slug derivation is path-character-sensitive (Decision 19). On case-insensitive FS, the OS-level path resolution is the authoritative tie-break — same as Claude Code's existing behavior. We inherit the same edge case rather than introducing a new one. (b) Decision 19 ties the rule to observed evidence and prescribes a one-line pre-flight (`ls ~/.claude/projects/`) before M3.implement.1 starts. SC-20 verifies the rule against the live filesystem. |
| **Cross-memory drifts into external-knowledge RAG** | Users start saving documents, books, third-party reference material in `~/.cross-memory/`. | Decision 17 — the non-goal is sharpened: external-knowledge RAG is out; project-fact distillation is in. The schema's `type` enum (`feedback|project|preference|fact|rule`) and the new `category` enum (Decision 16) frame what belongs. Discipline lives in the schema, not in code. |
| **Sidecar manifest divergence** | The `~/.<harness>/cross-memory-mirrors.json` sidecar gets out of sync with the canonical store after a manual file deletion. | The audit's collision detection treats this as a soft warning, not an error. The next mirror pass rewrites the sidecar from canonical truth. The frontmatter `mirrored_from` is the second signal — defense in depth (Decision 6). |
| **Always-on tier exceeds prompt budget** | A user accumulates 200 user-global preferences; the always-on tier injection blows past the harness's context budget. | Decision 15 — configurable `max_inject_chars` (default 2048) with explicit drop priority (Relevant Memories → oldest Project Knowledge → oldest User Profile; never drop the `[CROSS-MEMORY]` header). Inclusion rules are intentionally narrow (only `preference|rule|fact` for user-global, only `feedback|project|rule` for project, etc.). The escape hatch tag `always-on` opts specific memories in, not out — the v2 inverse tag `never-on` is a possible future addition. |
| **Sentinel corruption in `MEMORY.md`** | A user edits `MEMORY.md` and accidentally deletes only one of the two sentinel markers, or splices content across them. | Decision 18 step 2 — adapter refuses-and-halts if exactly one sentinel is present. If both are absent, the adapter treats the next write as the bootstrap (re-establishes both markers around an empty region). The audit also flags the corrupted state so the user can repair it before the next session. |

---

## 15. Verification Plan

Each success criterion (SC-1 through SC-21) is verified by a single scripted scenario or manual run. The verifier agent will run these post-implementation; the planner should generate a task per scenario.

| SC | Scenario |
| :--- | :--- |
| **SC-1** | (1) On project A, `/cross-memory save --scope user-global --type preference --tags python --name "Prefer pytest" "Use pytest..."`. Confirm. (2) Switch to project B (different absolute path → different slug). (3) Start new session. Verify the always-on tier injection includes "Prefer pytest" (the User Profile sub-section of the `[CROSS-MEMORY]` block, surfacing via the sentinel-bounded region of project B's `MEMORY.md` per Decision 18). |
| **SC-2** | (1) On Claude Code, save `project:<slug>` memory. Confirm. (2) Switch to Cursor on the same project. (3) Run `/cross-memory recall <topic>`. Verify the memory is returned. |
| **SC-3** | (1) Trigger explicit cue ("remember that..."). (2) Skill shows redacted candidate. (3) Reply `y`. (4) Verify file at canonical path; verify `originSessionId` matches. (5) Run `/cross-memory recall <topic>`; verify memory returned. |
| **SC-4** | (1) Save `project:<slug>` memory. (2) Verify per-memory mirror file written at `~/.claude/projects/<slug>/memory/<type>_<slug>.md` (with `mirrored_from` frontmatter and a sidecar entry per Decision 6). (3) Verify `~/.claude/projects/<slug>/memory/MEMORY.md` contains the sentinel-bounded `[CROSS-MEMORY]` block per Decision 18 (markers present; new memory's bullet rendered inside the User Profile or Project Knowledge sub-section per Decision 15). (4) Restart Claude Code on that project. (5) Verify Claude Code's native auto-injection includes both the per-memory mirror file (referenced from the corresponding `MEMORY.md` index line) and the literal `[CROSS-MEMORY]` block (injected as part of `MEMORY.md`'s contents). |
| **SC-5** | (1) Save `project:<slug>` memory; verify mirror written. (2) `/cross-memory forget <name>`; confirm. (3) Verify canonical file moved to archive; verify mirror removed; verify sidecar manifest updated; verify the `[CROSS-MEMORY]` block inside `MEMORY.md` no longer renders that memory's bullet. |
| **SC-6** | (1) Trigger auto-propose with body containing `sk-abc123def456...`. (2) Verify confirmation prompt shows `[REDACTED:api-key]`. (3) Confirm; verify persisted file has `redacted: true`. |
| **SC-7** | (1) `/cross-memory save ... "Bearer eyJabc.eyJdef.ghi"`. (2) Verify warning shown with `jwt` category named. (3) Verify default answer is `No`. (4) Confirm with `y`; verify persisted file has `redacted: true`. |
| **SC-8** | (1) Place a memory with `verified_at: 91 days ago` in the store. (2) `/cross-memory audit`. (3) Verify report's "Stale memories" section is rendered to chat (no on-disk artifact written per Decision 20) and lists the memory with refresh/archive/forget actions. |
| **SC-9** | (1) Same setup as SC-8. (2) `/cross-memory recall <topic>`; verify memory returned with staleness banner. (3) Start new session; verify always-on tier still injects it (banner preserved). |
| **SC-10** | (1) Save memory M1 with `name: foo`. (2) Save memory M2 with same `name: foo`. (3) Verify diff-confirmation UX. (4) Confirm. (5) Verify M1 moved to `~/.cross-memory/archive/foo-<timestamp>.md` with `superseded_by: <M2-filename>`. (6) Verify M2's `created_at` matches M1's; `updated_at` is now. |
| **SC-11** | (1) `/ops` dispatches `cross-memory` agent with `intent: synthesize, query: "Python preferences and security rules"`. (2) Verify response includes Python-tagged memories, excludes other-language memories, excludes unrelated-project memories, stays under 4000 chars. |
| **SC-12** | (1) Place two memories with overlapping `tags: [git]` and contradicting bodies. (2) `/cross-memory audit`. (3) Verify the chat-rendered report's "Contradictions" section lists both with paths and **does not auto-resolve**. |
| **SC-13** | (1) Spawn `cross-memory` agent with a brief that attempts to write to `src/auth/handler.py`. (2) Verify refuse-and-halt with violation report (per the Decision 22 lane-boundary text). (3) Verify no source file modified. (4) Verify the agent's allowlist as embedded in the agent definition contains exactly the three globs from Decision 22 (`~/.cross-memory/**`, the sentinel-bounded MEMORY.md glob, and `_tmp_*`) — no `.code-intel/**` or other non-cross-memory globs leaked into the copy. |
| **SC-14** | (1) Snapshot `~/.claude/projects/<slug>/memory/` contents per file (file paths + SHA-256 per file), with **`MEMORY.md` snapshot taking the bytes outside the sentinel-bounded region only** (the region inside the sentinels is adapter-managed and excluded from the byte-identical guarantee per Decision 18). (2) Install cross-memory; run first audit. (3) Re-snapshot per the same rule; diff against (1). Verify all per-memory `<type>_<slug>.md` files are byte-identical, and the outside-sentinel bytes of `MEMORY.md` are byte-identical. |
| **SC-15** | (Decision 14 — inline `<private>` markup.) (1) `/cross-memory save --scope user-global --type fact --name "Test secret" "API key is <private>my-secret-token</private>; rest of note."`. (2) Verify confirmation gate shows `API key is [REDACTED:private]; rest of note.` (3) Confirm. (4) Verify stored memory contains `[REDACTED:private]` literally in the body and `redacted: true` in frontmatter. (5) `/cross-memory recall "Test secret"` — verify rendered output replaces the placeholder with `…` (ellipsis) so the placeholder string itself does not display. |
| **SC-16** | (Decision 15 — `[CROSS-MEMORY]` injection format; Decision 18 — sentinel-bounded landing path.) (1) Seed three `user-global` memories with `category: preference` and two `project:<slug>` memories with `category ∈ {project-config, architecture}`. (2) Start a new session on the same project. (3) Verify the injected block lives between `<!-- cross-memory:begin -->` and `<!-- cross-memory:end -->` inside `~/.claude/projects/<slug>/memory/MEMORY.md`, and contains the literal header `[CROSS-MEMORY]`, a `User Profile:` sub-section with three bulleted descriptions, a `Project Knowledge:` sub-section with two bulleted descriptions, and **no** `Relevant Memories:` sub-section header (omitted at v1). (4) Verify each bullet is a single line under 120 chars (truncate with `…` if longer). (5) Verify total block length ≤ `max_inject_chars` (default 2048). |
| **SC-17** | (Decision 16 — `category` field.) (1) `/cross-memory save --scope user-global --type feedback --category error-solution --name "Build cache fix" "Clear .next/cache when builds drop env vars."`. Confirm. (2) Verify stored frontmatter has both `type: feedback` and `category: error-solution`. (3) Verify retrievable via `/cross-memory recall "build" --type feedback`. (4) Verify retrievable via `/cross-memory list --category error-solution`. (5) Verify a pre-existing memory at `~/.claude/projects/<slug>/memory/` without `category` is treated as `category: other` at read time and surfaces in `/cross-memory audit` as a curation opportunity (not an error). |
| **SC-18** | (Decision 17 — non-goal clarified; project-fact distillation in scope.) (1) `/cross-memory save --scope project --type project --category project-config --name "Build command" "Build command: bash tooling/deploy.sh"`. Confirm. (2) Verify saved memory has `scope: project:<slug>`, `type: project`, `category: project-config`. (3) Start a new session on that project. (4) Verify the `[CROSS-MEMORY]` block's `Project Knowledge:` sub-section includes a bullet rendered from this memory's `description`. |
| **SC-19** | (Decision 18 — sentinel-marker preservation.) (1) Pre-populate `~/.claude/projects/<test-slug>/memory/MEMORY.md` with three native index lines and no sentinel markers. (2) Run `/cross-memory save --scope project --name "Sentinel test" "Body."`. Confirm. (3) Verify `MEMORY.md` now contains the three original native index lines unchanged (byte-identical) AND the `<!-- cross-memory:begin -->` / `<!-- cross-memory:end -->` markers framing the rendered `[CROSS-MEMORY]` block. (4) Edit one native index line by hand to a new value; run another save. (5) Verify the user-edited native line is preserved byte-identically in the new `MEMORY.md`; the cross-memory region is updated to reflect the new save. (6) Manually delete only the `<!-- cross-memory:end -->` marker; run another save. (7) Verify the adapter refuses-and-halts with a "corrupted sentinel state" violation report and does not write. |
| **SC-20** | (Decision 19 — slug derivation against live filesystem.) (1) Run `ls ~/.claude/projects/` and capture the output. (2) For each entry the executor's slug-derivation function would produce given the corresponding absolute path, verify the function's output matches the literal directory name byte-for-byte. (3) For the active project (`D:\Repositories\Personal\Git\AI-Skills-Agents` on Windows / `~/.claude/projects/D--Repositories-Personal-Git-AI-Skills-Agents` on disk), verify the function produces `D--Repositories-Personal-Git-AI-Skills-Agents`. (4) For at least one Unix-style path (e.g., `/home/ubuntu/Projects/foo`), verify the function preserves the leading dash (`-home-ubuntu-Projects-foo`) — no leading-dash trim. |
| **SC-21** | (Decision 22 — cross-memory-specific lane allowlist.) (1) Spawn the cross-memory agent with a brief that attempts to write to (a) `.code-intel/index.sqlite` (b) `~/.claude/projects/<slug>/memory/<type>_<other>.md` outside the sentinel-bounded region of `MEMORY.md` (c) a path under `_tmp_*` (allowed). (2) Verify (a) and (b) refuse-and-halt with a structured lane-violation report containing the attempted path, refusal reason ("path does not match any allowed glob"), and requester context. (3) Verify (c) succeeds (allowed by the `_tmp_*` glob). (4) Verify the agent definition's lane-boundary text contains the three globs from Decision 22 and no others — specifically, no `.code-intel/**`, no `docs/code-intel/**`, no source-code globs. |

---

## 16. Open Questions Remaining

Two of the nine open questions stay open after this ADD. Both can be resolved post-v1 without architectural rework.

### OQ-5 — Embedding/keyword indexing for filtered auto-inject

**Why still open.** Per requirements, OQ-5 is explicitly post-v1. The architectural design above leaves three hooks for it: (a) the per-scope `MEMORY.md` index can be supplemented with an aggregate index without disrupting the per-scope ones; (b) the read path's `recall` and `search` are abstracted enough that swapping in a keyword/embedding backend is a single replacement; (c) the canonical store's flat-file structure trivially feeds an external indexer (sqlite-vss, lunr, etc.). The question of which backend to use depends on whether v1's grep-based `recall` proves slow enough to justify the indexing cost. Decision 15 also defers per-bullet **confidence scores** to this same milestone — semantic similarity is the upstream prerequisite for both. **Resolution path:** measure v1 in production for 30-90 days; if `recall` latency or relevance becomes a complaint, dispatch the architect again with the measured workload as input. The same dispatch revisits confidence scoring in the `[CROSS-MEMORY]` block.

### OQ-6 — Boundary against project documentation systems

**Why still open** (lightly refined to reflect Decision 17). Decision 17 has clarified the high-level boundary: external-knowledge RAG is out of scope; project-fact distillation is in. What remains genuinely open is the finer-grained question of **whether memories may reference repo paths** (e.g., `see docs/cross-memory/architecture-decision.md`) and **what happens when those paths move**. This is a product question, not an architecture question — the schema can accommodate either answer with a small additive change. **Resolution path:** the planner asks the user one question — "Should memories be allowed to reference paths inside repos, and what happens when those paths move?" — and either updates the schema (adding a `references:` array with stale-link detection in audit) or adds a "no repo-path references" body convention warning. Either resolution is a v1.x patch, not a v2 milestone. Decision 17 narrows but does not close OQ-6.

---

## Captured-Decision Concerns

None. The 12 settled decisions in the requirements doc are internally consistent and compatible with the design above. The architect did not find a captured decision that needed revision. The four post-review additions (Decisions 14-17) and the five critic-driven additions (Decisions 18-22) extend rather than contradict the captured decisions; the requirements doc is unchanged.

---

## Discovered During Revision

While incorporating the four supermemory-inspired revisions, two adjacent concepts surfaced that the user may want to evaluate but that are **out of scope for this revision**. Both are flagged here for the user's decision; the architect did **not** silently add them.

1. **`/cross-memory init` codebase-exploration command (post-v1).** `supermemoryai/opencode-supermemory` ships `/supermemory-init` that runs an initial codebase scan and writes typed memories about it. Decision 17 acknowledges this is in-scope for the cross-memory model but explicitly defers the command itself to post-v1. If the user wants v1 to ship this command, the requirements doc's v1 surface area would expand and a new architect dispatch would be warranted — it is structurally non-trivial because it interacts with redaction, confirmation, batch-write, and category assignment in one flow.

2. **Per-bullet confidence scoring in the `[CROSS-MEMORY]` block.** Deferred to post-v1 alongside indexing (OQ-5) per Decision 15. If the user later wants to ship this earlier (e.g., paired with a lightweight keyword index instead of full embeddings), the read-path design needs revisiting.

These are surfaced for transparency. No action taken.

---

## Discovered During Critic Revision

While addressing the five critic findings, the verification pass surfaced one adjacent observation that is **not silently fixed** and is recorded here for the critic's re-evaluation:

1. **Cross-memory's README will deploy to Cursor, but not to Claude Code or Claude Code WSL.** Per the verified manifest in Decision 21: claude-code and claude-code-wsl `skills.exclude` does NOT list `README.md`, but `skills.include: ["**/*.md","**/*.yaml"]` does match it — so README *will* deploy to Claude Code targets too. Re-checking: every other skill in the repo (`skills/clickup/README.md`, `skills/code-review/README.md`, etc.) deploys identically. This is consistent with existing precedent and is not a defect; it is documented here only because the prior ADD's "README excluded from skill deploy via the manifest" claim (in §"Existing Architecture" → "Repo layout") was overstated. The accurate statement is: **READMEs in `skills/<name>/` deploy on every target; only `agents/README.md` is excluded** (via the agents block's `README.md` exclude). The Existing Architecture section has been corrected to reflect this. No further action proposed.

This observation does not require a new decision; it is a correction to a wording inaccuracy that does not change any structural recommendation.

---

## Cross-References

- `docs/cross-memory/requirements.md` — authoritative input. This ADD references its sections by number throughout.
- `docs/cross-memory/critic-review.md` — drove Decisions 18-22 and the corresponding revisions in §1, §4, §6, §8, §10, §11, §12(b), §14, §15.
- `skills/ops/brief-contract.md` — universal brief grammar. The cross-memory agent's brief format builds on this.
- `agents/code-intel.md` — JSON-fenced brief precedent and the structural pattern reused (not the literal text) for Decision 22's lane-boundary section. The cross-memory agent's allowlist globs are cross-memory-specific.
- `tooling/deploy-manifest.json` — deploy entry points. Decision 21 documents the verified globs; cross-memory's components are picked up without a new manifest entry, subject to the markdown-only constraint on the cursor side.
- `~/.claude/projects/<slug>/memory/` — Claude Code's native memory layout. Cross-memory mirrors per-memory files into this directory; the `[CROSS-MEMORY]` block lives inside the sentinel-bounded region of `MEMORY.md` per Decision 18; SC-14 + SC-19 protect the rest from migration damage.
- `~/.claude/CLAUDE.md` Active Skill Detection table — the planner should add a `Cross-Memory` row. This is a documentor task downstream.
