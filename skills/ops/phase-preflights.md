# Phase 2.5b / 2.5c advisory preflights

> **Parent:** `~/.claude/skills/ops/SKILL.md` — Non-negotiables, Agent Briefing Format, and Handoff Documents live in the hub.

These two advisory preflights run before a Phase 3 Step 2 dispatch and enrich the dispatched agent's brief without ever blocking it. **Phase 2.5b** dispatches `code-intel` (impact analysis) before a code-modifying executor; **Phase 2.5c** dispatches `corpus-search` (multi-hop textual evidence) before an `executor`, `debugger`, or `documentor`. The trigger predicate, query-type set, and JSON brief shape differ per phase and are set out in each phase's section. Four sub-steps are common to both and are written once in **Shared preflight blocks** at the end — each phase references them.

## Phase 2.5b — Code Intelligence Preflight (advisory)

Before each code-modifying executor dispatch in Phase 3 Step 2, the team manager may dispatch a **code-intel** agent to perform an impact analysis. This phase is *advisory* — its output enriches the executor's brief but never blocks it.

### Trigger predicate

Evaluate the predicate `(ii) OR (iv) OR (vi)` against each code-modifying task at Phase 3 Step 2, before composing the executor brief:

- **(ii)** `files_touched > 1` — the task touches more than one file.
- **(iv)** The task brief contains at least one *risk keyword* (case-insensitive match): `refactor`, `rename`, `delete`, `breaking change`, `migrate`, `deprecate`, `extract`, `move`.
- **(vi) Information-need hypothesis** — before evaluating the keyword/structural terms above, the orchestrator forms a single categorical hypothesis against the task's **planned** `files_touched` and brief contents (the pre-executor moment): *"I lack the answer that `<query_type>` would give, and that gap is a risk for this task."* The `<query_type>` is bounded to the six code-intel query types listed under the dispatch contract (`find_definition`, `find_callers`, `find_dependencies`, `impact_analysis`, `find_implementations`, `execution_flow`) — no new query type is invented, and no numeric threshold is used; the judgment is categorical. The hypothesis term fires `code-intel` only when **(a)** a genuine, risk-relevant code-intel `query_type` would answer the gap, **and (b)** neither `(ii)` nor `(iv)` matched for this task. It can only *add* the dispatch the keyword/structural path missed.

The keyword/structural predicate `(ii) OR (iv)` is retained **unchanged as an unconditional floor**: any match on `(ii)` or `(iv)` fires `code-intel` regardless of the hypothesis verdict. The wiring is `(ii) OR (iv) OR (vi)` — an `OR`, never an `AND`, never a veto. The hypothesis term `(vi)` can never suppress, gate, or remove a dispatch the keyword/structural path would have fired.

**Dedup invariant (at most once per task/stage).** For a single task/stage, `code-intel` fires **at most once**. The hypothesis term `(vi)` is a no-op when a code-intel preflight already fired for this task/stage **by any path** — the keyword/structural path (`(ii)` or `(iv)`), the `--code-intel=always` flag, or a dual preflight sequence. In all those cases the hypothesis is already answered by the in-flight or returned report, so `(vi)` adds nothing. The hypothesis term only adds a dispatch when no code-intel preflight fired by any path.

If the predicate matches, dispatch `code-intel` synchronously (wait for the report path) before composing the executor brief. Synchronous dispatch closes the door on race conditions with mid-Phase-3 work.

### Budget governor (preflight consultation)

See **Shared preflight blocks → Budget governor**, with `code-intel` as the dispatched agent and the executor brief as the enriched brief.

### Flags

- `--code-intel` — alias for `--code-intel=always`. Fires `code-intel` on every code-modifying task regardless of predicate.
- `--code-intel=off` — disables Phase 2.5b for the entire run. This is additionally a no-op for non-code-modifying tasks, which the trigger predicate already excludes from Phase 2.5b.

### Dispatch trigger point

The team manager dispatches `code-intel` during **Phase 3 Step 2 (Batch parallel work), before each code-modifying executor dispatch**. The team manager evaluates `(ii) OR (iv) OR (vi)` against the task's `files_touched` and brief contents at that moment; if matched (or `--code-intel` is set), dispatches `code-intel` synchronously and waits for the JSON response before composing the executor brief. A hypothesis-added dispatch (matched via `(vi)` alone) uses the **same** JSON-fenced brief and the **same** per-call hard caps as any other Phase 2.5b dispatch (`max_results`, `max_depth`, `max_files`, `max_wall_clock_s` below) verbatim — no new caps and no cap bypass — with the same `output_mode: "disk"` and the same synchronous, advisory, never-blocking behavior: no mode branch and no per-dispatch checkpoint.

### First-time index build

On the first Phase 2.5b dispatch when `.code-intel/index.sqlite` is absent, the agent builds the index synchronously as preflight. The indexer wall-clock counts against `max_wall_clock_s`. The team manager's wait covers both the build and the query.

### Dispatch contract — what the team manager passes in

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

### Dispatch contract — what code-intel returns

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

### Yield record (post-return annotation)

See **Shared preflight blocks → Yield record**, with the executor brief as the composed brief and the six code-intel query types (`find_definition`, `find_callers`, `find_dependencies`, `impact_analysis`, `find_implementations`, `execution_flow`) as the `query_type` set.

### State cache invalidation

See **Shared preflight blocks → State cache invalidation**, with `code-intel` as the agent and the executor as the downstream consumer.

### Refusal handling

See **Shared preflight blocks → Refusal handling**, with `code-intel` as the agent and the executor brief as the enriched brief. A hypothesis-added dispatch (matched via `(vi)` alone) that returns `status: refused` reuses those steps verbatim and records yield `no-yield`.

### Dispatch log entry

See **Shared preflight blocks → Dispatch log entry**, with `code-intel` as the agent.

### Attaching to the executor brief

After a successful Phase 2.5b dispatch, append a `Code Intelligence Context:` block to the executor's brief. A hypothesis-added dispatch (matched via `(vi)` alone) appends the **same** block — the hypothesis path does not invent a different attachment:

> **Literal agent-brief text — keep fenced.** The block below is the exact text appended to the executor's prompt string, not a user-facing UI output. Do not unfence it.

```text
Code Intelligence Context: see .code-intel/runs/<run-id>/impact_analysis-<symbol>.md
  - <one-line summary from the response>
  - <caveat 1, if any>
  - <caveat 2, if any>
```

### Cleanup pointer

Phase 4 step 9 cleans `.code-intel/runs/<run-id>/` (ephemeral, this run only — analogous to `.agents/handoffs/<run_id>/`). Persistent infrastructure (`.code-intel/index.sqlite` and its WAL/SHM sidecars) is **not** Phase 4 cleaned.

## Phase 2.5c — Corpus Search Preflight (advisory)

Before each `executor`, `debugger`, or `documentor` dispatch in Phase 3 Step 2, the team manager may dispatch a **corpus-search** agent to perform a multi-hop textual evidence search. This phase is *advisory* — its output enriches the consumer's brief but never blocks it.

### Trigger predicate

Evaluate the predicate `(i) OR (ii) OR (iii) OR (iv)` against each dispatch where `agent_type` ∈ `{executor, debugger, documentor}` at Phase 3 Step 2, before composing the consumer brief. When Phase 2.5b also matches for an `executor` task, run Phase 2.5b first, then Phase 2.5c (see **Dual preflight sequence** below).

- **(i) Investigation keyword** — the task brief contains at least one (case-insensitive): `find evidence`, `where is`, `where are`, `grep for`, `search for`, `locate`, `verify that`, `confirm that`, `investigate`, `trace`, `mentions`, `documented in`, `free-text`, `corpus`, `string match`.
- **(ii) Consumer agent + non-symbol task** — `agent_type` ∈ `{debugger, documentor}` AND the **symbol-extraction algorithm** (below) returns no extractable primary symbol. Clause (ii) passes only when all three ordered checks fail.
- **(iii) Rename/migration cue** — code-modifying task (`agent_type == executor`) AND the brief contains at least one *risk keyword* from Phase 2.5b (`refactor`, `rename`, `delete`, `breaking change`, `migrate`, `deprecate`, `extract`, `move`) AND at least one textual migration cue: `update references`, `rename mentions`, `docs mention`, `string replace`, `across repo`, `all occurrences`.
- **(iv) Information-need hypothesis** — before evaluating the keyword/structural terms above, the orchestrator forms a single categorical hypothesis against the task's **planned** scope and brief contents (the pre-composition moment): *"I lack the answer that `<query_type>` would give, and that gap is a risk for this task."* The `<query_type>` is bounded to the four corpus-search query types listed under the dispatch contract (`evidence_search`, `locate`, `verify_claim`, `trace_reference`) — no new query type is invented, and no numeric threshold is used; the judgment is categorical. The hypothesis term fires `corpus-search` only when **(a)** a genuine, risk-relevant corpus-search `query_type` would answer a textual-evidence gap, **and (b)** none of `(i)`, `(ii)`, `(iii)` matched for this task. It can only *add* the dispatch the keyword/structural path missed.

The keyword/structural predicate `(i) OR (ii) OR (iii)` is retained **unchanged as an unconditional floor**: any match on `(i)`, `(ii)`, or `(iii)` fires `corpus-search` regardless of the hypothesis verdict. The wiring is `(i) OR (ii) OR (iii) OR (iv)` — an `OR`, never an `AND`, never a veto. The hypothesis term `(iv)` can never suppress, gate, or remove a dispatch the keyword/structural path would have fired.

**Dedup invariant (at most once per task/stage).** For a single task/stage, `corpus-search` fires **at most once**. The hypothesis term `(iv)` is a no-op when a corpus-search preflight already fired for this task/stage **by any path** — the keyword/structural path (`(i)`, `(ii)`, or `(iii)`), the `--corpus-search=always` flag, or the dual preflight sequence. In all those cases the hypothesis is already answered by the in-flight or returned report, so `(iv)` adds nothing. The hypothesis term only adds a dispatch when no corpus-search preflight fired by any path.

If the predicate matches (and `--corpus-search=off` is not set), dispatch `corpus-search` synchronously (wait for the report path) before composing the consumer brief.

### Budget governor (preflight consultation)

See **Shared preflight blocks → Budget governor**, with `corpus-search` as the dispatched agent and the consumer brief as the enriched brief.

### Symbol-extraction algorithm (clause (ii))

Evaluate in order against the resolved task brief (after `description_ref` resolution). Stop at the first successful extraction — if any check yields a symbol, clause (ii) **fails** (corpus-search is not triggered via this clause):

1. **`Symbol:` line** — a line matching `Symbol:` outside Markdown code fences (column-0 or indented prose only; ignore fenced blocks).
2. **First backtick token in `## Task`** — the first backtick-wrapped token in the `## Task` section body.
3. **`def` / `class` / `function` name** — a name following `def`, `class`, or `function` in task prose (outside code fences).

Clause (ii) passes only when **all three checks fail** — no extractable primary symbol → corpus-search eligible for debugger/documentor non-symbol tasks.

### Flags

- `--corpus-search` — alias for `--corpus-search=always`. Fires `corpus-search` on every Phase 3 Step 2 dispatch where the consumer is `executor`, `debugger`, or `documentor`, regardless of predicate.
- `--corpus-search=off` — disables Phase 2.5c for the entire run.

### Dispatch trigger point

The team manager dispatches `corpus-search` during **Phase 3 Step 2 (Batch parallel work), before composing the brief** for tasks where `agent_type` ∈ `{executor, debugger, documentor}`. Evaluate `(i) OR (ii) OR (iii) OR (iv)` against the task brief at that moment; if matched (or `--corpus-search` is set), dispatch `corpus-search` synchronously and wait for the JSON response before composing the consumer brief. A hypothesis-added dispatch (matched via `(iv)` alone) uses the **same** JSON-fenced brief and the **same** per-call hard caps as any other Phase 2.5c dispatch (single-preflight `max_results`, `max_hops`, `max_files`, `max_wall_clock_s`, and the dual-preflight caps, both below) verbatim — no new caps and no cap bypass — with the same `output_mode: "disk"` and the same synchronous, advisory, never-blocking behavior: no mode branch and no per-dispatch checkpoint. The hypothesis term `(iv)` changes only *whether* Phase 2.5c fires — never *how* it composes the brief: a hypothesis-added dispatch follows the **Dual preflight sequence** and standalone seed rules below exactly as a keyword-matched dispatch would.

**Dual preflight sequence (when both Phase 2.5b and 2.5c match on an executor task):**

This sequence applies whenever Phase 2.5b ran for the `executor` task — whether 2.5b matched via its keyword/structural predicate **or** fired via its own hypothesis clause `(vi)`. A hypothesis-added 2.5c dispatch on such a task honors this ordering and these seed rules unchanged; the hypothesis term `(iv)` changes only *whether* 2.5c fires, never *how* the brief is composed once it does.

1. Dispatch **code-intel** (Phase 2.5b); wait for JSON response.
2. Invalidate state cache (read-on-next-Step-1).
3. Dispatch **corpus-search** with `query_type: "trace_reference"` and seed `query` from the symbol-extraction algorithm above; if all extraction checks fail, use the first non-empty line of `## Task` prose as fallback seed. Wait for JSON response.
4. Invalidate state cache again.
5. Attach **both** `Code Intelligence Context:` and `Corpus Search Context:` blocks to the executor brief.

When Phase 2.5b did **not** run (the standalone, non-dual case — including a standalone hypothesis-added 2.5c dispatch), use `query_type: "evidence_search"` with `query` derived from the task subject or investigative string in the brief. The hypothesis clause does not introduce a different seed source — it derives the standalone seed exactly as the existing standalone path does.

### Dispatch contract — what the team manager passes in

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

### Dispatch contract — what corpus-search returns

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

### Yield record (post-return annotation)

See **Shared preflight blocks → Yield record**, with the consumer brief as the composed brief and the four corpus-search query types (`evidence_search`, `locate`, `verify_claim`, `trace_reference`) as the `query_type` set.

### State cache invalidation

See **Shared preflight blocks → State cache invalidation**, with `corpus-search` as the agent and the consumer as the downstream consumer.

### Refusal handling

See **Shared preflight blocks → Refusal handling**, with `corpus-search` as the agent and the consumer brief as the enriched brief. A hypothesis-added dispatch (matched via `(iv)` alone) that returns `status: refused` reuses those steps verbatim and records yield `no-yield`.

### Dispatch log entry

See **Shared preflight blocks → Dispatch log entry**, with `corpus-search` as the agent.

### Attaching to the consumer brief

After a successful Phase 2.5c dispatch, append a `Corpus Search Context:` block to the consumer's brief (`executor`, `debugger`, or `documentor`). A hypothesis-added dispatch (matched via `(iv)` alone) appends the **same** block — including the dual-preflight path-token reflection (`trace_reference-<slug>.md`) where applicable — the hypothesis path does not invent a different attachment:

> **Literal agent-brief text — keep fenced.** The block below is the exact text appended to the consumer's prompt string, not a user-facing UI output. Do not unfence it.

```text
Corpus Search Context: see .corpus-search/runs/<run-id>/evidence_search-<slug>.md
  - <one-line summary from the response>
  - <caveat 1, if any>
  - <caveat 2, if any>
```

When dual preflight ran, the path token reflects `trace_reference-<slug>.md` (where `<slug>` is a short lowercase, hyphen-separated label) instead of `evidence_search-<slug>.md`.

### Cleanup pointer

Phase 4 step 9 cleans `.corpus-search/runs/<run-id>/` (ephemeral, this run only). Unlike code-intel, corpus-search has **no persistent index** — only run-scoped report directories are deleted. **Do not delete** the parent `.corpus-search/` directory or `docs/corpus-search/` (durable human opt-in reports).

## Shared preflight blocks

Each block is written once and parameterized by the dispatched **agent** (`code-intel` for 2.5b, `corpus-search` for 2.5c) and the enriched **brief** (executor brief for 2.5b, consumer brief for 2.5c). Each phase references the block from its own section above; the per-phase trigger predicate, query-type set, and JSON shape stay in that phase's section and are **not** shared.

### Budget governor

This consultation runs only when the user set a run-level dispatch-count ceiling with `--budget`; when no budget is set it is a strict no-op and the preflight fires exactly as it does today. When a budget is set, before firing the advisory preflight the orchestrator consults the budget: at ceiling, it **may skip this low-yield advisory preflight**. Because the preflight is advisory and never-blocking, skipping it never harms correctness; it is declining an optional lookup, **not** a task drop and **not** a scope reduction. A skip records a `type: budget-escalation` adaptation with `action_taken: budget-skipped` (see `state-schema.md`); the task itself still dispatches. The budget never skips, shortens, or marks-satisfied any verification or correctness gate — only this optional, advisory preflight.

### Yield record

After a hypothesis-added dispatch returns, the team manager records one entry in the run-level `adaptations` array (see `state-schema.md`) with `type: preflight-yield`, the categorical yield value, and the answering `query_type` sub-field (one of the per-phase query types named in that phase's section). The yield value is judged against the returned report versus the brief the orchestrator then composes — the post-dispatch moment — and is one of three categories:

- `changed-brief` — the returned evidence altered what the orchestrator wrote into the brief.
- `confirmed` — the evidence was consulted and matched the orchestrator's prior assumption (a useful negative signal).
- `no-yield` — the preflight returned nothing the orchestrator used, **or** the dispatch was refused or returned empty. A refused or empty-report dispatch records `no-yield` with the refusal/empty reason in the `note`.

The team manager **records yield only; it never reads prior yield to decide a dispatch**. This annotation is bookkeeping for a future capability to learn by category; nothing in the preflight consults it.

### State cache invalidation

After the agent returns from the preflight dispatch, the team manager invalidates (marks the cached copy stale so it is re-read from disk) its state cache (read-on-next-Step-1) before composing the brief. The dispatched agent is an agent rather than a nested skill, so the nested-skill-return rule at Phase 3 Step 1 does not strictly fire on its own — but because the agent writes a report to disk that the consumer must subsequently read, invalidation is required to keep the consumer's view consistent.

### Refusal handling

If the agent returns `status: refused` for any reason (timeout, hard-cap hit, malformed brief, lane violation, and the agent-specific causes — symbol-not-found or DB corruption for code-intel, git repo unavailable for corpus-search), the team manager:

1. Logs the refusal in the dispatch log when `--dispatch-log` is set (standard entry format: timestamp, agent name, task ID, brief excerpt, return status `refused`).
2. Attaches the refusal reason to the brief so the consumer knows the consultation was attempted but did not yield results.
3. Proceeds. The preflight is *advisory* — refusal does not block the consumer.

### Dispatch log entry

When `--dispatch-log` is set, the preflight dispatch appends to `docs/ops-dispatch-log.md` following the standard dispatch-log entry format (timestamp, agent name, task ID, brief excerpt, return status). When `--dispatch-log` is not set, no log entry is written — matching the existing per-dispatch behavior in `dispatch-log.md`.
