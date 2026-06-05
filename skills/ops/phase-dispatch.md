# Phase 2.5 preflight and Phase 3 dispatch

> **Parent:** `~/.claude/skills/ops/SKILL.md` — Non-negotiables, Agent Briefing Format, and Handoff Documents live in the hub.

### Phase 2.5b — Code Intelligence Preflight (advisory)

Before each code-modifying executor dispatch in Phase 3 Step 2, the team manager may dispatch a **code-intel** agent to perform an impact analysis. This phase is *advisory* (informs the brief but never blocks it) — its output enriches the executor's brief but never blocks it.

#### Trigger predicate

Evaluate the predicate `(ii) OR (iv)` against each code-modifying task at Phase 3 Step 2, before composing the executor brief:

- **(ii)** `files_touched > 1` — the task touches more than one file.
- **(iv)** The task brief contains at least one *risk keyword* (case-insensitive match): `refactor`, `rename`, `delete`, `breaking change`, `migrate`, `deprecate`, `extract`, `move`.

If the predicate matches, dispatch `code-intel` synchronously (wait for the report path) before composing the executor brief. Synchronous dispatch closes the door on race conditions with mid-Phase-3 work.

#### Flags

- `--code-intel` — alias for `--code-intel=always`. Fires `code-intel` on every code-modifying task regardless of predicate.
- `--code-intel=off` — disables Phase 2.5b for the entire run. This is additionally a no-op for non-code-modifying tasks, which the trigger predicate already excludes from Phase 2.5b.

#### Dispatch trigger point

The team manager dispatches `code-intel` during **Phase 3 Step 2 (Batch parallel work), before each code-modifying executor dispatch**. The team manager evaluates `(ii) OR (iv)` against the task's `files_touched` and brief contents at that moment; if matched (or `--code-intel` is set), dispatches `code-intel` synchronously and waits for the JSON response before composing the executor brief.

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

#### State cache invalidation

After `code-intel` returns from a Phase 2.5b dispatch, the team manager invalidates (marks the cached copy stale so it is re-read from disk) its state cache (read-on-next-Step-1) before composing the executor brief. `code-intel` is an agent rather than a nested skill, so the nested-skill-return rule at Phase 3 Step 1 does not strictly fire on its own — but because `code-intel` writes a report to disk that the executor must subsequently read, invalidation is required to keep the executor's view consistent.

#### Refusal handling

If `code-intel` returns `status: refused` for any reason (timeout, symbol-not-found, hard-cap hit, malformed brief, lane violation, DB corruption), the team manager:

1. Logs the refusal in the dispatch log when `--dispatch-log` is set (standard entry format: timestamp, agent name, task ID, brief excerpt, return status `refused`).
2. Attaches the refusal reason to the executor's brief so the executor knows the consultation was attempted but did not yield results.
3. Proceeds. Phase 2.5b is *advisory* — refusal does not block the executor.

#### Dispatch log entry

When `--dispatch-log` is set, Phase 2.5b dispatches append to `docs/ops-dispatch-log.md` following the standard dispatch-log entry format (timestamp, agent name, task ID, brief excerpt, return status). When `--dispatch-log` is not set, no log entry is written — matching the existing per-dispatch behavior in `dispatch-log.md`.

#### Attaching to the executor brief

After a successful Phase 2.5b dispatch, append a `Code Intelligence Context:` block to the executor's brief:

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

Evaluate the predicate `(i) OR (ii) OR (iii)` against each dispatch where `agent_type` ∈ `{executor, debugger, documentor}` at Phase 3 Step 2, before composing the consumer brief. When Phase 2.5b also matches for an `executor` task, run Phase 2.5b first, then Phase 2.5c (see **Dual preflight sequence** below).

- **(i) Investigation keyword** — the task brief contains at least one (case-insensitive): `find evidence`, `where is`, `where are`, `grep for`, `search for`, `locate`, `verify that`, `confirm that`, `investigate`, `trace`, `mentions`, `documented in`, `free-text`, `corpus`, `string match`.
- **(ii) Consumer agent + non-symbol task** — `agent_type` ∈ `{debugger, documentor}` AND the **symbol-extraction algorithm** (below) returns no extractable primary symbol. Clause (ii) passes only when all three ordered checks fail.
- **(iii) Rename/migration cue** — code-modifying task (`agent_type == executor`) AND the brief contains at least one *risk keyword* from Phase 2.5b (`refactor`, `rename`, `delete`, `breaking change`, `migrate`, `deprecate`, `extract`, `move`) AND at least one textual migration cue: `update references`, `rename mentions`, `docs mention`, `string replace`, `across repo`, `all occurrences`.

If the predicate matches (and `--corpus-search=off` is not set), dispatch `corpus-search` synchronously (wait for the report path) before composing the consumer brief.

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

The team manager dispatches `corpus-search` during **Phase 3 Step 2 (Batch parallel work), before composing the brief** for tasks where `agent_type` ∈ `{executor, debugger, documentor}`. Evaluate `(i) OR (ii) OR (iii)` against the task brief at that moment; if matched (or `--corpus-search` is set), dispatch `corpus-search` synchronously and wait for the JSON response before composing the consumer brief.

**Dual preflight sequence (when both Phase 2.5b and 2.5c match on an executor task):**

1. Dispatch **code-intel** (Phase 2.5b); wait for JSON response.
2. Invalidate state cache (read-on-next-Step-1).
3. Dispatch **corpus-search** with `query_type: "trace_reference"` and seed `query` from the symbol-extraction algorithm above; if all extraction checks fail, use the first non-empty line of `## Task` prose as fallback seed. Wait for JSON response.
4. Invalidate state cache again.
5. Attach **both** `Code Intelligence Context:` and `Corpus Search Context:` blocks to the executor brief.

When Phase 2.5b did **not** run, use `query_type: "evidence_search"` with `query` derived from the task subject or investigative string in the brief.

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

#### State cache invalidation

After `corpus-search` returns from a Phase 2.5c dispatch, the team manager invalidates its state cache (read-on-next-Step-1) before composing the consumer brief. `corpus-search` is an agent rather than a nested skill, so the nested-skill-return rule at Phase 3 Step 1 does not strictly fire on its own — but because `corpus-search` writes a report to disk that the consumer must subsequently read, invalidation is required to keep the consumer's view consistent.

#### Refusal handling

If `corpus-search` returns `status: refused` for any reason (timeout, hard-cap hit, malformed brief, lane violation, git repo unavailable), the team manager:

1. Logs the refusal in the dispatch log when `--dispatch-log` is set (standard entry format: timestamp, agent name, task ID, brief excerpt, return status `refused`).
2. Attaches the refusal reason to the consumer's brief so the consumer knows the consultation was attempted but did not yield results.
3. Proceeds. Phase 2.5c is *advisory* — refusal does not block the consumer.

#### Dispatch log entry

When `--dispatch-log` is set, Phase 2.5c dispatches append to `docs/ops-dispatch-log.md` following the standard dispatch-log entry format (timestamp, agent name `corpus-search`, task ID, brief excerpt, return status). When `--dispatch-log` is not set, no log entry is written — matching the existing per-dispatch behavior in `dispatch-log.md`.

#### Attaching to the consumer brief

After a successful Phase 2.5c dispatch, append a `Corpus Search Context:` block to the consumer's brief (`executor`, `debugger`, or `documentor`):

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

**Step 5 — Stage transition check.** When all tasks in a pipeline stage finish:

| Mode | Behavior |
| :--- | :--- |
| Interactive (default) | Show stage summary + dashboard (`phase-completion.md`; full if ≥ 3 tasks; one-liner per task if ≤ 2). Ask user to proceed, adjust, or stop. |
| Autonomous | Proceed automatically. Stop on escalation/scope issues and any brainstorm design-approval checkpoint. |
| Supervised | Already checking in per-task — just note the stage boundary. |

**Step 6 — Loop.** Return to Step 1.
