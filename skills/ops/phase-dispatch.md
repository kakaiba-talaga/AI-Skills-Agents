# Phase 2.5 preflight and Phase 3 dispatch

> **Parent:** `~/.claude/skills/ops/SKILL.md` — Non-negotiables, Agent Briefing Format, and Handoff Documents live in the hub.

### Phase 2.5b — Code Intelligence Preflight (advisory)

Before each code-modifying executor dispatch in Phase 3 Step 2, the team manager may dispatch a **code-intel** agent to perform an impact analysis. This phase is *advisory* (informs the brief but never blocks it) — its output enriches the executor's brief but never blocks it.

#### Trigger predicate

Evaluate the predicate `(ii) OR (iv) OR (vi)` against each code-modifying task at Phase 3 Step 2, before composing the executor brief:

- **(ii)** `files_touched > 1` — the task touches more than one file.
- **(iv)** The task brief contains at least one *risk keyword* (case-insensitive match): `refactor`, `rename`, `delete`, `breaking change`, `migrate`, `deprecate`, `extract`, `move`.
- **(vi) Information-need hypothesis** — before evaluating the keyword/structural terms above, the orchestrator forms a single categorical hypothesis against the task's **planned** `files_touched` and brief contents (the pre-executor moment): *"I lack the answer that `<query_type>` would give, and that gap is a risk for this task."* The `<query_type>` is bounded to the six code-intel query types listed under the dispatch contract (`find_definition`, `find_callers`, `find_dependencies`, `impact_analysis`, `find_implementations`, `execution_flow`) — no new query type is invented, and no numeric threshold is used; the judgment is categorical. The hypothesis term fires `code-intel` only when **(a)** a genuine, risk-relevant code-intel `query_type` would answer the gap, **and (b)** neither `(ii)` nor `(iv)` matched for this task. It can only *add* the dispatch the keyword/structural path missed.

The keyword/structural predicate `(ii) OR (iv)` is retained **unchanged as an unconditional floor**: any match on `(ii)` or `(iv)` fires `code-intel` regardless of the hypothesis verdict. The wiring is `(ii) OR (iv) OR (vi)` — an `OR`, never an `AND`, never a veto. The hypothesis term `(vi)` can never suppress, gate, or remove a dispatch the keyword/structural path would have fired.

**Dedup invariant (at most once per task/stage).** For a single task/stage, `code-intel` fires **at most once**. The hypothesis term `(vi)` is a no-op when a code-intel preflight already fired for this task/stage **by any path** — the keyword/structural path (`(ii)` or `(iv)`), the `--code-intel=always` flag, or a dual preflight sequence. In all those cases the hypothesis is already answered by the in-flight or returned report, so `(vi)` adds nothing. The hypothesis term only adds a dispatch when no code-intel preflight fired by any path.

If the predicate matches, dispatch `code-intel` synchronously (wait for the report path) before composing the executor brief. Synchronous dispatch closes the door on race conditions with mid-Phase-3 work.

#### Budget governor (preflight consultation)

This consultation runs only when the user set a run-level dispatch-count ceiling with `--budget`; when no budget is set it is a strict no-op and the preflight fires exactly as it does today. When a budget is set, before firing this advisory preflight the orchestrator consults the budget: at ceiling, it **may skip this low-yield advisory preflight**. Because Phase 2.5b is advisory and never-blocking — its output enriches the executor brief but never gates it — skipping a preflight never harms correctness; it is declining an optional lookup, **not** a task drop and **not** a scope reduction. A skip records a `type: budget-escalation` adaptation with `action_taken: budget-skipped` (see `state-schema.md`); the executor task itself still dispatches. The budget never skips, shortens, or marks-satisfied any verification or correctness gate — only this optional, advisory preflight.

#### Flags

- `--code-intel` — alias for `--code-intel=always`. Fires `code-intel` on every code-modifying task regardless of predicate.
- `--code-intel=off` — disables Phase 2.5b for the entire run. This is additionally a no-op for non-code-modifying tasks, which the trigger predicate already excludes from Phase 2.5b.

#### Dispatch trigger point

The team manager dispatches `code-intel` during **Phase 3 Step 2 (Batch parallel work), before each code-modifying executor dispatch**. The team manager evaluates `(ii) OR (iv) OR (vi)` against the task's `files_touched` and brief contents at that moment; if matched (or `--code-intel` is set), dispatches `code-intel` synchronously and waits for the JSON response before composing the executor brief. A hypothesis-added dispatch (matched via `(vi)` alone) uses the **same** JSON-fenced brief and the **same** per-call hard caps as any other Phase 2.5b dispatch (`max_results`, `max_depth`, `max_files`, `max_wall_clock_s` below) verbatim — no new caps and no cap bypass — with the same `output_mode: "disk"` and the same synchronous, advisory, never-blocking behavior: no mode branch and no per-dispatch checkpoint.

#### First-time index build

On the first Phase 2.5b dispatch when `.code-intel/index.sqlite` is absent, the agent builds the index synchronously as preflight. The indexer wall-clock counts against `max_wall_clock_s`. The team manager's wait covers both the build and the query.

#### Dispatch contract — what the team manager passes in

Compose a JSON-fenced brief and embed it in the dispatch prompt. The **JSON-fenced brief is the sole and authoritative orchestrator-path signal** — the agent detects the orchestrator caller by the presence of a fenced `json` block, not by any additional marker or sentinel. Do not add a `[context]` literal block. Run-scoped context (`run_id`, `files_touched`, `predicate_match`, `executor_brief_excerpt`) belongs in the standard **`## Context` Markdown section** of the agent brief per `skills/ops/brief-contract.md` — the agent reads that Markdown for human-readable display only and does not act on it programmatically.

> **Literal JSON brief — keep fenced.** The block below is the exact JSON payload passed to the `code-intel` agent, not a user-facing UI output. Do not unfence it.

```json
{
  "query_type": "impact_analysis",
  "symbol": "<primary symbol from the executor's task brief>",
  "scope": "<optional file glob, e.g. 'src/auth/**'>",
  "depth": 2,
  "output_mode": "disk",
  "max_results": 200,
  "max_depth": 5,
  "max_files": 5000,
  "max_wall_clock_s": 600
}
```

`query_type` must be one of: `find_definition`, `find_callers`, `find_dependencies`, `impact_analysis`, `find_implementations`, `execution_flow`. Use `impact_analysis` for typical executor preflight. `output_mode` should be `"disk"` for orchestrator dispatch — the agent writes the report to disk and returns the path.

#### Dispatch contract — what code-intel returns

For `output_mode: "disk"` (the orchestrator default), `code-intel` returns this JSON-fenced response:

> **Literal JSON response shape — keep fenced.** The block below documents the exact JSON structure returned by `code-intel`, not a user-facing UI output. Do not unfence it.

```json
{
  "status": "ok" | "partial" | "refused",
  "report_path": ".code-intel/runs/<run-id>/impact_analysis-<symbol>.md",
  "json_sidecar": ".code-intel/runs/<run-id>/impact_analysis-<symbol>.json",
  "summary": "<one-paragraph human summary>",
  "db_indexed_sha": "a3f7c12",
  "generated_at": "2026-04-26T14:35:00Z",
  "caveats": ["tier-2 partition: rust files", "truncated at 200 results"]
}
```

For `output_mode: "inline"`: includes `report_inline` (full Markdown), omits `report_path`. For `output_mode: "both"`: both populated, but `report_inline` carries only the summary and path — not duplicate full content.

#### Yield record (post-return annotation)

After a hypothesis-added `code-intel` dispatch returns, the team manager records one entry in the run-level `adaptations` array (see `state-schema.md`) with `type: preflight-yield`, the categorical yield value, and the answering `query_type` sub-field. The yield value is judged against the returned report versus the brief the orchestrator then composes — the post-dispatch moment — and is one of three categories:

- `changed-brief` — the returned evidence altered what the orchestrator wrote into the executor brief.
- `confirmed` — the evidence was consulted and matched the orchestrator's prior assumption (a useful negative signal).
- `no-yield` — the preflight returned nothing the orchestrator used, **or** the dispatch was refused or returned empty. A refused or empty-report dispatch records `no-yield` with the refusal/empty reason in the `note`.

The team manager **records yield only; it never reads prior yield to decide a dispatch**. This annotation is bookkeeping for a future capability to learn by category; nothing in Phase 2.5b consults it.

#### State cache invalidation

After `code-intel` returns from a Phase 2.5b dispatch, the team manager invalidates (marks the cached copy stale so it is re-read from disk) its state cache (read-on-next-Step-1) before composing the executor brief. `code-intel` is an agent rather than a nested skill, so the nested-skill-return rule at Phase 3 Step 1 does not strictly fire on its own — but because `code-intel` writes a report to disk that the executor must subsequently read, invalidation is required to keep the executor's view consistent.

#### Refusal handling

If `code-intel` returns `status: refused` for any reason (timeout, symbol-not-found, hard-cap hit, malformed brief, lane violation, DB corruption), the team manager:

1. Logs the refusal in the dispatch log when `--dispatch-log` is set (standard entry format: timestamp, agent name, task ID, brief excerpt, return status `refused`).
2. Attaches the refusal reason to the executor's brief so the executor knows the consultation was attempted but did not yield results.
3. Proceeds. Phase 2.5b is *advisory* — refusal does not block the executor.

A hypothesis-added dispatch (matched via `(vi)` alone) that returns `status: refused` reuses these steps verbatim — attach the reason, proceed, never block — and records yield `no-yield` per the **Yield record** step above.

#### Dispatch log entry

When `--dispatch-log` is set, Phase 2.5b dispatches append to `docs/ops-dispatch-log.md` following the standard dispatch-log entry format (timestamp, agent name, task ID, brief excerpt, return status). When `--dispatch-log` is not set, no log entry is written — matching the existing per-dispatch behavior in `dispatch-log.md`.

#### Attaching to the executor brief

After a successful Phase 2.5b dispatch, append a `Code Intelligence Context:` block to the executor's brief. A hypothesis-added dispatch (matched via `(vi)` alone) appends the **same** block — the hypothesis path does not invent a different attachment:

> **Literal agent-brief text — keep fenced.** The block below is the exact text appended to the executor's prompt string, not a user-facing UI output. Do not unfence it.

```text
Code Intelligence Context: see .code-intel/runs/<run-id>/impact_analysis-<symbol>.md
  - <one-line summary from the response>
  - <caveat 1, if any>
  - <caveat 2, if any>
```

#### Cleanup pointer

Phase 4 step 9 cleans `.code-intel/runs/<run-id>/` (ephemeral, this run only — analogous to `.agents/handoffs/<run_id>/`). Persistent infrastructure (`.code-intel/index.sqlite` and its WAL/SHM sidecars) is **not** Phase 4 cleaned.

### Phase 2.5c — Corpus Search Preflight (advisory)

Before each `executor`, `debugger`, or `documentor` dispatch in Phase 3 Step 2, the team manager may dispatch a **corpus-search** agent to perform a multi-hop textual evidence search. This phase is *advisory* — its output enriches the consumer's brief but never blocks it.

#### Trigger predicate

Evaluate the predicate `(i) OR (ii) OR (iii) OR (iv)` against each dispatch where `agent_type` ∈ `{executor, debugger, documentor}` at Phase 3 Step 2, before composing the consumer brief. When Phase 2.5b also matches for an `executor` task, run Phase 2.5b first, then Phase 2.5c (see **Dual preflight sequence** below).

- **(i) Investigation keyword** — the task brief contains at least one (case-insensitive): `find evidence`, `where is`, `where are`, `grep for`, `search for`, `locate`, `verify that`, `confirm that`, `investigate`, `trace`, `mentions`, `documented in`, `free-text`, `corpus`, `string match`.
- **(ii) Consumer agent + non-symbol task** — `agent_type` ∈ `{debugger, documentor}` AND the **symbol-extraction algorithm** (below) returns no extractable primary symbol. Clause (ii) passes only when all three ordered checks fail.
- **(iii) Rename/migration cue** — code-modifying task (`agent_type == executor`) AND the brief contains at least one *risk keyword* from Phase 2.5b (`refactor`, `rename`, `delete`, `breaking change`, `migrate`, `deprecate`, `extract`, `move`) AND at least one textual migration cue: `update references`, `rename mentions`, `docs mention`, `string replace`, `across repo`, `all occurrences`.
- **(iv) Information-need hypothesis** — before evaluating the keyword/structural terms above, the orchestrator forms a single categorical hypothesis against the task's **planned** scope and brief contents (the pre-composition moment): *"I lack the answer that `<query_type>` would give, and that gap is a risk for this task."* The `<query_type>` is bounded to the four corpus-search query types listed under the dispatch contract (`evidence_search`, `locate`, `verify_claim`, `trace_reference`) — no new query type is invented, and no numeric threshold is used; the judgment is categorical. The hypothesis term fires `corpus-search` only when **(a)** a genuine, risk-relevant corpus-search `query_type` would answer a textual-evidence gap, **and (b)** none of `(i)`, `(ii)`, `(iii)` matched for this task. It can only *add* the dispatch the keyword/structural path missed.

The keyword/structural predicate `(i) OR (ii) OR (iii)` is retained **unchanged as an unconditional floor**: any match on `(i)`, `(ii)`, or `(iii)` fires `corpus-search` regardless of the hypothesis verdict. The wiring is `(i) OR (ii) OR (iii) OR (iv)` — an `OR`, never an `AND`, never a veto. The hypothesis term `(iv)` can never suppress, gate, or remove a dispatch the keyword/structural path would have fired.

**Dedup invariant (at most once per task/stage).** For a single task/stage, `corpus-search` fires **at most once**. The hypothesis term `(iv)` is a no-op when a corpus-search preflight already fired for this task/stage **by any path** — the keyword/structural path (`(i)`, `(ii)`, or `(iii)`), the `--corpus-search=always` flag, or the dual preflight sequence. In all those cases the hypothesis is already answered by the in-flight or returned report, so `(iv)` adds nothing. The hypothesis term only adds a dispatch when no corpus-search preflight fired by any path.

If the predicate matches (and `--corpus-search=off` is not set), dispatch `corpus-search` synchronously (wait for the report path) before composing the consumer brief.

#### Budget governor (preflight consultation)

This consultation runs only when the user set a run-level dispatch-count ceiling with `--budget`; when no budget is set it is a strict no-op and the preflight fires exactly as it does today. When a budget is set, before firing this advisory preflight the orchestrator consults the budget: at ceiling, it **may skip this low-yield advisory preflight**. Because Phase 2.5c is advisory and never-blocking — its output enriches the consumer brief but never gates it — skipping a preflight never harms correctness; it is declining an optional lookup, **not** a task drop and **not** a scope reduction. A skip records a `type: budget-escalation` adaptation with `action_taken: budget-skipped` (see `state-schema.md`); the consumer task itself still dispatches. The budget never skips, shortens, or marks-satisfied any verification or correctness gate — only this optional, advisory preflight.

#### Symbol-extraction algorithm (clause (ii))

Evaluate in order against the resolved task brief (after `description_ref` resolution). Stop at the first successful extraction — if any check yields a symbol, clause (ii) **fails** (corpus-search is not triggered via this clause):

1. **`Symbol:` line** — a line matching `Symbol:` outside Markdown code fences (column-0 or indented prose only; ignore fenced blocks).
2. **First backtick token in `## Task`** — the first backtick-wrapped token in the `## Task` section body.
3. **`def` / `class` / `function` name** — a name following `def`, `class`, or `function` in task prose (outside code fences).

Clause (ii) passes only when **all three checks fail** — no extractable primary symbol → corpus-search eligible for debugger/documentor non-symbol tasks.

#### Flags

- `--corpus-search` — alias for `--corpus-search=always`. Fires `corpus-search` on every Phase 3 Step 2 dispatch where the consumer is `executor`, `debugger`, or `documentor`, regardless of predicate.
- `--corpus-search=off` — disables Phase 2.5c for the entire run.

#### Dispatch trigger point

The team manager dispatches `corpus-search` during **Phase 3 Step 2 (Batch parallel work), before composing the brief** for tasks where `agent_type` ∈ `{executor, debugger, documentor}`. Evaluate `(i) OR (ii) OR (iii) OR (iv)` against the task brief at that moment; if matched (or `--corpus-search` is set), dispatch `corpus-search` synchronously and wait for the JSON response before composing the consumer brief. A hypothesis-added dispatch (matched via `(iv)` alone) uses the **same** JSON-fenced brief and the **same** per-call hard caps as any other Phase 2.5c dispatch (single-preflight `max_results`, `max_hops`, `max_files`, `max_wall_clock_s`, and the dual-preflight caps, both below) verbatim — no new caps and no cap bypass — with the same `output_mode: "disk"` and the same synchronous, advisory, never-blocking behavior: no mode branch and no per-dispatch checkpoint. The hypothesis term `(iv)` changes only *whether* Phase 2.5c fires — never *how* it composes the brief: a hypothesis-added dispatch follows the **Dual preflight sequence** and standalone seed rules below exactly as a keyword-matched dispatch would.

**Dual preflight sequence (when both Phase 2.5b and 2.5c match on an executor task):**

This sequence applies whenever Phase 2.5b ran for the `executor` task — whether 2.5b matched via its keyword/structural predicate **or** fired via its own hypothesis clause `(vi)`. A hypothesis-added 2.5c dispatch on such a task honors this ordering and these seed rules unchanged; the hypothesis term `(iv)` changes only *whether* 2.5c fires, never *how* the brief is composed once it does.

1. Dispatch **code-intel** (Phase 2.5b); wait for JSON response.
2. Invalidate state cache (read-on-next-Step-1).
3. Dispatch **corpus-search** with `query_type: "trace_reference"` and seed `query` from the symbol-extraction algorithm above; if all extraction checks fail, use the first non-empty line of `## Task` prose as fallback seed. Wait for JSON response.
4. Invalidate state cache again.
5. Attach **both** `Code Intelligence Context:` and `Corpus Search Context:` blocks to the executor brief.

When Phase 2.5b did **not** run (the standalone, non-dual case — including a standalone hypothesis-added 2.5c dispatch), use `query_type: "evidence_search"` with `query` derived from the task subject or investigative string in the brief. The hypothesis clause does not introduce a different seed source — it derives the standalone seed exactly as the existing standalone path does.

#### Dispatch contract — what the team manager passes in

Compose a JSON-fenced brief and embed it in the dispatch prompt. The **JSON-fenced brief is the sole and authoritative orchestrator-path signal** — the agent detects the orchestrator caller by the presence of a fenced `json` block, not by any additional marker or sentinel. Do not add a `[context]` literal block. Run-scoped context belongs in the standard **`## Context` Markdown section** of the agent brief — the agent reads that Markdown for human-readable display only and does not act on it programmatically.

> **Literal JSON brief — keep fenced.** The blocks below are exact JSON payloads passed to the `corpus-search` agent, not user-facing UI output. Do not unfence them.

**Single preflight** (Phase 2.5b did not run — use `evidence_search`):

```json
{
  "query_type": "evidence_search",
  "query": "<task subject or investigative string from the brief>",
  "scope": "<optional file glob from task scope, e.g. 'skills/ops/**'>",
  "output_mode": "disk",
  "max_results": 50,
  "max_hops": 3,
  "max_files": 2000,
  "max_wall_clock_s": 120
}
```

**Dual preflight** (Phase 2.5b ran first — use `trace_reference`):

```json
{
  "query_type": "trace_reference",
  "query": "<symbol from symbol-extraction algorithm, or first non-empty line of ## Task if extraction fails>",
  "scope": "<optional file glob from task scope>",
  "output_mode": "disk",
  "max_results": 50,
  "max_hops": 3,
  "max_files": 2000,
  "max_wall_clock_s": 120
}
```

`query_type` must be one of: `evidence_search`, `locate`, `verify_claim`, `trace_reference`. Use `evidence_search` for typical standalone preflight and `trace_reference` after dual preflight with code-intel. `output_mode` should be `"disk"` for orchestrator dispatch — the agent writes the report to disk and returns the path.

#### Dispatch contract — what corpus-search returns

For `output_mode: "disk"` (the orchestrator default), `corpus-search` returns this JSON-fenced response:

> **Literal JSON response shape — keep fenced.** The block below documents the exact JSON structure returned by `corpus-search`, not a user-facing UI output. Do not unfence it.

```json
{
  "status": "ok" | "partial" | "refused",
  "report_path": ".corpus-search/runs/<run-id>/evidence_search-<slug>.md",
  "json_sidecar": ".corpus-search/runs/<run-id>/evidence_search-<slug>.json",
  "summary": "<one-paragraph human summary>",
  "corpus_indexed_sha": "a3f7c12",
  "generated_at": "2026-05-24T14:35:00Z",
  "evidence_count": 12,
  "files_touched": 4,
  "caveats": ["truncated at 50 results"]
}
```

For `output_mode: "inline"`: includes `report_inline` (full Markdown), omits `report_path`. For `output_mode: "both"`: both populated, but `report_inline` carries only the summary and path — not duplicate full content.

#### Yield record (post-return annotation)

After a hypothesis-added `corpus-search` dispatch returns, the team manager records one entry in the run-level `adaptations` array (see `state-schema.md`) with `type: preflight-yield`, the categorical yield value, and the answering `query_type` sub-field. The yield value is judged against the returned report versus the brief the orchestrator then composes — the post-dispatch moment — and is one of three categories:

- `changed-brief` — the returned evidence altered what the orchestrator wrote into the consumer brief.
- `confirmed` — the evidence was consulted and matched the orchestrator's prior assumption (a useful negative signal).
- `no-yield` — the preflight returned nothing the orchestrator used, **or** the dispatch was refused or returned empty. A refused or empty-report dispatch records `no-yield` with the refusal/empty reason in the `note`.

The team manager **records yield only; it never reads prior yield to decide a dispatch**. This annotation is bookkeeping for a future capability to learn by category; nothing in Phase 2.5c consults it.

#### State cache invalidation

After `corpus-search` returns from a Phase 2.5c dispatch, the team manager invalidates its state cache (read-on-next-Step-1) before composing the consumer brief. `corpus-search` is an agent rather than a nested skill, so the nested-skill-return rule at Phase 3 Step 1 does not strictly fire on its own — but because `corpus-search` writes a report to disk that the consumer must subsequently read, invalidation is required to keep the consumer's view consistent.

#### Refusal handling

If `corpus-search` returns `status: refused` for any reason (timeout, hard-cap hit, malformed brief, lane violation, git repo unavailable), the team manager:

1. Logs the refusal in the dispatch log when `--dispatch-log` is set (standard entry format: timestamp, agent name, task ID, brief excerpt, return status `refused`).
2. Attaches the refusal reason to the consumer's brief so the consumer knows the consultation was attempted but did not yield results.
3. Proceeds. Phase 2.5c is *advisory* — refusal does not block the consumer.

A hypothesis-added dispatch (matched via `(iv)` alone) that returns `status: refused` reuses these steps verbatim — attach the reason, proceed, never block — and records yield `no-yield` per the **Yield record** step above.

#### Dispatch log entry

When `--dispatch-log` is set, Phase 2.5c dispatches append to `docs/ops-dispatch-log.md` following the standard dispatch-log entry format (timestamp, agent name `corpus-search`, task ID, brief excerpt, return status). When `--dispatch-log` is not set, no log entry is written — matching the existing per-dispatch behavior in `dispatch-log.md`.

#### Attaching to the consumer brief

After a successful Phase 2.5c dispatch, append a `Corpus Search Context:` block to the consumer's brief (`executor`, `debugger`, or `documentor`). A hypothesis-added dispatch (matched via `(iv)` alone) appends the **same** block — including the dual-preflight path-token reflection (`trace_reference-<slug>.md`) where applicable — the hypothesis path does not invent a different attachment:

> **Literal agent-brief text — keep fenced.** The block below is the exact text appended to the consumer's prompt string, not a user-facing UI output. Do not unfence it.

```text
Corpus Search Context: see .corpus-search/runs/<run-id>/evidence_search-<slug>.md
  - <one-line summary from the response>
  - <caveat 1, if any>
  - <caveat 2, if any>
```

When dual preflight ran, the path token reflects `trace_reference-<slug>.md` (where `<slug>` is a short lowercase, hyphen-separated label) instead of `evidence_search-<slug>.md`.

#### Cleanup pointer

Phase 4 step 9 cleans `.corpus-search/runs/<run-id>/` (ephemeral, this run only). Unlike code-intel, corpus-search has **no persistent index** — only run-scoped report directories are deleted. **Do not delete** the parent `.corpus-search/` directory or `docs/corpus-search/` (durable human opt-in reports).

### Phase 2.5 — Preflight Validation

After the task board is created and before the first dispatch, run a preflight check to confirm the environment is ready. Dispatch a **preflight** agent (see `~/.claude/agents/preflight.md`). If any critical check fails, stop and report to the user. If standard checks fail, attempt auto-fix once. Warnings are logged but do not block dispatch.

### Cursor: state file sync (mandatory)

> Applies only when the active harness is **Cursor**. Claude Code has no `TodoWrite` tool — skip this section there.

Cursor exposes `TodoWrite` for an IDE-visible task list. Models often update `TodoWrite` alone and **never** write `.ops-state/<run-id>-board.json` after the initial board creation. That breaks `resume`, `status`, timing, handoffs, and nested-skill recovery.

| Layer | Role |
| :--- | :--- |
| `.ops-state/<run-id>-board.json` | **Source of truth** — dependencies, timing, `blocked_by`, adaptations, `pending_nested_skill` |
| `TodoWrite` | **Display only** — mirrors status for the IDE; never authoritative |

**Forbidden:** Calling `TodoWrite` for a status change without completing **Write → Read verify** on the board file in the **same assistant turn** first.

**Required ritual** (every status change: `pending` → `in_progress`, completion, failure, new task, cancel, adaptation):

1. `Read` the board file (or use cache only if this turn already wrote and verified it).
2. Mutate the JSON in memory (`status`, `started_at`, `completed_at`, `duration_seconds`, `attempts`, etc.).
3. `Write` the **full** board JSON to `.ops-state/<run-id>-board.json`.
4. `Read` the file back; confirm the mutated field(s) match. If not, stop and rewrite — **do not** call `TodoWrite` until verify passes.
5. **Then** `TodoWrite(merge=true, todos=[{id, content, status}])` (or `merge=false` when recreating the full board after `resume`).

Use **separate tool calls** for steps 3–5. Never treat `TodoWrite` as satisfying Non-negotiable #1 or #3.

**Before every subagent spawn:** If the board file does not show the task as `in_progress` with a fresh `started_at`, run the ritual for that transition first.

**Dashboard and `/ops status`:** Derive timing, dependencies, and progress from the board file — not from `TodoWrite`.

### Phase 3 — Dispatch Loop

This is the core orchestration loop. Repeat until all tasks are completed or the user intervenes:

**Step 1 — Scan for ready tasks.** Use the cached state; read the state file from disk only on invalidation events (read-on-change). If the file doesn't exist, stop and re-create it (Phase 2 step 1). A task is ready when `status == "pending"` and all `blocked_by` entries are `"completed"`.

**State cache** — maintain an in-memory snapshot of the last-known state. Invalidate the cache (re-read from disk) on these events only:
- **Bootstrap**: before the first dispatch of each loop invocation (initial read).
- **Task completed**: immediately after Step 4 writes task completion to disk (state file just mutated).
- **Resume / status subcommand**: always re-read on `resume` or `status` — external changes may have occurred.
- **User mid-run command** (`add`, `drop`, `reprioritize`, `do #N next`, `skip`) — re-read after processing the command.
- **Nested skill return** — after any nested-skill call returns, the cache is invalidated. The state file on disk may have been written by the team manager in the same turn (via the `pending_nested_skill` write-before step). Re-read before processing the return. See `state-schema.md` and Non-negotiable #10.

Between these events, operate on the cached snapshot. Do not re-read on routine Step 1 → Step 2 → Step 3 cycles within one dispatch iteration.

> **Safety note:** If the user manually edits the state file JSON between invalidation events, those changes won't be visible until the next invalidation trigger. Manual out-of-band edits are not a supported workflow; the safety note in `state-schema.md` documents this caveat.

**Step 2 — Batch parallel work.** Dispatch tasks on different files/modules concurrently up to `--parallel N`. Never parallelize tasks that share files. When in doubt, run sequentially.

**Step 3 — Dispatch agents.** For each task (or parallel batch):

1. Update the state file: set `status` to `"in_progress"`, record `started_at` with ISO-8601 timestamp, record `model_used`. Write the state file to disk. **Cursor only:** follow § **Cursor: state file sync** (Write → Read verify → then `TodoWrite`) in the same turn before step 2.
2. **Resolve description_ref (LB2 — mandatory before dispatch):** If the task has a `description_ref`, read the plan doc at the pointer (e.g., `Read("docs/plan/<name>-plan.md")`) and extract the referenced section to obtain the full task description, acceptance criteria, and implementation notes. Use this resolved content to compose the Context, Scope, and Acceptance Criteria sections of the brief. The final agent prompt must be fully self-contained — `description_ref` is resolved here so the agent never receives a bare pointer. If the task has `description_inline` instead, use that directly.
3. **Evaluate the memory-injection predicate (Lever 1) and call the selector (Lever 2).** Before spawning an agent, determine whether to inject `## Project Knowledge` into the brief. The rules below say when to skip (the user turned it off, the agent ignores project rules, or a retry already carried the notes) and how to avoid injecting the section twice.

   **Override flag.** The run-level flag `--memory-inject=off|auto|always` controls injection:
   - `off` — skip injection unconditionally for every dispatch in this run.
   - `auto` (default) — apply the full predicate below.
   - `always` — skip the predicate; call the selector with `enable_agent_type_intersection=false` (pure always-on tier output, no agent-type tag filtering).

   **Mechanical agents.** Some agents are convention-blind: their output does not change based on project rules because they are read-only analysis tools or mechanical revert agents. These agents derive no benefit from rule injection and incur unnecessary brief overhead. The list at v1 is:

   > **Literal constant definition — keep fenced.** The block below is a code-style definition used for reference, not a user-facing UI output. Do not unfence it.

   ```
   MECHANICAL_AGENTS = {code-intel, corpus-search, work-verifier, preflight, change-analyzer, rollback}
   ```

   An agent belongs on this list when project conventions do not change its output — read-only or convention-blind agents that neither author files nor apply coding standards. To add or remove an agent from the list, edit it here.

   **Predicate decision tree.** Evaluate top-to-bottom; the first matching branch governs:

   | Condition | Action |
   | :--- | :--- |
   | `--memory-inject=off` | Skip injection. Proceed to spawn without `## Project Knowledge`. |
   | `agent_type` ∈ `MECHANICAL_AGENTS` | Skip injection. Proceed to spawn without `## Project Knowledge`. |
   | `attempt > 1` AND the prior handoff body contains the exact sentinel (a fixed hidden marker the system writes so a later step can detect it) `<!-- project-knowledge:carried -->` | Skip injection (section was already carried in the prior attempt's handoff). |
   | `--memory-inject=always` | Call selector with `enable_agent_type_intersection=false`. Inject if bytes returned. |
   | Otherwise (default `auto` path) | Call selector with `enable_agent_type_intersection=true`. Inject if bytes returned. |

   **Handoff-detection rule (sentinel marker).** On retry (attempt > 1), the predicate searches the prior handoff body for the sentinel marker `<!-- project-knowledge:carried -->`. The prior handoff body is the content of the file referenced by the upstream task's `handoff_file` field in the state JSON. Detection is **exact-byte grep** — no regular expressions, no whitespace tolerance, no case folding. The literal byte sequence `<!-- project-knowledge:carried -->` must match or the predicate proceeds as if the sentinel is absent.

   Behavior on detection: skip injection — the downstream agent already received the section in the prior attempt's handoff and the content is considered carried.
   Behavior on no detection: proceed with the normal predicate flow above.

   **Why the sentinel approach?** A naïve substring scan for `## Project Knowledge` at the start of a line produces false positives when a handoff body contains a Markdown code fence that quotes a brief structure as an example — code fences do not indent their content, so column-0 matching cannot distinguish a real heading from a fenced example. The HTML-comment sentinel does not appear inside rendered Markdown code fences in normal output, eliminating this false-positive class.

   **Failure shapes (both non-correctness-breaking):**
   - Sentinel emitted but not detected on retry → predicate proceeds, brief carries the section a second time. Cost: duplicate bytes on attempt-2+ dispatches. Recovery: tighten the sentinel grep or verify the handoff file was written correctly.
   - Sentinel detected but content removed from the prior handoff (e.g., the handoff file was edited after the orchestrator wrote it) → predicate skips, agent retry operates without rules. Cost: same posture as pre-injection behavior. Recovery: none needed; the next fresh dispatch will re-inject.

   **Selector call.** Call the function documented in `skills/cross-memory/brief-injector.md` with a context object derived from the dispatch state:
   - `agent_type` — the task's `agent_type` value from the state file
   - `task_subject` — the task's `subject` field
   - `stage` — the task's `stage` field
   - `attempt` — the current attempt number
   - `prior_handoff` — full body of the upstream handoff file, or `None` if attempt == 1
   - `enable_agent_type_intersection` — `true` for default-inject, `false` for `always`-override
   - `budget_chars` — pass the call-site budget (default: read `max_brief_inject_chars` from `~/.cross-memory/config.yaml`, default `4096`)

   **Post-selector rule.** If the selector returns empty bytes, omit `## Project Knowledge` entirely — do not render an empty heading. If the selector returns non-empty bytes, render them as the `## Project Knowledge` section in the brief, placed **between `## Context` and `## Scope`**. After rendering, append the sentinel marker on its own line at the bottom of the section:

   > **Literal sentinel string — keep fenced.** The block below is an exact byte sequence written into agent brief text, not a user-facing UI output. Do not unfence it.

   ```
   <!-- project-knowledge:carried -->
   ```

   This sentinel enables the next attempt's predicate to detect that the section was carried, avoiding re-injection.

   **Cursor first-time awareness banner.** When the active harness is **Cursor** AND this is the first dispatch in the current session that fires injection (i.e., the selector returned non-empty bytes AND the run-level state field `memory_inject_banner_emitted` is not yet `true`), emit the following one-line banner to the user before the dispatch:

   > **Literal banner text — keep fenced.** The block below is the exact one-line string emitted to the user as a plain text message, not a formatted dashboard output. Do not unfence it.

   ```
   [memory-inject] Subagent briefs now carry ## Project Knowledge from your canonical store; top-level Cursor turns do not yet see this — see adapter-cursor.md §6 for the trust-model implication.
   ```

   After emitting the banner, set `memory_inject_banner_emitted: true` in the state file. The banner fires exactly once per session. Under **Claude Code**, suppress this banner — the top-level turn already sees `[CROSS-MEMORY]` injected by the always-on tier, so there is no trust-model inversion to disclose. At v1.1, once Cursor's `update_sentinel_block` lands and the top-level turn also sees the canonical store, this banner becomes unnecessary; the harness-conditional remains in place but evaluates to false.

4. Spawn the agent via the **Agent** tool using the task's `agent_type` from the state file. Follow the dispatch procedure below.
5. For parallel batches, issue all Agent tool calls in a **single message** so they run concurrently.

**Agent Dispatch Procedure** (applies to ALL agent dispatches throughout the workflow, not just Phase 3):

The Agent tool's `subagent_type` parameter accepts any agent type that has a definition file at `~/.claude/agents/` (Claude Code) or `~/.cursor/agents/` (Cursor). All agents in this taxonomy are registered `subagent_type` values in both environments. For each dispatch:

   a. **Manager read (frontmatter only):** Open `~/.claude/agents/<agent_type>.md` for `<agent_type>` from the state file; extract `model` from YAML frontmatter **only**. Never read or retain the agent body in the team manager's context — YAML frontmatter is the sole manager read; the spawned agent loads the full definition via the self-read prompt (rule e).
   b. **`model`**: Set from the agent's frontmatter `model` field (e.g., `"sonnet"`, `"opus"`).
   c. **`subagent_type`**: Always set to the task's `agent_type`. All agents with definition files at `~/.claude/agents/` are registered `subagent_type` values — no whitelist check is needed. The agent's definition still materializes via the self-read prompt (rule e) for full context.
   d. **`description`**: Always set to just `"<task subject>"`. The UI prefixes the `subagent_type` name automatically — wrapping the description with the agent_type (e.g., `"executor(Implement auth middleware)"`) produces double-labeling: `executor(executor(Implement auth middleware))`.
   e. **`prompt`**: Compose using the self-read template below, followed by the task brief (see Agent Briefing Format). The agent reads its full definition as its first action — self-containment is preserved because the agent body materializes in the agent's own context, not the team manager's.

**Self-read prompt template** (use verbatim, substituting `<agent_type>` and `<task brief>`):

> **Literal prompt string — keep fenced.** This is the exact text passed to each spawned agent as its prompt, not a user-facing UI output. Do not unfence it.

```
You are running as agent type: <agent_type>.

**First action:** Read `~/.claude/agents/<agent_type>.md` in full before any other work.

**Before any completion claim** — re-read the brief's `## Constraints` in full (load-bearing for scope, evidence, and verdict validity).

---

<task brief here>
```

**Dispatch example:**

> **Code invocation example — keep fenced.** The block below is a code-style invocation example, not a user-facing UI output. Do not unfence it.

```
Agent(
  description: "Implement auth middleware",
  model: "sonnet",
  subagent_type: "executor",
  prompt: <self-read template + task brief>
)
UI renders: executor(Implement auth middleware)
```

DO NOT set `description: "executor(Implement auth middleware)"` when `subagent_type: "executor"` is set.
This produces `executor(executor(Implement auth middleware))` in the UI.

Use the brief format below.

**Dispatch Log Append (opt-in via `--dispatch-log`)** — when the `--dispatch-log` flag is set, append a one-line entry to `docs/ops-dispatch-log.md` after each dispatch (or direct-tool choice governed by the Subagent Dispatch Decision Framework), capturing kind, framework row, and short description. This applies universally when enabled: Phase 3 dispatch loop, Trivial Dispatch, Brainstorm Gate, Phase 1a scoper/critic, Phase 2.5 preflight, and every other agent dispatch. When the flag is not set, skip entirely — do not touch the log file. The log is persistent across runs and serves as the audit trail for framework adherence.

> **Reference:** See `~/.claude/skills/ops/dispatch-log.md` for the file location, append procedure, entry format, kinds table, and audit usage. If the file is missing, proceed using the summary above. Read only when `--dispatch-log` is set.

**Foreground vs. Background Dispatch Policy**

Default dispatch is **foreground**; background criteria live in the companion.

> **Reference:** You MUST Read `~/.claude/skills/ops/dispatch-policy.md` for foreground/background decision criteria, batch rules, and interaction with health monitoring and worktree isolation. If the file is missing, default to **foreground** dispatch.

**Nested skill invocations:** When the team manager invokes a nested skill (e.g., `/deslop`, `/clickup`) during the dispatch loop, execute the write-before / clear-after ritual to prevent the turn from ending on the nested skill's return. The ritual has eleven steps (5 write-before + 6 clear-after):

- **Write-before** (immediately before the nested-skill call): (1) build the `pending_nested_skill` record with fields `skill`, `invoked_at`, `resume_phase`, `resume_notes`; (2) read the state file from disk; (3) set the `pending_nested_skill` field on the root object; (4) write the state file to disk; (5) issue the nested-skill call.
- **Clear-after** (immediately after the nested skill returns, in the same turn): (1) read the state file from disk (cache was invalidated — see Step 1); (2) read `pending_nested_skill.resume_phase` and `resume_notes` to identify where to resume and how to proceed; (3) capture any output the nested skill produced that downstream phases need — write it into a handoff file where one exists, or hold it in-turn for the next agent's brief when no handoff procedure applies; (4) set `pending_nested_skill` back to `null`; (5) write the state file to disk; (6) execute the `resume_phase`-specified next action. **Do not end the turn.** See Non-negotiable #10.

**Step 4 — Process results.** When an agent returns, **immediately** update the state file: record `completed_at` with ISO-8601 timestamp, calculate and store `duration_seconds`, increment `attempts`. Write the state file to disk. **Cursor only:** after Write, Read-verify per § **Cursor: state file sync**, then update `TodoWrite` for any `status` change in the outcome table below. `TodoWrite` alone does not satisfy Non-negotiable #3. (Non-negotiable — see #3.)

After updating timing, check elapsed time of all in-progress background agents against their estimates. Emit a `⚠️ SLOW` warning when elapsed exceeds 1.5× estimate, or `🔴 OVERRUN` when elapsed exceeds 2.5× estimate. Warnings are emitted once per threshold crossing per task. For tasks with `estimate_source: "ops"` (rough estimates), suppress SLOW and emit OVERRUN only.

**Health-action sub-step (background agents only).** After the `⚠️ SLOW` / `🔴 OVERRUN` emission, the orchestrator evaluates the **sustained-`OVERRUN`** trigger for each in-progress **background** agent. An agent is in *sustained* `OVERRUN` when **either** holds:

- its elapsed time has stayed past the **2.5× display threshold** across **N = 2 consecutive check-in events** (provisional — pending more timing data); **OR**
- its elapsed time has crossed a **higher multiple of the 2.5× display threshold — `≥ 4× estimate`** (provisional — pending more timing data).

Either condition is sufficient in the structural definition; the current **provisional calibration requires BOTH** (N = 2 AND ≥ 4×) to hold before firing, pending real health-action telemetry. When that telemetry accumulates, the values can be re-derived and the provisional flag dropped.

The trigger is a **prompt to diagnose, not a decision to act** — firing it dispatches the read-only `work-verifier` and does not by itself re-dispatch or mutate anything. It is a **third, distinct number**, not to be conflated with: the **2.5× display threshold** (`phase-dispatch.md:466`, which lights `🔴 OVERRUN`; a single instantaneous 2.5× crossing never fires this sub-step, and `⚠️ SLOW` at 1.5× never does); nor the **orphan-suspicion timeout** `MIN(agent-type default, 3× task estimate)` (`work-verifier.md:176`, which drives `👻 ORPHAN?`), which is usually below 3× (for example, an executor on a 15-min estimate → `MIN(15, 45) = 15 = 1×`). The higher multiple is deliberately derived **from the 2.5× display threshold, not the orphan timeout** — anchoring to the orphan timeout would fire *after* the dashboard already showed `👻 ORPHAN?`, an inverted ordering.

The trigger is evaluated at **every** check-in event (after foreground returns, after background completion notifications, before responding to user messages, per `dispatch-policy.md:38-40`) — not only after a foreground return.

**Diagnosis: dispatch the read-only `work-verifier`.** When the sustained-`OVERRUN` trigger fires, the orchestrator dispatches the read-only `work-verifier` to inspect the suspected-orphan's *work-state*. The dispatch uses the **existing mechanical-agent dispatch shape**: no memory injection (`work-verifier` is in `MECHANICAL_AGENTS`, `phase-dispatch.md:346,356`), with a standard `## Task` / `## Scope` / `## Constraints` brief and orphan detection enabled (the same enablement the `status` command uses, `phase-intake.md:12`). The dispatch is read-only — `work-verifier` inspects files and git state and reports findings; it modifies nothing and re-dispatches nothing (`work-verifier.md:14`, `:234-240`). Because the diagnosis is read-only, it requires **no pre-approval in any mode**. The `work-verifier` returns a *work-state* verdict — `completed` / `partial` / `not-started` / `broken` (`work-verifier.md:32-37`) — which describes how much work landed. It does **not** return process liveness; that is outside its lane (`work-verifier.md:234-240`) and is supplied separately by the orchestrator's own dispatch bookkeeping.

**Verdict branch and liveness gate.** The sub-step branches on the `work-verifier` work-state verdict. The **re-dispatch leg additionally requires the orchestrator's own "no live agent" signal**: the task is `in_progress`, its `OVERRUN` is sustained, AND no completion/heartbeat notification has arrived on its background handle — the same "no completion received" signal the `👻 ORPHAN?` flag uses (`phase-completion.md:78`). No path re-dispatches on the bare `OVERRUN` signal alone, and no path re-dispatches on a `partial` work-state while the orchestrator's handle still shows the agent alive.

- **`completed`** — the agent finished and the orchestrator missed the notification. Mark the task done in the state file and write any missing handoff (`work-verifier.md:219`). **No re-dispatch.** Append one `type: health-action` entry to `adaptations` with `action_taken: diagnosed-alive`.
- **`not-started` or `partial` AND the orchestrator confirms no live agent** — confirmed orphan. Enter the recovery path below. Append one `type: health-action` entry to `adaptations` with `action_taken: re-dispatched` (or `action_taken: re-dispatch-escalated` if the recovery escalates).
- **`not-started` or `partial` but the background handle is still live or a notification is pending** — the agent is slow but alive; a `partial` result reflects how much work has landed, not whether the writer is gone. Keep watching. **No re-dispatch.** Append one `type: health-action` entry to `adaptations` with `action_taken: diagnosed-alive`.
- **`broken`** — a wrong-output event, not a liveness event. Route through the existing rollback-then-re-dispatch path (`work-verifier.md:222`, `SKILL.md:417`): dispatch a **rollback** agent to revert the broken output, then re-dispatch the original agent on a clean slate. Append one `type: health-action` entry to `adaptations` with `action_taken: re-dispatched`.

**Recovery rule (confirmed orphan).** A confirmed-orphan recovery is governed by **exactly one** rule: the Failure Handling row "Agent timeout or crash → Retry once with same brief, then escalate" (`SKILL.md:413`) — one same-brief re-dispatch, then escalate to the user if that also orphans or fails (logging `action_taken: re-dispatch-escalated`). The confirmed orphan does **not** enter the four-step Step-4 outcome ladder above and no debugger is interposed — a debugger diagnoses output, build, or logic failures, whereas an orphan is a liveness event the `work-verifier` plus the orchestrator's own signal have already diagnosed. The retry cap stays single-sourced in `SKILL.md:413` by cross-reference; it is not restated here.

The re-dispatched orphan inherits the **same foreground/background and worktree posture** as the original dispatch: a background-with-worktree orphan is re-dispatched background-with-worktree, reusing the surviving worktree if `work-verifier` reports it intact (`work-verifier.md:202-208`), else falling back to the main tree. The re-dispatched orphan is **itself health-monitored** under the same sustained-`OVERRUN` trigger — no exemption. The recursion is bounded by the single-retry `attempts` cap from `SKILL.md:413`: at most one orphan re-dispatch per task; a re-dispatched orphan that also orphans escalates to the user rather than triggering another re-dispatch.

**Parallel safety on re-dispatch.** Before re-dispatching a confirmed orphan, the orchestrator applies the **existing** Parallel Safety Rules (`SKILL.md:376-393`): if the re-dispatched task would touch a file an in-flight sibling task touches, the re-dispatch is **sequenced** (waits for the sibling) rather than parallelized. The `work-verifier` already checks worktree state and file conflicts between parallel tasks as part of its procedure (`work-verifier.md:194-208`); the orchestrator consumes that finding rather than re-deriving it. The re-dispatch is bound by the same parallel-safety floor every dispatch is — no new rule is introduced.

**Mode-conditional surfacing.** In **autonomous mode (`--autonomous`)**, the diagnose-and-recover sequence proceeds automatically (no human is watching), with each action logged to `adaptations`; the *escalation* leg of the reused retry rule (`SKILL.md:413` — "then escalate") still stops for the user, consistent with the Autonomy table's stop conditions (`SKILL.md:426`). In **interactive or supervised mode**, before re-dispatching a confirmed orphan the orchestrator surfaces a one-line note such as: "Task #N's agent appears orphaned (sustained OVERRUN; work-verifier confirms no live agent); re-dispatching per the timeout/retry rule." The one-line note rides the existing check-in cadence (`dispatch-policy.md:38-40`) and does not introduce a new checkpoint. The **read-only diagnosis** (the `work-verifier` dispatch) requires no pre-approval in any mode.

| Outcome | Action |
| :--- | :--- |
| **Passed** — acceptance criteria met | Update state file: `status` → `"completed"`. **Cursor:** Write → verify → `TodoWrite`, then write handoff (see Handoff Documents). Check for newly unblocked tasks. |
| **Failed — 1st attempt** | Re-dispatch with the error appended to the brief. Narrow the scope or add constraints based on what went wrong. |
| **Failed — 2nd attempt** | Dispatch a **debugger** agent (or **debugger-build** if the failure is a build/import/type error) to diagnose the root cause. Use its findings to re-brief the original agent with a corrected approach. |
| **Failed — 3rd attempt** | Escalate model (e.g., sonnet → opus) and re-dispatch with full error history. Skip if already on opus. See Model Escalation in Adaptability. |
| **Failed — 4th attempt** | Escalate to the user with: the task, all attempts, errors, debugger findings, and your diagnosis. Pause this chain; continue other independent chains. |
| **Blocked** — agent hit an external dependency or environment issue | Create a new blocker task describing the issue. Pause dependent chain. Flag to user. |
| **Scope issue** — agent says the plan is wrong or incomplete | Pause chain. Ask the user whether to re-plan or adjust. |
| **NEEDS_CLARIFICATION** — brief is well-formed but agent has one clarifying question before starting | See handling below. |

**NEEDS_CLARIFICATION handling:**

- **Interactive mode:** Present the agent's question and context to the user verbatim. Get the answer. Re-dispatch the same agent with the answer appended to `## Context` under a heading like `**Clarification answer:**`.
- **Autonomous mode:** The team manager answers if it has the information from the state file, plan doc, or prior handoff context. If it does not have the information, escalate to the user (same as interactive mode for this question).
- **Round-trip cap:** Allow at most one NEEDS_CLARIFICATION round-trip per task. If the re-dispatched agent returns NEEDS_CLARIFICATION a second time, treat it as a **Scope issue** and escalate to the user — do not answer autonomously a second time.
- Do not mark the task `failed` or increment the attempt counter on a NEEDS_CLARIFICATION return. The re-dispatch after clarification is attempt 1.

Orphan detection is handled by the **work-verifier** agent (see `~/.claude/agents/work-verifier.md`), which includes timeout budgets per agent type and orphan detection heuristics.

**Budget governor (model-escalation consultation).** This sub-step runs only when the user set a run-level dispatch-count ceiling with `--budget`. When no budget is set, the entire sub-step is a strict no-op: there is no accumulator, no consultation, and no `budget` object written to the state file, and every path below behaves byte-for-byte as it does on a run without a budget.

When a budget **is** set, the orchestrator maintains `budget.consumed_so_far` (see `state-schema.md`) as a running count of dispatches in the run, incrementing it as dispatches complete. The accumulator only counts; it **never interrupts, kills, or re-dispatches an agent that is already running** to enforce the budget — in-flight work always runs to completion under the existing parallel-safety rules. The governor is consulted only *before* a new, not-yet-started cost-affecting action.

Before a **model escalation** — the "Failed — 3rd attempt" escalate-model action in the outcome table above, where a task is about to be retried on a higher model tier — the orchestrator consults the budget:

- **Near ceiling (a fixed default of 80% of the ceiling consumed, first crossing only).** Surface a one-line advisory — "budget ~80% consumed; the next escalation would spend more" — and **proceed** with the escalation. The note is informational and **never blocks, in any mode** (interactive, supervised, autonomous). It fires **once per threshold crossing**: set `budget.near_note_fired` so subsequent choice points below the at-ceiling line stay silent and the run does not degrade into confirmation-prompt noise. Append a `type: budget-escalation` adaptation with `action_taken: budget-near`.
- **At ceiling (this escalation would cross the ceiling).** **Escalate to the user** — in interactive, supervised, **and** autonomous mode alike; like a blocker, a budget ceiling is a decision point the user must resolve, never silently auto-resolved. Flush `budget.consumed_so_far` and `budget.near_note_fired` to the state file **before** the escalation surfaces, so a `resume` mid-escalation recovers the budget context. The escalation states the task, the action about to be taken (escalate this task to the higher model tier), the estimated marginal cost (one more dispatch), and exactly three options: **spend it** (proceed with the escalation), **defer the task with user approval**, or **stop the run**. It **never** offers "silently drop the task" — hitting the ceiling escalates; it never drops, skips, or marks-done a task to stay under budget. Record the user's resolution with the matching `action_taken` (`budget-escalated` when the escalation surfaces, then `budget-spent` or `budget-deferred` for the resolution).

**Escalation composition (one decision point, never two stacked stops).** When an at-ceiling budget escalation and the existing "Failed — 4th attempt" escalate-to-user action fire on the **same task**, they compose into **one** decision point: the budget trade-off is surfaced *as part of* that single escalate-to-user stop, not a second stop layered on top of it.

**Never above a correctness gate.** This consultation is wired only in front of the model-escalation choice. It is **never** placed above the Verify → Fix loop or its 3-loop cap, the agent-level verification-gate ritual (`verification-gate.md`), the deliverables-on-disk / timing / lane non-negotiables, or the security-review stage. A budget ceiling can defer or escalate a *cost* choice; it can never cause a correctness gate to be skipped, shortened, or marked satisfied without fresh evidence.

**Step 5 — Stage transition check.** When all tasks in a pipeline stage finish:

**Reflection beat (pipeline route only).** Before rendering the stage summary and dashboard, perform one short self-critique: given what the stage that just finished produced, does the remaining plan still hold — is any downstream task now redundant, mis-sequenced, or under-specified? Write the answer as a single bounded paragraph (one paragraph, roughly 80 words or fewer) and append it to the run-level `adaptations` array with `type: reflection`, the finishing stage, and an `action_taken` value. Do this exactly once per stage transition. The beat runs only on the `pipeline` route — the trivial route has no stage transitions, so it never fires there. **The beat does NOT fire after the final stage:** once the last stage finishes there is no remaining plan to reflect on, so reflecting would only produce a vacuous "nothing left" entry. Fire it only on transitions *into* a subsequent stage. If nothing is flagged on a firing transition, still write a single-line "no remaining-plan concern" entry with `action_taken: logged`, so the log shows the beat ran.

The beat is advisory and additive-only. Branch on what it surfaces:

- **Addition or re-sequencing** — if the beat finds work to add or a step to re-order, route it through the existing Mid-run plan adjustment mechanisms (see Adaptability) and record the entry with `action_taken: proposed-addition` or `proposed-resequence`. Both are already-allowed adaptations. **A re-sequence may only re-order tasks — it must never orphan, drop, or cancel a task.** A re-sequence that would remove a task from the plan is a scope reduction in disguise: treat it as a reduction and escalate (next branch) rather than recording it as `proposed-resequence`.
- **Reduction** — if the beat finds work that should be removed (a task now redundant), do not remove or mark-cancelled any task. Escalate to the user and record the entry with `action_taken: escalated`. Scope reduction always requires user approval (see the Adaptability guardrail). When **two or more** remaining tasks are now-redundant, that case routes through the Re-plan escalation sub-step's scope-drop gate rather than the single-task escalate path above.

These two branches are mutually exclusive for a given finding. The beat only writes the note and, at most, proposes through the existing mechanism or escalates. It does not call the planner, does not re-score estimates, and does not mutate the dependency graph itself.

**Re-plan escalation (pipeline route only).** When the reflection beat finds material remaining-graph invalidation — meaning it identifies a case that exceeds what the advisory beat can handle — the orchestrator executes a controlled re-plan of the unfinished task graph. This sub-step is the controlled escalation target the beat hands to when it cannot resolve the problem in-place; the beat itself is left capped at "does not call the planner."

**Trigger predicate.** The re-plan fires only when the finished stage's real output makes **two or more** remaining `pending` or `blocked` tasks impossible-as-written, now-redundant, or dependent on an assumption the stage falsified. The evaluation is post-stage against the finished stage's real output, at the same moment as the reflection beat — it is never pre-emptive. Single-task drift stays in the existing Mid-run plan adjustment table (see Adaptability); a whole-plan invalidation that renders every remaining task invalid still escalates to the user rather than triggering a re-plan. A re-plan that would change nothing is a no-op (idempotent re-evaluation — if the planner's revision leaves every pending/blocked task identical, no board rewrite occurs and the event is logged with `action_taken: logged`).

Two path-exclusion rules apply at this evaluation point. First, the Step 4 / agent-return Scope-issue path (around line 440: "Scope issue — agent says the plan is wrong or incomplete → Pause chain. Ask the user whether to re-plan or adjust.") pre-empts this sub-step for the same stage: a paused chain never reaches a clean stage boundary, so the two never both fire for a single stage. Second, if two or more remaining tasks are now-redundant (rather than impossible-as-written or falsely-assumed), those tasks must route through the scope-drop gate (user approval) rather than being silently removed — redundancy-removal is not laundered past the reflection beat's escalate-as-reduction branch.

**Boundary guard.** The re-plan fires only at a clean stage boundary: all tasks in the finished stage have `status: completed`, no parallel-dispatch window is open, and no task is `in_progress`. When a parallel window is still open (one or more tasks are still running), the re-plan waits — it does not interrupt in-flight work. Tasks that are `in_progress` or in an open parallel window are never revision candidates; only `pending` and `blocked` tasks are eligible. This uses the same stage-boundary point the reflection beat uses — not a new boundary. Additionally, the re-plan trigger is suppressed when the run is wrapped in `ralph` (see the SKILL.md Ralph Loop Integration section): in that mode, ralph owns per-iteration re-planning and the team manager must not interpose a mid-run re-plan.

**Cap guard.** A default of **1** in-flight re-plan is allowed per run; a second re-plan requires explicit user approval at the checkpoint before it may proceed. The cap is enforced by counting every `adaptations` entry with `type: replan`, including entries with `action_taken: replan-escalated` — escalated re-plan attempts count against the cap. When the cap has been consumed by a prior re-plan (applied or escalated), the orchestrator surfaces the situation to the user and requests explicit approval before dispatching the planner again.

**Planner re-dispatch.** When the trigger fires at a clean boundary within cap, the orchestrator dispatches the `planner` agent on the `pending` and `blocked` tasks, accompanied by the finished stage's real output as evidence. Completed work is passed as immutable context — it is never a revision candidate. The planner updates the existing `plan_file` in place (it does not create a new plan document). The planner's brief instructs it to: keep stable slugs for surviving tasks; for replaced tasks, retain their existing ids while assigning a new heading and anchor; give genuinely new tasks a fresh id and heading. The planner's lane is plans-only: it does not estimate, implement, or review. The mid-run re-plan does not route back through the project-scoper for re-estimation — it reuses the critic loop only.

**Critic loop re-entry.** After the planner delivers the revision, it re-enters the existing Phase 1a Critic Verdict Handling loop — see `plan-validation.md` for the REVISE/ACCEPT/REJECT table and the hard cap on revision loops. The mid-run re-plan does not carry its own separate cap; it reuses the Phase 1a loop wholesale, including its cap number and escalation condition (which are single-sourced in `plan-validation.md` and are not restated here). On a critic ACCEPT — and only if no scope drop is required — the board rewrite proceeds. On `ACCEPT WITH RESERVATIONS`, the team manager stops and surfaces the reservations to the user before any board rewrite, regardless of mode.

**Cap-exhaustion escalation.** When the critic loop reaches its cap mid-run without converging on an ACCEPT, the orchestrator escalates to the user with the critic's findings and the remaining graph marked "known-invalid — re-plan did not converge." Both silent resume of the invalidated plan and silent abandonment of the run are forbidden. The event is logged with `action_taken: replan-escalated`. This is the Phase 1a cap-exhaustion posture applied at a mid-run stage boundary — see `plan-validation.md` for the canonical escalation condition.

**Board-rewrite invariants.** On a critic-ACCEPTED, non-scope-dropping revision, the board rewrite proceeds subject to five invariants: (a) only `pending` and `blocked` tasks are revision candidates — no other status is touched; (b) `completed` and `in_progress` tasks are immutable; (c) the run-id, state file, and `plan_file` are retained — no new run, no new plan document; (d) `blocked_by` chains remain valid after rewrite — no orphaned or dangling edges; (e) for every revised task, the stored `description_ref` anchor is re-derived from the task's (possibly new) heading slug in the updated `plan_file`, so the Phase 3 Step 3 heading-grep (`state-schema.md:225`) resolves — no `pending` or `blocked` task is left with a `description_ref` whose heading is absent from the updated plan document. The board write is ordered last in the transition so that an interrupted rewrite never points the board at headings the plan document lacks.

**Scope-drop gate.** A critic ACCEPT validates quality but does not grant scope authority. If the critic-ACCEPTED revision drops any committed task (any task already on the board), the orchestrator stops and presents the proposed removal to the user for explicit approval before applying the rewrite, regardless of mode — this applies in interactive, autonomous, and supervised modes alike. The two gates are stacked, not substituted: critic ACCEPT is required first, then the scope-drop gate clears the removal. The SKILL.md Adaptability no-silent-scope-reduction guardrail ("The team-manager … must not silently remove tasks or reduce scope. Scope reduction always requires user approval.") is unchanged. A user-approved scope-dropping re-plan logs `action_taken: replan-escalated`.

**Mode-conditional surfacing.** When a re-plan proceeds (critic ACCEPT, no scope drop, or a user-approved scope-dropping re-plan), the surfacing behavior follows the existing Step 5 mode branch: interactive surfaces a one-line checkpoint to the user before resuming the dispatch loop; autonomous proceeds on a non-scope-dropping result with the logged `type: replan` adaptation recorded in `adaptations`, EXCEPT a scope-dropping re-plan always stops for user approval even in autonomous mode; supervised is already checking in per-dispatch, so the stage-boundary note covers it. The promotion pattern follows the same one-line checkpoint and logged-adaptation surfacing pattern the existing Step 5 mode branch uses — the procedure is not duplicated here.

| Mode | Behavior |
| :--- | :--- |
| Interactive (default) | Show stage summary + dashboard (`phase-completion.md`; full if ≥ 3 tasks; one-liner per task if ≤ 2). Ask user to proceed, adjust, or stop. |
| Autonomous | Proceed automatically. Stop on escalation/scope issues and any brainstorm design-approval checkpoint. |
| Supervised | Already checking in per-task — just note the stage boundary. |

**Step 6 — Loop.** Return to Step 1.
