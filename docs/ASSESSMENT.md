# AI Skills and Agents — Assessment Report

**Date:** 2026-04-17 (project audit)
**Previous assessment:** 2026-04-15 (agent dispatch fix), 2026-04-14 (state unification), 2026-04-14 (updated), 2026-04-14 (initial), 2026-04-07
**Scope:** All agents and skills in the repository
**Overall Rating:** HEALTHY — no structural issues

---

## Inventory

### Agents (`agents/`)

15 agent definitions + 1 README.

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

### Skills (`skills/`)

9 multi-file skills. 6 converted from single-file commands in this update.

| Skill | Directory | Files | SKILL.md Lines | Purpose |
|-------|-----------|-------|----------------|---------|
| ClickUp | `skills/clickup/` | 2 | ~276 | ClickUp REST API integration |
| Code Review | `skills/code-review/` | 2 | ~207 | Diff-based code review orchestration |
| Commit Message | `skills/commit-message/` | 2 | ~75 | Conventional Commits message generation |
| Deslop | `skills/deslop/` | 2 | ~669 | AI slop cleanup (dead code, redundant comments, over-abstraction) |
| Doc Sync | `skills/doc-sync/` | 2 | ~83 | Documentation audit and sync against codebase |
| Linter | `skills/linter/` | 2 | ~141 | Source file linting with auto-fix and incremental cache |
| Ops | `skills/ops/` | 22 | ~757 (Claude), ~812 (Cursor) | Multi-agent task orchestration, dispatch, and tracking |
| Deploy | `skills/deploy/` | 9 | ~412 (Claude), ~408 (Cursor) | Remote deployment orchestration via ssh-executor |
| Ralph Loop | `skills/ralph-loop/` | 17 (incl. 5 YAML templates) | ~319 | Iterative execute-verify-reflect loop with state persistence |

### Documentation (`docs/`)

| File | Purpose |
|------|---------|
| ASSESSMENT.md | This file |
| portability-guide.md | Format differences and tool gaps between Claude Code and Cursor |

### Cursor Rules (`.cursor/rules/`)

| File | Purpose |
|------|---------|
| documentation-sync.mdc | Mirror of `CLAUDE.md` § Documentation Sync for Cursor, loaded as a cursor rule |

### Tooling (`tooling/`)

| File | Purpose |
|------|---------|
| deploy-manifest.json | Maps repo source directories to tool-specific global directories |
| deploy.ps1 | PowerShell deploy script (primary). Includes `SKILL.cursor.md` detection, agent tool-restriction hardening. |
| deploy.sh | Bash deploy script (cross-platform, requires `jq`). Same features as deploy.ps1. |

### Planning Documents (`docs/plan/` — gitignored)

| File | Purpose |
|------|---------|
| agent-health-monitoring-gaps-plan.md | Plan to close agent health monitoring gaps in dispatch and recovery |
| agent-roster-expansion-architecture.md | Architecture doc for agent roster expansion (architect and security-reviewer additions) |
| agent-splitting-plan.md | Plan to split large agents into smaller definitions |
| cursor-portability-gaps.md | Plan for Cursor-native adaptations of ops and deploy (completed) |
| deploy-skill-interface-contract.md | Interface spec for `/deploy` ↔ `ssh-executor` briefs |
| deploy-skill-plan.md | Implementation plan for deploy skill |
| next-steps-roadmap.md | Roadmap for restructure, portability, and deployment automation |
| ops-handoff-cleanup-plan.md | Handoff file lifecycle and cleanup for ops |
| ops-skill-optimization-plan.md | Context reduction plan for ops SKILL.md |
| ops-skill-optimization-r2-assessment.md | Round-2 assessment and extraction plan for ops SKILL.md and SKILL.cursor.md |
| ralph-loop-audit-assessment.md | Post-migration audit of ralph-loop skill |
| ralph-loop-skill-optimization-plan.md | Modularization plan for ralph-loop |
| ssh-agent-plan.md | Plan for ssh-executor and ops/deploy integration |
| unify-ops-state-management-plan.md | Plan to unify ops state management across Claude Code and Cursor |

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

- No agents added or removed between `2026-04-15` and `2026-04-21`. On `2026-04-21`, 4 agents were added (`preflight`, `work-verifier`, `rollback`, `change-analyzer`) and 1 skill was added (`timing-calibrator`) as part of the ops decoupling. Existing agents `git-master`, `work-verifier`, and `ssh-executor` were enriched with logic from 3 additional deleted helper files. Total: 8 ops companion files deleted across Tier 1 and Tier 2 (see `docs/plan/ops-decoupling-plan.md`).
- No tooling files added or removed.

---

## Changes Since Last Assessment (2026-04-15 — agent dispatch fix)

### Agent dispatch procedure for Claude Code

| Change | Detail |
|--------|--------|
| **Claude Code `subagent_type` gap documented** | Claude Code's `Agent` tool `subagent_type` enum only includes `debugger-build`, `git-master`, `code-reviewer`, and `code-reviewer-diff` from the ops taxonomy (Claude Code built-ins; the enum may expand). All other agent types (executor, verifier, planner, etc.) dispatch as `general-purpose` and display as "Agent" — custom agent files at `~/.claude/agents/` do not extend the enum for programmatic dispatch. |
| **Read-and-inject workaround in ops `SKILL.md`** | Phase 3 now includes an Agent Dispatch Procedure: read the agent definition, set `description` to `"<agent_type>(<subject>)"` for UI labeling, set `model` from frontmatter, inject full agent instructions into the prompt. |
| **Cursor `SKILL.cursor.md` explicit dispatch** | `debugger-build` dispatch in failure handling made explicit: `Task(subagent_type="debugger-build")`. |
| **Portability guide expanded** | New "Agent Dispatch Mechanism" section documenting the platform difference and workaround. Feature gap table updated with `subagent_type` coverage row. |
| **`agents/README.md` updated** | New "Programmatic dispatch" subsection documenting the `subagent_type` limitation and read-and-inject workaround. |
| **`skills/ops/README.md` updated** | Dispatch section added explaining the difference between Claude Code and Cursor dispatch mechanisms. |
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

No active issues.

### Issues noted but not changed (carried from previous assessments)

| File | Issue | Reason Not Changed |
|------|-------|--------------------|
| git-master.md | "No Co-Authored-By trailer" rule contradicts the Claude Code system prompt | Intentional user override — explicitly stated preference. |
| agents/README.md | References `/schedule` skill not found in `skills/` | `/schedule` is a built-in Claude Code skill, not a custom skill. Valid reference. |

---

## Overall Health Assessment

**Rating: HEALTHY — no structural issues**

### Strengths

- **Unified skill structure:** All 9 skills are multi-file under `skills/`. No more `commands/` vs `skills/` distinction.
- **Consistent structure** across all 15 agents: frontmatter, role statement, help card, workflow, guidelines, failure modes, scaling, and handoff sections present in every file.
- **Consistent pipeline diagrams** across all agent files — `[Interviewer]` and `[Deslop]` present in all full and abbreviated pipeline references.
- **Shared constraints repeated verbatim** in all agents: no compound Bash commands, no `cd` prefix, relative paths only. No variations.
- **Logical model assignments** verified: opus for deep reasoning (planner, project-scoper, critic, debugger, debugger-build, interviewer, architect, security-reviewer); sonnet for execution (executor, ssh-executor, verifier, code-reviewer, code-reviewer-diff, documentor, git-master). No mismatches between frontmatter and README.
- **Valid cross-references** between agents and skills — no broken path references.
- **Deployment automation** in place — deploy script with dry-run, diff, per-target, and per-category support. Cursor transform is fully automatic.
- **Portability documented** — format differences, tool gaps, and verified findings captured in `docs/portability-guide.md`.
- **Comprehensive agents/README.md** with usage examples, full pipeline, utility agent handoff matrices, parallelization thresholds, and permissions reference.

### Observations

These are not defects — they are patterns worth monitoring.

- **Large skill files:** After two rounds of extractions, `skills/ops/SKILL.cursor.md` (~812 lines) is now the largest single file, followed by `skills/ops/SKILL.md` (~757 lines) and `skills/deslop/SKILL.md` (~669 lines). Context pressure may still occur when ops loads multiple companion files simultaneously, but the trend is down from the ~958-line peak. See `docs/plan/ops-skill-optimization-plan.md` and `docs/plan/ops-skill-optimization-r2-assessment.md`.
- **No version identifiers** in any agent or skill file. If these files are shared across machines or updated frequently, a version field in frontmatter would aid change tracking.
- **Planning docs gitignored:** `docs/plan/` is in `.gitignore`, meaning planning context is local-only and won't survive a machine change or clone.
- **Cursor transform is text-based:** Tool name replacements (`Bash`→`Shell`, `Edit`→`StrReplace`, `Agent`→`Task`) use word-boundary matching, which may produce false positives in prose that coincidentally matches tool names. No issues observed in current files.
- **ops and deploy have Cursor-native versions:** Both skills have `SKILL.cursor.md` files. State management (`.ops-state/` JSON files) is now unified across both versions; the Cursor-native file is still needed for `Task` tool dispatch, TodoWrite display layer, read-and-dispatch skill invocation, and Cursor-specific limitations. Remaining limitations: no model escalation, no tool enforcement. See `docs/portability-guide.md` for details.
- **Agent dispatch mechanism differs between platforms:** Claude Code's `subagent_type` enum is limited — `debugger-build`, `git-master`, `code-reviewer`, and `code-reviewer-diff` from the ops taxonomy are built-in (Claude Code built-ins; the enum may expand). All other agents dispatch as `general-purpose` and require a read-and-inject workaround. Cursor's `Task` tool includes all 15 agent types as built-in `subagent_type` values. This is the primary reason ops needs a `SKILL.cursor.md` companion. See `docs/portability-guide.md` § Agent Dispatch Mechanism.

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
| Agents | 15 definitions + 1 README | 16 |
| Skills (clickup) | 2 | 2 |
| Skills (code-review) | 2 | 2 |
| Skills (commit-message) | 2 | 2 |
| Skills (deslop) | 2 | 2 |
| Skills (doc-sync) | 2 | 2 |
| Skills (linter) | 2 | 2 |
| Skills (ops) | 22 (incl. SKILL.cursor.md) | 22 |
| Skills (deploy) | 9 (incl. SKILL.cursor.md) | 9 |
| Skills (ralph-loop) | 17 (incl. 5 templates + templates README) | 17 |
| Documentation | 2 (ASSESSMENT.md, portability-guide.md) | 2 |
| Cursor Rules | 1 (documentation-sync.mdc) | 1 |
| Tooling | 3 (manifest + 2 scripts) | 3 |
| Planning (gitignored) | 14 | 14 |
| Config | 1 (.gitignore) | 1 |
| Root | 1 (README.md) | 1 |
| **Total** | | **97** |

---

*Assessment updated 2026-04-17 (project audit). Files assessed: 15 agents, 9 skills (60 files, incl. 2 SKILL.cursor.md), 1 agents README, 2 docs, 1 cursor rule, 3 tooling, 14 plans, 1 root README, 1 CLAUDE.md, 1 .gitignore, 1 .markdownlint.json. Active issues: 0. Carried from previous: 2.*
