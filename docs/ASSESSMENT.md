# AI Skills and Agents — Assessment Report

**Date:** 2026-07-02 (team agents: generalist, infra, db; scout read-only investigator)
**Previous assessment:** 2026-06-11 (agentic vectors + preflights extraction), 2026-06-01 (research agent), 2026-05-24 (corpus-search v1 ship), 2026-05-19 (ops save subcommand), 2026-05-14 (cross-memory v1.1 + v1.2 + skill optimization), 2026-05-09 (cross-memory v1 ship), 2026-05-04 (agent-contract hardening + brief contract), 2026-04-26 (code-intel agent), 2026-04-21 (ops decoupling and tooling expansion), 2026-04-17 (project audit), 2026-04-15 (agent dispatch fix), 2026-04-14 (state unification), 2026-04-14 (updated), 2026-04-14 (initial), 2026-04-07
**Scope:** All agents, skills, hooks, and tooling in the repository
**Overall Rating:** HEALTHY — no structural issues

---

## Inventory

### Agents (`agents/`)

27 agent definitions + 1 README.

| File | Model | Role |
| :--- | :--- | :--- |
| architect.md | opus | Design exploration and Architecture Decision Documents (ADDs) |
| change-analyzer.md | sonnet | Classifies git diffs and recommends pipeline stages to run or skip |
| code-intel.md | opus | Indexes the project into a SQLite symbol graph and answers structural queries (callers, dependencies, impact, execution flow) for other agents |
| code-reviewer.md | sonnet | Two-stage pipeline code review with severity-rated findings |
| code-reviewer-diff.md | sonnet | Standalone diff review with full diff-gathering protocol |
| corpus-search.md | opus | Terminal-native multi-hop corpus search for free-text evidence, file location, claim verification, and reference tracing — every finding cites path:line |
| critic.md | opus | Quality gate on plans and scoping documents |
| cross-memory.md | opus | Synthesizes curated context blocks from the cross-memory store and audits the store for staleness, duplicates, contradictions, and redaction misses |
| db.md | sonnet | Database operations — schema migrations, queries, backup/restore; backup-before-mutate discipline with a permission-layer-gated write path |
| debugger.md | opus | Hypothesis-driven runtime bug investigation |
| debugger-build.md | opus | Build/compilation error diagnosis (import, type, dependency, config) |
| documentor.md | sonnet | Documentation writer, delegates accuracy checks to `/doc-sync` |
| executor.md | sonnet | Implements code changes from validated plans |
| generalist.md | sonnet | Disciplined in-domain catch-all for cross-lane residual work no specialist owns; minor/small edits only, defers everything else via a specialist gate |
| git-master.md | sonnet | Git operations, branching, commits, PRs, releases, pause/resume |
| infra.md | sonnet | Provider-agnostic IaC / cloud / Kubernetes operations; validate→plan→gated-apply→verify with a permission-layer destructive-op gate |
| interviewer.md | opus | Socratic requirements interview before planning |
| planner.md | opus | Breaks specs into structured implementation plans |
| preflight.md | sonnet | Environment readiness checks before agent work begins |
| project-scoper.md | opus | Requirements analysis, gap detection, effort estimates |
| research.md | opus | External/web research, multi-source fact-checking, and synthesis into cited reports; read-only on code, writes only `docs/research/` report artifacts |
| rollback.md | sonnet | Safely undoes agent-produced changes at configurable scope |
| scout.md | sonnet | Read-only investigator for open, fuzzy repo questions; sweeps adaptively and synthesizes inline `path:line` findings |
| security-reviewer.md | opus | Security audit with severity-rated vulnerability findings |
| ssh-executor.md | sonnet | Remote command execution and file transfer via SSH |
| verifier.md | sonnet | Validates implementation against acceptance criteria |
| work-verifier.md | sonnet | Verifies whether prior agent work was completed, partial, or never started |

### Skills (`skills/`)

13 multi-file skills. 6 converted from single-file commands in the initial restructure; 1 added in the ops decoupling; 1 added as the kickoff skill; 1 added in the cross-memory v1 ship; 1 added as `using-ai-skills-agents`.

| Skill | Directory | Files | SKILL.md Lines | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| ClickUp | `skills/clickup/` | 2 | ~276 | ClickUp REST API integration |
| Code Review | `skills/code-review/` | 2 | ~207 | Diff-based code review orchestration |
| Commit Message | `skills/commit-message/` | 2 | ~75 | Conventional Commits message generation |
| Cross-memory | `skills/cross-memory/` | 19 | 381 | Harness-portable memory layer with nine subcommands (init, save, recall, list, forget, search, audit, doctor, reflect) and an opus-class agent for synthesis, audit, and distill |
| Deploy | `skills/deploy/` | 9 | ~412 (Claude), ~408 (Cursor) | Remote deployment orchestration via ssh-executor |
| Deslop | `skills/deslop/` | 2 | ~669 | AI slop cleanup (dead code, redundant comments, over-abstraction) |
| Doc Sync | `skills/doc-sync/` | 2 | ~83 | Documentation audit and sync against codebase |
| Kickoff | `skills/kickoff/` | 7 | 451 | Scaffolds project planning infrastructure, interviews users, dispatches agents to produce structured plans, and populates plan files ready for `/next` execution |
| Linter | `skills/linter/` | 2 | ~141 | Source file linting with auto-fix and incremental cache |
| Ops | `skills/ops/` | 25 | 567 (Claude), 611 (Cursor) — phase flow extracted into companions | Multi-agent task orchestration, dispatch, and tracking (Phase 2.5b/2.5c advisory preflights in `phase-preflights.md`; budget governor `--budget=<N>`; durable adaptation ledger with `--no-adaptation-memory` opt-out; health-action recovery) |
| Ralph Loop | `skills/ralph-loop/` | 16 (incl. SKILL.cursor.md, 5 YAML templates) | ~334 (Claude), ~338 (Cursor) | Iterative execute-verify-reflect loop with state persistence |
| Timing Calibrator | `skills/timing-calibrator/` | 2 | ~214 | Captures timing patterns from agent runs and calibrates estimates |
| Using AI Skills Agents | `skills/using-ai-skills-agents/` | 1 | ~83 | Usage/onboarding guide for this repo's agents and skills (single-file, instructional) |

### Documentation (`docs/`)

| File | Purpose |
| :--- | :--- |
| `docs/ASSESSMENT.md` | This file — periodic repo health snapshots |
| `docs/portability-guide.md` | Format differences and tool gaps between Claude Code and Cursor |
| `docs/ops-dispatch-log.md` | Append-only audit trail of `/ops` dispatch decisions (opt-in via `--dispatch-log`; 18 lines — seed header only until populated) |

### Documentation (`docs/agent-audits/`)

| File | Purpose |
| :--- | :--- |
| `docs/agent-audits/tier-a-opus-4-7-audit.md` | Tier A Opus 4.7 explicitness audit — 5 core agents reviewed, 4 BLOCKERs + 27 MAJORs + 19 MINORs found; BLOCKERs resolved via brief-contract spec |

### Documentation (`docs/code-intel/`)

| File | Purpose |
| :--- | :--- |
| `docs/code-intel/integration-test.md` | 418-line walkthrough spec for ralph-loop → /ops → code-intel end-to-end integration test |
| `docs/code-intel/failure-mode-walkthrough.md` | 85-line R10 walkthrough covering 13 failure-mode scenarios |
| `docs/code-intel/design-trace.md` | 76-line R1–R11 + Q1–Q10 design trace table (21 rows, all DONE) |

### Documentation (`docs/corpus-search/`)

| File | Purpose |
| :--- | :--- |
| `docs/corpus-search/integration-test.md` | 210-line walkthrough spec for standalone dispatch, `/ops` Phase 2.5c integration, dual preflight with code-intel, Phase 4 cleanup, and refusal handling |

### Hooks (`hooks/`)

| File | Purpose |
| :--- | :--- |
| post-compaction-context.sh | Restores project context after Claude Code compaction events |
| notify.sh | Cross-platform notification script (Windows toast, macOS osascript, Linux notify-send) |

### Cursor Rules (`.cursor/rules/`)

| File | Purpose |
| :--- | :--- |
| documentation-sync.mdc | Mirror of `CLAUDE.md` § Documentation Sync for Cursor, loaded as a cursor rule |

### Tooling (`tooling/`)

| File | Purpose |
| :--- | :--- |
| deploy-manifest.json | Maps repo source directories to tool-specific global directories. 3 targets (claude-code, claude-code-wsl, cursor), 4 categories (agents, skills, hooks, settings). |
| deploy.ps1 | PowerShell deploy script (primary). `SKILL.cursor.md` detection, agent tool-restriction hardening, `--prune` mode, hooks/settings deployment. |
| deploy.sh | Bash deploy script (cross-platform, requires `jq`). Same features as deploy.ps1. |
| transform-cursor-ops.ps1 | PowerShell transform: generates `skills/ops/SKILL.cursor.md` from `SKILL.md` via an embedded patch list (`SKILL.cursor.additions.md` is a documentation mirror of those patches, not a transform input). |
| transform-cursor-ops.sh | Bash version of the ops Cursor transform. |
| transform-cursor-ralph-loop.ps1 | PowerShell transform: generates `skills/ralph-loop/SKILL.cursor.md` from `SKILL.md`. |
| transform-cursor-ralph-loop.sh | Bash version of the ralph-loop Cursor transform. |
| transform-cursor-deploy.ps1 | PowerShell transform: generates `skills/deploy/SKILL.cursor.md` from `SKILL.md`. |
| transform-cursor-deploy.sh | Bash version of the deploy Cursor transform. |

### Planning Documents (`docs/plan/` — 33 files: 7 tracked at root + 26 archived at `docs/plan/archive/`, all gitignored except the 7 tracked plans)

The seven tracked plans (`code-intel-agent-{requirements,scoping,design,plan,critique,critique-final}.md` and `ops-decoupling-plan.md`) remain at `docs/plan/` root as first-class historical references. The remaining 26 plans were moved to `docs/plan/archive/` as part of the 2026-05-14 cleanup pass — they map to shipped work in the repo and are kept locally for chronology, not for active consumption.

| File | Purpose |
| :--- | :--- |
| agent-health-monitoring-gaps-plan.md | Plan to close agent health monitoring gaps in dispatch and recovery |
| agent-roster-expansion-architecture.md | Architecture doc for agent roster expansion (architect and security-reviewer additions) |
| agent-splitting-plan.md | Plan to split large agents into smaller definitions |
| brief-contract-spec-add.md | Implementation additions spec for the brief-contract rollout |
| brief-contract-spec-plan.md | Plan for the ops agent-dispatch brief contract specification |
| code-intel-agent-critique-final.md | Final critic findings for code-intel agent (BLOCKER + 6 MAJORs) |
| code-intel-agent-critique.md | Initial critic pass on the code-intel agent design |
| code-intel-agent-design.md | Design document for code-intel agent architecture |
| code-intel-agent-plan.md | Implementation plan for code-intel agent |
| code-intel-agent-requirements.md | Requirements document for code-intel agent |
| code-intel-agent-scoping.md | Scoping document for code-intel agent |
| cursor-portability-gaps.md | Plan for Cursor-native adaptations of ops and deploy (completed) |
| deploy-prune-mode-plan.md | Plan for deploy `--prune` mode implementation |
| deploy-skill-interface-contract.md | Interface spec for `/deploy` ↔ `ssh-executor` briefs |
| deploy-skill-plan.md | Implementation plan for deploy skill |
| kickoff-skill-plan.md | Plan for the kickoff skill |
| next-steps-roadmap.md | Roadmap for restructure, portability, and deployment automation |
| ops-claude-code-features-plan.md | Plan for Claude Code–specific ops features (--brainstorm, nested-skill handoff) |
| ops-decoupling-plan.md | Plan for extracting ops companion files into standalone agents/skills (**tracked in git**) |
| ops-handoff-cleanup-plan.md | Handoff file lifecycle and cleanup for ops |
| ops-nested-skill-handoff-plan.md | Plan for nested-skill handoff gap closure |
| ops-skill-optimization-plan.md | Context reduction plan for ops SKILL.md |
| ops-skill-optimization-r2-assessment.md | Round-2 assessment and extraction plan for ops SKILL.md and SKILL.cursor.md |
| ops-skill-optimization-r3-deep-dive.md | Round-3 deep-dive assessment for ops companion consolidation |
| ralph-loop-audit-assessment.md | Post-migration audit of ralph-loop skill |
| ralph-loop-optimization-r2-deep-dive.md | Round-2 deep-dive for ralph-loop optimization sprints |
| ralph-loop-skill-optimization-plan.md | Modularization plan for ralph-loop |
| ssh-agent-plan.md | Plan for ssh-executor and ops/deploy integration |
| unify-ops-state-management-plan.md | Plan to unify ops state management across Claude Code and Cursor |

---

## Changes Since Last Assessment (2026-06-11 — agentic vectors + preflights extraction)

Five agentic-improvement vectors and a structural remediation shipped to `skills/ops/` across commits `3482a5a` (health-action), `7fb6dbe` (adaptation-ledger write-half), `65712ea` (budget governor), and `30f444e` (preflights extraction + remediation):

| Change | Summary |
| :--- | :--- |
| **Health-monitoring that acts** | Sustained-`OVERRUN` background agents are diagnosed via the read-only `work-verifier`; confirmed orphans re-dispatch once under the existing retry-then-escalate rule (`type: health-action` adaptations). |
| **Durable adaptation ledger (write-half)** | Phase 4 step 7a writes a per-run rollup (per-type adaptation counts, file-conflict pairs, plan-validation tier, critic-REVISE flag) to a gitignored per-project ledger before the run board is deleted; threshold-gated, unconditionally redacted, rolling 10-run window; `--no-adaptation-memory` opts out. The read-half (soft priors) is gated on corpus accrual; the `prior-applied` enum value is reserved for it. |
| **Standing budget governor** | Optional `--budget=<N>` dispatch-count ceiling consulted at a closed registry of cost-affecting choice points (2.5b/2.5c preflights, at-ceiling new-dispatch escalation, critique-tier); advisory and escalation-only — never above a verification or correctness gate. New `budget-escalation` adaptation type with `budget-near/escalated/deferred/spent/skipped` outcomes. |
| **Advisory-preflights extraction** | Phase 2.5b/2.5c contracts moved from `phase-dispatch.md` into the new `skills/ops/phase-preflights.md` companion with duplicated paragraph pairs unified; `phase-dispatch.md` retitled `# Phase 3 dispatch loop` (70.3KB → 44.2KB on the eager MUST-read path, under both extraction thresholds). Doc-sync map rows re-pointed. |
| **File count** | `skills/ops/` 21 → 25 files (`phase-preflights.md` + Vector-series companions). |

## Changes Since Last Assessment (2026-06-01 — research agent)

### New agent: `research`

`agents/research.md` (model: opus) is an external/web research layer that answers questions by searching the open web, corroborating claims across multiple independent sources, and producing cited, structured reports. Every factual claim in a report traces to a source row with a URL, access date, confidence label, and optional note. It is read-only on code and existing documentation; all write output is new file creation under `docs/research/<slug>.md` (durable) or `.research/runs/<run-id>/` (ephemeral scratch, self-cleaned at end-of-dispatch).

Confidence labels: `direct`, `corroborated`, `single-source`, `inferred`. Performance defaults: 15 source fetches, 5 follow-on hops, 120-second soft wall-clock. Brief-supplied URL sets are fixed at dispatch time and cannot be extended by fetched content (prevents indirect-injection pivots).

### `/ops` routing rows for `research`

Two routing rows were added to `skills/ops/phase-intake.md` to wire the research agent into the `/ops` dispatch table, covering standalone research tasks and web-evidence requests originating from planning or investigative dispatches.

### Net effect

| Surface | Before | After |
|---|---|---|
| Agent definitions | 22 | 23 |

---

## Changes Since Last Assessment (2026-07-02 — team agents: generalist, infra, db)

### Three new agents

Three project-owned agents were added so the team stops falling back to the harness-provided generic agents (`general-purpose`/`claude`), reserving those for genuinely out-of-domain work:

- **`agents/generalist.md`** (model: sonnet) — a disciplined in-domain catch-all for cross-lane residual work no specialist owns. Bounded by a defer-to-specialist gate (web work routes to `research`, structural/textual search to `code-intel`/`corpus-search`, IaC to `infra`, databases to `db`, and so on) and a six-predicate minor/small-edit boundary; anything larger defers to `executor`. No web tools.
- **`agents/infra.md`** (model: sonnet) — provider-agnostic Infrastructure-as-Code, cloud CLI, and Kubernetes operations (Terraform/Pulumi/CloudFormation/CDK/Ansible, aws/gcloud/az, kubectl/helm). Deliberately not split per cloud. Operating spine: validate → plan/diff → human-gated apply → verify convergence. Its destructive-op gate is permission-layer-enforced (mutating CLIs are not auto-allowed, so they prompt, and autonomous mode pauses on the prompt); the agent's STOP-before-mutate is a backstop. Composes with `ssh-executor` (domain vs transport).
- **`agents/db.md`** (model: sonnet) — database operations: migrations, queries, backup/restore. Backup-before-mutate discipline with the same permission-layer-enforced write gate. Composes with `ssh-executor` for tunneled/bastioned access.

Both `infra` and `db` carry a **custom proactive-opus escalation policy** — they default to `sonnet` but escalate to `opus` proactively for mutating/destructive/high-blast-radius operations, a second fleet-wide escalation exception alongside the `security-reviewer` opus ceiling.

### `/ops` wiring

The three agents were wired into `/ops` in companion files only — no `skills/ops/SKILL.md` edit, so no Cursor transform was required: `skills/ops/tool-restrictions.md` (residual in-domain work now routes to `generalist` rather than being absorbed directly by the team manager; delegate-first rows for `infra`/`db`; the proactive-opus escalation note) and `skills/ops/phase-intake.md` (Agent Assignment Rules rows + lane-boundary rows). Deployment needs no manifest edit — `tooling/deploy-manifest.json` picks up new agent files by its `**/*.md` glob.

### Net effect

| Surface | Before (2026-06-11) | After (2026-07-02) |
|---|---|---|
| Agent definitions | 23 | 26 |
| Fleet-wide model-escalation exceptions | 1 (`security-reviewer` opus ceiling) | 2 (+ `infra`/`db` proactive-opus) |
| In-domain catch-all | harness `general-purpose` | project-owned `generalist` |

---

## Changes Since Last Assessment (2026-07-02 — scout read-only investigator)

### New agent: `scout`

`agents/scout.md` (model: sonnet) is a first-class reconnaissance agent for open, fuzzy, read-only investigation — how something works, where something happens, whether a claim holds across the repo. It sweeps adaptively with `Read`/`Glob`/`Grep`/read-only `Bash`, follows leads across as many rounds as the question needs, and reports back inline with `path:line` citations, distinguishing confirmed findings (direct `Read`) from inferred ones. It holds no `Write` tool and no write-side `Bash`, so the read-only guarantee is structural rather than a promise. A defer-to-specialist gate routes fixed/reproducible queries to `corpus-search`, structural symbol-graph queries to `code-intel`, web-dependent questions to `research`, reproducible bugs to `debugger`, and any needed edit to `generalist`/`executor` — `scout` performs only what remains: genuinely open, fuzzy, repo-internal, read-only investigation. It is a first-class agent with its own identity, not a stripped-down copy of `generalist`, which is only one of its five lane-boundary neighbors.

### Fleet-wide `Explore` → `scout` consistency swap

The `/ops` Subagent Dispatch Decision Framework's `Explore` row (unknown location, broad scope, 3+ rounds likely) now points at `scout`, reserving the harness `Explore`/`general-purpose` agents for genuinely out-of-domain work. The same swap was carried fleet-wide to every remaining in-domain "Explore agent" reference for consistency: the Planner and Architect parallelization rows in `agents/README.md`, the Scaling sections of `agents/architect.md` and `agents/planner.md`, the input-analysis note in `agents/interviewer.md`, and the three in-domain mentions in `skills/ops/dispatch-log.md` — while any explicitly out-of-domain reference kept the harness fallback.

### `/ops` wiring

`scout` was wired into `/ops` in companion files only — no `skills/ops/SKILL.md` edit, so no Cursor transform was required: `skills/ops/phase-intake.md` (an Agent Assignment Rules row placed above the `generalist` residual row, plus a lane-boundary row adjacent to `generalist`) and `skills/ops/tool-restrictions.md` (a Delegate-First Table row and the Subagent Dispatch Decision Framework `Explore` → `scout` swap). Deployment needs no manifest edit — `tooling/deploy-manifest.json` picks up the new agent file by its `**/*.md` glob.

### Net effect

| Surface | Before (2026-07-02, team agents) | After (2026-07-02, scout) |
|---|---|---|
| Agent definitions | 26 | 27 |
| In-domain `Explore`-agent references (fleet-wide) | `Explore` | `scout` (harness `Explore`/`general-purpose` reserved for out-of-domain work) |

---

## Changes Since Last Assessment (2026-05-24 — corpus-search v1 ship)

### New agent: `corpus-search`

`agents/corpus-search.md` (531 lines, model: opus) is a terminal-native multi-hop corpus search layer that answers four investigative query types — `evidence_search`, `locate`, `verify_claim`, and `trace_reference` — via `rg`/`Glob`/`Read`, returning deterministic `path:line` evidence stamped with `corpus_indexed_sha` and `generated_at`. It is read-only on source code; writes are limited to `.corpus-search/**`, `docs/corpus-search/**`, and `_tmp_*`.

The agent is dispatched by `/ops` Phase 2.5c (advisory preflight) and standalone for human investigative tasks. It is a sidecar utility, not a pipeline stage.

### `/ops` Phase 2.5c — corpus-search dispatch stage

A new "Phase 2.5c — Corpus Search Preflight (advisory)" section was added to both `skills/ops/SKILL.md` and `skills/ops/SKILL.cursor.md`. The stage fires when predicate `(i) OR (ii) OR (iii)` matches for `executor`, `debugger`, or `documentor` dispatches: investigation keywords in the brief, debugger/documentor tasks with no extractable primary symbol, or executor rename/migration tasks with textual migration cues. When Phase 2.5b also matches on an executor task, the dual preflight sequence runs code-intel first, then corpus-search with `trace_reference`. The analysis is advisory — the consumer proceeds whether or not corpus-search responds — and dispatches are logged when `--dispatch-log` is set. Phase 4 step 9 cleans `.corpus-search/runs/<run-id>/` (ephemeral run artifacts only; no persistent index).

Flags: `--corpus-search` (alias for `--corpus-search=always`) and `--corpus-search=off`.

### Three consumer Corpus Search Context sections

Three consumer agents received a new `## Corpus Search Context` section establishing how they consume corpus-search output:

| Agent | Integration |
|-------|-------------|
| `agents/executor.md` | Reads the Evidence table from Phase 2.5c reports before the first `Edit` |
| `agents/debugger.md` | Seeds hypotheses from Evidence table hits before Phase 3 (Hypothesis & Testing) |
| `agents/documentor.md` | Cites Evidence table entries when writing docs; verification-gate requires fresh `Read` before completion |

`skills/ops/brief-contract.md` gained `Corpus Search Context` as an optional brief section for orchestrator dispatch.

### Supporting touchpoints

| Change | Detail |
|--------|--------|
| **`agents/README.md`** | Added corpus-search to the agent roster table, Utility Agent section, and model assignments |
| **`CLAUDE.md` doc-sync row** | Added `agents/corpus-search.md` row mapping to `skills/ops/SKILL.md` (Phase 2.5c) and `tooling/deploy-manifest.json` |
| **`.cursor/rules/documentation-sync.mdc`** | Mirror row added; agent count corrected to 22 |
| **`docs/corpus-search/integration-test.md`** | 210-line walkthrough spec: standalone dispatch, Phase 2.5c, dual preflight, Phase 4 cleanup, refusal handling |
| **`skills/ops/verification-gate.md`** | Canonical verification-gate ritual referenced by corpus-search consumer agents and documentor |

### Net effect

| Surface | Before (2026-05-19) | After (2026-05-24) |
|---|---|---|
| Agent definitions | 21 | 22 |
| `/ops` preflight stages | Phase 2.5b (code-intel) | Phase 2.5b + Phase 2.5c (corpus-search) |
| `skills/ops/` companion files | 17 | 21 |
| `skills/ops/SKILL.md` lines | 939 | 1,223 |
| Corpus-search consumer hooks | 0 | 3 (executor, debugger, documentor) |

---

## Changes Since Last Assessment (2026-05-19 — ops save subcommand)

### `/ops save` subcommand — 2026-05-19

The `/ops` skill gained a `save` subcommand that writes a manual checkpoint mid-run. Invoking `/ops save` flushes the current board state and writes a second file — `.ops-state/<run-id>-save.json` (8 fields) — capturing conversation-side context the board file does not preserve: the next intended action, verbal decisions made mid-run, the working hypothesis, and open questions awaiting a decision. The canonical spec lives in the new companion file `skills/ops/subcommand-save.md` (~189 lines); `SKILL.md` gained an argument bullet, a Triage Gate row, a Phase 1 Intake row, a Save Subcommand subsection, and a Phase 4 cleanup paragraph. `state-schema.md` gained the `phase-3-save-followup` resume phase value; `interruption-recovery.md` gained a `Pause vs Save` subsection; `help-card.md` and `README.md` were updated with the new command.

Four design properties distinguish this subcommand. First, **unconditional redaction**: all four user-supplied text fields (`next_action`, `verbal_decisions`, `working_hypothesis`, `open_questions`) pass through the existing cross-memory redaction module — Pass A (regex) and Pass B (LLM) — before the file touches disk. There is no `--redact` flag and no opt-out; the subcommand reuses the existing module rather than introducing parallel logic. Second, **atomic write**: the save file is written to a temp path, parsed back to confirm valid JSON, then renamed into place on success; on failure the temp file is deleted and no partial write is left on disk. Third, **`pending_nested_skill` non-null guard**: if a nested skill is already mid-flight (the state field is non-null), the post-save prompt offering to run `/cross-memory reflect` is suppressed entirely, preventing a second nested skill from launching while one is already pending. Fourth, the **reflect handoff is optional and default-N**: the user must opt in to the `/cross-memory reflect` step after the save file is written, keeping the reflect step a deliberate choice rather than automatic behavior. The subcommand is in-run-only for v1 — it errors if no active state file is found; free-floating saves are deferred to v1.1. Cursor parity was confirmed via drift-check exit 0 after `transform-cursor-ops.{ps1,sh}` PATCH 2 inline-help sync regenerated `SKILL.cursor.md`. Doc-sync map rows were added to both `CLAUDE.md` and `.cursor/rules/documentation-sync.mdc`.

---

## Changes Since Last Assessment (2026-05-09 — cross-memory v1 ship)

Five ships landed between 2026-05-09 and 2026-05-14. The cross-memory skill expanded from a v1 save/recall/list/forget/search/audit surface to a v1.2 surface that includes `init`, `doctor`, and `reflect`, and was then optimized to extract twelve major sections from `SKILL.md` into dedicated sub-files. A small settings tweak and a planning-docs reorganization landed alongside.

### Merge 1 — `da262ed`: cross-memory v1.1 (init + doctor)

`/cross-memory init` and `/cross-memory doctor` shipped on 2026-05-09. The init subcommand provisions `~/.cross-memory/`, runs the five-step adapter precedence chain, probes the harness-native `MEMORY.md`, and writes the always-on injection block between sentinel markers. It is additive only — never deletes, overwrites, or repairs. The doctor subcommand runs read-only structural and integration health checks across the canonical store, sentinel blocks, mirrors, and redaction surface, with check sets grouped A through E. Bare invocation of `/cross-memory` gained a first-run hint that fires when the store is absent or sentinel block is missing. The check-name vocabulary and shared flag parsing landed as shared substrate for both subcommands. Full surface traceability: `docs/cross-memory/v1.1-shipped.md`.

### Merge 2 — `25c291a`: cross-memory v1.1 documentation

The v1.1 traceability doc (`docs/cross-memory/v1.1-shipped.md`) and supporting scoping/critic-review artifacts (`v1.1-scoping.md`, `v1.1-critic-review.md`, `v1.1-critic-review-r2.md`) landed in `docs/cross-memory/`. The CLAUDE.md doc-sync map gained a row mapping v1.1-shipped to the skill surface and agent.

### Merge 3 — `e5896a1`: cross-memory v1.2 reflect subcommand + distill intent

`/cross-memory reflect` proposes memory candidates distilled from git history, plan docs, handoffs, and (Claude Code only) session transcripts; it renders an interactive candidate report with nothing saved without explicit confirmation. The cross-memory agent gained a third intent, `distill`, which produces candidate memories from these sources. Two new per-project files joined the substrate: `state.toml` (tracking `last_reflect_at` and `reflect_count`) and `reflect_declined.md` (append-only decline ledger). A staleness nudge surfaces a reminder when the reflect cadence lapses. The doc-gap prerequisite — a `## What NOT to save in memory` section in `~/.claude/CLAUDE.md` — was installed at execute time so the reflect filter can reference it as a categorical exclusion corpus. Full surface traceability: `docs/cross-memory/v1.2-shipped.md`.

### Merge 4 — `177e462`: cross-memory skill optimization (12-section extraction)

`skills/cross-memory/SKILL.md` reduced from 2,778 lines (205 KB) to 381 lines (86.3% reduction) by extracting twelve subsections into dedicated sub-files with thin pointer blocks. Twelve new files joined `skills/cross-memory/`: `subcommand-{init,doctor,reflect,save,recall-list-search,forget,audit}.md` (nine subcommand definitions consolidated into seven files via the merged recall/list/search trio), plus `schema-validator.md`, `adapter-selection.md`, `reflect-decline-ledger.md`, `always-on-tier.md`, and `injection-block.md`. The directory now contains nineteen markdown files. Companion doc updates: the doc-sync map, `skills/cross-memory/README.md`, and the v1, v1.1, v1.2 traceability docs all gained references to the new sub-file layout. The mirror at `.cursor/rules/documentation-sync.mdc` stays byte-for-byte consistent with `CLAUDE.md`.

### Merge 5 — `9796c75`: settings model key tweak

`settings.json` switched the default `model` field from `claude-opus-4-6[1m]` to `opus[1m]` and moved the field to the end of the JSON object for consistency with the surrounding key ordering.

### Planning-docs reorganization (2026-05-14, working-tree only)

The 33 documents under `docs/plan/` were partitioned. The seven git-tracked plans (`code-intel-agent-{requirements,scoping,design,plan,critique,critique-final}.md` and `ops-decoupling-plan.md`) stay at `docs/plan/` root. The remaining 26 plans — all mapping to shipped work — were moved to `docs/plan/archive/`, which remains gitignored. This split keeps the directory navigable without losing chronology.

### Net effect

| Surface | Before (2026-05-09) | After (2026-05-14) |
|---|---|---|
| `skills/cross-memory/` SKILL.md lines | 2,155 | 381 |
| `skills/cross-memory/` total `.md` files | 7 | 19 |
| Cross-memory subcommands | 6 | 9 |
| Cross-memory agent intents | 2 | 3 |
| Planning docs at `docs/plan/` root | 29 | 7 |
| Planning docs at `docs/plan/archive/` | 0 | 26 |

---

## Changes Since Last Assessment (2026-05-04 — agent-contract hardening + brief contract)

### Merge 1 — `63f49be`: code-intel critic revision

`agents/code-intel.md` received a critic-driven revision round that addressed 1 BLOCKER and 6 MAJORs surfaced during review. The agent grew from 782 → 811 lines. A JSON-with-prose-noise fixture was added as regression coverage for the M5 verification task.

### Merge 2 — `3903442`: Tier A Opus 4.7 explicitness audit

`docs/agent-audits/tier-a-opus-4-7-audit.md` (262 lines) landed as the first entry in the new `docs/agent-audits/` subdirectory. The audit covered 5 Tier A agents — executor, verifier, debugger, git-master, and project-scoper — and produced:

- 4 BLOCKERs (all resolved by the brief-contract spec; see Merge 3 below)
- 27 MAJORs (deferred to backlog — see Deferred Backlog section under Issues Found)
- 19 MINORs (deferred to backlog)

### Merge 3 — `2c5017c`: brief-contract spec

`skills/ops/brief-contract.md` (281 lines) establishes the shared brief format that every `/ops` agent dispatch must follow. Required sections: Task, Scope, Acceptance Criteria, Constraints. Optional sections: Context, Mode, Handoff Artifacts, Code Intelligence Context.

Five Tier A consumer agents gained a new `## Brief Format` subsection linking them to the contract and listing their required brief inputs:

| Agent | File |
| :--- | :--- |
| Executor | `agents/executor.md` (194 lines) |
| Verifier | `agents/verifier.md` (237 lines) |
| Debugger | `agents/debugger.md` (306 lines) |
| Git Master | `agents/git-master.md` (299 lines) |
| Project Scoper | `agents/project-scoper.md` (299 lines) |

This resolves all 4 BLOCKERs from the Tier A audit.

### Merge 4 — `a771ac4`: ops SKILL.md token cleanup

11 opaque audit tokens ("R/Q/C-ADD/G/M" style) were removed from `skills/ops/SKILL.md` and its Cursor mirror `skills/ops/SKILL.cursor.md` and replaced with self-contained prose. SKILL.md is now 939 lines (was 935). SKILL.cursor.md remains at 968 lines.

### Merge 5 — `85d1dd9`: doc-sync integration-test citation patch

Three stale citations in `docs/code-intel/integration-test.md` were patched (commit `c6ebbb7`) after the SKILL.md token cleanup (Merge 4) invalidated the original citation anchors. The integration-test spec is now 418 lines (was 416).

### Inventory corrections

The prior assessment (2026-04-26) reported `skills/ops/` at 15 files. A tree inspection of the prior assessment commit (`d73c088`) shows 16 files were present at that time — `dispatch-log.md` (added 2026-04-24 in commit `21f0c7d`) was not counted. With `brief-contract.md` now added, the correct current count is **17 files**. The Inventory and File Counts tables above and below reflect the corrected 17.

### Supporting touchpoints

| Change | Detail |
| :--- | :--- |
| **`docs/agent-audits/`** | New subdirectory established. `tier-a-opus-4-7-audit.md` is the first entry. |
| **`skills/ops/brief-contract.md`** | New companion file (281 lines). Not deployed to Cursor — Claude Code only. |
| **`3f0ef61`** | Handoff storage moved from `docs/plan/.handoffs/` to `.agents/handoffs/` (refactor between assessment commits; no tracked files changed). |

### Carried-issue re-evaluation

Both carried issues were re-evaluated. The `git-master.md` Co-Authored-By override and the `agents/README.md` `/schedule` reference remain valid. See Issues Found.

---

## Changes Since Last Assessment (2026-04-26 — code-intel agent)

### New agent: `code-intel`

`agents/code-intel.md` (782 lines, model: opus) is a code-intelligence layer that indexes the project's source tree into a SQLite-backed symbol graph at `.code-intel/index.sqlite` and answers structural queries for other agents — callers, dependencies, impact, implementations, and execution flow — via six recursive-CTE query templates and a strict JSON brief schema. It replaces structural guessing with citable lookups that are traceable to rows in the index.

The agent uses a three-tier indexing cascade: Tier 1 uses AST parsing (Python via `ast`, TypeScript/JavaScript via `@typescript-eslint/parser`), Tier 2 falls back to grep-heuristics for other languages, and Tier 3 escalates to interactive tree-sitter parsing (suppressed on the orchestrator path per constraint C-ADD-1 to avoid blocking automated dispatch).

It is dispatched by `/ops` Phase 2.5b, not by the canonical pipeline. It is a sidecar utility, not a pipeline stage.

### `/ops` Phase 2.5b — code-intel dispatch stage

A new "Phase 2.5b — Code Intelligence" section was added to both `skills/ops/SKILL.md` and `skills/ops/SKILL.cursor.md` (~95 lines each). The stage fires when the R5 predicate is true: `files_touched > 1` OR the brief contains a risk keyword from the 8-keyword list (`auth`, `permission`, `secret`, `token`, `session`, `sql`, `query`, `inject`). The analysis is advisory — the executor proceeds whether or not code-intel responds — and the dispatch is logged in `docs/ops-dispatch-log.md`. State cache invalidation and Phase 4 cleanup of `.code-intel/runs/<run-id>/` are also specified.

### Seven R7 Code Intelligence Context sections

Seven consumer agents received a new `## Code Intelligence Context (R7)` section establishing how they consume code-intel output:

| Agent | Integration |
|-------|-------------|
| `agents/executor.md` | R1-A keystone — reads `impact_analysis` from the Phase 2.5b brief before the first Edit |
| `agents/code-reviewer.md` | R1-C diff-scope verification using `find_callers` and `impact_analysis` |
| `agents/code-reviewer-diff.md` | Byte-equivalent copy of code-reviewer.md's CIC section (per C-PLAN-3, both files must stay in sync) |
| `agents/debugger.md` | R1-B call-chain tracing via `execution_flow` and `find_callers` |
| `agents/debugger-build.md` | Build-time symbol resolution — locates where a missing import is defined |
| `agents/change-analyzer.md` | Blast-radius prediction — identifies which callers and implementations are touched |
| `agents/security-reviewer.md` | CVE reachability — uses `find_callers` to trace whether vulnerable code is reachable from an entry point |

### Supporting touchpoints

| Change | Detail |
|--------|--------|
| **`.gitignore`** | Added `.code-intel/` to ensure the index database and run-scoped sidecar files are never committed |
| **`agents/README.md`** | Added code-intel to the agent roster table, the Utility Agent section, and the handoffs entry |
| **`CLAUDE.md` doc-sync row** | Added `agents/code-intel.md` row mapping to `skills/ops/SKILL.md` (Phase 2.5b) and `tooling/deploy-manifest.json` |
| **`.cursor/rules/documentation-sync.mdc`** | Mirror row added; agent count corrected from stale "13" to 20 (resolves the active issue carried from the 2026-04-21 assessment) |
| **`docs/code-intel/integration-test.md`** | 416-line walkthrough spec: ralph-loop → /ops → code-intel end-to-end integration test |
| **`docs/code-intel/failure-mode-walkthrough.md`** | 125-line R10 walkthrough covering 13 failure-mode scenarios |
| **`docs/code-intel/design-trace.md`** | 76-line R1-R11 + Q1-Q10 design trace table (21 rows, all DONE) |

---

## Changes Since Last Assessment (2026-04-21 — ops decoupling and tooling expansion)

### Ops decoupling — 8 companion files extracted or absorbed

The ops skill carried operational logic (preflight checks, rollback, estimation feedback, health monitoring, etc.) inside companion `.md` files loaded at runtime. This inflated context and coupled unrelated concerns. The decoupling extracted that logic into standalone agents and skills, or folded it into existing agents.

| Change | Detail |
|--------|--------|
| **Tier 1 — 5 files → 4 new agents + 1 new skill** (commit `9e3ac3a`) | `preflight-validation.md` → `agents/preflight.md` (189 lines). `resume-dedup.md` → `agents/work-verifier.md` (234 lines). `rollback-strategy.md` → `agents/rollback.md` (224 lines). `conditional-stage-skip.md` → `agents/change-analyzer.md` (229 lines). `estimation-feedback.md` → `skills/timing-calibrator/` (SKILL.md 214 lines, README.md 98 lines). |
| **Tier 2 — 3 files → folded into existing agents** (commit `e5a449a`) | `agent-health-monitoring.md` → folded into `agents/interviewer.md` (+60 lines). `ssh-integration.md` → folded into `agents/ssh-executor.md` (+21 lines). `branch-isolation.md` → folded into `agents/git-master.md` (+26 lines). |
| **Cursor companion updated** (commit `169b57d`) | `skills/ops/SKILL.cursor.md` regenerated to reflect Tier 1 + Tier 2 deletions. |
| **Net effect** | `skills/ops/` shrank from 22 → 15 files. Agent roster grew from 15 → 19. New skill `timing-calibrator` added (2 files). |

### Ralph-loop R2 optimization (Sprints 2-6 + P13)

Sprints 2-6 ran between 2026-04-17 and 2026-04-18, compressing and consolidating ralph-loop companion files. P13 added Cursor support.

| Change | Detail |
|--------|--------|
| **Sprints 2-4** (commits `4db9fe2`, `a529aa6`, `aa69493`) | Content-level optimizations: template YAML boilerplate dedup, state array caps, rule compression, README slimming. No file additions or removals. |
| **Sprint 5 — P7/P8 consolidation** (commit `6220825`) | Pointer table added. Content from multiple companions merged. |
| **Sprint 6 — P12 consolidation** (commit `ffeab6f`) | 4 companions deleted (`acceptance-criteria.md`, `rollback.md`, `subagent-parallelism.md`, `usage-examples.md`). Content folded into 2 files: `execution-extras.md` (new, 87 lines) and `lightweight-and-examples.md` (renamed from `lightweight-mode.md`, expanded). |
| **P13 — Cursor support** (commit `cde1fda`) | `skills/ralph-loop/SKILL.cursor.md` added (338 lines). Transform scripts: `transform-cursor-ralph-loop.ps1` (275 lines) and `transform-cursor-ralph-loop.sh` (251 lines). |
| **Net effect** | `skills/ralph-loop/` went from 17 → 16 files (4 deleted, 1 renamed, 2 added incl. SKILL.cursor.md). SKILL.md: 319 → 334 lines. |

### Tooling expansion

| Change | Detail |
|--------|--------|
| **`--prune` mode** (commit `700322d`) | Deploy scripts (`deploy.ps1`, `deploy.sh`) gained `--prune` mode to remove deployed files that no longer exist in the repo source directory. |
| **Prune settings bug fix** (commit `8f2d493`) | Fixed a bug where `--prune` would delete all files under a settings target instead of only orphaned files. The settings category now sets `"prune": false` in the manifest. |
| **Transform script rename** (commit `7702a9f`) | `transform-cursor.ps1` → `transform-cursor-ops.ps1`, `transform-cursor.sh` → `transform-cursor-ops.sh`. Added drift-check default behavior and `--force` bypass flag. |
| **Hooks and settings categories** (commit `e8defda`) | Deploy scripts and manifest expanded with `hooks` and `settings` categories alongside `agents` and `skills`. |
| **UTF-8 BOM fix** (commit `ab55ae1`) | Transform-cursor `.ps1` scripts now emit UTF-8 BOM for Windows PowerShell 5.1 compatibility. |
| **Temp path fix** (commit `4a73242`) | Transform scripts resolve temp `.py` path against `$PWD` to survive `pwsh Set-Location` changes. |
| **WSL target** | Deploy manifest added `claude-code-wsl` target for deploying to WSL Ubuntu environments. |

### New infrastructure files

| Change | Detail |
|--------|--------|
| **`settings.json`** (commit `1fd3751`) | Claude Code settings file at repo root. Configures permissions (allow/deny lists), model (`opus[1m]`), hooks (SessionStart, Notification), effort level (`xhigh`). |
| **`hooks/post-compaction-context.sh`** (commit `1fd3751`) | Restores project context after Claude Code compaction events. Bound to `SessionStart` hook with `compact` matcher. |
| **`hooks/notify.sh`** (commit `1e7eda4`) | Cross-platform notification script (Windows toast via PowerShell, macOS `osascript`, Linux `notify-send`). Bound to `Notification` hook. |
| **`skills/ops/SKILL.cursor.additions.md`** | ~660-line human-readable documentation mirror of the Cursor transform's hard-coded patch list (NOT read by any tool; the `.ps1`/`.sh` scripts are the source of truth). Keyed by anchor lines and `rep(old,new)`-style replacements. Created during P14 transform infrastructure. |

### Ops feature additions

| Change | Detail |
|--------|--------|
| **`--brainstorm` gate** (commits `7353b42`, `e139c77`) | Opt-in pre-planning gate (`--brainstorm`) that pauses for autonomous-mode checkpoints before plan execution. |
| **Nested-skill handoff gap** (commit `ce9a607`) | Fixed a gap where nested skill invocations lost state. Now uses state-based mechanism for handoff continuity. |
| **UI-label doubling fix** (commits `1989529`, `1d6fa8a`) | Dispatch rules reordered with concrete examples to prevent duplicate labels in Agent dispatch procedure. |
| **Line count changes** | `SKILL.md`: 757 → 846 lines. `SKILL.cursor.md`: 812 → 865 lines. |

### Planning documents — 14 → 20

Six new plan files, plus a `.handoffs/` subdirectory:

- `deploy-prune-mode-plan.md` — plan for the `--prune` mode feature.
- `ops-claude-code-features-plan.md` — `--brainstorm` gate and nested-skill handoff.
- `ops-decoupling-plan.md` — companion extraction plan (**now tracked in git**, not gitignored).
- `ops-nested-skill-handoff-plan.md` — nested-skill handoff gap closure.
- `ops-skill-optimization-r3-deep-dive.md` — round-3 deep-dive for P12 consolidation.
- `ralph-loop-optimization-r2-deep-dive.md` — R2 sprint analysis.

### Documentation updates

| Change | Detail |
|--------|--------|
| **`CLAUDE.md`** | Doc-sync map updated: 19 agents (was 15), added `timing-calibrator` and `ralph-loop/SKILL.cursor.md` entries. |
| **`agents/README.md`** | +77 lines — 4 new agent entries documented with role descriptions, pipeline position, and usage examples. |
| **`skills/ops/README.md`** | Updated to reflect decoupling changes and reduced companion file count. |
| **`skills/ralph-loop/README.md`** | Updated for Sprint 5/6 consolidations and SKILL.cursor.md addition. |

### Cross-reference spot-checks

- `~/.claude/skills/ops/` companion references in `skills/ops/SKILL.md` — all resolve. 8 former companions no longer referenced.
- `~/.claude/agents/preflight.md`, `work-verifier.md`, `rollback.md`, `change-analyzer.md` — all exist in `agents/`.
- `~/.claude/skills/timing-calibrator/SKILL.md` — exists.
- `~/.claude/skills/ralph-loop/SKILL.cursor.md` — exists.
- No `~/.claude/commands/` references remain in any tracked file except this ASSESSMENT.md (historical narrative only).

### Carried-issue re-evaluation

Both carried issues were re-evaluated. The `git-master.md` Co-Authored-By override and the `agents/README.md` `/schedule` reference remain valid for the same reasons previously recorded. See active issues section for a new documentation drift finding.

---

## Changes Since Last Assessment (2026-04-17 — project audit)

### Ops skill optimization rounds (R1 and R2)

| Change | Detail |
|--------|--------|
| **R1 — 4 new ops companion files** (commit `e1c3ca4`) | Extracted `dispatch-policy.md`, `plan-validation.md`, `state-schema.md`, `tool-restrictions.md` from `SKILL.md` for context-window optimization (186 inserted lines across the 4 companions). |
| **R2 — `skills/ops/SKILL.md` reduction** (commit `97188a1`) | Reduced `SKILL.md` from 957 → 757 lines via 10 extractions. New/expanded companions: `branch-isolation.md`, `cost-tracking.md`, `estimation-feedback.md`, `interruption-recovery.md`, `rollback-strategy.md`, `ssh-integration.md`. `skills/ops/README.md` also updated. |
| **R2 — `skills/ops/SKILL.cursor.md` reduction** (commit `68c4202`) | Reduced `SKILL.cursor.md` from 922 → 788 lines via R2 extractions (now 812 lines after a subsequent docs sync in `5c0ff0c`). |
| **Net effect on inventory** | `skills/ops/` remains at 24 files (now 22 after P12 consolidation). Largest single file shifts from `SKILL.md` (~872 at last audit) to `SKILL.cursor.md` (~812). |

### Inventory corrections for previously-stale line counts

Prior assessments reported line counts for several skills that never matched the actual files (the files have not changed since the initial commit). Corrected to actuals:

| Skill file | Prior (stale) | Actual |
|------------|---------------|--------|
| `skills/linter/SKILL.md` | ~453 | 141 |
| `skills/commit-message/SKILL.md` | ~151 | 75 |
| `skills/doc-sync/SKILL.md` | ~276 | 83 |
| `skills/clickup/SKILL.md` | ~277 | 276 |
| `skills/code-review/SKILL.md` | ~208 | 207 |
| `skills/deslop/SKILL.md` | ~670 | 669 |
| `skills/ralph-loop/SKILL.md` | ~320 | 319 |
| `skills/deploy/SKILL.md` | ~403 | 412 |
| `skills/deploy/SKILL.cursor.md` | ~400 | 408 |

### Cursor rules now tracked in git

| Change | Detail |
|--------|--------|
| **`.cursor/rules/documentation-sync.mdc`** | Mirror of the `CLAUDE.md` § Documentation Sync section, loaded as a Cursor rule. `.gitignore` was updated with explicit exceptions so `.cursor/rules/**` is tracked while the rest of `.cursor/` is ignored. Added to inventory under a new `### Cursor Rules` section. |

### Planning documents (gitignored) — 10 → 14

Four new plan files landed since the last audit:

- `agent-health-monitoring-gaps-plan.md` — from the `fix/agent-health-monitoring-gaps` branch work.
- `agent-roster-expansion-architecture.md` — architecture doc for the architect + security-reviewer additions.
- `ops-skill-optimization-r2-assessment.md` — round-2 assessment for the ops extractions executed in `97188a1` and `68c4202`.
- `unify-ops-state-management-plan.md` — plan for the state unification merged in `8232220`.

### Cross-reference spot-checks

- `~/.claude/skills/ops/help-card.md`, `state-schema.md`, `plan-validation.md`, `dispatch-policy.md` references in `skills/ops/SKILL.md` — all resolve to files present in `skills/ops/`. (Note: 8 ops companion files were extracted into standalone agents/skills and deleted in Tier 1 and Tier 2 of the ops decoupling — see `docs/plan/ops-decoupling-plan.md`.)
- `~/.claude/skills/deploy/help-card.md`, `brief-construction.md`, `deployment-patterns.md`, `response-interpretation.md` references in `skills/deploy/SKILL.md` — all resolve.
- `~/.claude/agents/ssh-executor.md` reference in deploy dispatch procedure — resolves.
- No `~/.claude/commands/` references remain in any tracked file except this ASSESSMENT.md (historical narrative only).

### Carried-issue re-evaluation

All three issues in the "Issues noted but not changed" table were re-evaluated. Each is still valid for the same reason previously recorded — no resolutions and no regressions. Table preserved as-is.

### Other structural changes

- No agents added or removed between `2026-04-15` and `2026-04-17`.
- No tooling files added or removed between `2026-04-15` and `2026-04-17`.

---

## Changes Since Last Assessment (2026-04-15 — agent dispatch fix)

### Agent dispatch procedure for Claude Code

| Change | Detail |
|--------|--------|
| **Claude Code `subagent_type` parity reached** | All agent definition files at `~/.claude/agents/` are now auto-registered as `subagent_type` values for the `Agent` tool. The ops skill dispatches directly via `Agent(subagent_type="<agent_type>")` — the previous 4-value whitelist and read-and-inject workaround are no longer needed for dispatch labeling. The self-read prompt pattern is retained so agents read their full definition on startup. |
| **Dispatch procedure simplified in ops `SKILL.md`** | Rules c and d no longer branch on a whitelist. Always set `subagent_type=<agent_type>` and `description="<task subject>"`. Single example pattern, no built-in vs custom distinction. |
| **Cursor `SKILL.cursor.md` explicit dispatch** | `debugger-build` dispatch in failure handling made explicit: `Task(subagent_type="debugger-build")`. |
| **Portability guide updated** | "Agent Dispatch Mechanism" section rewritten to reflect platform parity. Feature gap table updated — `subagent_type` row now shows parity. |
| **`agents/README.md` updated** | "Programmatic dispatch" subsection updated to document direct `subagent_type` dispatch (no workaround needed). |
| **`skills/ops/README.md` updated** | Dispatch section simplified — both platforms now dispatch directly. |
| **`skills/deploy/README.md` updated** | Architecture section expanded with platform-specific dispatch mechanism (Cursor uses `Task(subagent_type="ssh-executor")` directly; Claude Code uses read-and-inject pattern). |

---

## Changes Since Last Assessment (2026-04-14 — state unification)

### Unified ops state management

| Change | Detail |
|--------|--------|
| **State file for both platforms** | `SKILL.md` (Claude Code) now uses `.ops-state/<run-id>-board.json` state file, matching the approach already in `SKILL.cursor.md`. Replaces all `TaskCreate`/`TaskList`/`TaskUpdate` references. |
| **Helper files updated** | `resume-dedup.md`, `interruption-recovery.md`, `cost-tracking.md`, `handoffs.md` — all references to `TaskCreate`/`TaskList`/`TaskUpdate` replaced with state file operations. Consistent across both platforms. |
| **Portability guide updated** | Feature gap table and ops summary updated to reflect unified state management. |
| **SKILL.md line count** | ~778 → ~872 lines (added State Management section, updated phases). |

---

## Changes Since Last Assessment (2026-04-14 updated)

### Cursor portability gap closure

| Change | Detail |
|--------|--------|
| **`SKILL.cursor.md` convention** | Deploy scripts (`deploy.ps1`, `deploy.sh`) now detect `SKILL.cursor.md` companion files and use them as the Cursor deployment source, skipping mechanical transforms. |
| **Agent tool-restriction hardening** | Deploy scripts inject `## Tool Constraints` markdown into Cursor-deployed agents whose Claude Code frontmatter restricted tools. Affected: critic, ssh-executor, interviewer, verifier. |
| **Ops Cursor-native version** | `skills/ops/SKILL.cursor.md` (~922 lines) — uses JSON state file (`.ops-state/`) + TodoWrite for task board, `Task` tool for dispatch, read-and-dispatch for skill invocation. |
| **Deploy Cursor-native version** | `skills/deploy/SKILL.cursor.md` (~400 lines) — uses `Task(subagent_type="ssh-executor")` for dispatch. All deployment patterns preserved. |
| **Portability guide expanded** | Added Cursor-Native Adaptations section documenting `SKILL.cursor.md` convention, agent hardening, and read-and-dispatch pattern. Updated feature gap table with mitigations. |

### File count changes

- `skills/ops/`: 19 → 20 files (+`SKILL.cursor.md`), then 20 → 24 files (+`dispatch-policy.md`, `plan-validation.md`, `state-schema.md`, `tool-restrictions.md`)
- `skills/deploy/`: 8 → 9 files (+`SKILL.cursor.md`)

---

## Changes Since Last Assessment (2026-04-14 initial)

### Structural changes

| Change | Detail |
|--------|--------|
| **6 commands → multi-file skills** | All files from `commands/` moved to `skills/*/SKILL.md`. Matching docs READMEs moved to `skills/*/README.md`. |
| **`commands/` directory removed** | No longer exists. All skills are multi-file under `skills/`. |
| **`docs/` simplified** | Only `ASSESSMENT.md` and `portability-guide.md` remain. Command README files moved to their respective skill directories. |
| **`tooling/` directory created** | Deploy script (`deploy.ps1`, `deploy.sh`) and manifest (`deploy-manifest.json`) for automated deployment to Claude Code and Cursor. |
| **Portability guide added** | `docs/portability-guide.md` documents format differences, tool name mappings, and feature gaps between Claude Code and Cursor. |
| **Deploy script with Cursor transform** | Automatically transforms Claude Code specs to Cursor format at deploy time — strips `model`/`tools`, derives frontmatter, remaps tool names and paths. |

### Previous issues — status

All 8 issues from the initial 2026-04-14 assessment have been resolved:

| # | Issue | Resolution |
|---|-------|------------|
| 1 | Pipeline diagrams missing `[Interviewer]` and `[Deslop]` | Fixed in critic.md, executor.md, verifier.md, debugger.md, documentor.md |
| 2 | Help-card pipeline excerpts omitting `[Deslop]` | Fixed in code-reviewer.md, code-reviewer-diff.md. Also fixed missing `[Interviewer]` in planner.md, project-scoper.md (discovered during sweep). |
| 3 | "team-manager" used as skill name in ops companion files | `metadata.estimate_source: "team-manager"` → `"ops"` in SKILL.md. Role descriptions ("You are a team manager") kept intentionally. |
| 4 | interviewer.md constraints inconsistency | Normalized `cd` and compound Bash bullets to match other agents. |
| 5 | ssh-executor.md "team manager" cross-reference | Changed to "ops" in 2 spots. |
| 6 | agents/README.md "Team Manager (skill)" header | Changed to "Ops (skill)". |
| 7 | `/team-manager` in pipeline table | Already resolved — not found in current file. |
| 8 | Convention gap (no docs READMEs for multi-file skills) | Resolved by restructure — all skills now have README.md in their directory. |

Path references to `~/.claude/commands/` updated in 6 files:
- `skills/ops/SKILL.md`, `skills/ops/deslop-integration.md`, `skills/ralph-loop/cleanup-deslop.md` (planned)
- `skills/deslop/SKILL.md` (3 references discovered during execution)

---

## Issues Found

### Active issues

None.

### Deferred backlog (not active issues — tracked separately)

The Tier A Opus 4.7 audit (`docs/agent-audits/tier-a-opus-4-7-audit.md`) produced 27 MAJORs and 19 MINORs that were deferred and are not active issues. They represent explicitness and contract-completeness improvements across executor, verifier, debugger, git-master, and project-scoper. No structural or correctness defects were found — all deferred items are enhancement-class findings. The 4 BLOCKERs from that audit were resolved in Merge 3 (brief-contract spec).

### Issues noted but not changed (carried from previous assessments)

| File | Issue | Reason Not Changed |
|------|-------|--------------------|
| git-master.md | "No Co-Authored-By trailer" rule contradicts the Claude Code system prompt | Intentional user override — explicitly stated preference. |
| agents/README.md | References `/schedule` skill not found in `skills/` | `/schedule` is a built-in Claude Code skill, not a custom skill. Valid reference. |

---

## Overall Health Assessment

**Rating: HEALTHY — no structural issues**

### Strengths

- **Unified skill structure:** All 13 skills are multi-file under `skills/`. No more `commands/` vs `skills/` distinction.
- **Consistent structure** across all 27 agents: frontmatter, role statement, help card, workflow, guidelines, failure modes, scaling, and handoff sections present in every file.
- **Clean separation of concerns:** The ops decoupling moved operational logic (preflight, rollback, work verification, change analysis, timing calibration) out of skill companion files and into standalone agents/skills where it belongs. This reduces ops context pressure and makes each capability independently dispatchable.
- **Consistent pipeline diagrams** across all agent files — `[Interviewer]` and `[Deslop]` present in all full and abbreviated pipeline references.
- **Shared constraints repeated verbatim** in all agents: no compound Bash commands, no `cd` prefix, relative paths only. No variations.
- **Logical model assignments** verified: opus for deep reasoning (planner, project-scoper, critic, debugger, debugger-build, interviewer, architect, security-reviewer, code-intel, corpus-search, research, cross-memory); sonnet for execution (executor, ssh-executor, verifier, code-reviewer, code-reviewer-diff, documentor, git-master, preflight, work-verifier, rollback, change-analyzer, generalist, infra, db — `infra` and `db` additionally carry a custom proactive-opus escalation policy for mutating/destructive operations). No mismatches between frontmatter and README.
- **Valid cross-references** between agents and skills — no broken path references. Former ops companion references removed.
- **Deployment automation** expanded — deploy scripts support 4 categories (agents, skills, hooks, settings), 3 targets (claude-code, claude-code-wsl, cursor), dry-run, diff, per-target, per-category, and `--prune` mode. Cursor transform is fully automatic with dedicated transform scripts per skill.
- **Portability documented** — format differences, tool gaps, and verified findings captured in `docs/portability-guide.md`.
- **Comprehensive agents/README.md** with usage examples, full pipeline, utility agent handoff matrices, parallelization thresholds, and permissions reference.
- **Infrastructure as code:** `settings.json` and hooks are now version-controlled and deployable, ensuring consistent Claude Code configuration across machines.

### Observations

These are not defects — they are patterns worth monitoring.

- **Large skill files:** `skills/deslop/SKILL.md` (~689 lines) and `skills/ops/SKILL.cursor.additions.md` (~660 lines — the Cursor transform documentation mirror, repo-only) are the largest single files, followed by `skills/ops/SKILL.cursor.md` (~561 lines) and `skills/ops/SKILL.md` (~517 lines). Net context per ops invocation remains lower than before the companion extraction because companions are no longer loaded.
- **No version identifiers** in any agent or skill file. If these files are shared across machines or updated frequently, a version field in frontmatter would aid change tracking.
- **Planning docs mostly gitignored:** `docs/plan/` is in `.gitignore`, meaning most planning context is local-only. Exception: `ops-decoupling-plan.md` is now tracked in git, establishing a precedent for tracking significant architectural plans.
- **Cursor transform is text-based:** The ops transform applies a hard-coded `rep(old,new)` patch list embedded in the `.ps1`/`.sh` scripts; `SKILL.cursor.additions.md` documents those patches block-by-block for review but is not consumed by the transform. Ralph-loop uses the simpler transform approach. No false-positive issues observed in current files.
- **Three skills have Cursor-native versions:** ops, deploy, and ralph-loop all have `SKILL.cursor.md` files. State management (`.ops-state/` JSON files) is unified across both versions. Remaining limitations: no model escalation, no tool enforcement. See `docs/portability-guide.md` for details.
- **Agent dispatch mechanism at parity:** Claude Code's `Agent` tool auto-registers all agent definition files at `~/.claude/agents/` as `subagent_type` values — matching Cursor's native coverage. Both platforms dispatch directly via `subagent_type="<agent_type>"`. The ops skill retains the self-read prompt pattern so agents load their full definition on startup. `SKILL.cursor.md` is still needed for Cursor-specific differences (TodoWrite, `Task` tool, `~/.cursor/` paths). See `docs/portability-guide.md` § Agent Dispatch Mechanism.
- **`code-intel` and `corpus-search` model assignments:** Both are assigned `opus`, consistent with other deep-reasoning agents (planner, critic, debugger, security-reviewer). The Logical model assignments bullet above should be read as: sonnet for execution-track agents, opus for analysis/reasoning agents — `code-intel` and `corpus-search` fall in the latter category.

---

## Pipeline Reference

The canonical agent pipeline:

```text
[Interviewer] → [Architect] → Planner → Project Scoper → Critic → Executor → Verifier → [Security Reviewer] → [Deslop] → Code Reviewer → Documentor → Done
```

_Brackets indicate optional/automatic stages. Interviewer runs only when specs are ambiguous. Architect runs when the spec involves significant architectural decisions. Security Reviewer runs when the task content involves security-sensitive patterns (auth, secrets, data handling, permissions) or when change-analyzer flags the post-executor diff as security-sensitive; override with `--security-review=off|always`. Deslop runs automatically unless disabled with `--no-deslop`._

_The `ssh-executor` can be inserted between Executor and Verifier for deployment workflows. It can also operate standalone._

Skills invoked within pipeline stages:

| Stage | Skills Typically Used |
|-------|-----------------------|
| Executor | `/linter`, `/ralph-loop` |
| Code Reviewer | `/code-review` |
| Documentor | `/doc-sync` |
| Any stage | `/clickup`, `/commit-message`, `/ops` |

---

## File Counts

Methodology: tracked (committed) files per category, via `git ls-files` — a committed inventory counts only what is in the repo. Gitignored/untracked content is excluded (`docs/plan/**` scratch, `docs/architecture/`, `docs/assessments/`, on-disk-only `docs/` files, `AI-Skills-Agents.zip`, `.cursorignore`/`.cursorindexingignore`). Categories and skill rows are alphabetical.

| Category | Files | Total |
|----------|-------|-------|
| Agents | 27 definitions + 1 README | 28 |
| Agent shared snippets (`agents/_shared/`) | 5 | 5 |
| Skills (clickup) | 2 | 2 |
| Skills (code-review) | 2 | 2 |
| Skills (commit-message) | 2 | 2 |
| Skills (cross-memory) | 30 | 30 |
| Skills (deploy) | 9 | 9 |
| Skills (deslop) | 2 | 2 |
| Skills (doc-sync) | 2 | 2 |
| Skills (kickoff) | 7 | 7 |
| Skills (linter) | 2 | 2 |
| Skills (ops) | 25 | 25 |
| Skills (ralph-loop) | 17 | 17 |
| Skills (timing-calibrator) | 2 | 2 |
| Skills (using-ai-skills-agents) | 1 | 1 |
| Documentation (docs/, tracked) | 4 (ASSESSMENT.md, code-intel-integration-test.md, corpus-search-integration-test.md, portability-guide.md) | 4 |
| Cursor Rules (`.cursor/rules/`) | 16 | 16 |
| Tooling | 10 (README.md + deploy-manifest.json + 2 deploy scripts + 6 transform scripts) | 10 |
| Hooks | 3 (notify.sh, post-compaction-context.sh, security-pattern-warn.sh) | 3 |
| Config | 3 (.gitattributes, .gitignore, .markdownlint.json) | 3 |
| Root | 4 (CLAUDE-root.md, CLAUDE.md, README.md, settings.json) | 4 |
| **Total** | | **176** |

---

*Assessment updated 2026-06-11 (agentic vectors + preflights extraction). Files assessed: 23 agents, 13 skills (ops phase companions `phase-intake.md` / `phase-preflights.md` / `phase-dispatch.md` / `phase-completion.md`; `agents/_shared/` orchestrator briefs; prior research-agent baseline). See `CLAUDE.md` Documentation Sync map for doc-to-code links. Active issues: 0. Carried from previous: 2. Deferred backlog: 27 MAJORs + 19 MINORs (see docs/agent-audits/tier-a-opus-4-7-audit.md).*
