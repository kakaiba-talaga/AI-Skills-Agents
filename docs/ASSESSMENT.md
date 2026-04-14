# AI Skills and Agents — Assessment Report

**Date:** 2026-04-14 (updated)
**Previous assessment:** 2026-04-14 (initial), 2026-04-07
**Scope:** All agents and skills in the repository
**Overall Rating:** HEALTHY — no structural issues

---

## Inventory

### Agents (`agents/`)

13 agent definitions + 1 README. Unchanged from previous assessment.

| File | Model | Role |
|------|-------|------|
| interviewer.md | opus | Socratic requirements interview before planning |
| planner.md | opus | Breaks specs into structured implementation plans |
| project-scoper.md | opus | Requirements analysis, gap detection, effort estimates |
| critic.md | opus | Quality gate on plans and scoping documents |
| executor.md | sonnet | Implements code changes from validated plans |
| ssh-executor.md | sonnet | Remote command execution and file transfer via SSH |
| verifier.md | sonnet | Validates implementation against acceptance criteria |
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
| ClickUp | `skills/clickup/` | 2 | ~277 | ClickUp REST API integration |
| Code Review | `skills/code-review/` | 2 | ~208 | Diff-based code review orchestration |
| Commit Message | `skills/commit-message/` | 2 | ~151 | Conventional Commits message generation |
| Deslop | `skills/deslop/` | 2 | ~670 | AI slop cleanup (dead code, redundant comments, over-abstraction) |
| Doc Sync | `skills/doc-sync/` | 2 | ~276 | Documentation audit and sync against codebase |
| Linter | `skills/linter/` | 2 | ~453 | Source file linting with auto-fix and incremental cache |
| Ops | `skills/ops/` | 20 | ~778 (Claude), ~907 (Cursor) | Multi-agent task orchestration, dispatch, and tracking |
| Deploy | `skills/deploy/` | 9 | ~403 (Claude), ~400 (Cursor) | Remote deployment orchestration via ssh-executor |
| Ralph Loop | `skills/ralph-loop/` | 17 (incl. 5 YAML templates) | ~320 | Iterative execute-verify-reflect loop with state persistence |

### Documentation (`docs/`)

| File | Purpose |
|------|---------|
| ASSESSMENT.md | This file |
| portability-guide.md | Format differences and tool gaps between Claude Code and Cursor |

### Tooling (`tooling/`)

| File | Purpose |
|------|---------|
| deploy-manifest.json | Maps repo source directories to tool-specific global directories |
| deploy.ps1 | PowerShell deploy script (primary). Includes `SKILL.cursor.md` detection, agent tool-restriction hardening. |
| deploy.sh | Bash deploy script (cross-platform, requires `jq`). Same features as deploy.ps1. |

### Planning Documents (`docs/plan/` — gitignored)

| File | Purpose |
|------|---------|
| agent-splitting-plan.md | Plan to split large agents into smaller definitions |
| deploy-skill-interface-contract.md | Interface spec for `/deploy` ↔ `ssh-executor` briefs |
| deploy-skill-plan.md | Implementation plan for deploy skill |
| ops-handoff-cleanup-plan.md | Handoff file lifecycle and cleanup for ops |
| ops-skill-optimization-plan.md | Context reduction plan for ops SKILL.md |
| ralph-loop-audit-assessment.md | Post-migration audit of ralph-loop skill |
| ralph-loop-skill-optimization-plan.md | Modularization plan for ralph-loop |
| ssh-agent-plan.md | Plan for ssh-executor and ops/deploy integration |
| next-steps-roadmap.md | Roadmap for restructure, portability, and deployment automation |
| cursor-portability-gaps.md | Plan for Cursor-native adaptations of ops and deploy (completed) |

---

## Changes Since Last Assessment (2026-04-14 updated)

### Cursor portability gap closure

| Change | Detail |
|--------|--------|
| **`SKILL.cursor.md` convention** | Deploy scripts (`deploy.ps1`, `deploy.sh`) now detect `SKILL.cursor.md` companion files and use them as the Cursor deployment source, skipping mechanical transforms. |
| **Agent tool-restriction hardening** | Deploy scripts inject `## Tool Constraints` markdown into Cursor-deployed agents whose Claude Code frontmatter restricted tools. Affected: critic, ssh-executor, interviewer, verifier. |
| **Ops Cursor-native version** | `skills/ops/SKILL.cursor.md` (~907 lines) — uses JSON state file (`.ops-state/`) + TodoWrite for task board, `Task` tool for dispatch, read-and-dispatch for skill invocation. |
| **Deploy Cursor-native version** | `skills/deploy/SKILL.cursor.md` (~400 lines) — uses `Task(subagent_type="ssh-executor")` for dispatch. All deployment patterns preserved. |
| **Portability guide expanded** | Added Cursor-Native Adaptations section documenting `SKILL.cursor.md` convention, agent hardening, and read-and-dispatch pattern. Updated feature gap table with mitigations. |

### File count changes

- `skills/ops/`: 19 → 20 files (+`SKILL.cursor.md`)
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
| code-reviewer.md | Has Edit/Write tools despite being a review-only agent | Supports the "Offer to apply fixes" feature. Intentional design. |
| agents/README.md | References `/schedule` skill not found in `skills/` | `/schedule` is a built-in Claude Code skill, not a custom skill. Valid reference. |

---

## Overall Health Assessment

**Rating: HEALTHY — no structural issues**

### Strengths

- **Unified skill structure:** All 9 skills are multi-file under `skills/`. No more `commands/` vs `skills/` distinction.
- **Consistent structure** across all 13 agents: frontmatter, role statement, help card, workflow, guidelines, failure modes, scaling, and handoff sections present in every file.
- **Consistent pipeline diagrams** across all agent files — `[Interviewer]` and `[Deslop]` present in all full and abbreviated pipeline references.
- **Shared constraints repeated verbatim** in all agents: no compound Bash commands, no `cd` prefix, relative paths only. No variations.
- **Logical model assignments** verified: opus for deep reasoning (planner, project-scoper, critic, debugger, debugger-build, interviewer); sonnet for execution (executor, ssh-executor, verifier, code-reviewer, code-reviewer-diff, documentor, git-master). No mismatches between frontmatter and README.
- **Valid cross-references** between agents and skills — no broken path references.
- **Deployment automation** in place — deploy script with dry-run, diff, per-target, and per-category support. Cursor transform is fully automatic.
- **Portability documented** — format differences, tool gaps, and verified findings captured in `docs/portability-guide.md`.
- **Comprehensive agents/README.md** with usage examples, full pipeline, utility agent handoff matrices, parallelization thresholds, and permissions reference.

### Observations

These are not defects — they are patterns worth monitoring.

- **Large skill files:** `skills/ops/SKILL.md` (~778 lines) is the largest single file. Context pressure may occur when ops loads multiple companion files simultaneously. The `docs/plan/ops-skill-optimization-plan.md` already addresses this.
- **No version identifiers** in any agent or skill file. If these files are shared across machines or updated frequently, a version field in frontmatter would aid change tracking.
- **Planning docs gitignored:** `docs/plan/` is in `.gitignore`, meaning planning context is local-only and won't survive a machine change or clone.
- **Cursor transform is text-based:** Tool name replacements (`Bash`→`Shell`, `Edit`→`StrReplace`, `Agent`→`Task`) use word-boundary matching, which may produce false positives in prose that coincidentally matches tool names. No issues observed in current files.
- **ops and deploy have Cursor-native versions:** Both skills now have `SKILL.cursor.md` files that use Cursor primitives (`Task` tool, TodoWrite, state files). Remaining limitations: no model escalation, no tool enforcement. See `docs/portability-guide.md` for details.

---

## Pipeline Reference

The canonical agent pipeline:

```text
[Interviewer] → Planner → Project Scoper → Critic → Executor → Verifier → [Deslop] → Code Reviewer → Documentor → Done
```

_Brackets indicate optional/automatic stages. Interviewer runs only when specs are ambiguous. Deslop runs automatically unless disabled with `--no-deslop`._

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
| Agents | 13 definitions + 1 README | 14 |
| Skills (clickup) | 2 | 2 |
| Skills (code-review) | 2 | 2 |
| Skills (commit-message) | 2 | 2 |
| Skills (deslop) | 2 | 2 |
| Skills (doc-sync) | 2 | 2 |
| Skills (linter) | 2 | 2 |
| Skills (ops) | 20 (incl. SKILL.cursor.md) | 20 |
| Skills (deploy) | 9 (incl. SKILL.cursor.md) | 9 |
| Skills (ralph-loop) | 17 (incl. 5 templates + templates README) | 17 |
| Documentation | 2 (ASSESSMENT.md, portability-guide.md) | 2 |
| Tooling | 3 (manifest + 2 scripts) | 3 |
| Planning (gitignored) | 10 | 10 |
| Config | 1 (.gitignore) | 1 |
| Root | 1 (README.md) | 1 |
| **Total** | | **88** |

---

*Assessment updated 2026-04-14. Files assessed: 13 agents, 9 skills (58 files, incl. 2 SKILL.cursor.md), 1 agents README, 2 docs, 3 tooling, 10 plans, 1 root README, 1 CLAUDE.md, 1 .gitignore. Active issues: 0. Carried from previous: 3.*
