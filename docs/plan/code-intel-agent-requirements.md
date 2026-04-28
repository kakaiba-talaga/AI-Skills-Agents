# Requirements: `code-intel` Agent

## Summary

The `code-intel` agent is a **code intelligence layer** for the AI-Skills-Agents ecosystem — a native Claude Code / Cursor agent that indexes a project's source tree into a structured *symbol graph* and exposes that graph to other agents and orchestrators through a small, deterministic query API. Where existing agents (executor, debugger, code-reviewer) currently *infer* call relationships, inheritance, and import topology by re-reading code on every invocation, `code-intel` *consults a precomputed index* and returns precise, citable answers. The goal is **prevention-first**: stop downstream agents and orchestrators from guessing at structure they could otherwise look up, and so reduce the rate at which edits silently break callers, implementers, or execution paths elsewhere in the project.

The v1 scope is a single-file agent definition (`agents/code-intel.md`) backed by a persistent SQLite index at `.code-intel/index.sqlite`, deployed via the existing `tooling/deploy.{ps1,sh}` machinery. No MCP, no graph database, no external service, no third-party dependency on `GitNexus` or similar tools. The index is built and maintained by the agent itself using only Claude tools (`Read`, `Glob`, `Grep`, `Bash`, `Write`) plus runtimes already on `PATH` (Python, Node, sqlite3). Six query types are supported in v1, all answered in sub-second time via recursive CTEs on a normalized node/edge schema.

## Design Pivot History

This requirements document reflects a **mid-interview pivot** in v1 architecture. The first half of the interview converged on a *stateless* design: the agent would re-derive structural facts on every query by walking the codebase fresh with `Read`/`Grep`/`Bash`, with no persistent index. That model survived several rounds before the user surfaced two concerns that broke it.

First, latency: re-deriving a call graph for `impact_analysis` on a non-trivial repository (thousands of files) on *every* `/ops` Phase 2.5b invocation would balloon executor wall-clock and defeat the prevention-first invariant — agents would simply skip the consultation under time pressure. Second, consistency: stateless derivation made cross-query consistency hard to guarantee, since two queries seconds apart could see slightly different graphs if files changed between them.

The user explicitly chose **Path α** — a persistent SQLite-backed index living at `.code-intel/index.sqlite`, rebuilt on git-SHA staleness, queried via recursive CTEs. SQLite is a *file*, not a service, so the "no external dependency" and "no MCP" constraints still hold. The index is treated as a *build artifact* (like `node_modules` or a Python `venv`), not source code, and is therefore git-ignored. All decisions in R1–R11 below were made *after* this pivot and assume the SQLite-backed model.

## Confirmed Constraints

These four constraints are **hard** and override any later design preference:

1. **Self-contained native agent.** Definition lives at `agents/code-intel.md` in this repo, follows the same shape as the existing 19 agents, and is deployed via `tooling/deploy.{ps1,sh}` to `~/.claude/agents/` and `~/.cursor/agents/`. No new tooling channels, no new deploy scripts.

2. **No MCP, no graph DB, no external service.** Only Claude tools (`Read`, `Glob`, `Grep`, `Bash`, `Write`) and runtimes already on `PATH` (Python, Node, `sqlite3` CLI) may be used. Per-machine installs (e.g., `tree-sitter`) are permitted only via interactive **Tier-3** escalation, never silently.

3. **Read-only on source code.** Source files are inputs, never outputs. `Write` is allowed only for paths under `docs/code-intel/**`, `_tmp_*`, or `.code-intel/**` (SQLite database and sidecars). The agent body must enforce this; refusal is hard-stop, not warning.

4. **SQLite-backed v1.** A persistent index at `.code-intel/index.sqlite` stores nodes (functions, classes, methods, files) and edges (calls, imports, extends, implements, overrides). Sub-second queries via recursive CTEs. No graph database engine, no external service, no MCP server.

## Resolved Dimensions (R1–R11)

### R1 — Use Case Priority

The four candidate use cases were prioritized **prevention-first**, ordered by where unrecognized structural change does the most damage:

1. **A — Pre-edit impact surfacing** *(executor consumer; the keystone)*. Before an executor edits a function, `code-intel` returns its callers, implementers, and downstream test exposure. This is the primary `/ops` Phase 2.5b consumer.
2. **C — Diff-scope verification** *(code-reviewer / `/code-review`)*. After a change is staged, the reviewer confirms the diff actually touches what it claims to and surfaces collateral effects the author missed.
3. **B — Call-chain tracing during debugging** *(debugger consumer)*. When a bug surfaces, the debugger asks for the execution flow and caller chain rather than re-grepping the repo.
4. **D — Ad-hoc queries** *(user, standalone)*. The human can invoke `code-intel` directly via labeled-prose brief for exploratory queries.

### R2 — Query Taxonomy MVP

All six query types ship in v1. Each is answered via a recursive CTE against the SQLite schema:

| Query | Input | Output |
| :--- | :--- | :--- |
| `find_definition` | symbol, optional scope | file + line + signature |
| `find_callers` | symbol, optional scope, optional depth (default 1) | list of `{caller, file, line, snippet}` |
| `find_dependencies` | symbol or file path | outbound imports/calls |
| `impact_analysis` *(keystone)* | symbol/file/diff, optional depth (default 2) | direct + transitive callers, implementers, test exercise, risk summary |
| `find_implementations` | interface/base symbol | concrete implementers |
| `execution_flow` | entry symbol | call-graph trace |

`impact_analysis` is the *keystone* query — the one the executor consumer (R1-A) leans on hardest, and the one most likely to grow new fields in v2.

### R3 — Query API Shape

The brief format is **dual-mode** with strict refusal on malformed input.

- **Orchestrator path:** brief opens with a fenced ```json block. Required fields: `query_type`, `symbol`. Optional fields: `scope`, `depth`, `output_mode`, `max_results`, `max_depth`, `max_files`, `max_wall_clock_s`. JSON brief is the contract for `/ops` Phase 2.5b dispatches.
- **Human ad-hoc path:** labeled-prose fallback using `Query:`, `Symbol:`, `Scope:`, `Depth:`, `Output:`, `Max-Results:`, etc. lines. Suitable for direct user invocation.
- **Malformed path:** the agent refuses with a usage card showing both formats. No fuzzy parsing, no inference.

### R4 — Language Coverage v1

Three-tier cascade *feeding the indexer*. Each node and edge stored in SQLite carries a `precision` flag so consumers know whether they are reading AST-grade truth or regex-grade approximation.

- **Tier-1 (precise AST).** Python via `python -c "import ast; ..."`; TypeScript / JavaScript via Node + `tsc`. Used when the runtime is detected on `PATH`. Output: structured node/edge records loaded into SQLite with `precision: "ast"`.
- **Tier-2 (Grep fallback).** Language-aware regex heuristics for Rust, Go, C#, Java, PHP, Dart, Bash, PowerShell, and other languages where Tier-1 is unavailable. Records loaded with `precision: "regex"`.
- **Tier-3 (interactive escalation).** When the agent detects a query that would *meaningfully* benefit from `tree-sitter` — for example, `find_implementations` on Java/C#/Rust where Tier-2 is unreliable, or `execution_flow` with polymorphic dispatch — it asks the user whether to install `tree-sitter` and re-index, or proceed with current data plus a precision caveat. **Default on no response: proceed with current data.** Never install silently.

### R5 — Auto-Dispatch Trigger in `/ops` Phase 2.5b

A new **Phase 2.5b** stage slots between Phase 2 (task board) and Phase 3 (dispatch loop) in `skills/ops/SKILL.md`. The team manager dispatches `code-intel` once per code-modifying task whose brief matches the predicate, attaches the resulting impact report path to the executor's brief, and proceeds.

- **Predicate (Option v):** `(ii) OR (iv)` — multi-file scope (`files_touched > 1`) **or** brief contains a *risk keyword* (`refactor`, `rename`, `delete`, `breaking change`, `migrate`, `deprecate`, `extract`, `move`).
- **Flags:**
  - `--code-intel` (alias for `--code-intel=always`) — fires on every code-modifying task regardless of predicate.
  - `--code-intel=off` — disables Phase 2.5b entirely for the run.

The predicate is intentionally generous: false positives cost an index lookup; false negatives cost a broken caller chain.

### R6 — Output Format and Rendering

Hybrid dispatch:

- **Orchestrator (R3 JSON brief detected):** the agent writes a Markdown report to `.code-intel/runs/<run-id>/<query>-<symbol>.md` plus a JSON sidecar, then returns a **brief summary plus the path** inline. This keeps the executor's context window lean. Orchestrator-driven runs are *ephemeral*: cleaned by `/ops` Phase 4 (or its analogue) and inherit gitignore from the parent `.code-intel/`. Durable, committable reports — produced by humans opting in via `output_mode: "disk"` or `"both"` — live at `docs/code-intel/<symbol>-<query>.md` instead. The path itself encodes the lifetime.
- **Human (R3 labeled-prose brief detected):** the agent returns the **full rendered report inline**; no disk write. Optimized for read-now consumption.

Every artifact — Markdown or JSON, inline or on disk — carries two metadata fields for *drift detection*:

- `db_indexed_sha` — the git SHA at which the queried index was built.
- `generated_at` — ISO-8601 timestamp of report generation.

Consumers can compare `db_indexed_sha` against `git rev-parse HEAD` to know whether they are reading a stale view.

### R6b — Detection Heuristic

**Option β — format-as-default with explicit override.**

- **Default:** dispatch is detected from the brief format per R3. JSON brief → disk-mode. Labeled-prose brief → inline-mode.
- **Override:** `output_mode: "inline" | "disk" | "both"` (in JSON brief) or `Output: inline | disk | both` (in labeled prose).
- **`output_mode: "both"`:** the inline portion is **summary plus path** (consistent with default orchestrator behavior), not duplicated full content. This avoids context bloat when an orchestrator wants both a quick read and a persistent record.

### R7 — Cross-Agent Integration Depth

**Option B — seven agents** receive a full **"Code Intelligence Context"** section in their definitions:

| Agent | Why it integrates |
| :--- | :--- |
| `executor` | Primary consumer; pre-edit impact surfacing (R1-A) |
| `code-reviewer` | Diff-scope verification (R1-C) |
| `code-reviewer-diff` | Same as above, scoped to diff hunks |
| `debugger` | Call-chain tracing during debugging (R1-B) |
| `debugger-build` | Build-time symbol-resolution failures |
| `change-analyzer` | Cross-cutting structural impact assessment |
| `security-reviewer` | Reachability of vulnerable symbols |

The remaining 12 agents are unchanged in v1.

### R8a — Write Enforcement Violation Posture

**Option B — refuse-and-halt.** On the *first* attempted `Write` to a forbidden path:

1. The agent refuses the operation.
2. It emits a structured **violation report** containing: path attempted, reason for refusal, requester context (which query, which orchestrator, which brief).
3. The run halts. No further `Write` or `Bash` operations in the same dispatch.
4. In-flight read-only queries (`Read`, `Glob`, `Grep`, read-only `Bash`) may complete, since refusing them serves no safety purpose.

There is **no sticky sentinel**: a fresh run starts with a clean slate. The user does not need to clear state to re-invoke after a violation.

### R8b — Bash Scope

**Option D — proposed scope plus capability-detection probes.** The agent's `Bash` use is constrained by an explicit allow-list and deny-list, both enforced verbatim in the agent body.

**Permitted:**

- *Language introspection:* `python -c "import ast; ..."`, `python -c "import json, sys; ..."`, `node -e "..."`, `tsc --listFiles`, `tsc --noEmit --pretty false`.
- *SQLite operations:* `sqlite3 .code-intel/index.sqlite "<read query>"`, `sqlite3 .code-intel/index.sqlite "<write/DDL>"`.
- *Read-only git:* `git rev-parse HEAD`, `git log --format=...`, `git blame <file>`, `git diff` (read-only inspection).
- *Capability detection:* `which <cmd>`, `python --version`, `node --version`, `tree-sitter --version`.

**Forbidden:**

- *Package installs:* `npm install`, `pip install`, `cargo install`, `gem install`, `apt`, `brew`, etc.
- *Network calls:* `curl`, `wget`, `nc`, `ssh`, `scp`, `rsync`.
- *Code-modifying shell:* `sed -i`, `awk` writing back to project files, redirects to project files (`> file`, `>> file`).
- *Process management:* `kill`, `pkill`, `systemctl`, `service`.
- *Git write operations:* `git commit`, `git push`, `git checkout` (modifying), `git stash`, `git reset`.

Refuse-and-halt per R8a applies uniformly to any forbidden invocation.

### R9 — Performance Budget

**Option 9-D — defaults plus per-run override knobs.** The defaults below balance protection against runaway indexing with practical coverage of mid-sized repos. Per-run overrides allow a knowledgeable caller to push past defaults when justified.

| Phase | Limit | Threshold | Action on hit |
| :--- | :--- | :--- | :--- |
| Indexer — files | Hard cap | 5,000 | Abort; refuse "narrow scope" |
| Indexer — wall-clock | Soft / Hard | 60s / 600s | Warn / abort |
| Indexer — DB size | Soft / Hard | 100MB / 500MB | Warn / refuse new index |
| Query — depth | Default / Hard | 2 / 5 | Use default / refuse |
| Query — output size | Hard cap | 200 results | Truncate w/ note |

**Per-run override knobs:**

- *JSON brief:* `max_results`, `max_depth`, `max_files`, `max_wall_clock_s`.
- *Labeled prose:* `Max-Results:`, `Max-Depth:`, `Max-Files:`, `Max-Wall-Clock-S:`.

Overrides cannot exceed the *hard* threshold. A request to set `max_files: 10000` is refused, not silently clamped.

### R10 — Failure Modes

**Option 10-A — accept the proposed matrix verbatim.** The matrix below encodes the prevention-first invariant: when in doubt, *refuse* rather than guess. Partial-with-caveat is the only middle ground; silent fallback is never permitted.

| Failure type | Phase | Behavior |
| :--- | :--- | :--- |
| Symbol not found | Query | Refuse |
| Soft cap hit | Indexer/Query | Partial w/ truncation note |
| Hard cap hit | Indexer | Refuse |
| Tier-2 only (precision degraded) | Query | Partial w/ `precision: regex` caveat |
| Ambiguous symbol | Query | Partial — return all w/ disambiguation |
| File unreadable | Indexer | Skip + caveat; log to `_tmp_indexer-skipped.log` |
| Tier-1 runtime missing | Indexer | Silent fallback to Tier-2 + caveat in next response |
| DB corrupted | Query | Refuse + auto-recovery offer |
| Query timeout (>30s recursive CTE) | Query | Refuse w/ narrow-scope hint |
| Brief malformed | Pre-query | Refuse w/ usage card |
| Lane violation | Any | Refuse-and-halt per R8a |
| Bash violation | Any | Refuse-and-halt per R8b |
| DB missing or stale | Query | See R11 |

The "Tier-1 runtime missing" row is the only *silent* fallback in the matrix, and it is silent only at the indexer level — the *query* response carries a precision caveat so the consumer knows what they are reading.

### R11 — Indexer Lifecycle

The lifecycle has three sub-decisions: when to build, what to do when stale, and how to clean up.

#### R11a — Build Trigger: Option (d), Combination

Three triggers coexist so no consumer is second-class:

- **(a) Ad-hoc users** — the first query transparently builds the index. The user does not need to invoke a separate `index` command first.
- **(c) Orchestrators** — `/ops` Phase 2.5b checks index existence and triggers a build *as preflight* if missing. The executor never sees a missing index; it sees either a valid report or an explicit indexer failure.
- **(b) Escape hatch** — `query_type: "reindex"` forces a rebuild on demand, bypassing staleness logic. Used when the user knows the index is wrong and wants to force a rebuild.

The cost of supporting all three triggers is documentation surface (each path must be explained). The benefit is that no class of consumer is locked out.

#### R11b — Staleness Behavior: Option (α), Full Reindex

On *every* dispatch:

1. The agent runs `git rev-parse HEAD` and compares against `indexed_sha` stored in the DB metadata table.
2. If the SHAs differ, the agent **drops and rebuilds** the index before answering the query, bounded by R9 caps.
3. If the SHAs match, the agent answers from the existing index.

Three alternatives were considered and rejected:

- **(β) Incremental reindex** — deferred to v2. Implementing diff-aware reindex correctly is a multi-week project on its own.
- **(γ) Warn-and-proceed on stale** — explicitly rejected. It reintroduces silent guessing, which is the exact failure mode this agent exists to prevent.
- **(δ) Mode option** (let the caller decide) — explicitly rejected for the same reason.

The cost of full reindex on every staleness check is wall-clock; the R9 wall-clock cap (60s soft / 600s hard) bounds it.

#### R11c — Cleanup Defaults

Four points, all confirmed:

1. **`.code-intel/` is added to `.gitignore`.** The index is a build artifact, not source. Treating it like `node_modules` or a Python `venv` matches its lifecycle and avoids contaminating PRs with multi-megabyte binary diffs.
2. **`query_type: "clean"` drops the SQLite DB and sidecar state.** User-invoked only — orchestrators do not auto-clean.
3. **`/ops` Phase 4 does NOT clean the index.** The index is *persistent infrastructure*. Auto-cleaning at end-of-run would defeat the entire point of caching.
4. **Indexer-emitted `_tmp_*` files (e.g., `_tmp_indexer-skipped.log`) follow the standard `_tmp_*` cleanup protocol.** Batch cleanup at run checkpoints, not individual deletion mid-run.

## Agent Contract Sketch

The architect should produce `agents/code-intel.md` with the following shape. This sketch is *advisory* — the architect owns the final body — but the items below are non-negotiable per the resolved dimensions above.

### Frontmatter

```yaml
---
name: code-intel
model: opus
description: Indexes the project into a SQLite-backed symbol graph and answers structural queries (callers, dependencies, impact, implementations, execution flow) for other agents and orchestrators. Prevents silent breakage by replacing structural guessing with citable lookups.
tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
---
```

The description's first sentence states *what it does*; the second states *why it exists*. This matches the rhetorical pattern of the existing 19 agents.

### Brief Format

Per **R3**, the agent accepts two brief formats and refuses on malformed input:

- **JSON-fenced** (orchestrator path) — required fields `query_type`, `symbol`; optional fields per R3, R6b, R9.
- **Labeled-prose** (human path) — `Query:`, `Symbol:`, `Scope:`, `Depth:`, `Output:`, `Max-*:` lines.
- **Malformed** — refuse with a usage card showing both formats. No fuzzy parsing.

### Lane Phrasing

The agent body must include a **Lane Boundaries** section with at least:

- *Read-only on source code.* Source files are inputs, never outputs.
- *Write to any path under* `.code-intel/**`, *including* `*.sqlite-wal`, `*.sqlite-shm`, *and any* `_tmp_*` *files emitted by SQLite during WAL operation. Also write to* `docs/code-intel/**` *(durable human-opt-in reports) and* `_tmp_*` *(repo-root temporary files). All other paths are forbidden. The agent must use* **glob matching** *for path enforcement, not a literal-path allow-list — a literal set would refuse legitimate WAL sidecar writes and crash the indexer on first run (addresses C-REQ-2).*
- *Refuse-and-halt on first violation* per R8a — emit structured violation report, stop the run.

### Bash Scope Phrasing

The agent body must include the **R8b allow-list and deny-list verbatim** (see R8b above). The architect should not paraphrase or generalize — orchestrators rely on the explicit list to detect drift between the agent's claimed posture and its observed behavior.

### Output Dispatch Logic

Per **R6 plus R6b**:

- Detect brief format → JSON ⇒ disk + summary path inline; labeled-prose ⇒ inline full report.
- Honor `output_mode` override if present.
- Stamp every artifact with `db_indexed_sha` and `generated_at`.

## Integration Touchpoints

The following table enumerates every file the planner will need to touch to land v1. Items marked **New** are created from scratch; items marked **Updated** are edited in place.

| Status | Path | Purpose |
| :--- | :--- | :--- |
| New | `agents/code-intel.md` | The agent definition itself |
| Updated | `agents/README.md` | Add roster entry for `code-intel` |
| Updated | `skills/ops/SKILL.md` | Add Agent Assignment Rules row, lane-boundary row, and new **Phase 2.5b** stage between Phase 2 and Phase 3 |
| Updated | `tooling/deploy-manifest.json` | Add `code-intel` agent entry so deploy.{ps1,sh} picks it up |
| Updated | `CLAUDE.md` (Documentation Sync table) | Add row mapping `agents/README.md` and `agents/code-intel.md` |
| Updated | `agents/executor.md` | Add **Code Intelligence Context** section (R7) |
| Updated | `agents/code-reviewer.md` | Add **Code Intelligence Context** section (R7) |
| Updated | `agents/code-reviewer-diff.md` | Add **Code Intelligence Context** section (R7) |
| Updated | `agents/debugger.md` | Add **Code Intelligence Context** section (R7) |
| Updated | `agents/debugger-build.md` | Add **Code Intelligence Context** section (R7) |
| Updated | `agents/change-analyzer.md` | Add **Code Intelligence Context** section (R7) |
| Updated | `agents/security-reviewer.md` | Add **Code Intelligence Context** section (R7) |
| Updated | `.gitignore` | Add `.code-intel/` entry |
| New | `.code-intel/runs/` *(seeded on first orchestrator dispatch; gitignored via parent `.code-intel/`)* | Ephemeral run-scoped render artifacts. Durable reports live at `docs/code-intel/<symbol>-<query>.md` instead. |

The 12 unchanged agents are intentionally untouched — silent inflation of the integration surface is itself a failure mode (see `skills/ops/SKILL.md:Agent Assignment Rules`).

## Acceptance Criteria

These criteria define **done** for v1. Each is testable with a clear pass/fail condition.

- [ ] `agents/code-intel.md` exists, follows the same frontmatter shape as the other 19 agents in `agents/`, and declares only the five tools specified in R8b.
- [ ] `tooling/deploy.ps1` and `tooling/deploy.sh` deploy `code-intel` to both `~/.claude/agents/` and `~/.cursor/agents/` via the manifest, with no errors.
- [ ] First invocation on a fresh checkout (no `.code-intel/` directory) builds the index, answers the query, and persists the SQLite DB.
- [ ] Second invocation at the same git SHA reuses the index without rebuild (verifiable via `db_indexed_sha` metadata stamp).
- [ ] Invocation after a git operation that changes `HEAD` triggers a full reindex per R11b.
- [ ] All six R2 query types return well-formed responses for at least one symbol in this repo (e.g., `find_callers` for a function defined in `tooling/deploy.ps1`).
- [ ] A malformed brief (neither JSON-fenced nor labeled-prose) is refused with the usage card per R3.
- [ ] An attempted `Write` to a forbidden path emits a structured violation report and halts the run per R8a.
- [ ] An attempted forbidden `Bash` invocation (e.g., `npm install`) is refused per R8b.
- [ ] `/ops` Phase 2.5b dispatches `code-intel` for tasks matching the **(ii) OR (iv)** predicate per R5, and the resulting impact report path is attached to the executor's brief.
- [ ] `--code-intel=off` disables Phase 2.5b for the run; `--code-intel` (alias for `=always`) fires on every code-modifying task.
- [ ] Performance budgets in R9 are enforced: a 6,000-file repo is refused at indexer time; a query returning 250 results is truncated to 200 with a note.
- [ ] All seven R7 agents have a **Code Intelligence Context** section in their definition; the other 12 agents are unchanged.
- [ ] `.code-intel/` is git-ignored.
- [ ] `query_type: "clean"` removes the SQLite DB and sidecars; `/ops` Phase 4 does not.
- [ ] `CLAUDE.md` Documentation Sync table contains a row for the new agent.

## Success Criteria Lock

- **Status:** **Locked** *(per the dispatching brief, all 11 dimensions are resolved and the user has confirmed the requirements set is final)*.
- **Confirmation:** the user explicitly directed the interviewer to *"write the consolidated requirements document"* with no further questions, and the dispatching brief states *"All 11 dimensions are resolved."* That instruction is treated as the success-criteria-lock confirmation per the interviewer protocol Step 5.5.
- **Planning may proceed.** The architect can take this document as input without further clarification on the dimensions enumerated.

## Edge Cases

These scenarios are called out explicitly so the architect and planner do not have to re-derive them. Each maps to a row of the R10 failure matrix.

- **Empty repository** — indexer hits zero source files. Behavior: build an empty index, persist metadata, return "no symbols indexed" on any query. Not a failure.
- **Polyglot repository where Tier-1 runtime is missing for one language** — e.g., Python is on `PATH` but Node is not. Behavior: index Python with `precision: ast`, index TypeScript/JavaScript with `precision: regex` (Tier-2 fallback), include precision caveat in any response that pulls from the regex partition. *Silent fallback at indexer; explicit caveat at query.*
- **Symbol name collision across files** — e.g., two `process_data` functions in different modules. Behavior: per R10 "Ambiguous symbol" row — return all matches with disambiguation (file path, line, signature) so the caller can re-query with `scope`.
- **Recursive CTE timeout** — a query (likely `impact_analysis` at depth 5 on a hub function) exceeds 30s. Behavior: refuse with a narrow-scope hint suggesting smaller `depth` or explicit `scope`.
- **DB corruption** — power loss mid-write or filesystem error. Behavior: detect on next query (SQLite returns error code), refuse, offer auto-recovery (drop and rebuild). Recovery requires user confirmation; not silent.
- **Concurrent indexer invocations** — two agents try to build the index simultaneously. Behavior: SQLite's file-level locking serializes writes; the second invocation waits or returns a "build in progress" caveat. *Architect to confirm exact mechanism (see Open Questions below).*
- **`.code-intel/` accidentally committed** — defensive: even if the user forgets the `.gitignore` entry, the index is rebuilt on staleness (R11b), so a stale committed DB is harmless. Not a hard failure mode, but worth surfacing.
- **Source file deleted between indexing and querying** — the index references a now-missing file. Behavior: the query response includes the indexed location plus a `db_indexed_sha` stamp; the consumer compares against `git rev-parse HEAD` to detect drift. The next dispatch triggers reindex per R11b.
- **Brief specifies `output_mode: "both"`** — inline portion is summary plus path, not duplicate full content (per R6b explicit clarification).

## Open Questions for the Architect

The dimensions R1–R11 are resolved at the *requirements* level. The questions below are **design-level** questions the architect must resolve before the planner can break the work into tasks. Each is intentionally scoped narrowly so the architect can answer it in a single design pass.

1. **Exact SQLite schema.** *Recommendation:* node columns `id`, `kind` (function/class/method/file/etc.), `name`, `file_path`, `line_start`, `line_end`, `signature`, `language`, `precision`. Edge columns: `from_id`, `to_id`, `edge_type` (`CALLS` / `IMPORTS` / `EXTENDS` / `IMPLEMENTS` / `OVERRIDES`), `precision`. Indexes on `(name)`, `(file_path)`, `(from_id, edge_type)`, `(to_id, edge_type)` for the recursive-CTE workload. Architect to confirm or amend.

2. **Indexer worker concurrency.** Single-threaded is simplest and avoids SQLite write-lock contention; a worker pool is faster but adds complexity and a coordination layer. *Recommendation: single-threaded for v1.* Revisit only if the R9 60s soft cap is routinely exceeded on real repos.

3. **Query rendering Markdown template.** The exact structure of each query type's output report — section ordering, table shapes, snippet formatting, citation style. The architect should produce a per-query template so the seven R7 consumers know what to expect.

4. **Tier-3 escalation UX.** The exact wording the agent uses when offering to install `tree-sitter` and reindex. Should it explain *why* (which query, which language)? Should it require explicit `yes` or accept any non-empty confirmation? Default-on-no-response is decided (proceed with current data) but the prompt itself is unspecified.

5. **JSON brief schema validation posture.** Strict (refuse on unknown fields) or permissive (ignore unknown fields)? *Recommendation: strict for v1.* Permissive is forward-compatible but invites silent typos.

6. **SQLite WAL mode vs. default journal mode.** WAL gives better read/write concurrency and is friendlier for our staleness-check + reindex pattern, but it adds two sidecar files (`-wal`, `-shm`) that must also live under `.code-intel/`. Architect to choose and update R8b's permitted SQLite operations accordingly.

7. **Project language profile detection.** How does the indexer decide whether this is a Python project, a TypeScript project, or a polyglot? Does it sniff `pyproject.toml` / `package.json` / `Cargo.toml`, or does it walk file extensions, or both? Decision affects which Tier-1 runtimes to probe and in what order.

8. **Per-project configuration file.** Does v1 need `.code-intel/config.toml` (or similar) for per-project overrides — excluded paths, custom file extensions, vendor directories — or is the v1 minimum no-config? *Recommendation: no-config v1, with hardcoded sensible excludes (`node_modules`, `.git`, `__pycache__`, `dist`, `build`, `.venv`).* Add config in v2 if real projects need it.

9. **Cursor variant.** Do we need a `code-intel.cursor.md` variant via `tooling/transform-cursor-*.{ps1,sh}`, or does the same body work for both Claude Code and Cursor? Most agents in `agents/` do not have a Cursor variant; only skills (`skills/ops/SKILL.cursor.md`, `skills/ralph-loop/SKILL.cursor.md`, `skills/deploy/SKILL.cursor.md`) do. *Recommendation: single body, no Cursor variant for v1.*

10. **Indexer skipped-file log lifecycle.** `_tmp_indexer-skipped.log` is emitted per R10 when files are unreadable. Does it persist across runs (append) or reset per run (overwrite)? *Recommendation: per-run overwrite, since `_tmp_*` files are batch-cleaned at run checkpoints anyway.*

These are all design questions, not requirements questions — the answers should not change which dimensions in R1–R11 are resolved, only how the resolution is realized in code.

## Interview Log

The interview log below summarizes the rounds that produced this document. It is included for traceability so the architect and planner can see *why* each decision was made, not just *what* was decided.

- **Round 0 — Brief intake.** User stated the goal: a code-intelligence layer agent, not a documentation tool, indexing the project into a structured knowledge graph and exposing it to other agents and orchestrators. Hard constraints: no MCP, no GitNexus dependency, must work as a native agent.
- **Round 1 — Use case priority (R1).** User chose **A → C → B → D**, prevention-first.
- **Round 2 — Query taxonomy (R2).** User selected all six query types for v1, with `impact_analysis` as the keystone.
- **Round 3 — Query API shape (R3).** User chose Option C with JSON-fenced for orchestrators and labeled-prose for humans, with refuse-on-malformed.
- **Round 4 — Language coverage (R4) + design pivot.** Initial proposal was stateless; user surfaced latency and consistency concerns and chose **Path α** — SQLite-backed v1 with three-tier cascade feeding the indexer.
- **Round 5 — Auto-dispatch trigger (R5).** User chose Option (v) with predicate **(ii) OR (iv)** and the `--code-intel` / `--code-intel=off` flags. New `/ops` Phase 2.5b stage agreed.
- **Round 6 — Output format and rendering (R6 + R6b).** User chose hybrid (Option C) with `output_mode` override (Option β); `output_mode: "both"` returns summary plus path inline, not duplicated full content.
- **Round 7 — Cross-agent integration (R7).** User chose Option B — full Code Intelligence Context sections in seven agents.
- **Round 8 — Lane and Bash enforcement (R8a + R8b).** User chose refuse-and-halt for write violations (R8a Option B) and explicit allow-list / deny-list for Bash (R8b Option D).
- **Round 9 — Performance budget (R9).** User chose Option 9-D — defaults plus per-run override knobs.
- **Round 10 — Failure matrix (R10).** User accepted Option 10-A — proposed matrix verbatim.
- **Round 11 — Indexer lifecycle (R11a + R11b + R11c).** User chose combination build trigger (R11a Option d), full reindex on stale (R11b Option α, with β/γ/δ rejected), and the four cleanup-default points confirmed.

All 11 dimensions resolved below the 0.3 ambiguity threshold. Success criteria locked per Step 5.5. Recommended next step: invoke the **architect** with this document as input, then the **planner** to break the architect's design into executable tasks.

---

*Revision note (2026-04-26, architect agent): R8a Lane Phrasing tightened to spell out WAL/SHM sidecars and `_tmp_*` SQLite emissions, and to require glob matching rather than a literal-path allow-list (addresses C-REQ-2 from `docs/plan/code-intel-agent-critique.md`). No other content changed.*
