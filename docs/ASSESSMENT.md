# AI Skills and Agents — Assessment Report

**Date:** 2026-05-04 (agent-contract hardening + brief contract)
**Previous assessment:** 2026-04-26 (code-intel agent), 2026-04-21 (ops decoupling and tooling expansion), 2026-04-17 (project audit), 2026-04-15 (agent dispatch fix), 2026-04-14 (state unification), 2026-04-14 (updated), 2026-04-14 (initial), 2026-04-07
**Scope:** All agents, skills, hooks, and tooling in the repository
**Overall Rating:** HEALTHY — no structural issues

---

## Inventory

### Agents (`agents/`)

20 agent definitions + 1 README.

| File | Model | Role |
|------|-------|------|
| interviewer.md | opus | Socratic requirements interview before planning |
| architect.md | opus | Design exploration and Architecture Decision Documents (ADDs) |
| planner.md | opus | Breaks specs into structured implementation plans |
| project-scoper.md | opus | Requirements analysis, gap detection, effort estimates |
| critic.md | opus | Quality gate on plans and scoping documents |
| executor.md | sonnet | Implements code changes from validated plans |
| ssh-executor.md | sonnet | Remote command execution and file transfer via SSH |
| verifier.md | sonnet | Validates implementation against acceptance criteria |
| security-reviewer.md | opus | Security audit with severity-rated vulnerability findings |
| code-reviewer.md | sonnet | Two-stage pipeline code review with severity-rated findings |
| code-reviewer-diff.md | sonnet | Standalone diff review with full diff-gathering protocol |
| documentor.md | sonnet | Documentation writer, delegates accuracy checks to `/doc-sync` |
| debugger.md | opus | Hypothesis-driven runtime bug investigation |
| debugger-build.md | opus | Build/compilation error diagnosis (import, type, dependency, config) |
| git-master.md | sonnet | Git operations, branching, commits, PRs, releases, pause/resume |
| preflight.md | sonnet | Environment readiness checks before agent work begins |
| work-verifier.md | sonnet | Verifies whether prior agent work was completed, partial, or never started |
| rollback.md | sonnet | Safely undoes agent-produced changes at configurable scope |
| change-analyzer.md | sonnet | Classifies git diffs and recommends pipeline stages to run or skip |
| code-intel.md | opus | Indexes the project into a SQLite symbol graph and answers structural queries (callers, dependencies, impact, execution flow) for other agents |

### Skills (`skills/`)

11 multi-file skills. 6 converted from single-file commands in the initial restructure; 1 added in the ops decoupling; 1 added as the kickoff skill.

| Skill | Directory | Files | SKILL.md Lines | Purpose |
|-------|-----------|-------|----------------|---------|
| ClickUp | `skills/clickup/` | 2 | ~276 | ClickUp REST API integration |
| Code Review | `skills/code-review/` | 2 | ~207 | Diff-based code review orchestration |
| Commit Message | `skills/commit-message/` | 2 | ~75 | Conventional Commits message generation |
| Deslop | `skills/deslop/` | 2 | ~669 | AI slop cleanup (dead code, redundant comments, over-abstraction) |
| Doc Sync | `skills/doc-sync/` | 2 | ~83 | Documentation audit and sync against codebase |
| Linter | `skills/linter/` | 2 | ~141 | Source file linting with auto-fix and incremental cache |
| Ops | `skills/ops/` | 17 | 939 (Claude), 968 (Cursor) | Multi-agent task orchestration, dispatch, and tracking |
| Deploy | `skills/deploy/` | 9 | ~412 (Claude), ~408 (Cursor) | Remote deployment orchestration via ssh-executor |
| Ralph Loop | `skills/ralph-loop/` | 16 (incl. SKILL.cursor.md, 5 YAML templates) | ~334 (Claude), ~338 (Cursor) | Iterative execute-verify-reflect loop with state persistence |
| Timing Calibrator | `skills/timing-calibrator/` | 2 | ~214 | Captures timing patterns from agent runs and calibrates estimates |
| Kickoff | `skills/kickoff/` | 7 | 1250 | Scaffolds project planning infrastructure, interviews users, dispatches agents to produce structured plans, and populates plan files ready for `/next` execution |

### Documentation (`docs/`)

| File | Purpose |
|------|---------|
| `docs/ASSESSMENT.md` | This file — periodic repo health snapshots |
| `docs/portability-guide.md` | Format differences and tool gaps between Claude Code and Cursor |
| `docs/ops-dispatch-log.md` | Append-only audit trail of `/ops` dispatch decisions (opt-in via `--dispatch-log`; 18 lines — seed header only until populated) |

### Documentation (`docs/agent-audits/`)

| File | Purpose |
|------|---------|
| `docs/agent-audits/tier-a-opus-4-7-audit.md` | Tier A Opus 4.7 explicitness audit — 5 core agents reviewed, 4 BLOCKERs + 27 MAJORs + 19 MINORs found; BLOCKERs resolved via brief-contract spec |

### Documentation (`docs/code-intel/`)

| File | Purpose |
|------|---------|
| `docs/code-intel/integration-test.md` | 418-line walkthrough spec for ralph-loop → /ops → code-intel end-to-end integration test |
| `docs/code-intel/failure-mode-walkthrough.md` | 85-line R10 walkthrough covering 13 failure-mode scenarios |
| `docs/code-intel/design-trace.md` | 76-line R1–R11 + Q1–Q10 design trace table (21 rows, all DONE) |

### Hooks (`hooks/`)

| File | Purpose |
|------|---------|
| post-compaction-context.sh | Restores project context after Claude Code compaction events |
| notify.sh | Cross-platform notification script (Windows toast, macOS osascript, Linux notify-send) |

### Cursor Rules (`.cursor/rules/`)

| File | Purpose |
|------|---------|
| documentation-sync.mdc | Mirror of `CLAUDE.md` § Documentation Sync for Cursor, loaded as a cursor rule |

### Tooling (`tooling/`)

| File | Purpose |
|------|---------|
| deploy-manifest.json | Maps repo source directories to tool-specific global directories. 3 targets (claude-code, claude-code-wsl, cursor), 4 categories (agents, skills, hooks, settings). |
| deploy.ps1 | PowerShell deploy script (primary). `SKILL.cursor.md` detection, agent tool-restriction hardening, `--prune` mode, hooks/settings deployment. |
| deploy.sh | Bash deploy script (cross-platform, requires `jq`). Same features as deploy.ps1. |
| transform-cursor-ops.ps1 | PowerShell transform: generates `skills/ops/SKILL.cursor.md` from `SKILL.md` + `SKILL.cursor.additions.md`. |
| transform-cursor-ops.sh | Bash version of the ops Cursor transform. |
| transform-cursor-ralph-loop.ps1 | PowerShell transform: generates `skills/ralph-loop/SKILL.cursor.md` from `SKILL.md`. |
| transform-cursor-ralph-loop.sh | Bash version of the ralph-loop Cursor transform. |

### Planning Documents (`docs/plan/` — 29 files, gitignored except `ops-decoupling-plan.md`)

| File | Purpose |
|------|---------|
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
|-------|------|
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
|--------|--------|
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
| **`skills/ops/SKILL.cursor.additions.md`** | Transform side-car file (754 lines) containing patch blocks injected into `SKILL.md` during Cursor transform. Keyed by anchor lines and actions (prepend, replace_line, insert_after, etc.). Created during P14 transform infrastructure. |

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

- **Unified skill structure:** All 10 skills are multi-file under `skills/`. No more `commands/` vs `skills/` distinction.
- **Consistent structure** across all 20 agents: frontmatter, role statement, help card, workflow, guidelines, failure modes, scaling, and handoff sections present in every file.
- **Clean separation of concerns:** The ops decoupling moved operational logic (preflight, rollback, work verification, change analysis, timing calibration) out of skill companion files and into standalone agents/skills where it belongs. This reduces ops context pressure and makes each capability independently dispatchable.
- **Consistent pipeline diagrams** across all agent files — `[Interviewer]` and `[Deslop]` present in all full and abbreviated pipeline references.
- **Shared constraints repeated verbatim** in all agents: no compound Bash commands, no `cd` prefix, relative paths only. No variations.
- **Logical model assignments** verified: opus for deep reasoning (planner, project-scoper, critic, debugger, debugger-build, interviewer, architect, security-reviewer, code-intel); sonnet for execution (executor, ssh-executor, verifier, code-reviewer, code-reviewer-diff, documentor, git-master, preflight, work-verifier, rollback, change-analyzer). No mismatches between frontmatter and README.
- **Valid cross-references** between agents and skills — no broken path references. Former ops companion references removed.
- **Deployment automation** expanded — deploy scripts support 4 categories (agents, skills, hooks, settings), 3 targets (claude-code, claude-code-wsl, cursor), dry-run, diff, per-target, per-category, and `--prune` mode. Cursor transform is fully automatic with dedicated transform scripts per skill.
- **Portability documented** — format differences, tool gaps, and verified findings captured in `docs/portability-guide.md`.
- **Comprehensive agents/README.md** with usage examples, full pipeline, utility agent handoff matrices, parallelization thresholds, and permissions reference.
- **Infrastructure as code:** `settings.json` and hooks are now version-controlled and deployable, ensuring consistent Claude Code configuration across machines.

### Observations

These are not defects — they are patterns worth monitoring.

- **Large skill files:** `skills/ops/SKILL.cursor.md` (~968 lines) is now the largest single file, followed by `skills/ops/SKILL.md` (~935 lines), `skills/ops/SKILL.cursor.additions.md` (~754 lines), and `skills/deslop/SKILL.md` (~669 lines). The ops files grew by a further ~90 lines each in this run due to the Phase 2.5b code-intel dispatch stage. Net context per ops invocation remains lower than before the companion extraction because companions are no longer loaded.
- **No version identifiers** in any agent or skill file. If these files are shared across machines or updated frequently, a version field in frontmatter would aid change tracking.
- **Planning docs mostly gitignored:** `docs/plan/` is in `.gitignore`, meaning most planning context is local-only. Exception: `ops-decoupling-plan.md` is now tracked in git, establishing a precedent for tracking significant architectural plans.
- **Cursor transform is text-based:** The ops transform now uses a dedicated side-car file (`SKILL.cursor.additions.md`) with an anchor-and-patch format, which is more robust than pure text replacement. Ralph-loop still uses the simpler transform approach. No false-positive issues observed in current files.
- **Three skills have Cursor-native versions:** ops, deploy, and ralph-loop all have `SKILL.cursor.md` files. State management (`.ops-state/` JSON files) is unified across both versions. Remaining limitations: no model escalation, no tool enforcement. See `docs/portability-guide.md` for details.
- **Agent dispatch mechanism at parity:** Claude Code's `Agent` tool auto-registers all agent definition files at `~/.claude/agents/` as `subagent_type` values — matching Cursor's native coverage. Both platforms dispatch directly via `subagent_type="<agent_type>"`. The ops skill retains the self-read prompt pattern so agents load their full definition on startup. `SKILL.cursor.md` is still needed for Cursor-specific differences (TodoWrite, `Task` tool, `~/.cursor/` paths). See `docs/portability-guide.md` § Agent Dispatch Mechanism.
- **`code-intel` model assignment:** `code-intel` is assigned `opus`, consistent with other deep-reasoning agents (planner, critic, debugger, security-reviewer). The Logical model assignments bullet above should be read as: sonnet for execution-track agents, opus for analysis/reasoning agents — `code-intel` falls in the latter category.

---

## Pipeline Reference

The canonical agent pipeline:

```text
[Interviewer] → [Architect] → Planner → Project Scoper → Critic → Executor → Verifier → [Security Reviewer] → [Deslop] → Code Reviewer → Documentor → Done
```

_Brackets indicate optional/automatic stages. Interviewer runs only when specs are ambiguous. Architect runs when the spec involves significant architectural decisions. Security Reviewer runs when task content involves security-sensitive patterns (auth, secrets, data handling, permissions). Deslop runs automatically unless disabled with `--no-deslop`._

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

| Category | Files | Total |
|----------|-------|-------|
| Agents | 20 definitions + 1 README | 21 |
| Skills (clickup) | 2 | 2 |
| Skills (code-review) | 2 | 2 |
| Skills (commit-message) | 2 | 2 |
| Skills (deslop) | 2 | 2 |
| Skills (doc-sync) | 2 | 2 |
| Skills (linter) | 2 | 2 |
| Skills (ops) | 17 (incl. SKILL.cursor.md, SKILL.cursor.additions.md, brief-contract.md, dispatch-log.md) | 17 |
| Skills (deploy) | 9 (incl. SKILL.cursor.md) | 9 |
| Skills (ralph-loop) | 16 (incl. SKILL.cursor.md, 5 templates + templates README) | 16 |
| Skills (timing-calibrator) | 2 | 2 |
| Skills (kickoff) | 7 (incl. project-template/ scaffold with /next command) | 7 |
| Documentation (docs/) | 3 (ASSESSMENT.md, portability-guide.md, ops-dispatch-log.md) | 3 |
| Documentation (docs/agent-audits/) | 1 (tier-a-opus-4-7-audit.md) | 1 |
| Documentation (docs/code-intel/) | 3 (integration-test.md, failure-mode-walkthrough.md, design-trace.md) | 3 |
| Cursor Rules | 1 (documentation-sync.mdc) | 1 |
| Tooling | 7 (manifest + 2 deploy scripts + 4 transform scripts) | 7 |
| Hooks | 2 (post-compaction-context.sh, notify.sh) | 2 |
| Planning (gitignored + 1 tracked) | 29 | 29 |
| Config | 2 (.gitignore, .markdownlint.json) | 2 |
| Root | 3 (README.md, CLAUDE.md, settings.json) | 3 |
| **Total** | | **135** |

---

*Assessment updated 2026-05-04 (agent-contract hardening + brief contract). Files assessed: 20 agents, 11 skills (63 skill files, incl. 3 SKILL.cursor.md + 1 SKILL.cursor.additions.md + 1 brief-contract.md + 5 kickoff templates), 1 agents README, 7 docs (3 top-level docs/, 1 docs/agent-audits/, 3 docs/code-intel/), 1 cursor rule, 7 tooling, 2 hooks, 29 plans, 1 root README, 1 CLAUDE.md, 1 settings.json, 1 .gitignore, 1 .markdownlint.json. Active issues: 0. Carried from previous: 2. Deferred backlog: 27 MAJORs + 19 MINORs (see docs/agent-audits/tier-a-opus-4-7-audit.md).*
