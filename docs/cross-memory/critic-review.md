# Cross-Memory v1 — Critic Review

**Verdict: REVISE — send back to architect (primary) and project-scoper (secondary).**

The plan and scoping document are tight at the task-decomposition and effort-estimation level. The blockers are upstream of both: the ADD has at least two foundational mechanism gaps (the always-on injection path on Claude Code, and the slug derivation contradiction) that propagate destructively into M3 and SC-4/SC-14/SC-16 verification. Two more findings raise execution-level risk on the plan and scoping. None of this invalidates the four-milestone shape — but populating the task board now would bake the upstream defects into executor work. Architect resolves Findings 1, 2, and 3; scoper revises gap entries G8 and adds two missing gaps; planner re-states M3.implement.1 and M3.verify.6 acceptance once Findings 1 and 2 are resolved.

I operated in **adversarial mode**. Trigger: one CRITICAL finding (Finding 1) plus three MAJOR findings (Findings 2, 3, 4) surfaced inside the first verification pass against the actual filesystem and existing artifacts. After escalation, two further MAJOR findings emerged on cross-document consistency.

---

## 1. Verdict (one line, in bold above)

**REVISE — send back to architect first, then project-scoper.** Implementation does not start until Findings 1, 2, and 3 land in the ADD and the scoping doc absorbs the consequences.

---

## 2. Top Findings (by severity)

### Finding 1 — CRITICAL — `[CROSS-MEMORY]` always-on injection mechanism on Claude Code is unspecified and likely wrong

- **Severity:** blocker.
- **Where:** `docs/cross-memory/architecture-decision.md` §4 ("Injection mechanism per harness" + §12(b) bottom half); `docs/plan/cross-memory-plan.md` task M3.implement.5; SC-1, SC-4, SC-16, SC-18 verification scenarios.
- **What:** ADD §4 states "Claude Code: the adapter mirrors project:<slug> and (optionally) writes the user-global + harness-specific tier files to ~/.claude/projects/<slug>/memory/ so Claude Code's native auto-injection picks them up. Mirroring is the injection path. No new injection mechanism." ADD §12(b) elaborates: "Writes [CROSS-MEMORY]-blocked tier to ~/.claude/projects/<slug>/memory/". Neither passage names the **filename** the `[CROSS-MEMORY]` block is written to, nor does it explain how Claude Code's auto-injection surfaces a single composite block versus the individual memory files. Empirically (this very session) Claude Code's auto-injection reads `~/.claude/projects/<slug>/memory/MEMORY.md` as the source of injected content — the index lines themselves get injected, and the linked `<type>_<slug>.md` files are loadable but not auto-prepended as a block. The ADD assumes a mechanism (write a `[CROSS-MEMORY]` file and Claude Code reads it as a block) that has no evidence in the host's documented behavior. Two ADD passages collide:
  1. "the mirror IS the injection path" (requirements §9, ADD §4) — implies mirroring individual files into `~/.claude/projects/<slug>/memory/` is sufficient.
  2. "Writes [CROSS-MEMORY]-blocked tier to ~/.claude/projects/<slug>/memory/" (ADD §12(b)) — implies a single composite-block file is also written.
- **Why it matters:** SC-4 (canonical write produces a mirror; on next session start Claude Code's native auto-injection includes it) and SC-16 (session injection contains the literal [CROSS-MEMORY] header with three sub-sections) cannot both pass under the same mechanism unless one of three things is specified: (a) the `[CROSS-MEMORY]` block is appended to `MEMORY.md` itself, (b) the block is written as a separate file (e.g., `_cross-memory-injection.md`) and `MEMORY.md` is updated to reference it, or (c) Claude Code has an undocumented behavior of auto-rendering arbitrary `.md` files in the directory. Option (c) is unsupported by observation. Without picking (a) or (b), M3.implement.5 has no concrete acceptance criterion for **where the block lives on disk**, and M3.verify.6 (SC-14, byte-identical pre-existing files) becomes unverifiable: the adapter MUST modify `MEMORY.md` to surface anything, but `MEMORY.md` is a pre-existing file — touching it potentially violates SC-14 unless the protocol distinguishes "append by adapter" from "user-edited."
- **What to do:** Architect revises ADD §4 + §6 + §12(b) to specify exactly:
  1. The on-disk filename for the `[CROSS-MEMORY]` block (recommendation: append it to `MEMORY.md` as a fenced block delimited by stable markers, e.g., `<!-- cross-memory:start -->` / `<!-- cross-memory:end -->`, so the adapter can update it idempotently without colliding with native entries).
  2. How SC-14's "byte-identical" guarantee composes with adapter writes to `MEMORY.md`. Likely answer: SC-14 protects pre-existing memory FILES, not the `MEMORY.md` index — the index gets a managed delimited block under sentinel markers. The adapter never edits content outside its own markers.
  3. The bootstrap path on a project where `MEMORY.md` does not exist yet — adapter creates an empty one with the markers if absent.

  After ADD revision, planner re-states M3.implement.1 (Claude Code adapter), M3.implement.5 (injection block formatter), and M3.verify.6 (SC-14 snapshot semantics) acceptance criteria. Scoper adjusts M3.implement.5 expected hours upward (current 1.5h does not include the marker-based MEMORY.md update protocol; estimate +0.5h).

### Finding 2 — CRITICAL — Slug derivation contradicts itself; example contradicts the rule contradicts the filesystem

- **Severity:** blocker.
- **Where:** `docs/cross-memory/architecture-decision.md` Decision 1 (§2, line 149); `docs/cross-memory/scoping.md` §5 gap G8; impacted tasks M3.implement.1, M3.verify.3 (SC-4), M3.verify.6 (SC-14).
- **What:** Decision 1's prose says: "...replace path separators (/, \, :) with -, drop leading -. Example: D:\Repositories\Personal\Git\AI-Skills-Agents → D--Repositories-Personal-Git-AI-Skills-Agents." The example does **not** drop the leading `-` — `D:` becomes `D-`, `\` becomes `-`, producing `D--`. The actual on-disk slug for this project is `D--Repositories-Personal-Git-AI-Skills-Agents` (verified: `~/.claude/projects/D--Repositories-Personal-Git-AI-Skills-Agents/memory/` exists). So the rule says one thing, the example says another, and the filesystem agrees with the example. Scoping doc gap G8 surfaces the issue but classifies it as `Edge case` — that severity is wrong; this is a contradiction between Decision 1's stated rule and Decision 1's stated example, and a correctness defect against actual host behavior. If an executor follows the prose rule literally, every Claude Code mirror lands in a wrong directory and SC-4 fails silently (no auto-injection) while SC-14 looks fine (no pre-existing file mutated, because no pre-existing file was touched).
- **Why it matters:** SC-4, SC-1, SC-9, SC-16 all depend on the mirror landing in the directory Claude Code actually reads. A one-character discrepancy on the slug breaks all of them and the plan provides no recovery path because M3.verify.6 verifies the wrong invariant (it checks that pre-existing files are untouched — they will be, because the adapter wrote nothing in the right place at all).
- **What to do:** Architect rewrites Decision 1 to either: (a) drop the "drop leading `-`" clause (the example and filesystem both agree the leading dashes stay), or (b) keep "drop leading `-`" and fix the example AND find out why the filesystem disagrees. Recommendation: (a) — the actual rule is "replace `:` with `-`, replace `\` with `-`, replace `/` with `-`, no leading-dash removal." Scoper upgrades G8 from `Edge case` to a hard prerequisite for M3.implement.1 and adds an executor pre-flight: "before M3.implement.1 starts, run `ls ~/.claude/projects/` and use the literal slug for the active project; if it diverges from Decision 1's stated derivation, halt and route back to architect." This pre-flight already exists in scoping OQ-C — promote it from "if no decision" to a mandatory pre-task.

### Finding 3 — MAJOR — Audit-reports directory is referenced but not provisioned; brief template and flow are inconsistent

- **Severity:** major.
- **Where:** `docs/cross-memory/architecture-decision.md` §8 (Brief contract — input shape, `## Scope` line `~/.cross-memory/audit-reports/ (write — for audit reports only)`); §10 audit flow; Decision 13 lazy provisioning sequence; `docs/plan/cross-memory-plan.md` M1.implement.5 (provisioning subdirs `user-global/, projects/, harnesses/{claude-code,cursor,generic}/, archive/`); `docs/cross-memory/scoping.md` gap G10 + open question OQ-D.
- **What:** ADD §8 hard-codes `~/.cross-memory/audit-reports/` as a write target in the agent's brief template `## Scope`. Decision 13's lazy-provisioning enumeration does not include `audit-reports/`. ADD §10 describes the audit flow as "Skill receives the report and renders it to the user" — the flow is chat-rendered, not file-rendered. The scoping doc surfaces this in G10 + OQ-D. The contradiction is real and unresolved between three documents.
- **Why it matters:** if an executor implements the agent and brief template per ADD §8, the agent expects `audit-reports/` to be a writable target. First call attempts a write into a directory that lazy-provisioning never creates. The agent either fails or silently writes outside its allowlist (refuse-and-halt path). SC-13 (agent write restricted to canonical store) would technically still pass (the agent IS within `~/.cross-memory/**`), but the audit flow becomes inoperable. Worse: SC-8 verification (M4.verify.1) walks the `/cross-memory audit` flow and would either trip the missing-directory case or paper over it because the verifier task description doesn't specify the on-disk artifact location.
- **What to do:** Architect picks one of:
  - Option A: keep `audit-reports/` in the brief template, add it to Decision 13 lazy provisioning, and specify a retention/pruning rule for the directory in §10.
  - Option B: remove `audit-reports/` from the brief template and delete the line from §8; declare audit reports chat-only at v1 (scoping OQ-D's recommendation).

  Either option is valid; option B is smaller and consistent with v1's "not a transcript archive" non-goal. Scoper updates G10 from `Contradiction` (which it already correctly classifies) to a hard plan revision and removes OQ-D once the architect chooses. Planner removes the `audit-reports/` line from M4.implement.1 acceptance language IF option B; or adds an `audit-reports/` line to M1.implement.5 IF option A.

### Finding 4 — MAJOR — Cursor target's deploy-manifest globs differ from what ADD §11 claims; the ADD's "no manifest changes needed" assertion is partially wrong

- **Severity:** major.
- **Where:** `docs/cross-memory/architecture-decision.md` §11 ("Deploy-manifest integration"); actual `tooling/deploy-manifest.json` lines 90-100; plan task M4.implement.3.
- **What:** ADD §11 claims: "agents/cross-memory.md → matched by agents.include: ['*.md'] in all three targets. ... skills/cross-memory/** → matched by skills.include: ['**/*.md'] in all three targets." The actual manifest disagrees on the cursor target — cursor's `skills.include` is `["**/*"]` (matches every file, not only `.md`) and cursor's `skills.exclude` is `["kickoff/**"]` (not `["**/SKILL.cursor.additions.md"]`). The agents block on cursor is closer (still `*.md` with `README.md` excluded), but the skills mismatch propagates. Practical consequence: any non-markdown file the executor drops in `skills/cross-memory/` (e.g., a `_tmp_*.json` left behind, a `state.yaml`) will deploy to Cursor unintentionally.
- **Why it matters:** M4.implement.3's acceptance ("Either: existing globs verified to cover all cross-memory files (no manifest edit) OR specific entries added with justification") asks the executor to audit the manifest. Under the ADD's stated globs, the conclusion is "no edit needed." Under the actual manifest, cursor's skill block is wider than the ADD claimed and the executor should add a matching exclude (or trust that the cross-memory skill ships only markdown — which is the design intent per the plan, but the plan has no enforcement for this on the cursor side). The skills/kickoff exclude pattern is also informative — kickoff was excluded entirely from cursor, suggesting that cursor's wider include glob has historically required per-skill explicit excludes. Cross-memory may need a similar treatment if any non-markdown files (e.g., a sample config.yaml fixture) end up in `skills/cross-memory/`.
- **What to do:** Architect updates ADD §11 to reflect the actual manifest (cursor skills include is `**/*` with `kickoff/**` excluded; cursor agents has `transform: true`). Scoper raises M4.implement.3 expected hours from 0.5 to 0.75 — the audit is real, not a no-op rubber-stamp. Planner adds an explicit acceptance line to M4.implement.3: "verify no non-markdown files exist in `skills/cross-memory/` post-implementation; if any were created during implementation as test fixtures, either delete them or add a manifest exclude entry."

### Finding 5 — MAJOR — Lane-boundary "verbatim from agents/code-intel.md" cannot be literal; path globs differ structurally

- **Severity:** major.
- **Where:** `docs/cross-memory/architecture-decision.md` §8 ("This pattern mirrors `agents/code-intel.md`'s Lane Boundaries section verbatim — the executor implementing the agent definition copies the structure"); `docs/plan/cross-memory-plan.md` M4.implement.1 acceptance: "lane-enforcement language matches agents/code-intel.md pattern verbatim"; `docs/cross-memory/scoping.md` §12 assumption A13.
- **What:** code-intel's Lane Boundaries (`agents/code-intel.md` lines 126-145) allowlist three globs: `.code-intel/**`, `docs/code-intel/**`, `_tmp_*`. Cross-memory's allowlist per ADD §8 is `~/.cross-memory/**` only. The structural pattern (refuse-and-halt, three numbered steps, structured violation report) IS reusable verbatim, but the **path globs and refusal context** are not. The plan and ADD both use the word "verbatim" loosely. An executor reading "matches verbatim" might either copy code-intel's globs into the cross-memory agent (wrong — it would allow writes to `.code-intel/**`, a different agent's territory), or hand back the task as un-actionable.
- **Why it matters:** M4.verify.4 (SC-13) acceptance says "the refusal language matches the ADD §8 lane-boundary text" — SC-13 verification can pass while the actual deployed agent has a wrong allowlist. Lane-boundary defects on a write-tool agent are a security-grade concern; A13's "Low" impact rating in scoping is too lenient.
- **What to do:** Architect rewrites the ADD §8 sentence: instead of "verbatim," say "the structural pattern (refuse-and-halt, numbered violation steps, structured report) is reused from `agents/code-intel.md`; the allowlist globs are cross-memory-specific." Plan task M4.implement.1 acceptance is rewritten to "lane-enforcement *structure* matches `agents/code-intel.md`'s pattern; the *allowlist globs* are exactly: `~/.cross-memory/**` (and nothing else)." Scoper upgrades A13 from `Low` to `Medium` impact. M4.verify.4 acceptance gains an explicit check: "after the refusal, confirm the agent definition's allowlist contains only `~/.cross-memory/**` — no `.code-intel/**` or other code-intel globs leaked into the copy."

### Finding 6 — MINOR — Active-Skill-Detection update on user-global `~/.claude/CLAUDE.md` requires an explicit edit-policy decision; scoping flags it but plan over-commits

- **Severity:** minor.
- **Where:** `docs/plan/cross-memory-plan.md` M4.document.5; `docs/cross-memory/scoping.md` gap G6 + OQ-B; user-global `~/.claude/CLAUDE.md`.
- **What:** Plan M4.document.5 says "the documentor reads it, edits it, and confirms with the user" — an explicit write to a user-global file outside the project repo. Scoping G6 + OQ-B correctly flag this and recommend Option B (documentor produces a diff; user pastes it). The plan and scoping are inconsistent: the plan over-commits to a write; the scoping recommends a diff-only flow. The plan should match scoping's recommendation, or the scoping should withdraw OQ-B if the plan has the user-already-approved-write authority.
- **Why it matters:** Editing user-global files from a documentor agent is a precedent the project has not established. The conservative path (diff-only) costs nothing and avoids the precedent. The aggressive path (direct edit) needs a permission audit M4.implement.4 doesn't currently scope.
- **What to do:** Resolve OQ-B explicitly. Recommendation: keep scoping's Option B (diff-only). Planner rewrites M4.document.5 acceptance to "documentor produces a single-row diff in the task handoff; the user applies the edit manually." If the user wants Option A (direct write), the planner adds a permission audit line to M4.implement.4.

---

## 3. Pressure-test on the high-impact assumptions (A1, A2, A3)

### A1 — single executor is Opus 4.7-class with repo conventions in working memory

**Defensible.** The repo's existing skills (`skills/clickup/SKILL.md`, `skills/commit-message/SKILL.md`, `skills/ops/SKILL.md`) are all prose-driven and short enough that an Opus-class agent can re-read them in <2 minutes. The 15-30% inflation risk for cold-start agents is correctly bounded. **No finding.**

### A2 — all `SKILL.md` work is prose-driven flow specification; no shell, no Python, no compiled code

**Defensible BUT depends on Finding 1 being fixed.** If the always-on injection mechanism turns out to require a `MEMORY.md` index update with sentinel markers (Finding 1 recommendation), that's still pure markdown — the assumption holds. If the architect picks a different resolution that requires a Python/shell helper to manage the index block, A2 breaks and every M3 implement task expands. **No finding here**, but flagging that A2's stability is contingent on Finding 1's resolution. Scoper should re-confirm A2 once the architect resolves Finding 1.

### A3 — verifier walks document expected behavior; they do NOT spawn second harness sessions or run end-to-end with a live Cursor instance

**Defensible AND scoping G3 already nails the resolution path.** The recommendation in G3 ("clarify the verifier-task acceptance criterion: 'the documented behavior is the verification artifact; no second harness session is spawned at verify time'") is actionable. **One refinement:** the plan's M3.verify.2 task description currently says "Walk SC-2: save project memory on Claude Code, switch to Cursor on the same project, recall returns it. Detection precedence is exercised by the harness switch." The phrase "switch to Cursor" is exactly the language that risks the over-interpretation A3 warns against. Planner should rewrite M3.verify.2 acceptance to use scoping G3's resolution language verbatim, before the task ships to a verifier. Surface as a low-friction plan fix, not a separate finding.

---

## 4. Pressure-test on the open scoping questions (OQ-A through OQ-E)

### OQ-A — How literally is the "prose-driven flow control" pattern to be taken?

**Real, but already answered by repo precedent.** The recommendation ("treat all SKILL.md work as prose-only") is exactly the precedent set by `skills/clickup/SKILL.md` and `skills/commit-message/SKILL.md`. OQ-A is not blocking; it is documenting the correct interpretation explicitly. **Defensible recommendation.** No finding; scoper can downgrade OQ-A from "open question requiring user decision" to "documented assumption" once the team manager confirms.

### OQ-B — Does M4.document.5 edit `~/.claude/CLAUDE.md` directly?

**Real and unresolved.** Already covered in Finding 6.

### OQ-C — Reconfirm slug derivation for `~/.claude/projects/<slug>/`

**Real and the recommendation is too soft.** "If literal does not match Decision 1's derivation, route back as a critic finding" — that's exactly what Finding 2 does. OQ-C should be promoted from "if no decision, executor pre-flights" to a mandatory architect revision before M3 starts. After Finding 2 lands, OQ-C closes.

### OQ-D — Does the audit persist reports to `~/.cross-memory/audit-reports/`?

**Real and unresolved.** Already covered in Finding 3. Scoper's recommendation (Option B, chat-only) is defensible and matches v1's "not a transcript archive" non-goal.

### OQ-E — Is M3.review.1 really 1.0–1.25 hours given M3's surface?

**Real and the recommendation is conservative-correct.** Keeping at 1.25h expected with 2.0h high gives the reviewer room without inflating the headline. A code-review pass against three ADD sections + four files + the SC-14 byte-identical guarantee is genuinely heavier than M1.review.1 (which is two files against two ADD sections), but the high-end of 2.0h absorbs the realistic upper bound. **No finding.**

---

## 5. Estimate Sanity Check (10 sampled tasks)

Sample selected to cover three of the four milestones, all four agent types, and the heaviest tasks per milestone.

### Sample 1 — M1.implement.3 (redaction module, executor, expected 2.0h)

The task covers: (a) `<private>` parser including unmatched-tag bounded fallback, (b) eight-pattern regex denylist with proximity rules for `aws-secret`, (c) `[REDACTED:<category>]` + `redacted: true` documentation, (d) cosmetic ellipsis-on-render rule. Sample of similar specs in repo: `skills/code-review/SKILL.md` redaction-style sections, none. Closest comparable: `skills/kickoff/templates/*.yaml` rule sets — those land at 60-90 minutes for similar surface. Cross-memory's redaction has ONE complexity beyond a typical rule set: the proximity rule on `aws-secret` (scoping G1) requires a precise textual definition. **Estimate is fair at expected, slightly low at low.** Confidence M is right.

### Sample 2 — M1.implement.4 (indexing module, executor, expected 0.75h)

Pure documentation: line format `- [Name](file.md) — <description>`, three scope dirs that get an index, archive directory does NOT. Trivial. **Estimate is fair, perhaps even generous.** Confidence H is right.

### Sample 3 — M2.implement.1 (save flow, executor, expected 2.0h)

Covers: arg parser documentation (10 flags), redaction pipeline call, two confirmation UX variants (no-pattern path + pattern path), canonical write, MEMORY.md update, mirror dispatch hook, `--no-redact` typed-phrase confirmation. The typed-phrase wording AND the warning UX example block (ADD §9, lines 952-962) both need to be reproduced as prose. **Estimate is fair at expected.** The high estimate of 3.0h absorbs the realistic case where the executor needs to draft the warning UX example to match the ADD's literal box-drawing form.

### Sample 4 — M2.implement.4 (recall, executor, expected 1.0h)

Match strategy + four optional flags + sort + staleness-banner inlining. Comparable to `skills/clickup/SKILL.md` sections that document task-listing flows (~50-60 minutes empirically). **Estimate is fair, possibly generous.** Confidence H is right.

### Sample 5 — M3.implement.1 (Claude Code adapter, executor, expected 2.0h)

Covers: detection logic (env vars + marker file), `mirror_write` with `mirrored_from` + sidecar manifest, `mirror_remove`, `detect_collisions` with three-state report, refusal rule. **Estimate is fair UNDER the current ADD wording**. Once Finding 1 lands and the adapter ALSO needs a `MEMORY.md` marker-block update protocol, expected moves to 2.5-3.0h. Once Finding 2 lands and slug derivation is corrected (no real work, just consistent text), no impact. **Flag: scoper should re-estimate after Finding 1 resolves.**

### Sample 6 — M3.implement.4 (always-on tier filter, executor, expected 1.5h)

Pseudocode in ADD §4 (lines 354-381) is detailed; the executor's job is to translate the pseudocode into prose-narrative flow control. Four inclusion rules, dedup, banner rendering. **Estimate is fair at expected.** Confidence M is right.

### Sample 7 — M3.implement.5 (`[CROSS-MEMORY]` injection block, executor, expected 1.5h)

Currently scopes: header + three sub-sections + bullet cap + drop priority + never-drop-header rule. After Finding 1 lands, this task ALSO owns the marker-based MEMORY.md update protocol — a non-trivial prose addition. **Estimate moves from 1.5h to 2.0h expected once Finding 1 lands.** Scoper should re-estimate.

### Sample 8 — M3.verify.6 (SC-14 byte-identical, verifier, expected 1.0h)

Currently the verifier walks "the adapter refused to overwrite native files." After Findings 1 + 2, this verifier ALSO needs to confirm: (a) the slug used by the adapter matches the on-disk slug (not Decision 1's prose rule), (b) `MEMORY.md` modifications stay inside sentinel markers, (c) pre-existing memory FILES are byte-identical (the original SC-14 invariant). Scoping G4 already adds an SHA-256 snapshot step — that's right. After Finding 1, the snapshot needs to handle `MEMORY.md` specially (compare outside-marker content, not the whole file). **Estimate moves from 1.0h to 1.25h expected.** Confidence drops from M to L on the high end.

### Sample 9 — M4.implement.1 (cross-memory agent definition, executor, expected 2.0h)

Frontmatter, lane boundaries, brief format, two output contracts. After Finding 5 lands and the "verbatim" wording is rewritten, no time impact (the work doesn't change, only the acceptance language does). After Finding 3 (Option B), the brief template loses a Scope line — saves <5 minutes. **Estimate is fair at expected.**

### Sample 10 — M4.document.1 (skills/cross-memory/README.md, documentor, expected 2.0h)

Nine sections; pattern matches `skills/code-review/README.md` (~310 lines) more closely than `skills/clickup/README.md` (~550 lines per scoping). Scoping's note that `~310 lines` is the realistic anchor checks out. **Estimate is fair at expected. 3.0h high absorbs the realistic upper bound for a documentor that has to cross-reference six other artifacts (the SKILL.md, redaction.md, indexing.md, three adapters).**

### Estimate-sanity summary

Of the 10 sampled tasks, **2 require upward revision after upstream findings land**: M3.implement.5 (+0.5h) and M3.verify.6 (+0.25h). The other 8 are within the scoper's confidence bands. Project total expected after upward revision: **~52.75h** (vs scoping's stated 52.0h). The ±18h confidence band absorbs this with room to spare. **No finding on systematic under-estimation.** Scoper revises M3.implement.5 and M3.verify.6 line items after Finding 1 resolves.

---

## 6. Critical-Path Scrutiny

The scoping doc's named critical path is 18 tasks long (the table in §6 has a typo — counts 17 lines but the chain is clearly written; counted from `M1.implement.1` through `M4.document.6` it's 17 steps in §6's text. Trivial.). Concerns:

### Critical-path concern 1 — M3.implement.4's blocked_by includes M3.implement.2 and .3 redundantly

Scoping §10 already correctly classifies M3.implement.4 ← M3.implement.2 / .3 as `Soft-not-redundant-but-loosenable`. The plan's parallelization map says all three adapters can run in parallel; the bottleneck for M3.implement.4 is the **adapter interface contract**, which is fixed once any one adapter is in draft. **Defensible to loosen.** Recommended action: planner updates M3.implement.4 `blocked_by` to `[M3.implement.1]` and notes `.2`/`.3` as soft only. Saves ~0.5h calendar at parallel-3.

### Critical-path concern 2 — M3.review.1 is on the critical path; estimate may be tight

Scoping OQ-E flags this. M3.review.1 reviews three adapters + four SKILL.md sections + SC-14 invariant against three ADD sections. Comparable: M1.review.1 covers two files against two ADD sections at 1.0h. M3 has roughly twice the surface. **The 1.25h expected is tight; 2.0h high is the realistic upper bound.** I am NOT flagging this as a finding because the scoping doc surfaces it explicitly and the high-end estimate is correct. Just confirm M3.review.1 is not pre-committed to the low end of the estimate when the team manager populates the task board.

### Critical-path concern 3 — Single verifier per milestone is a fragile single-point

M1.verify, M2.verify, M3.verify, M4.verify are each owned by a single `verifier` agent dispatch (or a small fan-out at parallel-3). M3.verify alone has 8 SCs covered by 8 verifier tasks. If any one verifier task surfaces a finding that routes back to M3.implement, ALL of M3.verify re-runs. Scoping doesn't quantify the risk of re-runs except through assumption A7 (~30-60 min patch-up overhead). For M3 specifically, with 8 SCs and the safety-critical SC-14 in the mix, a single REQUEST-CHANGES verdict on M3.review.1 is ~2-3h of redo (re-run subset of M3.verify + re-review). **Not a defect** — this is the cost of a single review gate, and the plan accepts it. **Watchpoint:** the team manager should be ready to spawn a small parallel verifier fan-out on M3.verify rather than a sequential 8-task chain, if calendar pressure surfaces.

### Critical-path concern 4 — M4.document.6 is a trivial last task on the critical path

M4.document.6 (traceability summary) is the last task on the critical path and it's 0.75h expected. Scoping correctly notes "if pressed, fold into M4.document.1 as an appendix; saves the dispatch overhead but not meaningful hours." **Defensible as-is.** No finding.

**Critical-path verdict:** the path is real and the dependencies are tight. The single concern worth acting on is loosening M3.implement.4's blocked_by as already recommended. **No finding requiring revision.**

---

## 7. Lane-Discipline Audit

Plan agent_types in use: `executor`, `verifier`, `code-reviewer`, `documentor`. Confirming each agent's tasks stay inside its lane:

### `executor` — confirmed

All 23 executor tasks write to either `skills/cross-memory/*.md`, `agents/cross-memory.md`, `tooling/deploy-manifest.json` (M4.implement.3), or `.claude/settings.json` (M4.implement.4). All four targets are code/contract-class files. **Lane-clean.**

### `verifier` — confirmed

All 19 verifier tasks read fixture stores (`_tmp_M*_verify/`), read the implementation artifacts, and document expected behavior. None edit. **Lane-clean.**

### `code-reviewer` — confirmed

All 4 review tasks have `_Read-only — no edits._` in the Files column. **Lane-clean.**

### `documentor` — confirmed

All 6 documentor tasks write to README/ASSESSMENT/CLAUDE.md/cursor mirror/v1-shipped.md. All targets are documentation files. **Lane-clean** under scoping's Option B for M4.document.5 (diff-only handoff for `~/.claude/CLAUDE.md`). Under Option A (direct write to user-global), the documentor would be writing outside the project repo — that's not a lane violation per se but a permission/precedent concern; see Finding 6.

### Implicit cross-cutting work

Scoping §9 (Deliverables Checklist) lists `_tmp_M*_verify/` cleanup as cross-cutting, owned by the team manager. The team manager is not a plan-task agent_type but an orchestrator role. **Defensible** — cleanup is operational, not a contract task. The scoping correctly puts it in `Nice-to-have`.

**Lane-discipline audit verdict:** no crossings. All four agent types stay inside their lanes. **No finding.**

---

## 8. Deliverables Traceability (5-SC Sample)

The scoping/plan claim every SC-1..SC-18 has a builder task and a verifier task. Sampling 5:

### SC-1 (user-global preference surfaces in different project)

Built by: M3.implement.4 (filter), M3.implement.5 (block), M3.implement.6 (mirror dispatch). Verified by: M3.verify.1. **Confirmed in plan §"Verification Plan Summary" line 316.** Trace holds. Note: Finding 1 affects M3.implement.5's correctness — if the block lands in the wrong place, SC-1 fails despite the trace.

### SC-7 (explicit save warns on detected secret)

Built by: M2.implement.1. Verified by: M2.verify.2. **Confirmed in plan line 322.** Trace holds.

### SC-13 (agent write restricted to canonical store)

Built by: M4.implement.1. Verified by: M4.verify.4. **Confirmed in plan line 328.** Trace holds. Note: Finding 5's allowlist-glob check should be added to M4.verify.4 acceptance.

### SC-14 (existing per-project files untouched)

Built by: M3.implement.1. Verified by: M3.verify.6. **Confirmed in plan line 329.** Trace holds. Note: Finding 1 affects SC-14's verification — the snapshot semantics change once `MEMORY.md` is touched by the adapter.

### SC-16 (`[CROSS-MEMORY]` block format)

Built by: M3.implement.5. Verified by: M3.verify.7. **Confirmed in plan line 331.** Trace holds. Note: Finding 1 affects this SC's mechanism.

**Traceability sample verdict:** all 5 sampled SCs have intact builder→verifier traces. The **content** of three of them is impacted by Finding 1 but the **traces** are correct. **No finding on traceability.** The verification plan summary in plan §"Verification Plan Summary" is well-formed.

---

## 9. Risk-Register Check (11 risks)

Plan §"Risk Register" lists 11 risks. Walking each:

| # | Risk | Mitigation real? | Notes |
| :---: | :--- | :---: | :--- |
| 1 | Silent capture surprises the user | Yes | M2.implement.3 + Decision 4 (explicit cues only) + M2.verify.1. Real. |
| 2 | Mirror collision corrupts Claude Code state | Partial | M3.implement.1 + Decision 6 + M3.verify.6. Real, but Finding 1 surfaces a NEW collision risk on `MEMORY.md` itself that this row doesn't address. |
| 3 | Redaction false negatives | Yes | M1.implement.3 + audit re-runs denylist + M2.verify.4 + M4.verify.1. Real. |
| 4 | Harness misdetection | Yes | M3.implement.7 + Decision 5 precedence + M3.verify.2. Real. |
| 5 | Store growth | Yes | M4.implement.2 audit staleness + manual prune + OQ-5 indexing as v2. Real. |
| 6 | Contradiction supersede loses context | Yes | M2.implement.2 + M4.implement.2 + M2.verify.3 + M4.verify.3. Real. |
| 7 | --no-redact typo persists secret | Yes | M2.implement.1 + Decision 10 typed-phrase + M2.verify.4 (`<private>` invariant). Real. |
| 8 | Always-on tier blows prompt budget | Yes | M3.implement.5 + Decision 15 max_inject_chars + drop priority + M3.verify.7. Real. |
| 9 | Sidecar manifest divergence | Yes | M4.implement.2 audit + M3.implement.1 frontmatter + sidecar. Real. |
| 10 | Adapter writes to wrong project on slug ambiguity | **Stated, but Finding 2 demonstrates the slug rule itself is broken** | The risk row says "OS path resolution is the tie-break — same edge case as Claude Code." That is true on case-insensitive filesystems, but the risk is **not** the only slug-ambiguity failure mode. Finding 2 shows a deterministic mis-derivation that is not an OS tie-break case. The risk row is incomplete. |
| 11 | Cross-memory drifts into RAG | Yes | M1.implement.2 schema enum + M4.implement.2 audit category-curation + Decision 17. Real. |

**Risk-register verdict:** 10 of 11 risks have real mitigations. Risk 10 is **incomplete** — it acknowledges the FS-tie-break failure mode but not the prose-rule mis-derivation failure mode that Finding 2 describes. **Minor finding** (subsumed under Finding 2's resolution): once the architect fixes Decision 1, the planner adds a sentence to Risk 10's mitigation column referencing the on-disk-slug pre-flight check.

---

## 10. Deferrals Safety Check

Plan §"Out-of-Scope (deferred items)" lists 16 deferred items. Walking each for: (a) explicit deferral, (b) named source, (c) v1 task does NOT depend on the deferred item.

| # | Deferred item | (a) explicit? | (b) source named? | (c) v1 doesn't depend? |
| :---: | :--- | :---: | :---: | :---: |
| 1 | `/cross-memory init` codebase-fact distillation | Yes | ADD Decision 17 + Discovered-During-Revision §1 | Yes — v1 supports manual save with `--scope project --category project-config`. SC-18 verifies this manual path. |
| 2 | Per-bullet confidence scoring | Yes | ADD Decision 15 + Discovered-During-Revision §2 | Yes — Relevant Memories sub-section is omitted at v1 (not rendered as `(none)`). |
| 3 | Embedding/keyword indexing | Yes | OQ-5 + ADD §16 | Yes — recall and search use Glob+Grep at v1. |
| 4 | Aggregate MEMORY.md index | Yes | ADD Decision 2 | Yes — per-scope only at v1. |
| 5 | Boundary policy on memories referencing repo paths | Yes | OQ-6 lightly refined in ADD §16 | Yes — schema doesn't force reference handling either way at v1. |
| 6 | Team-shared scope identifier | Yes | Implicit non-decision in requirements §2 | Yes — three scopes only. |
| 7 | profile subcommand | Yes | Not in requirements §10 | Yes. |
| 8 | Preemptive compaction integration | Yes | Not in requirements at all | Yes. |
| 9 | OpenCode/Cline/Aider adapters beyond generic | Yes | Requirements §9 | Yes — generic fallback covers them. |
| 10 | `/cross-memory export` and `import` | Yes | Requirements §10 | Yes. |
| 11 | Custom `tooling/transform-cursor-cross-memory.{ps1,sh}` | Yes | ADD Decision 12 | **Conditional** — v1 doesn't depend on it UNLESS Finding 4's manifest mismatch surfaces a Cursor-specific need. |
| 12 | Heuristic NLP-based auto-propose detection | Yes | ADD Decision 4 | Yes — explicit cues only at v1. |
| 13 | `intent: apply` for audit | Yes | ADD §8 — deferred — not v1 | Yes — user resolves findings manually via standard write-path. |
| 14 | Inverse opt-out tag `never-on` | Yes | ADD §14 risk row | Yes. |
| 15 | Codebase indexing integration with code-intel | Yes | User decision — separate lanes | Yes. |

(Plan lists 16 rows total when including the codebase-indexing row; counting matches.)

**Deferrals verdict:** All listed items have explicit deferral, named source, and no v1 dependency. The only conditional case is item 11 (custom Cursor transform), which depends on Finding 4's resolution but does not require the transform to ship at v1 in any branch. **No finding on deferrals safety.**

---

## 11. Recommendations (priority order, actionable)

### P0 — must land before task-board population

**R1.** *Architect revises ADD §4 + §6 + §12(b)* to specify the exact filename and protocol for the `[CROSS-MEMORY]` always-on injection block on Claude Code. Recommendation: append to `MEMORY.md` inside sentinel markers (`<!-- cross-memory:start -->` / `<!-- cross-memory:end -->`); adapter rewrites only the marker block, never content outside. Bootstrap path: if `MEMORY.md` absent, adapter creates an empty one with markers. (Resolves Finding 1.)

**R2.** *Architect rewrites ADD Decision 1* to remove the contradictory "drop leading `-`" clause; the actual rule (and observed filesystem state) keeps leading dashes. Add a parenthetical: "verified against `~/.claude/projects/` on the architect's machine, 2026-05-08." (Resolves Finding 2.)

**R3.** *Architect picks one option for `audit-reports/`* — either add to Decision 13 lazy-provisioning AND specify retention (Option A), or remove the line from §8 brief template AND declare audit chat-only (Option B). Recommendation: Option B. (Resolves Finding 3.)

### P1 — should land before task-board population

**R4.** *Architect updates ADD §11* to reflect the actual `tooling/deploy-manifest.json` cursor-target globs (cursor `skills.include` is `**/*` with `kickoff/**` excluded; cursor agents has `transform: true`). (Resolves Finding 4.)

**R5.** *Architect rewrites ADD §8* to replace "verbatim" with "structural pattern reused; allowlist globs are cross-memory-specific." Plan task M4.implement.1 acceptance picks up the new wording. M4.verify.4 acceptance gains a glob-allowlist check. (Resolves Finding 5.)

**R6.** *Project-scoper rewrites G8* from `Edge case` to `Contradiction` and adds a mandatory pre-flight (executor runs `ls ~/.claude/projects/` before M3.implement.1 begins). G3 already has the right resolution; planner pulls G3's wording into M3.verify.2's task description verbatim. (Subsumed by Finding 2 + Finding 4.)

**R7.** *Project-scoper revises estimates* for M3.implement.5 (+0.5h) and M3.verify.6 (+0.25h) once Finding 1's resolution lands. Project total moves to ~52.75h expected — within the ±18h confidence band, no headline impact. (From Estimate Sanity Check.)

**R8.** *Project-scoper upgrades A13* (lane-enforcement verbatim assumption) from `Low` to `Medium` impact. (Resolves Finding 5's residual.)

**R9.** *Planner rewrites M4.document.5* per scoping OQ-B Option B: documentor produces a single-row diff in the task handoff; user applies the edit manually. Plan and scoping recommendation now agree. (Resolves Finding 6.)

### P2 — nice-to-have, can land alongside the P0/P1 revisions

**R10.** *Planner loosens M3.implement.4's `blocked_by`* to `[M3.implement.1]` only; treat `.2`/`.3` as soft. Saves ~0.5h calendar at parallel-3. (From Critical-Path Scrutiny.)

**R11.** *Planner rewrites M3.verify.2 task description* to use scoping G3's resolution language verbatim ("the documented behavior is the verification artifact; no second harness session is spawned"). Avoids over-interpretation risk. (From A3 pressure-test.)

**R12.** *Planner adds a sentence to Risk 10's mitigation column* (Risk Register) referencing the on-disk-slug pre-flight check, after Finding 2 resolves. (From Risk-Register Check.)

---

## Open questions (low confidence; for the team manager to consider, not for forced resolution)

- Whether the `mirrored_from` frontmatter field should also include a checksum of the canonical content, so the audit can detect "user edited the mirror" without comparing full bodies. The ADD allows the audit to flag this state but doesn't specify the detection mechanism (just "content differs"). **Confidence: low** — the audit could full-body-compare at acceptable cost for v1 store sizes; checksum is a v1.x optimization.
- Whether `~/.cross-memory/config.yaml` should be excluded from any future scoping/listing operations. The plan and ADD don't say. **Confidence: low** — likely covered by `recall` and `search` only matching `*.md` files, but this is implicit.
- Whether the cross-memory agent should refuse-and-halt when invoked with `intent: apply` (deferred, not v1) versus emit a "not implemented at v1" message. **Confidence: low** — defaults to refuse-and-halt per the lane-boundary pattern, but the plan doesn't specify.

These are noted for transparency and would not change the verdict.

---

## Verdict justification

The plan and scoping document are well-structured, internally consistent at the task-decomposition level, and the scoping work (16 assumptions, 5 OQs, 10 gaps) is unusually thorough. I escalated to adversarial mode after Findings 1 and 2 surfaced; the additional findings (3-6) emerged from cross-document consistency checks rather than further deep-dives.

The primary blockers are upstream of the plan and scoping: ADD-level mechanism gaps (Findings 1, 2, 3) and ADD-level wording defects (Findings 4, 5). The scoping doc correctly identified two of these (G8/OQ-C maps to Finding 2; G10/OQ-D maps to Finding 3) but understated their severity — both should be ADD revisions, not "open questions for the user." The plan itself has one defect (Finding 6, M4.document.5 over-commits compared to scoping's recommendation) and one critical-path looseness recommendation (R10, soft dependency).

**Path to Approve:** architect resolves R1, R2, R3, R4, R5; scoper applies R6, R7, R8; planner applies R9, R10, R11, R12. Re-review estimated 1.5h. Total upstream rework: ~3-5h architect + ~1h scoper + ~0.5h planner + 1.5h critic. After that round, the verdict is **Approve** with high confidence.

**Self-audit recalibrations:** I downgraded one initial finding (M2.verify.4's cosmetic-ellipsis check is "tested in render, not on disk") from MAJOR to MINOR after re-reading ADD Decision 14's last paragraph, which is explicit about disk-vs-render distinction; the plan task acceptance does name it. I removed the candidate finding entirely after deciding it was a stylistic preference. I did NOT downgrade any data-loss / correctness / security finding (per self-audit rule).
