<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Agent Dispatch Brief Contract

**Purpose:** Canonical contract for the brief format the `/ops` team manager produces when dispatching agents.
**Producer:** The team manager (`/ops` orchestrator).
**Consumers:** Every agent that receives a dispatch brief — `executor`, `verifier`, `debugger`, `git-master`, `project-scoper`, and any future agent onboarded to the fleet.

---

## Purpose and Audience

This file defines the exact format every dispatch brief must follow, so any agent that receives one parses it the same way.

**Who reads this:**

- **Runtime agents** (`executor`, `verifier`, `debugger`, `git-master`, `project-scoper`, and any future fleet member) — consulted when encountering a malformed brief or an ambiguous precedence question.
- **The team manager** composing briefs — ensures every brief it produces conforms to the grammar defined here.
- **Agent authors** writing or revising agent contracts — use the vocabulary and section definitions here when declaring how their agent applies the universal grammar in its own `## Brief Format` subsection.

---

## Required Sections

Every valid brief must contain the four sections below. A brief missing any of these is malformed. See the missing-section behavior table in the "Missing-Section Behavior" section below for the correct response.

### `## Task`

**Shape:** One or two sentences, imperative mood.

**Content:** The single unit of work the agent must complete. Must match the task's `subject` field in the state file. No multi-task briefs — one brief, one task.

**Example:**

```
## Task
Implement the `## Brief Format` subsection in `agents/executor.md`.
```

### `## Scope`

**Shape:** Bulleted list of file paths or module globs.

**Content:** Every path or pattern the agent is authorized to read and write. Paths explicitly excluded should appear as a separate sub-list. Each agent's `## Brief Format` subsection further constrains this list against its file-class allowlist — the Scope section narrows what the team manager authorizes; the agent's allowlist narrows what the agent permits itself.

**Example:**

```
## Scope
- `agents/executor.md` (edit — add `## Brief Format` subsection)
- `skills/ops/brief-contract.md` (read only — reference)
```

### `## Acceptance Criteria`

**Shape:** Numbered list. Each item is a testable assertion (pass/fail, not subjective).

**Content:** Copied verbatim (word-for-word) from the plan document or the ADD. The agent uses this list as the contractual bar for declaring success. The verifier uses this list as the primary source for its verification pass. No paraphrasing — verbatim only.

**Example:**

```
## Acceptance Criteria
1. `agents/executor.md` contains a `## Brief Format` subsection between the pipeline diagram and the Workflow section.
2. The subsection names all four required brief sections.
3. The subsection states the missing-`## Acceptance Criteria` behavior as "refuse — do not infer from other sections."
```

### `## Constraints`

**Shape:** Prose or bulleted list. Opens with a reference to the Shared Brief Constraints block.

**Content:** Task-specific constraints that are additive to the eight shared rules. The `## Constraints` section in every brief MUST reference the Shared Brief Constraints block defined at `skills/ops/SKILL.md` (anchor `#shared-brief-constraints`). Do not duplicate those eight bullets here — reference them. Task-specific constraints follow: scope boundaries (what NOT to touch), codebase conventions, active file conflicts, and any restriction that applies to this task only. The shared rules include a standing secret-handling mandate: agents must never hardcode secrets, credentials, tokens, or keys, and must never write a secret value into any file, log, or report they produce.

**Example:**

```
## Constraints
[Shared Brief Constraints — see skills/ops/SKILL.md#shared-brief-constraints]
- Do not modify `skills/ops/SKILL.md` — that is a separate task.
- Match the heading level and spacing conventions of the existing executor.md body.
```

---

## Optional Sections

The sections below are not required in every brief. Their absence is not an error. Each section states what consumers do when it is missing.

### `## Context`

**When present:** When prior agent outputs, plan decisions, or upstream handoff content are relevant to this dispatch.

**Content:** Summaries of prior work, relevant file paths, line references, and decisions made by upstream agents. This section informs the consumer's understanding of the current state but never overrides `## Acceptance Criteria`.

**When absent:** Proceed without it. Context is often absent for first-stage dispatches or for tasks with no upstream dependency.

### `## Mode`

**When present:** When the orchestrator sets an explicit execution mode, or when the task's behavior diverges significantly between modes.

**Values:** `interactive | autonomous | supervised | tdd`

**`tdd`:** When present, the executor follows the RED-GREEN-REFACTOR discipline defined in `skills/ops/tdd-discipline.md`. No production code may be written before an observed-failing test exists for that behavior. The verifier adds a commit-ordering discipline check when this value is present. Propagated by the team manager when `--tdd` is set on the `/ops` invocation.

**When absent:** Default to `autonomous`. See the "Mode Handling" section below for the full specification.

### `## Handoff Artifacts`

**When present:** When a prior agent produced a handoff file that this agent must read before beginning.

**Content:** One or more paths to handoff documents under `.agents/handoffs/<run_id>/handoff-*.md`. See `skills/ops/handoffs.md` for the full handoff format and naming convention.

**When absent:** Proceed without it. Handoff artifacts are often absent for first-stage dispatches.

### `## Code Intelligence Context`

**When present:** When the Phase 2.5b code-intel dispatch fired and produced an impact-analysis report relevant to this task.

**Content:** The path to the code-intel report (`.code-intel/runs/<run-id>/<query>-<symbol>.md`) and a brief summary of its findings. See `agents/code-intel.md` for the full JSON-fenced brief schema used to produce these reports.

**When absent:** Proceed without it. Phase 2.5b is advisory — its absence is not a blocker.

### `## Corpus Search Context`

**When present:** When the Phase 2.5c corpus-search dispatch fired and produced an evidence report relevant to this task.

**Content:** The path to the corpus-search report (`.corpus-search/runs/<run-id>/<query_type>-<slug>.md`) and a brief summary of its findings. See `agents/corpus-search.md` for the full JSON-fenced brief schema used to produce these reports.

**When absent:** Proceed without it. Phase 2.5c is advisory — its absence is not a blocker.

### `## Project Knowledge`

**When present:** When the orchestrator predicate (the yes/no condition that decides this) fired AND the selector (documented in `skills/cross-memory/brief-injector.md`) returned non-empty bytes.

**Content:** Selector output rendered under the `## Project Knowledge` heading — the `User Profile:` and `Project Knowledge:` sub-sections defined in `skills/cross-memory/injection-block.md`. These sub-sections carry the user's standing durable rules from the canonical store (the single official source).

**When absent:** Predicate was skipped OR the selector returned empty bytes — proceed without it. No escalation required. This section is often absent by design; predicate-gated injection means many dispatches will omit it.

**Precedence:** This section sits at **tier 1.5** — below `## Acceptance Criteria` (tier 1) but above `## Scope` (tier 2), `## Constraints` (tier 3), and `## Context` / `## Code Intelligence Context` / `## Corpus Search Context` (tier 4). User-global durable rules carried here are NOT overridable by a per-task `## Constraints` bullet. See the Section Precedence section below for the full ordering and the mandatory escalation rule for security/correctness/safety contradictions.

---

## Section Precedence

When the brief contains an internal contradiction (for example, `## Scope` lists different files than `## Acceptance Criteria` references), apply this precedence order:

1. **`## Acceptance Criteria`** is the contractual bar. It defines what done means. No other section overrides it.
1.5. **`## Project Knowledge`** carries the user's standing durable rules from the canonical store. These rules sit above per-task scope and constraints; they are not overridable by a `## Constraints` bullet in the same brief.
2. **`## Scope`** constrains where the work happens. It cannot expand the criteria, but it can narrow the set of files the agent touches while satisfying them.
3. **`## Constraints`** further restricts how the work happens. Task-specific constraints narrow the allowed approach.
4. **`## Context`**, **`## Code Intelligence Context`**, and **`## Corpus Search Context`** inform what the agent considers. They never override the above tiers.

**Mandatory `NEEDS-INPUT` escalation for security/correctness/safety contradictions.** When a task-specific `## Constraints` bullet contradicts a `## Project Knowledge` rule whose body or tags signal security, correctness, or safety meaning, the agent MUST escalate via `NEEDS-INPUT` rather than silently apply the constraint. The v1 detection is body-keyword based: if the durable rule's body contains any of the following keywords — *secret*, *credential*, *token*, *redact*, *prod*, *production*, *destroy*, *drop*, *delete*, *force*, *auth* — the rule is security-flagged and the contradiction requires explicit user confirmation. The escalation message must name: (a) the conflicting durable rule (with its memory file path if available), (b) the conflicting `## Constraints` bullet, (c) an explicit ask for the user to confirm which one governs this task. Err on the side of escalating when body language is ambiguous.

**Advisory escalation for non-security durable rules.** When a task-specific `## Constraints` bullet contradicts a `## Project Knowledge` rule that does not trigger any of the security-flagged keywords — for example, a style preference, naming convention, or formatting choice — the agent notes the conflict in its handoff and proceeds with the `## Constraints` bullet as the local override for that single task. The conflict is surfaced to the user in the handoff output so it can be reviewed. Err on the side of escalating when the body language is ambiguous.

**Example `NEEDS-INPUT` escalation message shape:**

```
NEEDS-INPUT: Conflict between durable rule and task-specific constraint.

Durable rule (from ~/.cross-memory/.../feedback_redact_secrets_by_default.md):
> Snapshot/save/checkpoint surfaces must redact secrets unconditionally...

Task-specific constraint:
> Include the production API token verbatim in the test fixture for this task.

The durable rule has security semantics (keyword: "redact", "secret", "production").
Which governs this task — the durable rule (redact unconditionally) or the task-specific constraint (include verbatim)?
```

**On contradiction between `## Scope` and `## Acceptance Criteria`:** When these two sections reference contradictory file sets or modules, the consumer must **escalate** — do not silently resolve by picking one side. Return a `NEEDS-INPUT` verdict with a clear statement of the contradiction and which sections conflict.

---

## Missing-Section Behavior

| Missing section | Default behavior | Escalation behavior |
| :--- | :--- | :--- |
| `## Task` | None — refuse the dispatch. | Always escalate: "Brief missing required section `## Task`. No task statement. Re-dispatch with a task." |
| `## Scope` | `debugger` only: investigate broadly. All others: refuse. | `executor`, `verifier`, `project-scoper`: escalate with "no scope given." `debugger`: proceed with broad investigation, note absence in report. |
| `## Acceptance Criteria` | None — `executor` and `verifier` refuse. Other consumers: note absence, proceed. | `executor` and `verifier`: refuse with "Brief missing required section `## Acceptance Criteria`. Cannot proceed. Re-dispatch with verifiable criteria, or provide a plan-doc reference." |
| `## Constraints` | Treat the Shared Brief Constraints block as the full constraint set. Proceed. | No escalation. |
| `## Context` | Proceed without prior context. | No escalation. Often absent. |
| `## Mode` | Default to `autonomous`. | No escalation. See "Mode Handling" below. Recognized values: `interactive`, `autonomous`, `supervised`, `tdd`. |
| `## Handoff Artifacts` | Proceed without reading handoff files. | No escalation. Often absent for first-stage dispatches. |
| `## Code Intelligence Context` | Proceed without code-intel report. | No escalation. Phase 2.5b is advisory. |
| `## Corpus Search Context` | Proceed without corpus-search report. | No escalation. Phase 2.5c is advisory. |
| `## Project Knowledge` | Proceed without it. | No escalation. Often absent; predicate-gated injection means many dispatches will omit this section by design. |

**Multiple missing required sections:** If two or more required sections (`## Task`, `## Scope`, `## Acceptance Criteria`, `## Constraints`) are missing, refuse the dispatch and name every missing section in the refusal message.

---

## Mode Handling

The `## Mode` section carries one of four values: `interactive`, `autonomous`, `supervised`, or `tdd`.

**When `## Mode` is absent:** default to `autonomous`. This is the correct behavior for all trivial dispatches, ralph-loop dispatches, and any dispatch where the orchestrator did not explicitly set a mode.

**`git-master` is the canonical mode-branching consumer.** The `git-master` agent reads `## Mode` from the brief and forks its uncommitted-change handling on it:

- `autonomous` — stash with an ISO-timestamped descriptive label, emit the stash ref in the response. Do not prompt the user.
- `interactive` — ask the user to choose: stash, WIP commit, or include in new branch.
- `supervised` — equivalent to `interactive` for git-master's decision tree unless the agent's `## Brief Format` subsection specifies otherwise.

The decision tree forks only on these explicit mode values — never on a runtime-undetectable inferred mode.

**`tdd` is a discipline overlay, not a git-master fork trigger.** When `## Mode: tdd` is set, git-master treats it as `autonomous` for uncommitted-change decisions — `tdd` is not a recognized fork-triggering value, so the autonomous fallback applies. The `tdd` value primarily affects the executor (RED-GREEN-REFACTOR discipline, per `skills/ops/tdd-discipline.md`) and the verifier (commit-ordering check). Git-master applies no special behavior for `tdd` beyond the autonomous stash default.

**All other consuming agents** (`executor`, `verifier`, `debugger`, `project-scoper`) ignore the `## Mode` field unless they explicitly declare mode-branching behavior in their own `## Brief Format` subsection. Absence of a `## Brief Format` mode declaration means: read the field, ignore it, proceed as `autonomous`.

**Unrecognized `## Mode` value:** An unrecognized `## Mode` value is treated as absent — default to `autonomous` and note the unrecognized value in the response.

---

## File-Class Scope Conventions

The `## Scope` section lists paths. Each path belongs to a file class. The classes below form the fixed vocabulary this contract recognizes. Each agent declares its allowlist using these class names in its own `## Brief Format` subsection. The contract defines the vocabulary; the agent owns the policy.

| File class | Definition | Glob examples |
| :--- | :--- | :--- |
| `source` | Runtime executable code — the code the product runs. | `src/**/*.{py,ts,go,rs}`, `lib/**`, package source files |
| `test` | Test files — unit, integration, end-to-end. | `tests/**`, `**/*test*.{py,ts}`, `**/*.spec.*` |
| `docs` | Human-facing documentation not under `docs/plan/`. | `README.md` at any level, `docs/**/*.md` (excluding `docs/plan/*.md`) |
| `config` | Configuration files — build, packaging, environment. | `package.json`, `pyproject.toml`, `tsconfig.json`, `.gitignore`, `.gitattributes`, lockfiles |
| `agent-contract` | Runtime contracts that define agent or skill behavior. | `agents/*.md` (except `agents/README.md`), `skills/**/*.md` (except `README.md` at any level) |
| `plan-doc` | Planning artifacts — plans, ADDs, scoping docs, assessments. | `docs/plan/*.md`, `docs/*-assessment.md`, `docs/*-add.md` |
| `design-doc` | Architecture Decision Documents produced by the architect via the brainstorm gate. In scope for the `architect` agent only. | `docs/plan/*-design.md` |

**`agent-contract` routing rules:**

- Edits to `agent-contract` paths MUST route through the `executor`. No other agent class applies Edit or Write to these files in a planned dispatch.
- The `project-scoper` MUST refuse Edit/Write on `agent-contract` paths. When `## Scope` includes an `agent-contract` path, the scoper produces a revision plan and hands off to the executor — it does not apply the change itself.
- This rule is enforced at the agent level (declared in each agent's `## Brief Format` allowlist), not at the team-manager level. The team manager may include `agent-contract` paths in a scoper's `## Scope` in error; the scoper's own allowlist is the enforcement point.

---

## Examples

### Example 1 — Happy-path executor brief

```
## Task
Add the `## Brief Format` subsection to `agents/executor.md`.

## Context
The contract file at `skills/ops/brief-contract.md` is already in place. This task
retrofits the executor agent body with the subsection that applies the contract.

## Scope
- `agents/executor.md` (edit — insert `## Brief Format` subsection near line 56)
- `skills/ops/brief-contract.md` (read only — reference for grammar)

## Acceptance Criteria
1. `agents/executor.md` contains a `## Brief Format` standalone section between the
   pipeline diagram and the Workflow section.
2. The subsection names `## Task`, `## Scope`, `## Acceptance Criteria`, and
   `## Constraints` as required sections.
3. The subsection states: missing `## Acceptance Criteria` → refuse, do not infer.
4. The subsection references `~/.claude/skills/ops/brief-contract.md` by path.
5. No other section of `agents/executor.md` is modified.

## Mode
autonomous

## Constraints
[Shared Brief Constraints — see skills/ops/SKILL.md#shared-brief-constraints]
- Do not modify any file other than `agents/executor.md`.
- Match the heading depth and blank-line conventions of the existing executor body.
- The new subsection must be 15-25 lines.
```

The executor reads each section in order: validates `## Task` (present, well-formed), reads `## Scope` (two files — one edit, one read-only), reads `## Acceptance Criteria` (five testable items), reads `## Mode` (autonomous — no branching needed), reads `## Constraints` (shared rules plus two task-specific lines). All required sections present, no contradictions. The executor proceeds without escalation.

### Example 2 — Malformed brief refusal (verifier)

```
## Task
Verify the `## Brief Format` subsection added to `agents/executor.md`.

## Scope
- `agents/executor.md` (read)
- `skills/ops/brief-contract.md` (read)

## Constraints
[Shared Brief Constraints — see skills/ops/SKILL.md#shared-brief-constraints]
- Read-only pass. The verifier does not edit source files.
```

The verifier reads `## Task` (present), `## Scope` (present), `## Constraints` (present), then checks for `## Acceptance Criteria` — absent. The verifier consults the missing-section behavior table: row `## Acceptance Criteria`, consumer class verifier, behavior "refuse." The verifier returns:

```
VERDICT: NEEDS-INPUT

Brief missing required section `## Acceptance Criteria`. The verifier cannot
determine what "done" means without a verifiable criteria list. Re-dispatch
with an explicit numbered list of testable assertions, or provide a plan-doc
reference from which the team manager can extract the criteria.
```

The verifier does not guess, does not Glob for a plan doc, and does not infer criteria from `## Scope`. It refuses and returns control to the team manager.

### Example 3 — cross-memory `distill` intent brief

When the `/cross-memory reflect` subcommand needs to surface candidate memories, it composes a brief like the following for the cross-memory agent:

```
## Task
Distill candidate memories from the provided source set against the four reference sets
and the pattern taxonomy. Return a deterministic, filtered candidate list.

## Scope
- ~/.cross-memory/** (read — for Reference Sets A and B)
- ~/.claude/projects/<active-project-slug>/memory/MEMORY.md (read — confirm mirror state only)
- ~/.cross-memory/projects/<active-project-slug>/reflect_declined.md (read — Reference Set C)
- ~/.claude/CLAUDE.md (read — Reference Set D, "What NOT to save in memory" section)
- <source-set paths listed under sources: below> (read)
- _tmp_* (write — filter computation staging only)

## Acceptance Criteria
1. A fenced markdown block containing exactly one `## Cross-Memory Distill Candidates — <UTC timestamp>`
   header and a per-candidate table with columns: id, type, category, scope, proposed-name,
   body-preview, source-evidence, flags.
2. Candidates listed in deterministic order: sorted by category lexicographically, then by
   proposed-name lexicographically within each category.
3. Every candidate carries a stable id (e.g., c1, c2, ... within a single run — IDs do not
   persist across runs).
4. Every candidate is one of the four taxonomy categories — no project-goal candidates.
5. No candidate survives whose slug/tag/body-Jaccard against any of the four reference sets
   exceeds the configured thresholds.

## Mode
autonomous

## Constraints
[Shared Brief Constraints — see skills/ops/SKILL.md#shared-brief-constraints]
- intent: distill
- active_project_slug: <active-project-slug>
- active_harness: claude-code
- sources:
    source_1_transcripts: []
    source_3_git_history: true
    source_3_working_tree: true
    source_4_plan_docs_glob: docs/plan/**
    source_4_handoffs_glob: docs/cross-memory/handoff*
    source_4_dispatch_log_glob: docs/ops-dispatch-log*
    source_5_explicit_paths: []
- thresholds:
    slug_overlap: 0.85
    tag_overlap: 0.8
    body_token_jaccard: 0.7
- reference_sets:
    set_a_canonical_store: ~/.cross-memory/{user-global,projects/<active-project-slug>,harnesses/claude-code}/
    set_b_archive: ~/.cross-memory/archive/
    set_c_declined: ~/.cross-memory/projects/<active-project-slug>/reflect_declined.md
    set_d_excluded_rule: ~/.claude/CLAUDE.md ("What NOT to save in memory" section — LLM-prompt exclusion corpus)
- taxonomy:
    - architectural-decisions
    - conventions-implicit-in-code
    - workflow-patterns-from-successful-runs
    - user-preferences-from-feedback-patterns
- size_budget: 8000
```

**Read-only-scope note:** The `## Scope` section above lists only read paths (`~/.cross-memory/**` and the source inputs) plus `_tmp_*` for filter computation staging. There are no new write paths. The agent does not write `reflect_declined.md` — the skill does, after the user types `decline <id>` in the interactive loop.

The distill intent's filter consumes Sets A, B, and C deterministically (always produces the same result for the same input) against the three threshold signals (`slug_overlap: 0.85`, `tag_overlap: 0.8`, `body_token_jaccard: 0.7`); Set D is applied at the LLM-prompt layer during raw-candidate generation and is not part of the deterministic filter. The agent receives all four reference sets via the `reference_sets:` constraint block and the three threshold values via the `thresholds:` block.

---

## Versioning and Change Protocol

This file is an `agent-contract` per the file-class vocabulary in the "File-Class Scope Conventions" section above. It is a runtime document, not planning documentation.

- Any change to this contract routes through the `executor`. The project-scoper does not apply changes to this file directly.
- Every change to this contract requires a verifier pass per the standing constraint in `feedback_verify_agent_contracts.md`.
- Changes that add a new required section must be accompanied by updates to `skills/ops/SKILL.md` (the brief-composition section) and to every consumer agent's `## Brief Format` subsection in the same dispatch. A new required section that is not propagated to consumers breaks backward compatibility and must be treated as a breaking change.
- Breaking changes bump the affected section's identifier and add a migration note at the end of this section. Example: if §6.4 is revised in a backward-incompatible way, the new revision is noted as `§6.4 revision — <date> — <one-line summary of the breaking change>`.

---

## Cross-References

### Where this contract is referenced

- `skills/ops/SKILL.md` — Agent Briefing Format section (the producer-side reference that points here for the full contract grammar).
- `agents/executor.md` — `## Brief Format` subsection.
- `agents/verifier.md` — `## Brief Format` subsection.
- `agents/debugger.md` — `## Brief Format` subsection.
- `agents/git-master.md` — `## Brief Format` subsection.
- `agents/project-scoper.md` — `## Brief Format` subsection.

### Related documents

- `skills/ops/handoffs.md` — full handoff document format and naming convention, referenced from the `## Handoff Artifacts` optional section above.
- `skills/ops/state-schema.md` — state file format that `/ops` uses for run tracking; the `run_id` field used in handoff paths originates here.
- `agents/code-intel.md` — JSON-fenced brief schema with JSON Schema validation (Phase 2.5b). Orchestrator-path schema and validation rules live in `agents/_shared/code-intel-orchestrator-brief.md`; the agent `## Brief Format` section is a pointer plus labeled-prose fallback.
- `agents/corpus-search.md` — second JSON-fenced brief agent with JSON Schema validation (Phase 2.5c). Orchestrator-path schema lives in `agents/_shared/corpus-search-orchestrator-brief.md`; same strict `additionalProperties: false` pattern. Together with `code-intel`, these two agents are the JSON-schema precedents; the prose-brief fleet (executor, verifier, debugger, etc.) consumes the universal contract defined in this file.
