# Code Intel — Integration Test Procedures

## 1. Purpose and prerequisites

**Purpose:** Manual verification procedures for the **code-intel** agent — standalone dispatch, `/ops` Phase 2.5b pipeline integration, first-time index build, Phase 4 cleanup, and refusal handling.

**Prerequisites:**

- **Deployed agent:** `agents/code-intel.md` deployed to `~/.claude/agents/` (or project `.claude/agents/`) via `tooling/deploy.ps1` / `tooling/deploy.sh`.
- **Git repository:** working tree inside a git repo (`git rev-parse HEAD` succeeds) — required for `db_indexed_sha` stamping and staleness checks.
- **Indexer runtime:** at least one Tier-1 or Tier-2 language runtime available for this repo (Python is sufficient for AI-Skills-Agents).
- **SQLite:** `sqlite3` CLI available on PATH for index inspection during manual tests.
- **Ops skill:** `/ops` skill deployed; Phase 2.5b advisory preflight is implemented in `skills/ops/phase-preflights.md` (loaded from the ops hub after triage routes to pipeline).

---

## 2. Standalone dispatch (`impact_analysis`)

**Purpose:** Confirm the agent contract works outside `/ops`.

### Steps

1. Dispatch **code-intel** with a JSON-fenced brief (orchestrator path):

```json
{
  "query_type": "impact_analysis",
  "symbol": "MECHANICAL_AGENTS",
  "scope": "skills/ops/**",
  "depth": 2,
  "output_mode": "disk",
  "max_results": 200,
  "max_depth": 5,
  "max_files": 5000,
  "max_wall_clock_s": 600
}
```

2. Wait for the JSON-fenced response.

### Expected results

| Check | Expected |
| :--- | :--- |
| `status` | `"ok"` or `"partial"` (not `"refused"`) |
| `report_path` | Path under `.code-intel/runs/<run-id>/impact_analysis-MECHANICAL_AGENTS.md` |
| `json_sidecar` | Matching `.json` sidecar beside the report |
| `db_indexed_sha` | Short git HEAD sha matching `git rev-parse --short HEAD` |
| `generated_at` | ISO-8601 UTC timestamp |
| Report header | Contains indexed SHA, generated timestamp, query type, and symbol |
| Index file | `.code-intel/index.sqlite` exists after first dispatch |

### Pass criteria

Report file exists on disk; header fields populated; index database present.

---

## 3. Phase 2.5b ops test (pipeline path)

**Purpose:** Confirm `/ops` Phase 2.5b fires during Phase 3 Step 2 and attaches `Code Intelligence Context` to the executor brief.

> **Trivial-path limitation:** Trivial Dispatch skips Phase 2.5 entirely (see `skills/ops/phase-intake.md` § Trivial Dispatch). Phase 2.5b cannot be exercised via trivial dispatch — use the **pipeline path** below.

### Steps

1. Create a **multi-task board** with at least one code-modifying `executor` task that matches the Phase 2.5b predicate `(ii) OR (iv)`:
   - **(ii)** `files_touched > 1`, or
   - **(iv)** brief contains a risk keyword such as `refactor`, `rename`, or `move`.

   Example user request:

   _"/ops execute — Task 1: Refactor MECHANICAL_AGENTS references across skills/ops/SKILL.md and tooling/transform-cursor-ops.ps1. Task 2: Verify transform idempotency."_

   **Alternative:** Force Phase 2.5b on every code-modifying task with `--code-intel=always`:

   _"/ops --code-intel=always execute — implement task X from the plan"_

2. Confirm triage routes to **pipeline** (not trivial).

3. During Phase 3 Step 2, before the executor brief is composed, observe (or inspect `--dispatch-log` if enabled) that **code-intel** is dispatched synchronously.

4. Read the executor's composed brief. Confirm a **`Code Intelligence Context:`** block is present:

```text
Code Intelligence Context: see .code-intel/runs/<run-id>/impact_analysis-<symbol>.md
  - <one-line summary>
```

5. Confirm the report artifact exists:

```text
.code-intel/runs/<run-id>/impact_analysis-<symbol>.md
```

### Expected results

| Check | Expected |
| :--- | :--- |
| Triage route | `pipeline` (multi-task board, not trivial) |
| Phase 2.5b dispatch | `code-intel` runs before executor brief composition |
| Executor brief | Contains `Code Intelligence Context:` block with report path |
| Disk artifact | `.code-intel/runs/<run-id>/` directory with `.md` and `.json` sidecar |
| Advisory semantics | Executor proceeds even if code-intel returns `partial` or `refused` |

### Pass criteria

Pipeline path used; `Code Intelligence Context` appears in executor brief; ephemeral run directory exists before Phase 4.

---

## 4. First-time index build test

**Purpose:** Confirm transparent index build when `.code-intel/index.sqlite` is absent.

### Steps

1. Back up then remove the index (optional — skip if index already absent):

```text
mv .code-intel/index.sqlite _tmp_index-backup.sqlite
```

2. Dispatch **code-intel** with any valid JSON brief (§ 2).

3. Confirm the index is rebuilt before the query answer is returned.

4. Restore backup if created:

```text
mv _tmp_index-backup.sqlite .code-intel/index.sqlite
```

### Expected results

| Check | Expected |
| :--- | :--- |
| Index absent before dispatch | `.code-intel/index.sqlite` missing (or freshly removed) |
| Build completes | Index file created; `metadata.db_indexed_sha` matches current HEAD |
| Wall-clock | Index build + query completes within `max_wall_clock_s` |
| Caveats | Tier-2 fallback languages noted in response if Tier-1 runtime missing |

### Pass criteria

Query succeeds without manual index setup; `db_indexed_sha` in response matches `git rev-parse --short HEAD`.

---

## 5. Phase 4 cleanup test

**Purpose:** Confirm ephemeral run artifacts are deleted after run completion; persistent index infrastructure is preserved.

### Steps

1. Complete an ops run that triggered Phase 2.5b (§ 3).

2. Note the run-id and confirm `.code-intel/runs/<run-id>/` exists **before** Phase 4 completes.

3. Allow Phase 4 step 9 (cleanup) to finish.

4. Check filesystem state.

### Expected results

| Path | After Phase 4 |
| :--- | :--- |
| `.code-intel/runs/<run-id>/` | **Deleted** (ephemeral run artifacts) |
| `.code-intel/index.sqlite` | **Preserved** (persistent infrastructure) |
| `.code-intel/index.sqlite-wal` / `.code-intel/index.sqlite-shm` | **Preserved** if present |
| `docs/code-intel/` | **Untouched** (durable human-opt-in reports; empty dir is fine) |

### Pass criteria

Run-scoped directory absent post-Phase-4; index database and WAL/SHM sidecars remain.

---

## 6. Refusal test (malformed JSON brief)

**Purpose:** Confirm strict schema validation and advisory semantics — refusal does not block ops.

### Steps

1. Dispatch **code-intel** with a malformed JSON brief containing an unknown field:

```json
{
  "query_type": "find_callers",
  "symbol": "process_data",
  "unknown_field": true
}
```

2. Wait for the JSON-fenced response.

3. If testing via `/ops`, confirm the team manager proceeds with the executor dispatch.

### Expected results

| Check | Expected |
| :--- | :--- |
| `status` | `"refused"` |
| Response body | Usage card or refusal reason (unknown field / schema violation) |
| No report on disk | No new impact report written (or empty run dir only) |
| Ops behavior | Consumer brief notes consultation was attempted; dispatch **proceeds** (Phase 2.5b is advisory) |

### Pass criteria

`status: refused` returned; ops does not halt; consumer receives refusal note in brief when orchestrated.

---

## Quick reference — predicate clauses (Phase 2.5b)

For manual test design, Phase 2.5b fires when `(ii) OR (iv) OR (vi)` on code-modifying executor tasks:

| Clause | Condition |
| :--- | :--- |
| **(ii)** | `files_touched > 1` — the task touches more than one file |
| **(iv)** | Brief contains at least one risk keyword: `refactor`, `rename`, `delete`, `breaking change`, `migrate`, `deprecate`, `extract`, `move` |
| **(vi)** | Orchestrator forms a genuine information-need hypothesis — it lacks the answer a specific code-intel `query_type` would give and that gap is a risk for the task — and neither `(ii)` nor `(iv)` matched; additive only, never suppressing a keyword match |

Override flags: `--code-intel=always` forces dispatch; `--code-intel=off` disables Phase 2.5b for the run.

When both Phase 2.5b and Phase 2.5c match on an executor task, **code-intel runs first**, then corpus-search — see `docs/corpus-search-integration-test.md` § 4.
