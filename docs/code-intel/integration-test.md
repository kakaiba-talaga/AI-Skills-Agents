# Integration Test Spec: `ralph-loop` → `/ops` → `code-intel`

**Run-id context:** `code-intel-agent-2026-04-26`  
**Branch:** `feat/code-intel-agent`  
**Status:** Spec-only. v1 ships no automated test infrastructure for this chain. A human (or future test agent) walks through the checklist in the [Manual Walkthrough Checklist](#manual-walkthrough-checklist) section.

---

## Purpose

This spec documents the expected control flow for the full nested-skill chain:

```
ralph-loop (act stage) → /ops (Phase 2.5b) → code-intel (impact analysis)
```

It exists to answer **one concrete question**: when all three participants are active in the same run, does each handoff boundary carry the right shape and land in the right place?

**Audience.** A developer verifying that the implementation matches the design, or a future test-agent author who wants to build an automated fixture from this walkthrough. You do not need to understand every line of `skills/ops/SKILL.md` — the relevant sections are cited inline.

**What this is not.** This is not an automated test runner. It does not execute agents. It does not assert anything. It is a reference walkthrough that a human can tick off step by step, with concrete example values substituted throughout so there is no ambiguity about what "the right shape" means.

---

## Invocation Chain

Seven steps in order. Each step names the participant, the trigger, and the concrete action.

### Step 1 — User kicks off `ralph-loop`

The user starts a loop with a task that involves a code refactor. The task description contains a risk keyword (`refactor`) and touches more than one file, so `/ops` Phase 2.5b will fire later.

```
/ralph-loop Refactor process_data to accept a typed config object instead of kwargs
```

`ralph-loop` creates a state file at `.ralph-state/<task_id>.json` and opens iteration 1.

**Example values used throughout this spec:**

| Name | Example value |
| :--- | :--- |
| `task_id` | `rl-refactor-process-data-2026-04-28` |
| `run_id` (ops) | `refactor-process-data-2026-04-28` |
| `symbol` | `process_data` |
| `scope` | `src/core/**` |
| `query_type` | `impact_analysis` |

### Step 2 — `ralph-loop` reaches the `act` stage (Frame → Plan → Execute)

During the Execute stage of iteration 1, `ralph-loop` decides the task requires a multi-file code change and dispatches `/ops` to coordinate the implementation. Per the `ralph-loop` SKILL, Execute dispatches to `/ops` with a spec derived from the Plan output. The dispatch is a nested-skill invocation, so `ralph-loop` writes a `pending_nested_skill` record to its state file before handing off.

`ralph-loop` state after write-before:

```json
{
  "task_id": "rl-refactor-process-data-2026-04-28",
  "iteration": 1,
  "current_stage": "Execute",
  "pending_nested_skill": {
    "skill": "/ops",
    "invoked_at": "2026-04-28T10:00:00Z",
    "resume_phase": "reflect",
    "resume_notes": "Resume Reflect stage after /ops completes. Read code-intel report path from executor handoff."
  }
}
```

### Step 3 — `/ops` receives the task and reaches Phase 2.5b

`/ops` runs the pipeline route (not trivial — multi-file refactor implies stage-crossing). It builds a task board, runs Phase 2.5 preflight, and enters the Phase 3 dispatch loop. Before dispatching the executor for the `process_data` refactor task, it evaluates the Phase 2.5b trigger predicate against the task:

- **(ii)** `files_touched > 1` → **true** (the refactor touches `src/core/processor.py`, `src/core/config.py`, and `tests/test_processor.py`)
- **(iv)** brief contains risk keyword → **true** (`refactor` appears in the task description)

Predicate `(ii) OR (iv)` matches. `/ops` dispatches `code-intel` **synchronously** and waits for the JSON response before composing the executor brief.

**Source:** `skills/ops/SKILL.md` → "Phase 2.5b — Code Intelligence Preflight" → "Trigger predicate"

### Step 4 — The team manager dispatches `code-intel` with a JSON-fenced brief

`/ops` composes a self-contained dispatch prompt containing a JSON-fenced brief. The JSON block is the **sole orchestrator-path signal** per R3 / C-ADD-1. No `[context]` literal block is added.

The dispatch prompt structure:

```
You are running as agent type: code-intel.

**Your first action:** Read your full agent definition from `~/.claude/agents/code-intel.md`.

---

## Task
Impact analysis for `process_data` before executor refactor.

## Context
Run-id: refactor-process-data-2026-04-28
Files touched: src/core/processor.py, src/core/config.py, tests/test_processor.py
Predicate match: (ii) files_touched > 1, (iv) risk keyword "refactor"
Executor brief excerpt: "Refactor process_data to accept a typed config object"

## Scope
src/core/**

## Acceptance Criteria
Return impact_analysis report for symbol `process_data`. Write to disk (output_mode: disk).

```json
{
  "query_type": "impact_analysis",
  "symbol": "process_data",
  "scope": "src/core/**",
  "depth": 2,
  "output_mode": "disk",
  "max_results": 200,
  "max_depth": 5,
  "max_files": 5000,
  "max_wall_clock_s": 600
}
```

```

The JSON block above is the full brief shape the team manager passes. It conforms to the schema in `agents/code-intel.md` → "Brief Format" → "JSON-fenced (orchestrator)".

**Source:** `skills/ops/SKILL.md` → "Dispatch contract — what the team manager passes in"

### Step 5 — `code-intel` detects the orchestrator path and suppresses Tier-3

`code-intel` parses the dispatch prompt, finds the fenced `json` block, and routes to the **orchestrator path**. Per the Tier Cascade Logic in `agents/code-intel.md`:

```python
def consider_tier3_escalation(query_type, language, results, runtimes, brief_format):
    # Suppression in non-interactive contexts — JSON-fenced briefs come only
    # from orchestrators. Falling through to "proceed with current data + caveat"
    # preserves prevention-first in interactive contexts while keeping
    # orchestrator dispatches deterministic.
    if brief_format == 'json-fenced':
        return False
    ...
```

`brief_format` is `'json-fenced'` → `consider_tier3_escalation()` returns `False` immediately. The agent does **not** prompt the user about installing `tree-sitter`. It proceeds with current Tier-1 or Tier-2 data plus a precision caveat in the footer.

**Why this matters.** Tier-3 escalation requires interactive user input. An orchestrator dispatch is non-interactive by design — if Tier-3 fired, the chain would block indefinitely. C-ADD-1 locks the suppression to the brief format rather than a sentinel marker, which is simpler and impossible to forget.

**Source:** `agents/code-intel.md` → "Tier Cascade Logic" → `consider_tier3_escalation`; `docs/plan/code-intel-agent-requirements.md` → R3

### Step 6 — `code-intel` writes the report to disk

After running the `impact_analysis` CTE, `code-intel` writes two artifacts and returns a JSON-fenced response:

**Report path:**

```
.code-intel/runs/refactor-process-data-2026-04-28/impact_analysis-process_data.md
```

**JSON sidecar path:**

```
.code-intel/runs/refactor-process-data-2026-04-28/impact_analysis-process_data.json
```

**Source:** `agents/code-intel.md` → "Output Dispatch" → "For `output_mode: disk`"

The `mkdir -p .code-intel/runs/<run-id>/` call is the agent's first write-sequence step, ensuring the directory exists before writing either artifact.

### Step 7 — `ralph-loop` `reflect` stage reads the report path

After `/ops` completes, control returns to `ralph-loop`. The team manager's return payload includes the code-intel report path in the executor's handoff document. `ralph-loop` reads this during the Reflect stage to assess what structural risk the refactor carries. The report path is available at:

```
.code-intel/runs/refactor-process-data-2026-04-28/impact_analysis-process_data.md
```

`ralph-loop` then clears `pending_nested_skill` back to `null`, writes its state file, and continues to the Reflect stage normally.

---

## JSON Shapes at Each Boundary

### Boundary A — `ralph-loop` → `/ops` (the nested-skill handoff)

`ralph-loop` does not pass a structured JSON payload to `/ops`. It invokes `/ops` as a nested skill with a natural-language spec derived from the Plan stage output. The state-file record is the handoff artifact.

`ralph-loop` pending_nested_skill record (written before invoking `/ops`):

```json
{
  "skill": "/ops",
  "invoked_at": "2026-04-28T10:00:00Z",
  "resume_phase": "reflect",
  "resume_notes": "Resume Reflect stage after /ops completes. Read code-intel report path from executor handoff."
}
```

The `/ops` invocation itself is plain text: the task description from the Plan stage plus any relevant context from the Frame/Plan stages.

### Boundary B — `/ops` → `code-intel` (Phase 2.5b dispatch brief)

This is the JSON-fenced brief embedded in the dispatch prompt. This is the **in-brief shape** — what the team manager sends:

```json
{
  "query_type": "impact_analysis",
  "symbol": "process_data",
  "scope": "src/core/**",
  "depth": 2,
  "output_mode": "disk",
  "max_results": 200,
  "max_depth": 5,
  "max_files": 5000,
  "max_wall_clock_s": 600
}
```

Required fields per schema: `query_type` and `symbol`. All other fields are optional overrides.

### Boundary C — `code-intel` → `/ops` (agent response)

`code-intel` returns a JSON-fenced response. This is the **out-brief shape** — what the team manager reads back:

```json
{
  "status": "ok",
  "report_path": ".code-intel/runs/refactor-process-data-2026-04-28/impact_analysis-process_data.md",
  "json_sidecar": ".code-intel/runs/refactor-process-data-2026-04-28/impact_analysis-process_data.json",
  "summary": "process_data has 3 direct callers (handle_request, batch_processor, pipeline_runner) and 1 transitive caller (api_gateway). Tests: test_processor.py covers all direct callers. Precision: ast (Python). No implementers found (function, not class/interface).",
  "db_indexed_sha": "a3f7c12",
  "generated_at": "2026-04-28T10:02:15Z",
  "caveats": []
}
```

Possible `status` values: `"ok"` | `"partial"` | `"refused"`. When `status: "refused"`, the team manager attaches the refusal reason to the executor brief and proceeds — Phase 2.5b is advisory, not blocking.

### Boundary D — `/ops` → `ralph-loop` `reflect` stage (executor handoff)

`/ops` writes a handoff document that `ralph-loop` reads during Reflect. The relevant portion:

```
## Handoff: task-refactor-process-data → Reflect

Code Intelligence Context: see .code-intel/runs/refactor-process-data-2026-04-28/impact_analysis-process_data.md
  - process_data has 3 direct callers; all covered by tests. Low breakage risk.
  - Precision: ast (no caveats).
```

The `report_path` from boundary C is embedded in this handoff document. `ralph-loop` reads the path and can optionally read the full report for a detailed Reflect assessment.

---

## Expected File Paths

| Step | Participant | Action | Path |
| :--- | :--- | :--- | :--- |
| 1 | `ralph-loop` | Creates state file | `.ralph-state/rl-refactor-process-data-2026-04-28.json` |
| 1 | `ralph-loop` | Creates history log | `.ralph-state/rl-refactor-process-data-2026-04-28.history.jsonl` |
| 2 | `ralph-loop` | Writes pending_nested_skill (write-before) | `.ralph-state/rl-refactor-process-data-2026-04-28.json` (updated) |
| 3 | `/ops` | Creates ops state file | `.ops-state/refactor-process-data-2026-04-28-board.json` |
| 3 | `/ops` | Creates handoff directory | `.agents/handoffs/refactor-process-data-2026-04-28/` |
| 6 | `code-intel` | Creates run directory | `.code-intel/runs/refactor-process-data-2026-04-28/` |
| 6 | `code-intel` | Writes impact report (Markdown) | `.code-intel/runs/refactor-process-data-2026-04-28/impact_analysis-process_data.md` |
| 6 | `code-intel` | Writes impact report (JSON sidecar) | `.code-intel/runs/refactor-process-data-2026-04-28/impact_analysis-process_data.json` |
| 6 | `code-intel` | Persistent index (survives cleanup) | `.code-intel/index.sqlite` |
| 6 | `code-intel` | WAL sidecar (survives cleanup) | `.code-intel/index.sqlite-wal` |
| 6 | `code-intel` | SHM sidecar (survives cleanup) | `.code-intel/index.sqlite-shm` |
| 7 | `/ops` Phase 4 | Writes executor handoff | `.agents/handoffs/refactor-process-data-2026-04-28/handoff-002-implement-to-verify.md` |
| 7 | `ralph-loop` | Clears pending_nested_skill (clear-after) | `.ralph-state/rl-refactor-process-data-2026-04-28.json` (updated) |

---

## State-Cache-Invalidation Events

The `/ops` state cache invalidation is specified in `skills/ops/SKILL.md` → "Phase 3 — Dispatch Loop" → "Step 1 — Scan for ready tasks" → "State cache".

Five events invalidate the cache during the standard dispatch loop:

| Event | When it fires in this chain | Effect |
| :--- | :--- | :--- |
| **Bootstrap** | Before the first Phase 3 Step 2 dispatch (initial ops startup) | Full read from `.ops-state/refactor-process-data-2026-04-28-board.json` |
| **Task completed** | After Phase 3 Step 4 marks a task `completed` and writes to disk | Cache invalidated; next Step 1 re-reads |
| **Resume / status subcommand** | Not applicable in this chain (no mid-run resume) | — |
| **User mid-run command** | Not applicable in this chain (no interactive commands during dispatch) | — |
| **Nested skill return** | Not applicable here — `code-intel` is a **subagent**, not a nested skill | See note below |

**The code-intel-specific invalidation** (C-ADD-5 / Q2): after `code-intel` returns from a Phase 2.5b dispatch, the team manager invalidates its state cache before composing the executor brief. This is called out separately in `skills/ops/SKILL.md` → "State cache invalidation":

> `code-intel` is an agent rather than a nested skill, so the nested-skill-return rule at Phase 3 Step 1 does not strictly fire on its own — but because `code-intel` writes a report to disk that the executor must subsequently read, invalidation is required to keep the executor's view consistent.

In practical terms: after the `code-intel` agent returns its JSON response, the team manager reads the state file from disk before composing the executor brief. This ensures that any concurrent state mutations (e.g., from a prior parallel task completion) are visible before the executor receives its context.

**Sequence in this chain:**

1. Phase 2.5b fires: team manager dispatches `code-intel` synchronously.
2. `code-intel` returns JSON response (boundary C shape above).
3. **Team manager invalidates state cache** — reads `.ops-state/refactor-process-data-2026-04-28-board.json` from disk.
4. Team manager composes the executor brief with the `Code Intelligence Context:` block appended.
5. Team manager dispatches the executor.

---

## Cleanup Behavior

Cleanup occurs at `/ops` Phase 4 step 9, after all tasks complete. The rule is:

**Cleaned (ephemeral, run-scoped):**

- `.code-intel/runs/refactor-process-data-2026-04-28/` — the entire run subdirectory, including both artifacts:
  - `impact_analysis-process_data.md`
  - `impact_analysis-process_data.json`
- `.agents/handoffs/refactor-process-data-2026-04-28/` — ops handoff documents for this run
- `.ops-state/refactor-process-data-2026-04-28-board.json` — ops state file
- Any `_tmp_*` files at the repo root

**Not cleaned (persistent infrastructure, per R11c):**

- `.code-intel/index.sqlite` — the symbol graph. Persists across all runs and is rebuilt on git-SHA staleness, not on ops completion.
- `.code-intel/index.sqlite-wal` — WAL journal sidecar. SQLite writes to this during transactions; it is part of the persistent index.
- `.code-intel/index.sqlite-shm` — shared memory sidecar. Same lifecycle as the WAL file.
- `.code-intel/runs/` — the **parent** directory itself. Only the run-scoped subdirectory is deleted.
- `docs/plan/` documents (plan doc, scoping doc, etc.) — persistent deliverables, never touched by Phase 4 cleanup.
- `docs/ops-dispatch-log.md` (if present) — persistent audit trail, never touched by Phase 4 cleanup.

**Source:** `skills/ops/SKILL.md` → "Phase 4" → step 9; `agents/code-intel.md` → "Lifecycle" → "Cleanup"; `docs/plan/code-intel-agent-requirements.md` → R11c.

**Verifying cleanup is correct:** after Phase 4 completes, run:

```bash
ls .code-intel/runs/
```

Expected: either the `refactor-process-data-2026-04-28/` subdirectory is gone (cleaned) or an empty listing. If the subdirectory still exists, Phase 4 step 9 did not fire the code-intel cleanup pointer.

```bash
ls .code-intel/
```

Expected: `index.sqlite` (and optionally `index.sqlite-wal`, `index.sqlite-shm`, `runs/`) — the persistent index is intact.

---

## Manual Walkthrough Checklist

Walk through these steps in order. Each step has a concrete check you can perform or observe. Tick each item off as you go.

### Setup

- [ ] **S1.** Confirm `.code-intel/` does not exist yet (or note its current state). This determines whether Step 6 triggers a first-time index build.
- [ ] **S2.** Confirm `agents/code-intel.md` exists and the frontmatter declares `model: opus` and the five tools: `Read`, `Glob`, `Grep`, `Bash`, `Write`.
- [ ] **S3.** Confirm `skills/ops/SKILL.md` contains the "Phase 2.5b" section with the trigger predicate `(ii) OR (iv)`.

### Invocation

- [ ] **I1.** Start `ralph-loop` with a task description containing the word `refactor` and affecting multiple files.
- [ ] **I2.** Verify `.ralph-state/<task_id>.json` is written to disk after Frame. Read it and confirm `status: "active"` and `current_stage: "Execute"`.
- [ ] **I3.** When `ralph-loop` dispatches `/ops` (Execute stage), verify `.ralph-state/<task_id>.json` contains a `pending_nested_skill` record with `skill: "/ops"` before `/ops` starts.

### `/ops` Phase 2.5b

- [ ] **P1.** Verify `/ops` builds a state file at `.ops-state/<run-id>-board.json` before any dispatch.
- [ ] **P2.** Identify the code-modifying task on the board (the `process_data` refactor). Confirm it has `files_touched > 1` or a risk keyword in its description. Either condition satisfies the predicate.
- [ ] **P3.** Confirm `/ops` dispatches `code-intel` **before** the executor for this task. In the session log, `code-intel` should appear before `executor` in the Phase 3 Step 2 output.
- [ ] **P4.** Confirm the dispatch prompt to `code-intel` contains a fenced `json` block (not just `Query:` / `Symbol:` labeled prose). The JSON block must include at minimum `"query_type"` and `"symbol"`.
- [ ] **P5.** Confirm the JSON block does **not** contain a `[context]` literal marker (C-ADD-1: the JSON-fenced block is the sole orchestrator-path signal).

### `code-intel` execution

- [ ] **C1.** Confirm `code-intel` routes to the orchestrator path (disk-mode default). Look for the JSON-fenced response, not inline Markdown.
- [ ] **C2.** Confirm `code-intel` does **not** display the Tier-3 escalation prompt. (`"[code-intel] Tier-3 escalation available"` must not appear in the session output.)
- [ ] **C3.** Confirm `.code-intel/index.sqlite` exists after the dispatch (either pre-existing and reused, or freshly built per R11a).
- [ ] **C4.** Confirm the report file exists at `.code-intel/runs/<run-id>/impact_analysis-<symbol>.md`. Read the first few lines: should contain `## Code Intelligence Report — \`impact_analysis\`` and a `**Symbol:** \`process_data\`` line.
- [ ] **C5.** Confirm the JSON sidecar exists at `.code-intel/runs/<run-id>/impact_analysis-<symbol>.json`. It must contain `"status"`, `"report_path"`, `"db_indexed_sha"`, and `"generated_at"` fields.
- [ ] **C6.** Read the JSON sidecar and confirm `"status"` is `"ok"` or `"partial"` (not `"refused"` — a refusal means the symbol was not found or a hard cap was hit).

### State-cache invalidation

- [ ] **Q1.** In the session log, confirm that after `code-intel` returns, `/ops` reads the state file from disk before composing the executor brief. (Evidence: a `Read(".ops-state/...")` call in the log between the `code-intel` return and the `executor` dispatch prompt being composed.)

### Executor brief

- [ ] **E1.** Read the executor's dispatch prompt. Confirm it contains a `Code Intelligence Context:` block referencing the report path:
  ```
  Code Intelligence Context: see .code-intel/runs/<run-id>/impact_analysis-process_data.md
    - <one-line summary>
  ```
- [ ] **E2.** Confirm the executor brief does **not** contain the full Markdown report inline — only the path and summary line.

### `ralph-loop` reflect

- [ ] **R1.** After `/ops` completes, confirm `.ralph-state/<task_id>.json` has `pending_nested_skill: null` (cleared after the nested-skill return).
- [ ] **R2.** In the Reflect stage output, confirm `ralph-loop` references the code-intel report or its findings (either by path or by summarized content from the handoff document).
- [ ] **R3.** Confirm `ralph-loop` continues to the Reflect stage rather than halting. A nested-skill return is a mid-loop event, not a terminal event (Non-negotiable #10 in `skills/ops/SKILL.md`).

### Cleanup

- [ ] **CL1.** After `/ops` Phase 4 completes, confirm `.code-intel/runs/<run-id>/` no longer exists (cleaned).
- [ ] **CL2.** Confirm `.code-intel/index.sqlite` still exists (not cleaned — persistent infrastructure per R11c).
- [ ] **CL3.** Confirm `.code-intel/runs/` (parent directory) still exists (only the run-scoped subdirectory was removed).
- [ ] **CL4.** Confirm `.ops-state/<run-id>-board.json` no longer exists (cleaned by Phase 4 step 9).
- [ ] **CL5.** Confirm `.agents/handoffs/<run-id>/` no longer exists (cleaned by Phase 4 step 9).

---

## Out of Scope

- **Automated test execution.** This spec is a human-readable walkthrough. v1 ships no automated test runner for this chain. A future test agent can use this spec as the fixture definition.
- **Multi-symbol dispatches.** This spec covers a single `impact_analysis` query per executor task. The chain generalizes to other query types, but those are not covered here.
- **`--code-intel=off` behavior.** When the flag is set, Phase 2.5b is skipped entirely. That is a separate walkthrough: confirm steps P3–P5 do not appear in the session log and the executor brief has no `Code Intelligence Context:` block.
- **`status: "refused"` path.** When `code-intel` returns a refusal, the team manager attaches the refusal reason to the executor brief and proceeds. That path is covered by `task-verify-json-schema-fixtures` (M5.4), not here.
- **Concurrent executor dispatches.** Phase 2.5b fires once per code-modifying task. If multiple tasks match the predicate, each gets its own synchronous `code-intel` dispatch before its executor dispatch — they do not share a dispatch.
- **`ralph-loop` → `/ops` with `ralph` flag.** When `/ops` is invoked with the `ralph` flag, `/ops` itself wraps in a ralph-loop. That nesting scenario is more complex than what this spec covers.
- **Durable report writes.** When a human invokes `code-intel` with `output_mode: "disk"` directly (not via orchestrator), the report goes to `docs/code-intel/<symbol>-<query>.md` (durable). This spec covers only the orchestrator-path ephemeral writes to `.code-intel/runs/<run-id>/`.

---

*Source files for this spec: `agents/code-intel.md`, `skills/ops/SKILL.md` (Phase 2.5b, Phase 3 Step 1 state cache, Phase 4 step 9), `skills/ralph-loop/SKILL.md` (Non-negotiable #10 pattern via `/ops`), `docs/plan/code-intel-agent-requirements.md` (R3, R11c), `docs/plan/code-intel-agent-plan.md` (`task-nested-skill-integration-spec`, ADD risk 6).*
