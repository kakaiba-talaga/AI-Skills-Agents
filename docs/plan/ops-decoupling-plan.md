# Ops Skill Decoupling Plan

Extract reusable procedural logic from the `/ops` skill's helper files into standalone agents and skills. The helper files are **replaced** — ops depends on the new agents directly, with no fallback to the old files.

## Motivation

The ops skill (`skills/ops/SKILL.md`) accumulated 20+ helper files containing well-defined procedures that are architecturally independent of the ops dispatch loop. Today, these procedures are only accessible through ops. Decoupling them:

- **Reduces ops complexity.** The main SKILL.md delegates to standalone agents instead of embedding procedure references. Five helper files are deleted entirely.
- **Enables standalone invocation.** A user or orchestrator can run a preflight check, analyze a diff, or roll back changes without spinning up a full ops run.
- **Enables composition.** Other skills (deploy, ralph-loop) and future orchestrators can reuse the same capabilities without duplicating logic.
- **Follows existing architecture.** The project already separates agents (stateless workers) from skills (invocable workflows). These extractions follow that pattern.

## Scope

This plan covers 5 Tier 1 extractions (implemented), 3 Tier 2 moderate candidates (future), and identifies files that remain ops-internal.

---

## Implementation Status

| # | Deliverable | Status |
|---|---|---|
| 1 | `agents/preflight.md` — replaces `skills/ops/preflight-validation.md` | Done |
| 2 | `agents/work-verifier.md` — replaces `skills/ops/resume-dedup.md` | Done |
| 3 | `agents/rollback.md` — replaces `skills/ops/rollback-strategy.md` | Done |
| 4 | `agents/change-analyzer.md` — replaces `skills/ops/conditional-stage-skip.md` | Done |
| 5 | `skills/timing-calibrator/SKILL.md` — replaces `skills/ops/estimation-feedback.md` | Done |
| 6 | `skills/ops/SKILL.md` updated — direct agent references, no fallbacks | Done |
| 7 | `skills/ops/SKILL.cursor.additions.md` updated — Cursor anchors match | Done |
| 8 | `tooling/transform-cursor-ops.sh` updated — stale patches fixed | Done |
| 9 | `tooling/transform-cursor-ops.ps1` updated — stale patches fixed | Done |
| 10 | `agents/README.md` updated — new agents in tables, usage, handoffs | Done |
| 11 | `skills/ops/README.md` updated — companion files table, extraction table | Done |
| 12 | Cross-references cleaned in `interruption-recovery.md`, `agent-health-monitoring.md`, `pointer-format.md` | Done |

---

## Tier 1 — Implemented (New Agents/Skills)

### 1. Preflight Validation → `preflight` agent

**Replaces:** `skills/ops/preflight-validation.md` (deleted)

**What it does:** Validates project environment readiness before any agent work begins. Three-tier check system (critical / standard / warning), auto-fix for standard checks, structured `[PASS]/[FAIL]/[WARN]` output, overall verdict (`pass` / `blocked` / `pass-with-warnings`).

| Field | Value |
|---|---|
| Name | `preflight` |
| Model | `sonnet` |
| Lane | Read-only diagnostics + one auto-fix attempt per standard check |
| Input | Project root, optional plan summary (to resolve config file references) |
| Output | Structured checklist with per-check results and overall verdict |
| Does not | Modify project code, dispatch other agents, run tests |

**Ops integration:** Dispatched as an internal task at Phase 2.5. Ops depends on this agent — no fallback.

**Standalone use:** Any orchestrator, deploy skill, or user can invoke directly.

---

### 2. Resume Deduplication → `work-verifier` agent

**Replaces:** `skills/ops/resume-dedup.md` (deleted)

**What it does:** Determines whether interrupted agent work was completed, partial, or never started. 4-check protocol (file existence, git diff, handoff file, content validation) with a decision matrix producing per-deliverable verdicts.

| Field | Value |
|---|---|
| Name | `work-verifier` |
| Model | `sonnet` |
| Lane | Read-only verification (file reads, git status, content inspection) |
| Input | List of expected deliverables with acceptance criteria, scope files, run start timestamp |
| Output | Per-deliverable verdict: `completed` / `partial` / `not-started` / `broken`, plus re-dispatch context for partial items |
| Does not | Modify files, rollback changes, re-dispatch agents |

**Ops integration:** Dispatched per in-progress task during `resume`. Verdicts drive mark-complete / re-dispatch / rollback-then-re-dispatch decisions.

**Standalone use:** Post-crash recovery, pre-session verification.

---

### 3. Rollback Strategy → `rollback` agent

**Replaces:** `skills/ops/rollback-strategy.md` (deleted)

**What it does:** Safely undoes agent-produced changes at a specified scope level. Always stashes before reverting. Checks for file overlap with successful work. Never touches files outside scope.

| Field | Value |
|---|---|
| Name | `rollback` |
| Model | `sonnet` |
| Lane | Git operations (checkout, restore, stash, revert) scoped to specified files |
| Input | Rollback scope level, list of affected files, run ID |
| Output | Rollback report: stash reference, files rolled back, files skipped, overlap warnings |
| Does not | Decide scope (caller specifies), rollback committed changes without authorization, use `git reset --hard` |

**Ops integration:** Dispatched on chain failures, user cancellation, or scope issues.

**Standalone use:** Undo agent changes, deploy rollback, manual recovery.

---

### 4. Conditional Stage Skip → `change-analyzer` agent

**Replaces:** `skills/ops/conditional-stage-skip.md` (deleted)

**What it does:** Analyzes a git diff, classifies changes (code/config/docs/tests), and recommends which pipeline stages (verify, deslop, review) to run or skip. Uses "skip when ALL true" / "NEVER skip when ANY true" rule sets per stage.

| Field | Value |
|---|---|
| Name | `change-analyzer` |
| Model | `sonnet` |
| Lane | Read-only analysis (git diff, file categorization) |
| Input | Git diff or diff stats, optional historical data |
| Output | Per-stage recommendation: `run` / `skip` with justification, diff summary |
| Does not | Execute stages, modify files, make final skip decisions (recommends only) |

**Ops integration:** Dispatched at stage transitions when the trivial-skip rule doesn't apply.

**Standalone use:** CI gating, pre-commit classification, any orchestrator.

---

### 5. Estimation Feedback → `timing-calibrator` skill

**Replaces:** `skills/ops/estimation-feedback.md` (deleted)

**What it does:** Self-improving calibration loop. Captures per-agent-type timing patterns after runs, writes to a memory file with rolling averages (10-run sliding window), reads at run start to calibrate estimates.

| Field | Value |
|---|---|
| Name | `timing-calibrator` |
| Commands | `capture <task-data>`, `read` |
| Storage | `feedback_ops_timing_patterns.md` in the project memory directory |
| Input | Task metadata (agent type, estimated minutes, actual duration, model, attempts) |
| Output | Calibrated estimates, model escalation recommendations, calibration log |

**Ops integration:** `read` invoked at Phase 2 (calibrate estimates), `capture` invoked at Phase 4 (persist timing data).

**Standalone use:** Any orchestrator, post-mortem analysis, planning.

---

## Tier 2 — Implemented (Enrich Existing Agents)

### 6. Branch Isolation → Enriched `git-master` agent

**Replaces:** `skills/ops/branch-isolation.md` (deleted)

**What was done:** Added a "Branch workflow" section to `agents/git-master.md` incorporating the full decision matrix:

- When to create a branch vs. work on current (on main → always branch; on matching feature branch → stay; on unrelated branch → warn)
- How to handle uncommitted changes (interactive: ask; autonomous: stash)
- Branch naming conventions (detect from git log)
- After-completion cleanup (delete merged branches, remind about unmerged)
- Worktree interaction rules (worktree branches fork from working branch, ralph tags are branch-independent)

**Ops integration:** Ops dispatches git-master for branch workflow decisions instead of inlining the logic.

---

### 7. Agent Health Monitoring → Folded into `work-verifier` agent and ops inline

**Replaces:** `skills/ops/agent-health-monitoring.md` (deleted)

**What was done:**

- **Orphan detection** (Section 3b) folded into `agents/work-verifier.md` as a new "Orphan detection" section. The work-verifier now handles both "is this task orphaned?" and "was the work completed?" in a single dispatch.
- **Timeout budgets** (Section 1) and **stall detection thresholds** (Section 2) moved inline into ops `SKILL.md` — these are small tables the team manager needs directly, not a procedure to delegate.
- **Health warnings, escalation, dashboard integration** (Sections 3a, 4, 6) moved inline into ops `SKILL.md` — these are team manager responsibilities, not delegatable work.
- **Calibration feedback** (Section 7) already handled by the `timing-calibrator` skill.

---

### 8. SSH Integration → Enriched `ssh-executor` agent

**Replaces:** `skills/ops/ssh-integration.md` (deleted)

**What was done:**

- **SSH preflight checks** (5 checks: host exists, connectivity, key loaded, source files, remote directory) folded into `agents/ssh-executor.md` as a self-preflight procedure. The ssh-executor already had host validation and connectivity checks in its workflow (Steps 1-2); the remaining checks (key loaded, source files, remote directory) were added.
- **SSH handoff format** (SSH-specific fields for handoff documents) folded into the ssh-executor's output format section.
- **SSH parallel safety rules** folded into the ssh-executor's scaling section.
- **SSH handoff chains** already documented in the ssh-executor's handoff section.

Ops no longer needs to dispatch a separate verifier for SSH preflight — the ssh-executor validates its own prerequisites.

---

## Not Candidates (Remain Ops-Internal)

| File | Reason |
|---|---|
| `state-schema.md` | Defines the ops state file JSON structure |
| `tool-restrictions.md` | Team manager tool constraints |
| `dispatch-policy.md` | Foreground/background dispatch decisions |
| `timing-edge-cases.md` | Timing computation edge cases |
| `cost-tracking.md` | Token/cost estimation heuristics |
| `help-card.md` | Ops UI help text |
| `interruption-recovery.md` | Cancel/abort/reprioritize/inject/remove procedures |
| `handoffs.md` | Handoff document template and lifecycle |
| `plan-validation.md` | Tier decision logic delegating to project-scoper and critic |
| `integrations.md` | Deslop and Ralph Loop integration |
| `pointer-format.md` | Formatting convention |

---

## Design Decisions

### No fallbacks

The new agents ship alongside ops in the same repo and deploy through the same manifest. There is no scenario where ops is present but the agents aren't. Ops references the agents directly — no "if unavailable, fall back to helper file" patterns.

### Helper files deleted, not retained

The 5 source helper files are deleted. The agents are the single source of truth for their procedures. This avoids drift between two copies of the same logic.

### Agents follow existing conventions

Each new agent has: YAML frontmatter, help card, "When you're dispatched" section, procedure steps, edge cases, handoff section, lane boundaries, and constraints — matching the pattern established by the 15 existing agents.

### Transform scripts updated

Both `transform-cursor-ops.sh` and `transform-cursor-ops.ps1` (Python-embedded transforms) and `SKILL.cursor.additions.md` (declarative patches) were updated to match the new SKILL.md text. All three transform mechanisms stay in sync.

---

## Files Changed

**Created:**
- `agents/preflight.md`
- `agents/work-verifier.md`
- `agents/rollback.md`
- `agents/change-analyzer.md`
- `skills/timing-calibrator/SKILL.md`

**Deleted:**
- `skills/ops/preflight-validation.md`
- `skills/ops/resume-dedup.md`
- `skills/ops/rollback-strategy.md`
- `skills/ops/conditional-stage-skip.md`
- `skills/ops/estimation-feedback.md`

**Modified:**
- `skills/ops/SKILL.md` — direct agent references, new agents in assignment/lane tables
- `skills/ops/SKILL.cursor.additions.md` — updated anchors
- `skills/ops/README.md` — companion files table, extraction table
- `skills/ops/interruption-recovery.md` — `resume-dedup.md` → work-verifier
- `skills/ops/agent-health-monitoring.md` — `resume-dedup.md` → work-verifier
- `skills/ops/pointer-format.md` — removed `conditional-stage-skip.md` from always-hot list
- `agents/README.md` — new agents in all tables
- `tooling/transform-cursor-ops.sh` — 6 stale patches fixed
- `tooling/transform-cursor-ops.ps1` — 6 stale patches fixed
