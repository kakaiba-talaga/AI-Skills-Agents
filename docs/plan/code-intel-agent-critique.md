# Critic Review: `code-intel` Agent Tier-3 Combined Artifacts

**VERDICT: REVISE**

## Overall Assessment

The four documents are genuinely thorough and structurally sound — the architect's design work is unusually rigorous, the planner's sequencing honors lane discipline, and the scoper's variance correction (~+30% wall-clock, +26% per-task) is grounded in concrete codebase facts. However, there are two CRITICAL issues the scoper missed that would cause real implementation friction: a **brief-format ambiguity** (the architect-invented `[context]` block conflicts with the existing `/ops` `## Context` brief convention, and no document resolves which wins), and the **WAL sidecar Write-path enforcement** is unspecified (the agent body's lane enforcement must allow `*.sqlite-wal` and `*.sqlite-shm` writes, but neither the requirements nor ADD nor plan instructs the agent body's allow-list to include them — the architect declares it "no allowlist change needed" because they fall under `.code-intel/**`, but the actual *enforcement string* the agent self-checks against is not specified). These are addressable inside the existing milestone shape but must be resolved before M1's executor begins authoring. The scoper's GO-with-refinements verdict is otherwise well-founded; the four CRITICAL gaps it identified (G1, G4, G8, G15) are correctly flagged.

## Pre-commitment Predictions vs Findings

| Predicted | Found |
| :--- | :--- |
| Path amendment `.code-intel/runs/` missed in references | Mostly propagated. Minor leftover noted below. |
| WAL sidecars missed in Write-path enforcement | **Confirmed CRITICAL** — architect waved it away ("no allowlist change needed") without specifying the enforcement string. |
| M4 7-way parallel hidden serialization | **Confirmed MAJOR** — scoper caught the byte-equivalence issue between code-reviewer / code-reviewer-diff and recommended sequencing them; the plan still parallelizes them. |
| Phase 2.5b verification under-specified (regression risk) | **Confirmed MAJOR** — no task explicitly verifies existing `/ops` runs without Phase 2.5b still work end-to-end. |
| Tier-3 escalation suppression via `[context]` brittle | **Confirmed CRITICAL** — `[context]` literal block conflicts with the existing `## Context` convention; format unresolved across the four docs. |

Operated in **adversarial mode** after the second CRITICAL finding surfaced.

---

## Per-Document Review

### Requirements Doc (`docs/plan/code-intel-agent-requirements.md`)

**Strengths.**
- Pivot history (lines 11-15) explicitly captures the stateless→SQLite path α decision with reasoning.
- R10 failure matrix (lines 175-191) is comprehensive with explicit refusal posture per failure type.
- R11 lifecycle three-sub-decision split (lines 194-230) is genuinely tight.
- Hard constraints (lines 17-27) are immutable and unambiguous.

**Issues.**

- **`C-REQ-1` (MAJOR).** R6 / Integration Touchpoints table (line 301) describes `.code-intel/runs/` as the path *but* the prose at line 86 still says `docs/code-intel/<symbol>-<query>.md` for durable reports. The user's amendment moved orchestrator runs to `.code-intel/runs/`; durable human reports remain at `docs/code-intel/`. This is correct, but the requirements doc never spells out the dual-path lifecycle in one place. **Fix:** add a one-paragraph "Path lifetime summary" subsection under R6.

- **`C-REQ-2` (MAJOR).** R8b's allow-list (lines 137-141) lists `sqlite3 .code-intel/index.sqlite "<query>"` but does not list operations against the WAL/SHM sidecars or specify whether the agent's lane-enforcement string includes the sidecars. **Fix:** R8a Lane Phrasing should explicitly state "Write to any path under `.code-intel/**`, including `*.sqlite-wal`, `*.sqlite-shm`, and any `_tmp_*` files emitted by SQLite during WAL operation."

- **`C-REQ-3` (MINOR).** Acceptance criterion line 312 says "Second invocation at the same git SHA reuses the index without rebuild (verifiable via `db_indexed_sha` metadata stamp)" — but doesn't specify *how* a verifier would detect "without rebuild". **Fix:** acceptance criterion should specify "verifiable via `metadata.indexer_wall_clock_s == 0` or a log entry stating 'reusing index'".

### ADD (`docs/plan/code-intel-agent-design.md`)

**Strengths.**
- Q1 schema (lines 56-97) is concrete enough for the executor to copy verbatim.
- Q3 per-query templates (lines 160-167) plus citation format (line 169) make the rendering deterministic.
- Q4 prompt copy (lines 184-201) is verbatim and the strict-`yes` confirmation is correctly characterized.
- Q5 JSON schema (lines 223-249) is RFC-grade and uses `additionalProperties: false`.
- Open Implementation Risks section (lines 861-873) preserves caveats the executor and verifier need.

**Issues.**

- **`C-ADD-1` (CRITICAL).** Surfaced Question 5 (line 923) introduces the `[context]` block as the orchestrator-dispatch detection mechanism. But the existing `/ops` brief format (`skills/ops/SKILL.md:486-506`) uses a **`## Context`** Markdown heading, not a literal `[context]` block. The ADD does not reconcile these formats. **Impact:** if the executor implements Tier-3 suppression keyed on the `[context]` literal, but the actual `/ops` brief composer emits `## Context`, suppression never triggers and orchestrator dispatches will offer the Tier-3 prompt in a non-interactive setting. **Fix:** Either (a) change the ADD's suppression heuristic to "presence of a JSON-fenced brief" — JSON-fenced briefs can only come from orchestrators per R3, so detection is unambiguous *and* doesn't require a new format; or (b) commit to using a Markdown subheading like `## Code Intel Dispatch Context` inside the existing `## Context` block. Option (a) is cheaper. **Routing:** architect.

- **`C-ADD-2` (CRITICAL).** Q6 / WAL pragma (lines 275-289) declares "no allowlist change needed" because `.code-intel/**` covers the sidecars. But the agent body's enforcement (per R8a refuse-and-halt) must compare a path against a permitted list. The ADD does not specify whether the permitted list is a literal set or a glob set. **Impact:** indexer crash on first run if WAL writes are refused. **Fix:** ADD should add a sentence to Q6: "The agent body's Write-path enforcement uses glob matching against `.code-intel/**`, `docs/code-intel/**`, and `_tmp_*`. Glob matching is the canonical form; the agent must not use a literal-path allow-list." **Routing:** architect.

- **`C-ADD-3` (MAJOR).** Q7 language-profile detection (lines 298-345) describes the algorithm with a polyglot-with-mismatched-manifest edge case but does not specify whether Tier-1 probing uses *manifest* or *file count* as the precedence signal. **Impact:** indeterministic indexer behavior on polyglot repos. **Fix:** ADD Q7 should specify a stable probe order (e.g., "alphabetical by language name to ensure determinism"). **Routing:** architect.

- **`C-ADD-4` (MAJOR).** Surfaced Question 3 (lines 921-922) "code-reviewer-diff integration framing — assumes identical for v1" — `code-reviewer.md` (172 lines) and `code-reviewer-diff.md` (266 lines) are **structurally different agents** today. Adding a single shared CIC section that's "identical modulo self-references" is fine, but the planner's M4 parallel dispatch creates a real risk that the two executors diverge stylistically. **Fix:** Plan's M4 should explicitly serialize tasks `task-r7-code-reviewer` → `task-r7-code-reviewer-diff` rather than parallelize them. **Routing:** planner.

- **`C-ADD-5` (MAJOR).** Open Implementation Risk #6 (line 869) — "/ops Phase 2.5b in nested-skill scenarios" is acknowledged but the resolution is "the planner should confirm the integration tests cover the nested case." The plan responds with `task-nested-skill-integration-spec` (M5) which produces a *spec only, not an executed test*. **Fix:** the spec should explicitly enumerate the state-cache-invalidation events that fire when `code-intel` returns inside a Phase 2.5b dispatch. **Routing:** planner.

- **`C-ADD-6` (MINOR).** Recursive CTE template for `execution_flow` (lines 625-647) uses a substring-based cycle guard that can false-positive on exotic function names. **Fix:** comment in the CTE noting the limitation; document in the agent body.

### Plan (`docs/plan/code-intel-agent-plan.md`)

**Strengths.**
- Dependency graph (lines 590-632) is explicit and machine-readable (Mermaid).
- Parallel-safety analysis (lines 511-521) correctly identifies M2 and M4 as the parallel-dominated milestones.
- Out-of-scope section (lines 21-31) prevents v2 deferral leakage.
- Risks Called Forward table (lines 555-566) maps every ADD risk to a planner action.

**Issues.**

- **`C-PLAN-1` (CRITICAL).** No task verifies that **existing `/ops` runs without Phase 2.5b still pass**. M3 adds Phase 2.5b between Phase 2 and Phase 3 (an existing critical-path stage of every `/ops` run). **Impact:** the entire `/ops` orchestrator (which dispatches every other agent) could regress; rolling back is non-trivial. **Fix:** add `task-verify-ops-end-to-end-noop` to M3 or M5 — verifier dispatches a trivial `/ops` run and confirms Phase 2.5b is *skipped* (no risk keywords, single file) and the run completes through Phase 4 without error. Estimate: ~25 min. **Routing:** planner.

- **`C-PLAN-2` (MAJOR).** Task `task-create-agent-definition` (line 54) acceptance criteria specify "All 17 sections from the ADD's skeleton are present in order, with the section headings matching." But the ADD's skeleton uses numeric-prefixed section names — that is a *structural enumeration*, not the actual heading text. **Fix:** plan task acceptance should clarify "the skeleton is a structural outline; section headings should follow the `## <Section Name>` Markdown convention." **Routing:** planner.

- **`C-PLAN-3` (MAJOR).** M4 task `task-r7-code-reviewer-diff` (line 247) is described as "identical to code-reviewer.md per surfaced-question 4." But the M4 dispatch table marks it as parallel-safe. **Fix:** sequence `task-r7-code-reviewer` strictly before `task-r7-code-reviewer-diff`. **Routing:** planner.

- **`C-PLAN-4` (MAJOR).** M3 `task-add-phase-2.5b-base` (line 185) does not explicitly call out the dispatch trigger point. **Fix:** Plan task acceptance should specify the dispatch trigger point — recommend "during Phase 3 Step 2 (Batch parallel work), before each code-modifying executor dispatch". **Routing:** planner.

- **`C-PLAN-5` (MAJOR).** M5 `task-nested-skill-integration-spec` (line 306) writes to `docs/code-intel/integration-test.md`, but `docs/code-intel/` does not yet exist. The agent body's output dispatch logic must include `mkdir -p docs/code-intel/` before writing — and this must be in the R8b allow-list. **Fix:** Add to ADD Q6/R8b or to plan task-create acceptance. **Routing:** architect (R8b clarification) or planner.

- **`C-PLAN-6` (MAJOR).** Scoper's G15 (smoke test after deploy) is correctly flagged as CRITICAL but the plan as-written does not include it. **Fix:** add `task-smoke-test-after-deploy` to M8, between `task-run-deploy` and `task-commit-changes`, ~15 min. **Routing:** planner.

- **`C-PLAN-7` (MINOR).** `task-update-deploy-manifest` (line 105) is dispatched as verify-only. **Fix:** acceptance criterion should require the verifier to dry-run or grep `tooling/deploy.ps1` for glob handling. **Routing:** planner.

- **`C-PLAN-8` (MINOR).** Plan's "Open Questions for the Executor" §1 (line 574) flags `docs/code-intel/` directory creation uncertainty but doesn't resolve it. **Fix:** resolve at plan revision. **Routing:** planner.

### Scoping Doc (`docs/plan/code-intel-agent-scoping.md`)

**Strengths.**
- Variance computation is explicit (lines 114-116).
- Gap analysis G1–G15 (lines 178-194) is concrete with severity classification.
- Resourcing recommendation (lines 312-336) correctly identifies `--parallel 4` as the sweet spot.
- Verifier-fix loop probability estimates (lines 281-287) include numeric confidence levels.

**Issues.**

- **`C-SCOPING-1` (MAJOR).** The scoper missed the **brief-format ambiguity** (`C-ADD-1`). **Fix:** scoper should re-issue with C-ADD-1 added as a CRITICAL gap requiring architect resolution.

- **`C-SCOPING-2` (MAJOR).** The scoper missed the **WAL sidecar enforcement** issue (`C-ADD-2`). **Fix:** scoper should add this to gap analysis and route to architect.

- **`C-SCOPING-3` (MAJOR).** The scoper's gap G15 is correctly classified CRITICAL but the scoping doc's verdict says "GO with refinements" — verdict inflation. **Fix:** scoper's verdict statement should distinguish "GO after refinements applied" from the looser "GO with refinements" reading.

- **`C-SCOPING-4` (MINOR).** Scoping's §6 codebase-specific risk #1 (line 307) recommends sequencing tasks but does not propose modifying the plan. **Fix:** scoper should explicitly route to planner.

- **`C-SCOPING-5` (MINOR).** Scoper's §6 risk #2 ("verifier dispatch overhead") estimates 5–8 min per dispatch beyond the work itself but does not include this in the refined critical-path arithmetic. **Fix:** scoper's "honest wall-clock" should bake this in (current 620–680 min becomes 645–720 min).

---

## Cross-Document Consistency Review

| Concern | Status | Notes |
| :--- | :--- | :--- |
| User path amendment `.code-intel/runs/` propagation | **MOSTLY PASS** | Reaches requirements:301, design:872, plan:69, plan:298, scoping:17. |
| Architect Q1–Q10 resolutions land as plan tasks | **PASS** with caveats | Q1–Q10 all reach plan acceptance criteria. Caveats: Q5 strict validation has no behavioral test (G1); Q7 algorithm has paraphrase-vs-inline ambiguity (G3). |
| Architect surfaced Q1–Q5 → plan | **PARTIAL** | SQ1 → plan but Phase 4 implementation gap (G8). SQ2 deferred. SQ3 spec only. SQ4 byte-equivalence hazard. SQ5 brief-format ambiguity unresolved (C-ADD-1). |
| Hard constraints honored across all four docs | **PASS** with C-ADD-2 caveat | No external service, no MCP, no graph DB, deploy via existing tooling. WAL sidecar Write-path is the one hole. |
| Lane discipline | **PASS** | Source modifications → executor; verify → verifier; doc → documentor; git → git-master. |

---

## Hard-Constraint Compliance Audit

| Constraint | Status | Evidence | Notes |
| :--- | :--- | :--- | :--- |
| Self-contained native agent, deployed via `tooling/deploy.{ps1,sh}` | **PASS** | `plan:105` verify-only manifest task; manifest globs picks up `code-intel.md`. | Confirmed. |
| No MCP, no graph DB, no external service | **PASS** | All 6 CTEs are SQLite-native; R8b deny-list explicitly forbids installs. | — |
| Read-only on source code; Write only to permitted paths | **AT-RISK** | Lane phrasing in agent body is enumerated, but the WAL sidecar enforcement gap (C-ADD-2) means the implementation could refuse legitimate writes. | **Resolution required.** |
| Persistent SQLite at `.code-intel/index.sqlite` (WAL mode) | **PASS** | Schema authoritative at `design:454-498` with `PRAGMA journal_mode=WAL`. | — |

---

## Lane-Discipline Audit

All 30 plan tasks reviewed; all assignments respect lane boundaries per project memory. One AT-RISK note: M3 base edit modifies `skills/ops/SKILL.md`, which is an agent-contract surface — correctly verified by `task-verify-ops-integration`, but worth noting as the SKILL.md is the orchestrator's spec, not source code.

**Verdict: PASS with one AT-RISK note.**

---

## Estimate Realism Audit

The scoper's per-task variance (+26%) and critical-path variance (+29%) is in the right direction. Specific tasks where I would push further:

| Task | Scoper estimate | My recommendation | Rationale |
| :--- | ---: | ---: | :--- |
| `task-create-agent-definition` | 120 (90–140) | **140 (120–180)** | Agent body at 480–550 lines, not 400–500. |
| `task-verify-agent-definition` | 35 | **45** | Verifier must cross-reference ADD line numbers. |
| `task-add-phase-2.5b-base` | 65 | **80** | Phase-flow rewrite is more than paste-and-tweak. |
| Verifier cumulative time | 155 | **180** | Per scoper's §6 risk #2, 5 verifier dispatches × 5 min = 25 min added. |

**Adjusted total task effort:** ~880 minutes. **Adjusted critical-path:** ~570 minutes. **Adjusted "honest wall-clock with one verifier loop":** ~660–730 min.

---

## Failure-Mode Coverage Audit (R10 matrix)

For each row of R10 (`requirements:175-191`), is there a verification task in the plan that exercises it? **9 of the 13 R10 failure modes have no behavioral fixture.**

**Finding `C-FAILURE-1` (CRITICAL).** The plan does not include behavioral fixtures for **9 of the 13 R10 failure modes**. Acceptance criteria reference them but no task asks the verifier to *exercise* them. **Fix:** add `task-failure-mode-fixtures` to M5 — verifier composes mock briefs / DB states for each R10 row and confirms the agent's *prose* says it would refuse / partial / etc. as specified. Estimate: 30–40 min. **Routing:** planner.

---

## `/ops` Integration Risk Audit

Phase 2.5b is a *new orchestrator stage*. Risks specific to its integration:

1. **Regression of existing Phase 2 → Phase 3 control flow** — `C-PLAN-1`. **CRITICAL.**
2. **`[context]` block format conflict with existing `## Context` heading** — `C-ADD-1`. **CRITICAL.**
3. **Race condition with first-time index build during mid-Phase 3 dispatch** — `C-PLAN-4`. **MAJOR.**
4. **Phase 4 cleanup of `.code-intel/runs/<run-id>/`** — scoper G8. **CRITICAL** (per scoper G8).
5. **`--code-intel=off` behavior** — does this disable Phase 2.5b only for code-modifying tasks? **MINOR ambiguity.**
6. **State cache invalidation after `code-intel` returns** — per `SKILL.md:353`. **MINOR ambiguity.**

Risk #1 is the most important single missing piece.

---

## Required Revisions (REVISE verdict)

1. **Resolve brief-format ambiguity** (C-ADD-1) — Routing: **architect**.
2. **Specify WAL sidecar Write-path enforcement** (C-ADD-2) — Routing: **architect**.
3. **Stable language probe order in Q7** (C-ADD-3) — Routing: **architect**.
4. **Path lifetime summary in scoping** (C-REQ-1) — Routing: **scoper**.
5. **R8a Lane Phrasing includes WAL/SHM sidecars** (C-REQ-2) — Routing: **architect**.
6. **Add end-to-end `/ops` no-op verification task** (C-PLAN-1) — Routing: **planner**.
7. **Specify Phase 2.5b dispatch trigger point** (C-PLAN-4) — Routing: **planner**.
8. **Serialize `task-r7-code-reviewer` → `task-r7-code-reviewer-diff`** (C-PLAN-3) — Routing: **planner**.
9. **Specify section-heading convention in `task-create-agent-definition`** (C-PLAN-2) — Routing: **planner**.
10. **Add G15 smoke test, G8 Phase 4 cleanup, G1 fixture verification, G4 byte-diff to plan** — Routing: **planner**.
11. **Add `task-failure-mode-fixtures` to M5** (C-FAILURE-1) — Routing: **planner**.
12. **Update scoper to reflect findings** (C-SCOPING-1, C-SCOPING-2, C-SCOPING-3) — Routing: **scoper** (after architect/planner revisions land).
13. **Resolve `docs/code-intel/` directory creation policy** (C-PLAN-5, C-PLAN-8) — Routing: **planner**.

---

## Approved-as-Is Items

- Hard constraints (R1–R11 dimensions, 4 hard constraints).
- SQLite schema authoritative spec (ADD `design:454-498`).
- Six recursive-CTE templates (ADD `design:514-647`).
- Q4 Tier-3 prompt copy (ADD `design:184-201`).
- Q5 strict JSON schema (ADD `design:223-249`).
- Tier cascade pseudocode (ADD `design:787-829`).
- Indexer pipeline 5-phase split (ADD `design:840-857`).
- Lane-discipline routing across plan.
- Scoper's variance correction.
- Scoper's `--parallel 4` recommendation.
- `/ops` Phase 4 not auto-cleaning the index database (R11c).
- Q9 single-body deploy (no Cursor variant) for the agent.
- Q8 hardcoded excludes list.
- Out-of-scope deferrals.

---

## Final Verdict Statement

**REVISE.**

Two CRITICAL ADD issues (brief-format ambiguity `C-ADD-1`; WAL sidecar enforcement `C-ADD-2`), one CRITICAL `/ops` regression risk (`C-PLAN-1`), and one CRITICAL failure-mode coverage gap (`C-FAILURE-1`) that the scoper missed. The scoper's own four CRITICAL gaps (G1, G4, G8, G15) are correctly flagged but treated as "refinements" rather than blocking issues.

The scope of the revisions is small in absolute terms (~13 specific items routed to architect, planner, or scoper) and none of them require redesign — the agent's architecture is sound. The right path is:

1. **Architect** addresses C-ADD-1, C-ADD-2, C-ADD-3, C-REQ-2 (~30 min total).
2. **Planner** addresses C-PLAN-1 through C-PLAN-8, plus G15, G8, G1, G4, G6, G10, G12, C-FAILURE-1 (~45 min).
3. **Scoper** re-issues with C-SCOPING-1 through C-SCOPING-5 (~25 min).
4. **Critic** re-reviews (~25 min).

Total revision overhead: ~125 min. Versus implementing on the current artifacts and hitting these issues at execution time: probability ~75% of at least one CRITICAL surfacing during M1/M3.

---

## Open Questions (Lower-Confidence; for User/Architect)

1. Should `--code-intel=off` also disable Phase 2.5b for non-code-modifying tasks?
2. Does `code-intel`'s return trigger team-manager state-cache invalidation?
3. What happens if `code-intel` dispatched in Phase 2.5b takes >60s?
4. Are there observability/dispatch-log requirements specific to Phase 2.5b?
5. Does the deslop pass risk modifying the agent body in ways that break the verifier's byte-checks?

---

*Critique authored 2026-04-26 by the critic agent in adversarial mode after second CRITICAL surfaced. Files reviewed: requirements (389 lines), ADD (929 lines), plan (650 lines), scoping (493 lines).*
