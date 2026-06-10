# Corpus Search — Integration Test Procedures

## 1. Purpose and prerequisites

**Purpose:** Manual verification procedures for the **corpus-search** agent — standalone dispatch, `/ops` Phase 2.5c pipeline integration, dual preflight with code-intel, Phase 4 cleanup, and refusal handling.

**Prerequisites:**

- **Deployed agent:** `agents/corpus-search.md` deployed to `~/.claude/agents/` (or project `.claude/agents/`) via `tooling/deploy.ps1` / `tooling/deploy.sh`.
- **Git repository:** working tree inside a git repo (`git rev-parse HEAD` succeeds) — required for orchestrator-path `corpus_indexed_sha` stamping.
- **Search tools:** `rg` (ripgrep) available on PATH; agent falls back to `grep` if `rg` is unavailable.
- **Ops skill:** `/ops` skill deployed; Phase 2.5c advisory preflight is implemented in `skills/ops/phase-dispatch.md` (loaded from the ops hub after triage routes to pipeline).

---

## 2. Standalone dispatch (`verify_claim`)

**Purpose:** Confirm the agent contract works outside `/ops`.

### Steps

1. Dispatch **corpus-search** with a JSON-fenced brief (orchestrator path):

```json
{
  "query_type": "verify_claim",
  "query": "reusable AI agents",
  "scope": "README.md",
  "output_mode": "disk",
  "claim_mode": "exists"
}
```

2. Wait for the JSON-fenced response.

### Expected results

| Check | Expected |
| :--- | :--- |
| `status` | `"ok"` or `"partial"` (not `"refused"`) |
| `report_path` | Path under `.corpus-search/runs/<run-id>/verify_claim-*.md` |
| `json_sidecar` | Matching `.json` sidecar beside the report |
| `corpus_indexed_sha` | Short git HEAD sha (7+ hex chars) matching `git rev-parse --short HEAD` |
| `generated_at` | ISO-8601 UTC timestamp |
| Report header | Contains **Corpus SHA**, **Generated**, and **Query** lines |
| Verdict section | `CONFIRMED` (string exists in `README.md`) |

### Pass criteria

Report file exists on disk; header fields populated; verdict is `CONFIRMED`.

---

## 3. Phase 2.5c ops test (pipeline path)

**Purpose:** Confirm `/ops` Phase 2.5c fires during Phase 3 Step 2 and attaches `Corpus Search Context` to consumer briefs.

> **Trivial-path limitation:** Trivial Dispatch skips Phase 2.5 entirely (see `skills/ops/phase-intake.md` § Trivial Dispatch). Phase 2.5c cannot be exercised via trivial dispatch in v1 — use the **pipeline path** below.

### Steps

1. Create a **multi-task board** with at least one `executor` task. Example user request:

   _"/ops execute — Task 1: Search for evidence of Phase 2.5c advisory semantics in skills/ops and summarize findings. Task 2: Update agents/README.md with a one-line note confirming corpus-search is registered."_

   This produces a pipeline run (not trivial) with an executor task whose brief contains an investigation keyword from ADR-1 clause (i): e.g. `search for`, `evidence`, or `find evidence`.

   **Alternative:** Force Phase 2.5c on every consumer dispatch with `--corpus-search=always`:

   _"/ops --corpus-search=always execute — implement task X from the plan"_

2. Confirm triage routes to **pipeline** (not trivial) — Phase 1a plan/scoping may run if no plan exists.

3. During Phase 3 Step 2, before the executor brief is composed, observe (or inspect `--dispatch-log` if enabled) that **corpus-search** is dispatched synchronously.

4. Read the executor's composed brief. Confirm a **`Corpus Search Context:`** block is present:

```text
Corpus Search Context: see .corpus-search/runs/<run-id>/evidence_search-<slug>.md
  - <one-line summary>
```

5. Confirm the report artifact exists:

```text
.corpus-search/runs/<run-id>/evidence_search-<slug>.md
```

### Expected results

| Check | Expected |
| :--- | :--- |
| Triage route | `pipeline` (multi-task board, not trivial) |
| Phase 2.5c dispatch | `corpus-search` runs before executor brief composition |
| Executor brief | Contains `Corpus Search Context:` block with report path |
| Disk artifact | `.corpus-search/runs/<run-id>/` directory with `.md` and `.json` sidecar |
| Advisory semantics | Executor proceeds even if corpus-search returns `partial` |

### Pass criteria

Pipeline path used; `Corpus Search Context` appears in executor brief; ephemeral run directory exists before Phase 4.

---

## 4. Dual preflight test (Phase 2.5b + 2.5c)

**Purpose:** Confirm both code-intel and corpus-search run when an executor task matches both predicates.

### Steps

1. Create an executor task whose brief contains:
   - A **risk keyword** from Phase 2.5b: e.g. `rename` or `refactor`
   - A **textual migration cue** from Phase 2.5c clause (iii): e.g. `update references` or `rename mentions`
   - An extractable **symbol** (backtick-wrapped token in `## Task`, or `Symbol:` line)

   Example task subject: _"Rename `process_payment` and update references across repo"_

2. Run `/ops execute` on a pipeline board containing this task (multi-file scope or risk keyword ensures Phase 2.5b also matches).

3. Observe dispatch order during Phase 3 Step 2.

### Expected attachment order

1. **code-intel** dispatches first (Phase 2.5b); state cache invalidated.
2. **corpus-search** dispatches second with `query_type: "trace_reference"` and seed from symbol-extraction algorithm; state cache invalidated again.
3. Executor brief receives **both** blocks, in order:
   - `Code Intelligence Context:` (impact analysis report path)
   - `Corpus Search Context:` (trace_reference report path — filename token is `trace_reference-<slug>.md`, not `evidence_search-<slug>.md`)

### Pass criteria

Both context blocks present in executor brief; corpus-search report uses `trace_reference` query type in filename.

---

## 5. Phase 4 cleanup test

**Purpose:** Confirm ephemeral run artifacts are deleted after run completion; durable docs directory is preserved.

### Steps

1. Complete an ops run that triggered Phase 2.5c (§ 3 or § 4).

2. Note the run-id and confirm `.corpus-search/runs/<run-id>/` exists **before** Phase 4 completes.

3. Allow Phase 4 step 9 (cleanup) to finish.

4. Check filesystem state.

### Expected results

| Path | After Phase 4 |
| :--- | :--- |
| `.corpus-search/runs/<run-id>/` | **Deleted** (ephemeral run artifacts) |
| `.corpus-search/` (parent) | May remain if empty or from other runs — **not** deleted by Phase 4 |
| `docs/corpus-search/` | **Untouched** (durable human-opt-in reports; empty dir is fine) |
| `.code-intel/runs/<run-id>/` | Also deleted (parallel cleanup — unrelated but confirms step 9 ran) |

### Pass criteria

Run-scoped directory absent post-Phase-4; `docs/corpus-search/` not deleted.

---

## 6. Refusal test (malformed JSON brief)

**Purpose:** Confirm strict schema validation and advisory semantics — refusal does not block ops.

### Steps

1. Dispatch **corpus-search** with a malformed JSON brief containing an unknown field:

```json
{
  "query_type": "verify_claim",
  "query": "test",
  "unknown_field": true
}
```

2. Wait for the JSON-fenced response.

3. If testing via `/ops`, confirm the team manager proceeds with the consumer dispatch.

### Expected results

| Check | Expected |
| :--- | :--- |
| `status` | `"refused"` |
| Response body | Usage card or refusal reason (unknown field / schema violation) |
| No report on disk | No new `.md` report written (or empty run dir only) |
| Ops behavior | Consumer brief notes consultation was attempted; dispatch **proceeds** (Phase 2.5c is advisory) |

### Pass criteria

`status: refused` returned; ops does not halt; consumer receives refusal note in brief when orchestrated.

---

## Quick reference — predicate clauses (Phase 2.5c)

For manual test design, Phase 2.5c fires when `(i) OR (ii) OR (iii) OR (iv)`:

| Clause | Condition |
| :--- | :--- |
| **(i)** | Brief contains investigation keyword: `find evidence`, `where is`, `grep for`, `search for`, `locate`, `verify that`, `investigate`, `trace`, `mentions`, etc. |
| **(ii)** | Consumer is `debugger` or `documentor` AND symbol-extraction algorithm finds no primary symbol |
| **(iii)** | Consumer is `executor` AND brief has risk keyword (`rename`, `refactor`, …) AND migration cue (`update references`, `rename mentions`, …) |
| **(iv)** | Orchestrator forms a genuine information-need hypothesis — it lacks the answer a specific corpus-search `query_type` would give and that gap is a risk for the task — and none of `(i)`, `(ii)`, `(iii)` matched; additive only, never suppressing a keyword match |

Override flags: `--corpus-search=always` forces dispatch; `--corpus-search=off` disables Phase 2.5c for the run.
