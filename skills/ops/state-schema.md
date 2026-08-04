<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# State File Schema

## Cursor: dual-layer board

When the active harness is **Cursor**, ops uses a JSON board file plus `TodoWrite` for IDE display. **Only the board file is authoritative** for `resume`, timing, dependencies, and handoffs. Every status mutation (a change written to the state file) must follow the Write → Read verify → TodoWrite ritual in `phase-dispatch.md` § **Cursor: state file sync (mandatory)**. Updating `TodoWrite` without writing the board file in the same turn is a protocol violation.

## Directory Conventions

- `.ops-state/` holds one board file per run (supports concurrent/sequential runs without collision)
- `.ops-state/` should be in `.gitignore` (ephemeral (short-lived; this run only) runtime state, not project content) — "should be ignored" means covered by an ignore rule as verified by `git check-ignore -q .ops-state/`, not string-match against `.gitignore` lines
- Cleaned up on successful completion (same lifecycle as ralph-loop's `.ralph-state/`)

## State File Structure

The state file JSON structure:

```json
{
  "run_id": "auth-middleware-2026-04-14",
  "state_dir": ".ops-state/",
  "plan_file": "docs/plan/auth-middleware-plan.md",
  "tasks": [
    {
      "id": "task-0",
      "subject": "Plan auth middleware implementation",
      "description": "Break down auth feature into subtasks",
      "description_ref": "docs/plan/auth-middleware-plan.md#task-plan-auth-middleware",
      "status": "completed",
      "agent_type": "planner",
      "stage": "plan",
      "priority": 1,
      "estimated_minutes": 5,
      "estimate_source": "ops",
      "blocked_by": [],
      "started_at": "2026-04-14T10:00:00Z",
      "completed_at": "2026-04-14T10:03:00Z",
      "duration_seconds": 180,
      "model_used": "opus",
      "attempts": 1,
      "adaptation": null,
      "triage_confidence": null,
      "handoff_file": null,
      "_internal": false
    },
    {
      "id": "task-1",
      "subject": "Implement auth middleware",
      "description": "Auth middleware + tests in src/auth/",
      "description_ref": "docs/plan/auth-middleware-plan.md#task-implement-auth-middleware",
      "status": "pending",
      "agent_type": "executor",
      "stage": "implement",
      "priority": 1,
      "estimated_minutes": 15,
      "estimate_source": "ops",
      "blocked_by": ["task-0"],
      "started_at": null,
      "completed_at": null,
      "duration_seconds": null,
      "model_used": null,
      "attempts": 0,
      "adaptation": null,
      "triage_confidence": null,
      "handoff_file": null,
      "_internal": false
    }
  ],
  "pending_nested_skill": null,
  "pending_fable_confirm": null,
  "memory_inject_banner_emitted": false
}
```

### pending_nested_skill

Root-level field tracking whether the team manager is currently inside a nested-skill invocation.

**Type:** `null` or object.

**When null (or absent):** No nested skill is pending. This is the steady-state value.

**When set (object):**

```json
{
  "skill": "/deslop",
  "invoked_at": "2026-04-19T14:22:03Z",
  "resume_phase": "phase-3-deslop-stage",
  "resume_notes": "integrations.md steps 5-6: if deslop made changes, re-dispatch verifier; if no changes, proceed to code-review stage"
}
```

Field meanings:

- `skill` — the nested skill invoked (e.g., `"/deslop"`). Matches the skill identifier.
- `invoked_at` — ISO-8601 UTC timestamp of invocation. Enables future stale-marker detection.
- `resume_phase` — short identifier of where the team manager must resume. Allowed values (open set): `"phase-3-dispatch"`, `"phase-3-deslop-stage"`, `"phase-3-save-followup"`, `"phase-4-cleanup-sweep"` (9a's relocation sweep invoking `/cross-memory save`; see `phase-completion.md`'s Phase 4 completion section, step 9a).
- `resume_notes` — one-line human-readable instruction the team manager re-reads when clearing the marker.

**Lifecycle:** `null` → set on write-before → consumed and acted upon on clear-after → `null`.

**Backward compatibility:** The `pending_nested_skill` field is additive (optional; older files simply omit it). State files written before this field was introduced will not have it. The team manager treats absence as equivalent to `null`. No migration is required.

### worktrees_created

Root-level field tracking worktrees this run created, used for provenance (origin — which run created it)-safe cleanup in Phase 4.

**Type:** `array` (default `[]` when absent).

**Element shape:**

```json
{
  "path": "/absolute/path/to/worktree",
  "added_at": "2026-04-14T10:05:00Z"
}
```

Field meanings:

- `path` — absolute path to the worktree directory, as returned by `git worktree add`. Used for exact-match provenance verification during cleanup.
- `added_at` — ISO-8601 UTC timestamp recorded immediately after `git worktree add` succeeds. Used to confirm the worktree falls within this run's time window.

**Write lifecycle:** The team manager appends an entry to `worktrees_created` each time a worktree is created. This happens in Phase 1.5 when `--worktree` is set and git-master creates worktrees, or at any other point during the run where git-master creates additional worktrees on the team manager's behalf. The entry is written immediately after the git-master confirms the worktree was created.

**Backward compatibility:** Additive field. State files written before this field was introduced will not have it; the team manager treats absence as `[]`. No migration is required.

---

### Cleanup record file

A **file distinct from the board**, not a root-level field on it. It is written by Phase 4 step 9a and deleted by step 10 (see `phase-completion.md`'s Phase 4 completion section, steps 9a, 9b, and 10), and it exists for exactly the span between them: the board, the save file, and the handoffs are all deleted at step 9b, but two things 9a produces, its own relocation record and a copy of the board's `worktrees_created` array, still have readers after that delete. This file is what carries them across it.

**Path:** `.ops-state/<run-id>-cleanup.json`, alongside the board and save file.

**Shape:**

```json
{
  "run_id": "auth-middleware-2026-04-14",
  "relocations": [
    {"content": "Non-obvious decision: switched retry backoff from linear to exponential", "destination": "docs/plan/auth-middleware-plan.md"}
  ],
  "worktrees_created": [
    {"path": "/absolute/path/to/worktree", "added_at": "2026-04-14T10:05:00Z"}
  ]
}
```

Field meanings:

- `run_id`: confirmed before any `rm` targeting this file, checked against the `<run-id>` segment in the file's own path and the run this Phase 4 execution is completing. The board is already deleted by delete time, so this is an internal-consistency check between the path, the field, and the run being completed, not the re-read of a still-live board every other `<run-id>`-bearing path in Phase 4 cleanup performs.
- `relocations`: one entry per item 9a's sweep relocated, each naming the `content` and the `destination` it went to. An empty array means the sweep found nothing durable, a normal outcome, not an error.
- `worktrees_created`: copied verbatim from the board's own `worktrees_created` field (above) at the moment 9a writes this file, before 9b deletes the board.

**Lifecycle:** written once by 9a, before 9b's deletes; read by 9c's Cleanup block render and by the worktree-cleanup-by-provenance procedure (`completion-options.md`); deleted by step 10, after both of those readers are finished with it, with the delete verified and retried once on failure. Its delete happening later than the board's is a sequencing consequence of step 10 needing the file, not a retention exception: it is not on the board's never-delete list, and the run does not report completion while it is still on disk.

**Backward compatibility:** New file; a run using an older version of this skill never wrote one, and there is nothing to migrate. Its absence during the stale-artifact sweep at Phase 1 (see `handoffs.md`) is the expected outcome once step 10 has already deleted it for a completed run.

---

### memory_inject_banner_emitted

Root-level field tracking whether the Cursor first-time memory-injection awareness banner has been emitted in the current session.

**Type:** `boolean` (default `false` when absent).

**When `false` (or absent):** The banner has not yet fired this session. The first dispatch that fires injection under the Cursor harness will emit the banner and set this field to `true`.

**When `true`:** The banner has already fired this session. Suppress subsequent banner emissions even if more injection-eligible dispatches follow.

**Behavior:** The team manager writes `memory_inject_banner_emitted: true` immediately after emitting the banner, before the dispatch that triggered it proceeds. Under Claude Code, this field remains `false` (the banner is suppressed because there is no trust-model inversion to disclose — the top-level turn already sees `[CROSS-MEMORY]`).

**Backward compatibility:** Additive field. State files written before this field was introduced will not have it; the team manager treats absence as `false`. No migration is required.

### adaptations

Root-level array recording every adaptation the team manager makes during a run — strategy switches, mid-run plan adjustments, reflection-beat notes, and (when present) promotion events. This is the run-level backing store for the dashboard's Adaptations section and the Phase 4 adaptation summary.

This run-level `adaptations` array is distinct from the existing per-task `adaptation` field (singular) on each task object (`state-schema.md:42`). The plural `adaptations` array is the **run-level rollup**; the singular per-task `adaptation` field is unchanged by this work.

**Type:** `array` (default `[]` when absent).

**Element shape:**

```json
{
  "type": "reflection",
  "at": "2026-06-09T14:22:03Z",
  "stage": "implement",
  "note": "No remaining-plan concern detected after the implement stage.",
  "action_taken": "logged"
}
```

Field meanings:

- `type` — the kind of adaptation. One of `reflection` (a post-stage reflection-beat note), `promotion` (a triage-confidence promotion event), `replan` (a mid-run re-plan of the remaining task graph), `preflight-yield` (a post-dispatch annotation recording whether a hypothesis-added preflight changed the brief), `health-action` (a sustained-`OVERRUN` diagnose-and-recover event — the orchestrator dispatched the read-only diagnostician, evaluated the work-state verdict, and either confirmed the agent alive or recovered a confirmed orphan), `prior-applied` (a run-start event recording that a learned prior changed a default this run — which consumer fired and what default it changed), `budget-escalation` (a run-level budget event recorded only when a budget ceiling is set — a near-ceiling note surfaced and the run proceeded, or an at-ceiling escalation surfaced the spend/defer/stop trade-off to the user at a cost-affecting choice point), or one of the existing strategy-adaptation kinds already logged today (parallel-dispatch switch, sequential fallback, worktree enablement, reassignment, branch-creation skip).
- `at` — ISO-8601 UTC timestamp of when the adaptation was recorded.
- `stage` — the pipeline stage the adaptation was recorded against (e.g., `implement`, `verify`, `review`). For a reflection beat this is the stage that just finished.
- `note` — a short human-readable note. For a reflection beat this is the bounded self-critique paragraph (one paragraph, roughly 80 words or fewer).
- `action_taken` — what the team manager did in response. One of `logged` (recorded only; no plan change), `proposed-addition` (proposed adding work through the existing mid-run plan-adjustment mechanism), `proposed-resequence` (proposed re-ordering through the same mechanism), `escalated` (surfaced to the user — used whenever a reflection beat identifies work that should be removed, since scope reduction always requires user approval), `replanned` (the remaining task board was rewritten following a critic-ACCEPTED re-plan that dropped no scope), or `replan-escalated` (the re-plan crossed the scope-drop or escalation path — triggered by any of: the proposed re-plan would drop committed scope, requiring user approval before the rewrite is applied or declined; the re-plan loop exhausted its retry cap without the critic converging on ACCEPT; or the critic issued REVISE without converging after the allowed iterations). For `type: preflight-yield` entries, `action_taken` is one of the categorical yield values: `changed-brief` (the returned evidence altered what the orchestrator wrote into the brief), `confirmed` (the evidence was consulted and matched the orchestrator's prior assumption — a useful negative signal), or `no-yield` (the preflight returned nothing the orchestrator used, or the dispatch was refused or returned empty). For `type: health-action` entries, `action_taken` is one of: `diagnosed-alive` (the work-verifier found the work landed or the orchestrator's own signal showed the agent still live — no re-dispatch), `re-dispatched` (a confirmed orphan was re-dispatched once per the retry rule), or `re-dispatch-escalated` (the reused retry rule escalated to the user — the orphan re-dispatch also orphaned or failed, or the orphan recovery otherwise stopped for the user). For `type: budget-escalation` entries, `action_taken` is one of: `budget-near` (the near-ceiling note surfaced at a cost-affecting choice point and the run proceeded — informational, never blocking), `budget-escalated` (an at-ceiling escalation surfaced the trade-off to the user at a cost-affecting choice point and waited for the user's decision), `budget-deferred` (the user's resolution of an at-ceiling escalation was to defer the task — recorded only with user approval, never a unilateral drop), `budget-spent` (the user's resolution was to spend the budget and proceed with the cost-affecting action), or `budget-skipped` (the governor skipped a low-yield advisory preflight at ceiling — no user interaction). An at-ceiling event that escalates to the user appends two entries: `budget-escalated` when the escalation surfaces, then `budget-spent` or `budget-deferred` on the user's resolution. For `type: promotion` entries, `action_taken` is one of: `promoted` (the low-confidence trivial classification was promoted to a pipeline run), `checked-no-promotion` (the post-executor check ran but the evidence did not warrant promotion — the trivial path stood), or `empty-diff-no-promotion` (the post-executor check found no diff to evaluate — promotion skipped).
- `query_type` *(optional)* — present on `type: preflight-yield` entries only. Records which preflight query type the hypothesis-added dispatch answered — one of the six code-intel query types (`find_definition`, `find_callers`, `find_dependencies`, `impact_analysis`, `find_implementations`, `execution_flow`) or the four corpus-search query types (`evidence_search`, `locate`, `verify_claim`, `trace_reference`). Allows a future capability to learn which query categories produce useful evidence. Absence is tolerated; older entries without this field are valid. A Phase 2.5d (`docs-lookup`) yield entry has no `query_type` at all — it is keyed by `source` (`library` or `harness`) instead, since docs-lookup resolves a library-or-harness lookup rather than one of the ten query types above.

**Write lifecycle:** The team manager appends one entry to `adaptations` each time it makes an adaptation. Reflection-beat entries are appended at each pipeline stage transition (see Phase 3 Step 5). Strategy-adaptation entries are appended when the corresponding runtime condition fires. Each entry is written immediately when the adaptation is decided, before the next dispatch proceeds.

**Backward compatibility:** Additive field. State files written before this field was introduced will not have it; the team manager treats absence as `[]`. No migration is required.

### budget

Root-level object recording the run-level dispatch-count budget when the user sets a ceiling with `--budget`. It is the backing store for the budget governor — the running tally the orchestrator consults at cost-affecting choice points, and the source a `resume` reads to recover the budget context mid-run.

**Type:** `null` or object (absence treated as "no budget set").

**When null (or absent):** No budget ceiling was set for this run. The budget governor is fully inert — no accumulator, no consultation, no near/at-ceiling evaluation. This is the default; the budget is optional. Every cost-affecting choice point behaves exactly as it does on a run without a budget.

**When set (object):**

```json
{
  "unit": "dispatch-count",
  "ceiling": 40,
  "consumed_so_far": 31,
  "near_note_fired": true
}
```

Field meanings:

- `unit` — the budget unit. The string `"dispatch-count"`: the ceiling and the running tally are both counts of agent dispatches in the run. (Dispatch count is exact and is read from the dispatch bookkeeping that already exists.)
- `ceiling` — the user-supplied integer ceiling, the value passed to `--budget=<N>`.
- `consumed_so_far` — the running count of dispatches in the run, updated as dispatches complete.
- `near_note_fired` — boolean recording whether the near-ceiling note has already fired for the current threshold crossing. The near-ceiling note fires once per crossing, not on every choice point past the near-ceiling line; this flag suppresses the repeat. Persisting it in the state object lets the once-per-crossing rule survive a `resume`.

**Write lifecycle:** `consumed_so_far` and `near_note_fired` are flushed to the state file **before** an at-ceiling escalation surfaces to the user — pinned to the same before-the-stop point the `adaptations` event log uses ("written immediately when the adaptation is decided, before the next dispatch proceeds"). Flushing before the stop means a `resume` of a run interrupted mid-escalation recovers the full budget context: the ceiling, the consumed-so-far tally, and whether the near-ceiling note already fired this crossing.

**Backward compatibility:** Additive field. State files written before this field was introduced will not have it; the team manager treats absence as `null` (no budget set). No migration is required.

### pending_fable_confirm

Root-level field tracking an in-flight `fable`-escalation confirmation in **autonomous mode** — the best-effort ~1-minute wait between asking the user and defaulting NO. It backs the autonomous timeout mechanism (see `phase-dispatch.md` § *`fable`-escalation autonomous timeout*) and lets a `resume` recover an interrupted wait.

**Type:** `null` or object.

**When null (or absent):** No fable-confirm is pending. Steady-state value. In interactive mode this field is never set — the team manager waits for the answer inline and does not arm a deadline.

**When set (object):**

```json
{
  "task_id": "task-7",
  "original_model": "opus",
  "asked_at": "2026-06-22T14:22:03Z",
  "deadline": "2026-06-22T14:23:03Z"
}
```

Field meanings:
- `task_id` — the task whose 3rd-attempt escalation is gated.
- `original_model` — the pre-escalation model the 3rd attempt runs on if the gate resolves NO (always `opus` in practice, since the gate fires only on `opus → fable`).
- `asked_at` — ISO-8601 UTC timestamp when the confirmation prompt was surfaced.
- `deadline` — ISO-8601 UTC timestamp, `asked_at` + ~60s. The best-effort SLA. Evaluated at the next orchestrator beat, not by a wall-clock interrupt.

**Lifecycle:** `null` → set (and flushed to disk) immediately before the autonomous confirmation prompt surfaces → cleared back to `null` on resolution (yes within window → escalate to `fable`; no, or deadline passed → run on `original_model`). The before-the-prompt flush mirrors the `budget` object's before-the-stop flush so a `resume` mid-wait recovers the deadline.

**Resume recovery:** A `resume` of a run interrupted while `pending_fable_confirm` is set re-reads the deadline from the state file. If the deadline has already passed, the default-NO path fires immediately on resume. If the deadline has not yet passed, the orchestrator continues waiting until the next beat at or after the deadline.

**Never set in interactive mode.** In interactive (or `--supervised`) mode the team manager waits inline for the user's answer and never arms a deadline; this field remains `null`.

**Backward compatibility:** Additive field. State files written before this field was introduced will not have it; the team manager treats absence as `null`. No migration is required.

### triage_confidence

Per-task field recording how confident the Triage Gate was when it classified the
run, and which signals drove the call. Present on the task created at triage time
(trivial-path runs carry it on their single task entry; pipeline runs carry it on
the task that anchors the classification).

**Type:** `null` or object.

**When set (object):**

```json
{
  "level": "low",
  "signals": [
    "single-sentence scope but touches a code module",
    "no explicit `plan` request, but wording implies a multi-file edit"
  ]
}
```

Field meanings:

- `level` — the gate's confidence in the classification. One of `high`, `medium`,
  or `low`. There is no numeric score; the gate reasons categorically, the same way
  Phase 1a renders its tier decision with a signals line.
- `signals` — a list of short human-readable strings naming the observations that
  drove the classification. Mirrors the signal prose Phase 1a already displays.

A `low`-confidence `trivial` classification is the only case that can trigger a
post-executor promotion check. The promotion event itself is not stored here — it
is appended to the run-level `adaptations` array with `type: promotion`.

**Backward compatibility:** Additive field. State files written before this field was
introduced will not have it; the team manager treats absence as `null`. No migration
is required.

### adaptation ledger

A **persistent, cross-run learning file** — distinct from every field above. Each field
above lives in the per-run board (`.ops-state/<run-id>-board.json`), which is deleted at
Phase 4 completion. The adaptation ledger lives in the **project memory directory**
(`~/.claude/projects/<project>/memory/`, alongside the timing-patterns memory file) and is
**not part of the per-run board**. Its lifecycle is the inverse of the board's: the board is
ephemeral and deleted when the run ends; the ledger **survives that deletion** and accrues
across runs. The file sits outside the repository tree, is **gitignored**, and is **never
cleaned up** at Phase 4 — it is the corpus future runs learn from.

**Per-run rollup record shape.** The ledger does not store raw per-event prose. At completion,
the team manager appends **one rollup record per run**, keyed by project. Each record names
eight fields:

- `run_id` — the completing run's `run_id`.
- `project` — the project slug the run executed against. A record learned in one project never
  applies in another; the ledger is per-project-isolated.
- `adaptation_counts` — the per-`type` adaptation counts already computed for the Phase 4
  summary: `reflection`, `promotion`, `replan`, `preflight-yield`, `health-action`,
  `prior-applied`, `budget-escalation`, and `other` (count of strategy-adaptation kinds beyond the named types — parallel-dispatch switch, sequential fallback, worktree enablement, reassignment, branch-creation skip).
- `reflection_action_counts` — a count map from each reflection `action_taken` value to the
  number of `type: reflection` adaptation entries that carried it this run. Keys are the contract
  enum verbatim: `logged`, `proposed-addition`, `proposed-resequence`, `escalated`, `replanned`,
  `replan-escalated`. (`logged` maps to the "no concern" bucket and `escalated` maps to the
  "scope-reduction-escalated" bucket at read time — the persisted keys are not renamed.) **Invariant:** the six values sum to `adaptation_counts.reflection`.
- `triage_confidence_dist` — a nested object holding (a) the level distribution across all tasks
  whose `triage_confidence` is non-null (`high` / `medium` / `low` counts — one increment per
  task, not per entry), and (b) a nested `promotion` sub-block with the three `type: promotion`
  `action_taken` outcome counts (`promoted`, `checked-no-promotion`, `empty-diff-no-promotion`).
  **Invariant:** the three `promotion` sub-block values sum to `adaptation_counts.promotion`.
- `file_conflict_pairs` — the file-pairs that forced a parallel-to-sequential adaptation this
  run (the pairs a future run consults when pre-sequencing a known-conflicting dispatch).
- `plan_validation_tier` — the plan-validation tier this run ran at.
- `critic_revise` — whether a critic REVISE occurred this run.

**Window and occurrence bar.** The ledger holds a **rolling 10-run window** per project — on
write, the newest record is appended and the file is trimmed to the most recent 10 runs. A
pattern is recorded the first time it appears but is treated as a learnable signal only once it
has been observed in **at least 2 runs** within the window; a pattern seen in a single run is
recorded and waits, never acting on one-run noise. This ≥2-occurrence rule is a forward-looking
constraint: it specifies how the deferred read-half (not yet shipped) must evaluate the ledger
when it applies learned priors to future runs.

**Example record:**

```json
{
  "run_id": "20260610-143002-a1b2",
  "project": "ai-skills-agents",
  "adaptation_counts": {
    "reflection": 4,
    "promotion": 1,
    "replan": 0,
    "preflight-yield": 2,
    "health-action": 0,
    "prior-applied": 0,
    "budget-escalation": 0,
    "other": 0
  },
  "reflection_action_counts": {
    "logged": 3,
    "proposed-addition": 1,
    "proposed-resequence": 0,
    "escalated": 0,
    "replanned": 0,
    "replan-escalated": 0
  },
  "triage_confidence_dist": {
    "high": 0,
    "medium": 1,
    "low": 1,
    "promotion": {
      "promoted": 1,
      "checked-no-promotion": 0,
      "empty-diff-no-promotion": 0
    }
  },
  "file_conflict_pairs": [
    ["skills/ops/SKILL.md", "skills/ops/phase-completion.md"]
  ],
  "plan_validation_tier": 2,
  "critic_revise": false
}
```

**Backward compatibility:** The ledger is a new file. A project with no ledger yet has nothing
to read; the first run that produces an actionable adaptation creates it. Absence of the file is
treated as an empty corpus. No migration is required.

`reflection_action_counts` and `triage_confidence_dist` are additive fields. Older rollup
records (including already-accrued runs) omit them and remain valid. Absence of
`reflection_action_counts` is treated as an empty map (all reflection action breakdowns unknown
for that run). Absence of `triage_confidence_dist` is treated as an all-zero level distribution
with an all-zero promotion block (no triage signal recorded for that run). No migration or
backfill is required.

## Task Description Fields

Each task uses one of two description modes — never both simultaneously:

### `description_ref` (plan-doc pointer mode)

Used when `plan_file` is set (pipeline runs with a persisted plan document).

- **Format:** `"docs/plan/<name>-plan.md#task-<slug>"` — a markdown anchor pointing to the task's section in the plan doc.
- **Anchor convention:** lowercase, hyphen-separated, matching the section heading (e.g., heading `## Task: Implement Auth Middleware` → anchor `#task-implement-auth-middleware`).
- **`description` field:** Keep as a short one-line summary ≤ 100 chars (e.g., `"Auth middleware + tests in src/auth/"`). This is for display only — not the full prose.
- **Resolution algorithm (Phase 3 Step 3):** Before dispatching an agent, the team manager reads the plan doc file, locates the section matching the anchor (grep for the heading), and extracts the full section content (description, acceptance criteria, implementation notes, file list). This resolved content populates the Context, Scope, and Acceptance Criteria sections of the agent brief. The agent prompt is always fully self-contained after resolution — the agent never receives a bare pointer.

### `description_inline` (inline mode)

Used when `plan_file` is null — trivial-path runs or runs without a persisted plan doc.

- **Format:** Full task prose: description, acceptance criteria, notes, file list — everything needed to brief the agent without reading another file.
- **Resolution:** No resolution step needed. Used directly in the agent brief's Context, Scope, and Acceptance Criteria sections.
- **`description` field:** May duplicate `description_inline` summary or be omitted. `description_inline` is the authoritative source.

#### Example (`description_inline` mode)

```json
{
  "id": "task-0",
  "subject": "Add null-check to login handler",
  "description": "Guard against null user object in login handler",
  "description_inline": "Add a null-check for the user object in `src/auth/login.py` before the session is created. Acceptance criteria: a `pytest` run with a null-user fixture must pass. Files: `src/auth/login.py`, `tests/test_login.py`.",
  "status": "pending",
  "agent_type": "executor",
  "stage": "implement",
  "priority": 1,
  "estimated_minutes": 10,
  "estimate_source": "ops",
  "blocked_by": [],
  "started_at": null,
  "completed_at": null,
  "duration_seconds": null,
  "model_used": null,
  "attempts": 0,
  "adaptation": null,
  "triage_confidence": null,
  "handoff_file": null,
  "_internal": false
}
```

### Choosing the mode

| Condition | Mode | Set `description_ref`? | Set `description_inline`? |
| :--- | :--- | :---: | :---: |
| `plan_file` is set (pipeline run) | Pointer | Yes | No |
| `plan_file` is null (trivial or no plan doc) | Inline | No | Yes |

---

## State Cache Semantics

The team manager maintains an in-memory snapshot (cache) of the state file to avoid reading the full JSON on every Phase 3 loop iteration. The file on disk remains the source of truth — the cache is a read optimization only.

### Invalidation events

The cache is invalidated (state file re-read from disk) on these events:

1. **Bootstrap** — before the first dispatch of each loop invocation.
2. **Task completed** — immediately after Phase 3 Step 4 writes task completion to disk.
3. **Resume or status subcommand** — always re-read on `resume` or `status`; external changes may have occurred since the last session.
4. **User mid-run command** — after processing `add`, `drop`, `reprioritize`, `do #N next`, or `skip`.
5. **Nested skill return** — after any nested-skill call returns, the cache is invalidated. The state file on disk may have been written by the team manager in the same turn (via the write-before step of the `pending_nested_skill` ritual) and must be re-read before processing the return. See the Nested Skill Protocol section of SKILL.md.

Between these events, the team manager operates on the cached snapshot and does not re-read the disk.

### Safety note

If the user manually edits the state file JSON between invalidation events (out-of-band edit), those changes will not be visible until the next invalidation trigger. Manual out-of-band (made outside the team manager, e.g. a hand edit) edits are not a supported workflow — the state file is written exclusively by the team manager. If the user needs to intervene, use the supported mid-run commands (`add`, `drop`, `reprioritize`) which trigger an invalidation.
