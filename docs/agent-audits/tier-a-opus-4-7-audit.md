# Tier A Agent Audit — Opus 4.7 Explicitness

**Date:** 2026-05-04
**Branch:** `feature/agents-opus-4-7-audit`
**Scope:** 5 agents — `executor`, `verifier`, `debugger`, `git-master`, `project-scoper`
**Method:** 1 critic agent per audit target, parallel dispatch via `/ops --autonomous`

---

## Executive Summary

### Roll-up by agent

| Agent | Verdict | Cross-refs | BLOCKERs | MAJORs | MINORs |
| :--- | :--- | :--- | ---: | ---: | ---: |
| `executor` | READY-WITH-CAVEATS | 1 RESOLVED (`R5`, opaque to runtime) | 0 | 6 | 3 |
| `verifier` | **NEEDS-REWORK** | 0 (clean) | **2** | 6 | 4 |
| `debugger` | READY-WITH-CAVEATS | 0 (clean) | 0 | 5 | 4 |
| `git-master` | **NEEDS-REWORK** | 0 (clean) | **1** | 8 | 5 |
| `project-scoper` | **NEEDS-REWORK** | 0 (clean) | **1** | 6 | 3 |
| **Total** | — | — | **4** | **31** | **19** |

### BLOCKERs

The 4 BLOCKERs represent conditions where an Opus 4.7 agent will produce divergent runtime behavior on identical dispatches — not just degraded output, but genuinely unpredictable decisions with real data-integrity risk. `verifier` has two: its acceptance-criteria source is never specified (BLOCKER-1 at `verifier.md:67,71,83-88`) and its PASS/FAIL verdict boundaries collide on partial test passes (BLOCKER-2 at `verifier.md:118-124,200`). `git-master` has one BLOCKER around interactive-vs-autonomous mode that is undetectable by the runtime agent, creating a path to destroying or stashing user work without a recorded label (`git-master.md:77-81`). `project-scoper` has one BLOCKER where undefined file-class boundaries mean the agent will edit runtime contracts — `agents/*.md` and `skills/**/*.md` files — it should never touch (`project-scoper.md:107-117,258-277`).

### Systemic patterns

Three patterns cut across all five agents and should be addressed before per-agent rewrites begin. First, the brief-schema contract is nowhere codified in the agent files — every agent assumes a structured brief but none names the expected sections or specifies escalation when a section is missing, producing non-deterministic improvisation at exactly the moment precision matters most. Second, every agent in this set holds `Edit`/`Write` tool grants, but none carries a written path-allowlist; lane prose such as "no docs" or "no code" leaves Opus 4.7 to rationalize the boundary on each call, which it will do inconsistently. Third, fix-loop re-dispatch semantics are absent across `executor`, `verifier`, `debugger`, and `git-master` — re-entry rules, what gets re-checked, and how the attempt counter resets are all undefined, making multi-round recovery loops brittle.

---

## Cross-Cutting Patterns

1. **Brief-schema gap is systemic.** Almost every agent assumes a brief from the team manager but does not document its expected sections or required fields. When a brief is malformed, missing a section, or contradicts itself, agents improvise non-deterministically. The fix benefits from a *shared* brief contract (likely codified in `skills/ops/SKILL.md` or a sibling reference doc), not per-agent text.

2. **Edit/Write tool grants without textual lane policy.** Agents that have `Edit`/`Write` (`executor`, `verifier`, `debugger`, `git-master`, `project-scoper`) consistently lack path-allowlists. Lane prose says "no docs," "no code," "no test fixes," but Opus 4.7 must rationalize per-call. Capability-layer enforcement (omitting tools) or written allow/deny lists are the only reliable controls.

3. **Cross-file citation hygiene is mostly clean.** Only `executor.md` carries an opaque token (`R5`); the other four are clean. The code-intel pattern was a localized issue, not a fleet-wide rot.

4. **Fix-loop / re-dispatch semantics under-specified.** `verifier`, `executor`, `debugger`, and (implicitly) `git-master` all participate in retry loops without explicit re-entry rules — what's re-checked, what's preserved, when the counter resets, how feedback is reconciled with original criteria.

5. **Mode awareness leaks across the boundary.** "Interactive vs autonomous" is a `/ops` concept but agents reference it (e.g., `git-master.md:79`) without being told how to detect it. Subagents only see their own definition plus dispatch brief, so unstated mode flags become silent ambiguity.

6. **Output persistence inconsistent.** Some agents (`debugger`, `project-scoper`) produce reports without specifying whether they should be written to `.agents/handoffs/` or returned inline. The team manager parses one or the other; cross-session resume becomes lossy.

---

## Per-Agent Sections

### executor

**Verdict:** READY-WITH-CAVEATS

Solid lane document with crisp identity. No BLOCKERs. Risks concentrate on malformed or contradictory briefs and re-dispatch scenarios.

#### MAJORs

- **MAJOR-1** — `executor.md:64-76,166-179` — Brief-section parsing entirely unspecified. The brief format (`## Task / ## Context / ## Scope / ## Acceptance Criteria / ## Constraints`) is defined in `skills/ops/SKILL.md:583-603` but the executor body never names these sections. **Fix:** add a "Reading the brief" subsection naming the four/five expected sections and stating precedence; on missing sections, escalate.

- **MAJOR-2** — `executor.md:90,127` — Brief-internal inconsistency has no defined behavior. `## Scope` and `## Acceptance Criteria` may reference different files; the rule "stay within scope" and "satisfy acceptance criteria" both claim primacy. **Fix:** state that conflicts must be escalated, not silently resolved.

- **MAJOR-3** — `executor.md:173,53` — Fix-loop re-entry semantics under-specified. Silent re-dispatch on verifier FAILED leaves contradicting criteria handling, attempt-counter scope, and code-reviewer REQUEST CHANGES loop relationship undefined. **Fix:** add a "Fix-loop semantics" subsection treating verifier feedback as criterion refinement, escalating on out-of-scope demands, defining attempt counter scope, and integrating code-reviewer loop.

- **MAJOR-4** — `executor.md:85` vs `executor.md:94,107,151` — Internal contradiction on test modification. "Write tests when the plan specifies" vs "Does not modify tests to make them pass" — boundary implicit. **Fix:** replace with one explicit hierarchy: tests follow the plan; failures fix production code unless plan calls for test changes; "modify to make pass" means weakening assertions, not plan-directed work.

- **MAJOR-5** — `executor.md:115` — `R5` token opaque to runtime executor. Defined in `docs/code-intel/design-trace.md:34` but executor never loads that file. Predicate is inlined immediately after so operationally fine — but documentation drift risk. **Fix:** drop the `R5` label.

- **MAJOR-6** — `executor.md:98` — `_tmp_*` cleanup checkpoint and verifier handoff unspecified. "Clean up at checkpoints" without naming a checkpoint; verifier handoff may need `_tmp_*` artifacts. **Fix:** add explicit cleanup point with verifier-artifact exception (name persistent files in `Handoff Artifacts:` line).

#### MINORs

- **MINOR-1** — `executor.md:108` — "Documentation" lane boundary undefined. Docstrings/comments/annotations vs README/changelog left ambiguous.

- **MINOR-2** — `executor.md:53` vs `executor.md:166-179` — Quick-reference card claims code-reviewer loop the body never describes.

- **MINOR-3** — `executor.md:39,94,107,151` — "Modify tests to make them pass" repeated 4 times in close paraphrase.

---

### verifier

**Verdict:** NEEDS-REWORK

Two BLOCKERs will demonstrably produce divergent runtime behavior on identical dispatches. Six MAJORs reinforce systemic edge-case under-specification. Cross-reference hygiene clean.

#### BLOCKERs

- **BLOCKER-1** — `verifier.md:67,71,83-88` — Acceptance-criteria source not specified for runtime dispatch. Agent told to "verify against planner's acceptance criteria and project-scoper's scoping document" but never told where they live, what they're named, or what to do if dispatch brief omits them. **Fix:** add "Sources of acceptance criteria, in priority order" subsection: (1) explicit list in dispatch brief, (2) `docs/plan/*.md`, (3) executor's stated brief in handoff (MEDIUM confidence), (4) refuse with `NEEDS-INPUT`.

- **BLOCKER-2** — `verifier.md:118-124,200` — PASS / VERIFIED WITH GAPS / FAILED boundaries collide on partial test pass. If all ACs pass but 1 of 30 tests fails on an unrelated pre-existing issue, all three verdicts are plausible. **Fix:** decision tree: any AC fails → FAILED; previously-passing test now fails → FAILED; pre-existing failing test unaffected → VERIFIED WITH GAPS; untestable AC → FAILED with `AMBIGUOUS_AC`.

#### MAJORs

- **MAJOR-1** — `verifier.md:5-12,99-105,181-188` — Lane boundary on test-writing permissive given Edit/Write toolset. Agent has full Edit/Write; lane forbids "implementing fixes" but doesn't bound it to test paths. **Fix:** restrict Edit/Write to `tests/**`, `**/*test*.py`, or equivalent test paths.

- **MAJOR-2** — `verifier.md:90-98,120-122` — No-tests-at-all fallback undefined. If a new module has zero tests, lane forbids "comprehensive test suites from scratch" but verdict mapping doesn't say CRITICAL gap → FAILED. **Fix:** write minimal smoke test per AC; if untestable, FAILED with sub-status `UNTESTABLE`.

- **MAJOR-3** — `verifier.md:74,108-112,139` — Test discovery rule implicit. Sample command `pytest tests/` doesn't generalize to polyglot or heterogeneous repos. **Fix:** discovery procedure: probe `pyproject.toml` / `pytest.ini` / `tox.ini` / `package.json` / `Makefile`; prefer Make `test` target; fall back to language idioms; document choice.

- **MAJOR-4** — `verifier.md:122,218` — Re-verification semantics on fix loop unspecified. Second-pass instance not told what to re-check vs skip. **Fix:** "Re-verification" subsection: re-run all ACs (not just failed), full test suite, compare against first-pass evidence, flag as re-verify pass.

- **MAJOR-5** — `verifier.md:72` — "Reading the executor's handoff" asserted, not specified. Where is the handoff? Inline brief? Handoff dir? `git diff`? **Fix:** procedure: dispatch brief inline → `.agents/handoffs/<run_id>/executor.md` → `git diff HEAD`; flag discrepancies.

- **MAJOR-6** — `verifier.md:128-170` — Verdict report shape ignores partial / edge-case verdicts. No required-vs-optional rule per verdict; no `Re-verify of: <prior verdict>` row. **Fix:** explicit schema rules per verdict; always include `Pass type: initial / re-verify`.

#### MINORs

- **MINOR-1** — `verifier.md:73,194` — "Fresh evidence" undefined in time.

- **MINOR-2** — `verifier.md:74` — Testing pyramid 70/20/10 percentages presented as numbers.

- **MINOR-3** — `verifier.md:124` — Confidence-level definitions overlap.

- **MINOR-4** — `verifier.md:216` — git-master commit handoff is `/ops`-contextual but not gated.

---

### debugger

**Verdict:** READY-WITH-CAVEATS

Structurally sound, free of cross-file citation rot. Workflow, hypothesis discipline, cleanup, and final checklist explicit. Five MAJORs cluster on one underlying issue: the agent has Edit/Write but lacks operational predicates for fix-vs-report and regression-check scope.

#### MAJORs

- **MAJOR-1** — `debugger.md:62-67,119,155-160,285-288` — Fix-vs-report decision criteria not a predicate. Three different rules govern "do I apply the fix?" not unified into a checklist. "Design change," "minimal change," "minimal fix" intuitively used but never operationalized. **Fix:** explicit checklist — apply if all of: ≤N lines changed, single file, no new function/class, no public API change, no new dependency. Otherwise route to planner.

- **MAJOR-2** — `debugger.md:121,170-173,213-218` — Regression-check scope undefined. "Module tests" without defining boundary. **Fix:** define module = same package directory; regression scope = bug-reproducing test + co-located test file + tests importing changed module (via grep). >60s budget → document and report.

- **MAJOR-3** — `debugger.md:182-225` / `skills/ops/SKILL.md:529` — Output report has no machine-parseable contract for team manager. Markdown template returned in chat; no persistence to `.agents/handoffs/` required. Resume across session = findings lost. **Fix:** require persistence to `.agents/handoffs/<run_id>/handoff-<task>-debug-to-<next>.md` when invoked under `/ops`, OR clarify that team manager owns persistence.

- **MAJOR-4** — `debugger.md:47,117,147,246` — Circuit breaker exit conditions imprecise. "After 3 failed hypotheses → escalate" — "failed" vs "ELIMINATED" terminology mismatch; 4th iteration behavior undefined; debugger counter vs ops attempt-counter not reconciled. **Fix:** use ELIMINATED consistently; "When the circuit breaker fires" subsection: stop investigation, return Debug Report with Root Cause = UNKNOWN, list hypotheses, recommend escalation/planner; no fix on 4th iteration.

- **MAJOR-5** — `debugger.md:4,58,65,77` — debugger-vs-debugger-build predicate one-directional. All references are out-bound. `agents/debugger-build.md:59` has the reverse rule; `debugger.md` lacks the symmetric rule. **Fix:** add parallel rule: "If investigation reveals the issue is actually a build/compilation error, stop and hand off to `debugger-build` with reproduction notes."

#### MINORs

- **MINOR-1** — `debugger.md:78` vs `debugger.md:172,267` — Lane-boundary list omits "writing tests" while Workflow requires it. **Fix:** "Does not write comprehensive test suites (writes ONE focused regression test for the fixed bug only)".

- **MINOR-2** — `debugger.md:88` — `code-intel` report path schema with no anchor file. **Fix:** add citation "(schema defined in `agents/code-intel.md`)".

- **MINOR-3** — `debugger.md:120,166` — "Same module" undefined as filtering term. Same Python package? Same file? Same directory? **Fix:** define = same source file; sibling-dir files listed in Similar Issues but not fixed.

- **MINOR-4** — `debugger.md:253` — Pre-commitment example refers to project-specific stage path. Cosmetic; mark as illustrative.

---

### git-master

**Verdict:** NEEDS-REWORK

Highest-stakes findings of the run. Well-structured but multiple load-bearing ambiguities in the highest-blast-radius branches: dirty-tree handling on main, force-push to main, conflict-resolution authority, worktree merge protocol. For the most destructive agent in the fleet, this bar is not met.

#### BLOCKERs

- **BLOCKER-1** — `git-master.md:77-81` — "Interactive vs autonomous" mode undefined inside agent body and undetectable by runtime agent. Decision tree forks on a runtime mode the agent has no way to determine. With uncommitted changes on `main`, this can map to destroying or stashing user work without a recorded label. **Fix:** replace mode fork with explicit brief contract: brief MUST include `mode: interactive | autonomous`; default to autonomous; stash with ISO-timestamped descriptive label; emit stash ref in response. Add brief-schema block at top of file.

#### MAJORs

- **MAJOR-1** — `git-master.md:66-76` — Branch decision matrix omits at least three real-world starting states. Detached HEAD, in-progress merge/rebase/cherry-pick, and unborn HEAD all uncovered. **Fix:** add three rows: detached HEAD → refuse, report SHA; in-progress op → refuse, report; unborn HEAD → first commit on `main`.

- **MAJOR-2** — `git-master.md:180-186,266` — Conflict-resolution authority undefined. Edit/Write granted but lane says "no code"; merge-conflict resolution IS code editing. **Fix:** explicit subsection — MAY resolve in markdown/JSON config/lockfiles/.gitignore autonomously; MUST escalate on source code/tests/schema/migration/binary; leave conflict markers and return file list.

- **MAJOR-3** — `git-master.md:90` — Worktree contract is one paragraph for a multi-step concurrent-merge protocol. Missing: branch identification, merge order, "sequentially" command (`--no-ff`? squash? rebase?), "force-merging" semantics, cleanup, failure-branch handling. **Fix:** dedicated subsection — branch list from `.ops-state/<run-id>-board.json`; dispatch order; `git merge --no-ff <branch>`; skip failed-task branches; conflict policy from MAJOR-2; `git worktree remove` after merge; remove "force-merging" verb entirely.

- **MAJOR-4** — `git-master.md:252` — "Warn the user if they request it" leaves force-push to main executable after warning. Subagent in autonomous mode has no user; warning collapses to "execute force-push to main." **Fix:** "Refuse to force-push to `main`/`master` under any circumstance, including direct user request. If user genuinely needs to rewrite main, instruct them to perform manually after disabling branch protection."

- **MAJOR-5** — `git-master.md:88,258` — Push policy undefined. Two rules pull different ways: "always confirm before pushing" vs "do not auto-push." In autonomous dispatch, both are unsatisfiable. **Fix:** "Push policy" subsection — push only when brief explicitly authorizes (`push: true` or PR-creation task); always `--set-upstream` on first push; skip if no remote; never push to `main`/`master` regardless of authorization; `--force-with-lease` only on `force_push: true`.

- **MAJOR-6** — `git-master.md:206-229` — Pause/resume protocol non-deterministic across sessions. WIP commit message "wip: [task]" not unique; "small uncommitted changes" threshold vague; `git reset HEAD~1` assumes WIP at HEAD. Data-integrity risk if non-WIP commit added on top. **Fix:** standardize — `wip(<task-id>): <description> [<ISO-timestamp>]`; threshold = ≤5 files & ≤200 lines; resume verifies HEAD message starts with `wip(<task-id>)` before reset.

- **MAJOR-7** — `git-master.md:94-98,141` — Style detection runs `git log -30` with no fallback for fresh/shallow repos. Errors on unborn HEAD, shallow clone depth 1, first commit of new branch. **Fix:** if log returns <5 commits or errors, default to Conventional Commits and note in response.

- **MAJOR-8** — `git-master.md:10-11` vs `git-master.md:243` — Lane boundary "does not write code" conflicts with granted Edit/Write tools. **Fix:** enumerate explicitly — MAY use Edit/Write for `.gitignore`, `.gitattributes`, commit message files, `CHANGELOG.md`, PR descriptions, conflict resolution under MAJOR-2 rules. MUST refuse for source/tests/docs (other than CHANGELOG/PR)/configs.

#### MINORs

- **MINOR-1** — `git-master.md:121,254` — Hook-skip rules cover `--no-verify` but not `--no-gpg-sign`.

- **MINOR-2** — `git-master.md` (general) — Failure-escalation criteria absent for runtime git failures (push rejected, stash conflict, detached HEAD on rebase abort, gh auth failure).

- **MINOR-3** — `git-master.md:47` — Quick Reference card lists `--force-with-lease` only in Constraints, not Safety rules.

- **MINOR-4** — `git-master.md:3` — `model: sonnet` in frontmatter. Audit task assumes Opus 4.7; actual deployment routes to Sonnet. Worth confirming with user given blast radius (peers like `critic`, `rollback` are `model: opus`).

- **MINOR-5** — `git-master.md:118` and `git-master.md:102-105` — `git add -A` discouraged but `git add <file>` not specified for multi-file split-commit case.

---

### project-scoper

**Verdict:** NEEDS-REWORK

BLOCKER reproduces the live incident the user flagged. Forward-reference at `project-scoper.md:243` causes a deterministic miss of the document-revision workflow. Four MAJORs around methodology, precedence, and revision scope compound run-to-run inconsistency.

#### BLOCKERs

- **BLOCKER-1** — `project-scoper.md:107-117,258-277` — File-class boundary undefined; agent will edit runtime contracts. Agent claims lane covers "architecture and planning documents (e.g., schema designs, implementation plans, technical specs)" but never enumerates which file classes are in scope vs out of scope. Per user's standing memory `feedback_agent_contracts_are_code.md`, every `agents/*.md` and `skills/**/*.md` (except `README.md`) is a runtime contract that should NOT be edited by project-scoper. **Fix:** add "In-scope file classes" subsection with explicit allow/deny lists; load-bearing rule: if critic finding targets out-of-scope file, produce revision plan and hand off to executor (no Edit/Write against those paths).

#### MAJORs

- **MAJOR-1** — `project-scoper.md:243` — Forward reference written as "above." Step 2 of "From the critic or team manager" handoff says "Follow the workflow in 'Revising architecture and planning documents' above." Section is at `project-scoper.md:258` — *below* the citation. **Fix:** move section before Handoff section, or change "above" to "below." Moving it is preferred.

- **MAJOR-2** — `project-scoper.md:5-13,107-117` — `Edit` and `Write` tools unconstrained by textual policy. Compare to `agents/critic.md:5-9` which omits Edit/Write entirely. **Fix:** pair with BLOCKER fix — explicit tool-use rule: use Edit/Write only against in-scope paths; refuse out-of-scope and produce revision plan for executor instead.

- **MAJOR-3** — `project-scoper.md:84-90,201` — Estimation methodology undefined. Unit stated (hours) but no granularity, what's included, range vs point, milestone subtotal rule. **Fix:** "Estimation methodology" subsection: granularity (round to 0.5h below 4h, 1h above), include implementation + tests + light docs (integration/migration as separate line items), use ranges when confidence <70%, milestone subtotals = sum of point midpoints.

- **MAJOR-4** — `project-scoper.md:62-66,70-82` — Gap-analysis source-of-truth precedence undefined. When brief, plan, and codebase contradict, no rule for which wins. **Fix:** precedence rule — (1) explicit user instruction in brief, (2) architect ADD, (3) planner task breakdown, (4) codebase reality, (5) stale docs/READMEs. Surface conflicts as `Contradiction` rows before estimating.

- **MAJOR-5** — `project-scoper.md:121,204,240-244` — Revise-vs-create precedence buried and incomplete. Logic scattered across three places; no single decision rule; no glob-for-existing first step. **Fix:** "Decide: create or revise" subsection at top of "Output format": glob for existing scoping/plan docs matching subject; if exactly one match, revise; if multiple, ask which is canonical; if none, create new.

- **MAJOR-6** — `project-scoper.md:204,246-256` — Revision-scope rule lacks concrete bounds. "Affected sections" undefined; no upper bound. **Fix:** define three revision scopes — line-level (1-5 line diff), section-level (one heading + cascade for changed numbers), structural (reorganization → hand back to planner).

- **MAJOR-7** — `project-scoper.md:251,276,117` — "Hand back to planner" trigger vague. Three different overlapping triggers. **Fix:** concrete decision rule — hand back when (a) tasks added/removed/reordered, (b) milestone boundary moves, (c) dependency graph changes. Revise in place when only descriptions/estimates/assumptions change. When in doubt, hand back.

#### MINORs

- **MINOR-1** — `project-scoper.md` / `skills/ops/SKILL.md:241` — Hour→minute conversion convention owned upstream by team manager. Scoper file doesn't state this contract; future maintainer could shift to minutes "for consistency" and break manager parsing. **Fix:** one-line note in Scoping and estimation: "Output unit is hours. The team-manager converts hours to minutes when populating `estimated_minutes` in the task board — do not pre-convert."

- **MINOR-2** — `project-scoper.md:51` vs `project-scoper.md:268` — Pipeline diagram in quick-reference disagrees with file structure. Quick-ref shows revision branch but doesn't cite team-manager as router; body cites team-manager but doesn't echo dual-source diagram.

- **MINOR-3** — `project-scoper.md:119-186` — Output format silent on traceability/assumptions/timeline being mandatory vs optional.

---

## Recommended Implementation Order

### 1. Fix the 4 BLOCKERs first

Each BLOCKER has a known concrete failure scenario that Opus 4.7 will hit on real `/ops` runs:

- `verifier.md:67,71,83-88` — acceptance-criteria source lookup (BLOCKER-1)
- `verifier.md:118-124,200` — PASS/FAIL verdict decision tree (BLOCKER-2)
- `git-master.md:77-81` — interactive-vs-autonomous mode detection (BLOCKER-1)
- `project-scoper.md:107-117,258-277` — in-scope file-class allowlist (BLOCKER-1)

### 2. Address the cross-cutting brief-schema gap

`executor` MAJOR-1, `verifier` BLOCKER-1, and `git-master` BLOCKER-1 all share the same root cause: agents assume a structured dispatch brief but none names its required sections or specifies escalation on malformed input. A shared brief contract in `skills/ops/SKILL.md` or a new `agents/_brief-contract.md` reference would close multiple findings simultaneously, rather than duplicating identical prose across five agent files.

### 3. Per-agent MAJOR cleanup, ordered by dispatch frequency

After BLOCKERs and brief-schema are resolved, address per-agent MAJORs in this order: `executor` → `verifier` → `git-master` → `project-scoper` → `debugger`. This order reflects estimated dispatch frequency under `/ops`.

### 4. Batch or defer MINORs

The 19 MINORs across five agents are low-risk individually. Batch them into a single polish pass after MAJOR work is done, or defer until the next scheduled audit cycle.

---

## Reference

Full critic reports (per-agent raw output, "Why Opus 4.7 might struggle" analysis, and all supporting citations) are preserved in the frozen handoff file:

```
.agents/handoffs/agents-tier-a-audit-2026-05-04/audit-findings.md
```

Agents read-only during this audit: `agents/executor.md`, `agents/verifier.md`, `agents/debugger.md`, `agents/git-master.md`, `agents/project-scoper.md`, `agents/critic.md`, `agents/debugger-build.md`, `agents/code-intel.md`, `skills/ops/SKILL.md`, `docs/code-intel/design-trace.md`, `docs/plan/code-intel-agent-requirements.md`, project and global `CLAUDE.md`, user memory `feedback_agent_contracts_are_code.md`.

No source files were modified during the audit.

---

## Kickoff Skill Alignment (2026-05-07)

### Summary

On 2026-05-07, a code-reviewer agent audited `skills/kickoff/SKILL.md` and `skills/kickoff/project-template/.claude/commands/next.md` against the findings in this document. Seven priorities (P1–P7) were derived from applicable cross-cutting and per-agent findings. Parallel executors applied all seven, and the verifier returned PASS on each. The work was bounded by three explicit design constraints (see below); findings that conflicted with those constraints were either adapted (P5, adapted to P5′) or marked N/A by design.

### Design constraints applied

- **Portability and lightweight scaffolding.** The kickoff skill optimizes for producing projects that work in any Claude Code installation. Templates must not assume this repo's sibling skills or agents are available.
- **`next.md` is intentionally agent-installation-agnostic.** It uses role names in prose and does not set `subagent_type` on Agent dispatches. As a consequence, `next.md` must be fully self-contained — no outbound references to repo-siblings like `skills/ops/brief-contract.md`. This is why P5 was adapted to P5′: the brief grammar is inlined in `next.md` rather than referencing the central `brief-contract.md`.
- **Kickoff does not scaffold agent definitions.** Target projects' `.claude/agents/` directories are not populated by kickoff. Agent registration remains at the user's installation level.

### Priorities applied

| Priority | File:Lines | Source audit finding(s) | Description |
| :--- | :--- | :--- | :--- |
| P1 | `skills/kickoff/SKILL.md:47-60` | CC-1, executor MAJOR-1 | New `## Dispatch Brief Format` section between the Scope Classification Gate and Phase 1. Names the five expected sections (`## Task / ## Context / ## Scope / ## Acceptance Criteria / ## Constraints`), specifies escalation on missing or malformed sections, and references `~/.claude/skills/ops/brief-contract.md` and audit CC-1. |
| P2 | `skills/kickoff/project-template/.claude/commands/next.md:101-120` | project-scoper BLOCKER-1, CC-2 | Inline file-class allowlist for the implementor subagent. Source files, test files, and config files are permitted; plan documents, `.claude/`, `.cursor/`, and workflow marker files are prohibited. Closes the lane-boundary ambiguity that BLOCKER-1 identified for `project-scoper`. |
| P3 | `skills/kickoff/SKILL.md:189` | CC-6 | `project-scoper` must persist its output to `docs/kickoff-scoping.md`; a read-back verification step is specified. Addresses the output-persistence inconsistency flagged in CC-6. |
| P4 | `skills/kickoff/SKILL.md:446` | executor MAJOR-1 | Minimum requirements schema gate (project name + at least one milestone + acceptance criteria) added to the Phase 2 error-handling table row for partial-requirements recovery. Prevents non-deterministic improvisation on a malformed or incomplete brief. |
| P5′ | `skills/kickoff/project-template/.claude/commands/next.md:79-86` | CC-1 | Self-contained subagent brief grammar (`Task / Scope / Acceptance Criteria / Constraints`) inlined directly in `next.md`. Adapted from CC-1's recommendation to use a shared brief contract; the portability constraint prohibits an outbound reference to `skills/ops/brief-contract.md` from a scaffolded template. |
| P6 | `skills/kickoff/SKILL.md:166-175` | CC-4, executor MAJOR-3 | Re-entry semantics for the Phase 5 critic/planner revision loop. Specifies what is re-checked on each iteration, how feedback is reconciled with original criteria, and when the loop escalates. Addresses the under-specified fix-loop semantics flagged in CC-4. |
| P7 | `skills/kickoff/SKILL.md:104-109` | executor MAJOR-1, verifier BLOCKER-1 | Acceptance-criteria pass-through contract from `interviewer` → `planner` → `INDEX.md`. Verbatim copy required; specifies escalation when the chain breaks. Closes the AC-source ambiguity that verifier BLOCKER-1 identified at the fleet level. |

### Findings marked N/A by design

- **verifier BLOCKER-2** (`verifier.md:118-124,200`, PASS/FAIL verdict collision) — kickoff is not a verifier; it does not issue PASS/FAIL verdicts on test runs.
- **git-master BLOCKER-1** (`git-master.md:77-81`, interactive-vs-autonomous mode) — kickoff is user-interactive by design; the interactive/autonomous distinction does not apply.
- **git-master MAJOR-1–MAJOR-8** — kickoff prohibits issuing git commands; lane separation from git-master is intentional and pre-existing.
- **debugger MAJOR-1–MAJOR-5** — kickoff is a planning orchestrator, not a bug investigator; none of the debugger's fix-vs-report or regression-check predicates have an analogue.
- **executor MAJOR-4** (`executor.md:85`, test-modification contradiction) — kickoff does not modify tests; it delegates to the executor lane.
- **executor MAJOR-5** (`executor.md:115`, `R5` opaque token) — localized documentation drift in `executor.md`; kickoff carries no equivalent token.
- **project-scoper MAJOR-1** (`project-scoper.md:243`, forward reference written as "above") — no equivalent structural error exists in kickoff's document.
- **project-scoper MAJOR-3–MAJOR-7** — estimation methodology, gap-analysis precedence, revise-vs-create logic, revision-scope bounds, and hand-back triggers govern the scoper agent itself, not its caller.
- **verifier MAJOR-3** (`verifier.md:74,108-112,139`, test discovery in polyglot repos) — kickoff does not run tests.
- **git-master MINOR-4** (`git-master.md:3`, `model: sonnet` in frontmatter) — kickoff is a skill, not an agent definition with frontmatter; the frontmatter convention does not apply.

### Open coherence note

P3's obligation — that `project-scoper` must persist output to `docs/kickoff-scoping.md` with a read-back verification step — is stated in the body of Phase 5.5 (`skills/kickoff/SKILL.md:189`) rather than as a bullet inside Phase 7's own list. A reader scanning Phase 7 in isolation will not see `docs/kickoff-scoping.md` called out there. This satisfies the original acceptance criterion as written, but creates a minor symmetry gap: the two phases that produce durable artifacts (Phase 5.5 and Phase 7) are not stated in the same location. A future editor may want to add a cross-reference bullet in Phase 7 pointing to the Phase 5.5 obligation. This is a polish item, not a regression.
