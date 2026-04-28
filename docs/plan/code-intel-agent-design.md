# Architecture Decision Document: `code-intel` Agent

## Summary

The **`code-intel` agent** is a code-intelligence layer that gives the rest of the agent ecosystem something it has never had before — a *cheap, citable* way to ask structural questions about the project. Where the executor, debugger, and code-reviewer currently *re-derive* call graphs and import topologies on every dispatch (each one paying the wall-clock cost from scratch), `code-intel` consults a precomputed **symbol graph** stored in a SQLite file at `.code-intel/index.sqlite` and returns deterministic answers in well under a second. The ADD below resolves the ten design-level questions left open by the requirements doc and pins the rest of the structural choices the planner needs to break this work into tasks.

The shape of the v1 design that emerges is, deliberately, *boring*: a single-file native agent (`agents/code-intel.md`) that follows the same shape as the other 19 agents, a minimal SQLite schema with five edge types and one metadata table, six recursive-CTE templates baked into the agent body, a single-threaded indexer, no per-project config file, no Cursor variant, and a strict JSON brief schema. Boring is the right answer here because the whole point of the agent is to *eliminate* a class of guessing — the more clever the agent itself becomes, the less it can promise to its consumers.

## Inputs

- **Requirements doc:** `docs/plan/code-intel-agent-requirements.md` — 389 lines, 11 resolved dimensions (R1–R11), four hard constraints, 10 open design questions.
- **Handoff doc:** `docs/plan/.handoffs/code-intel-agent-2026-04-26/handoff-000-plan-to-design.md` — interviewer-to-architect summary.

This ADD assumes both documents are taken as binding. Where this ADD diverges from a requirements-doc *recommendation*, the divergence is called out explicitly with rationale.

## Context

The agent ecosystem already has 19 agents and 11 skills, but every agent that touches code today does so by re-grepping the project. That works fine for small repos, but it has two failure modes the user has flagged repeatedly: *latency* (re-deriving a call graph on every executor dispatch is expensive enough that orchestrators will skip the consultation under time pressure) and *consistency* (two queries seconds apart can see slightly different graphs if files change between them). Both failure modes corrode the **prevention-first invariant** — the whole point of `/ops` Phase 2.5b is to catch silent breakage *before* the executor commits, not after.

Without an ADD, the planner would walk into ten unresolved design questions — schema shape, concurrency, brief validation, language detection — and end up either deferring them to the executor (who is the wrong agent to make architecture calls) or making implicit choices that the user never had a chance to review. The ADD below pins those choices so the plan can encode them as constraints, not surprises.

## Decision Drivers

1. **Prevention-first invariant.** The agent exists to replace guessing with citable lookups. Any design choice that reintroduces silent fallback or fuzzy parsing is rejected by default.
2. **No new dependencies.** Only Claude tools (`Read`, `Glob`, `Grep`, `Bash`, `Write`) plus runtimes already on `PATH`. No MCP, no graph DB, no service. Per-machine installs only via interactive Tier-3 escalation.
3. **Same shape as the other 19 agents.** A single-file agent body deployed via `tooling/deploy.{ps1,sh}`, frontmatter matching the established pattern, lane-boundary section, no exotic infrastructure.
4. **Sub-second queries.** The performance budget caps the recursive-CTE timeout at 30s and the default depth at 2. The schema and indexes must make sub-second queries trivial, not heroic.
5. **Read-only on source code.** Source files are inputs, never outputs. `Write` is allowed only for paths under `docs/code-intel/**`, `_tmp_*`, or `.code-intel/**`. Refusal is hard-stop, not warning.
6. **Reversibility favored.** Where two options are roughly equivalent, prefer the one that is easier to walk back. v1 should not paint v2 into a corner.

## Existing Architecture (Relevant Slice)

A few facts from the codebase that constrain this design:

- **Agent shape.** Every agent in `agents/` is a single Markdown file with YAML frontmatter (`name`, `model`, `description`, `tools`) and a body that includes a quick-reference card, a workflow, lane boundaries, and constraints. Sizes range from 152 lines (`debugger-build.md`) to 443 (`ssh-executor.md`). The mean is around 230 lines. `code-intel` will sit comfortably in the upper half of that range — it is more like `ssh-executor` (an agent that owns a complex external surface) than like `preflight` (a simple checklist).
- **Deploy manifest.** `tooling/deploy-manifest.json` deploys every `*.md` file in `agents/` (except `README.md`) to `~/.claude/agents/`, `~/.cursor/agents/`, and the WSL mirror. Adding `code-intel` means dropping a file in `agents/` and adding a manifest entry — no other plumbing.
- **Cursor variants are rare.** Of the 19 existing agents, *zero* have a Cursor variant. Only certain skills do (`ops`, `ralph-loop`, `deploy`). The transform machinery in `tooling/transform-cursor-*.{ps1,sh}` is per-skill, not per-agent.
- **`/ops` pipeline.** `skills/ops/SKILL.md` defines the Phase 1 → 2 → 2.5 → 3 → 4 pipeline. Phase 2.5 is *preflight* (environment validation). Phase 2.5b is the new slot reserved for `code-intel`. The dispatch loop in Phase 3 reads agent frontmatter to pick the model, then dispatches via the self-read prompt template.
- **Brief format.** Other agents accept either a free-form natural-language brief or a structured one. `code-intel` is unusual in that it explicitly requires a JSON-fenced brief from orchestrators, with a labeled-prose fallback for humans. That is closer to how `change-analyzer` is dispatched than to how `executor` is.
- **State directories.** `.ops-state/` for the team manager, `.code-intel/` for the agent. Both are git-ignored, both are treated as build artifacts.

These constraints mostly *narrow* the design space, which is good. The planner does not have to invent integration plumbing — it just has to instantiate the patterns that already exist.

---

## Design Decisions

The ten open questions are answered below in the order surfaced by the requirements doc. Each decision is a *commitment* — the planner should encode it as a constraint, not re-litigate it. Where a *rejected* alternative is worth surfacing, it appears as a sub-bullet so the executor (and any future architect doing v2) can see why we chose what we chose.

### Q1 — Exact SQLite Schema

**Decision: confirm the requirements-doc recommendation, with three additions** — explicit column types, foreign keys, and a `metadata` table. The full schema is below.

The recommendation is the right shape. The recursive-CTE workload — chasing edges from a starting node — wants exactly two tables (`nodes`, `edges`) with a small fixed set of columns. The additions below tighten the contract and make the schema *self-describing*, which matters because the indexer and the query handlers may evolve at different rates.

```sql
-- Schema version 1. Bump SCHEMA_VERSION in metadata when this changes.

CREATE TABLE nodes (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  kind        TEXT    NOT NULL,    -- 'function' | 'class' | 'method' | 'file' | 'module' | 'interface'
  name        TEXT    NOT NULL,    -- bare symbol name, e.g. 'process_data'
  qualified   TEXT,                -- fully-qualified name where derivable, e.g. 'mypkg.module.Class.process_data'
  file_path   TEXT    NOT NULL,    -- repo-relative POSIX path
  line_start  INTEGER NOT NULL,
  line_end    INTEGER NOT NULL,
  signature   TEXT,                -- one-line callable signature where derivable
  language    TEXT    NOT NULL,    -- 'python' | 'typescript' | 'javascript' | 'rust' | ... | 'unknown'
  precision   TEXT    NOT NULL,    -- 'ast' | 'regex' | 'tree-sitter'
  CHECK (kind IN ('function','class','method','file','module','interface')),
  CHECK (precision IN ('ast','regex','tree-sitter'))
);

CREATE TABLE edges (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  from_id     INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  to_id       INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  edge_type   TEXT    NOT NULL,    -- 'CALLS' | 'IMPORTS' | 'EXTENDS' | 'IMPLEMENTS' | 'OVERRIDES'
  precision   TEXT    NOT NULL,    -- 'ast' | 'regex' | 'tree-sitter'
  CHECK (edge_type IN ('CALLS','IMPORTS','EXTENDS','IMPLEMENTS','OVERRIDES')),
  CHECK (precision IN ('ast','regex','tree-sitter'))
);

CREATE TABLE metadata (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL
);
-- Required keys: 'schema_version', 'db_indexed_sha', 'generated_at',
-- 'indexer_wall_clock_s', 'languages_seen', 'tier1_runtimes', 'file_count'.

-- Recursive-CTE-friendly indexes.
CREATE INDEX idx_nodes_name      ON nodes(name);
CREATE INDEX idx_nodes_file      ON nodes(file_path);
CREATE INDEX idx_nodes_qualified ON nodes(qualified);
CREATE INDEX idx_edges_from      ON edges(from_id, edge_type);
CREATE INDEX idx_edges_to        ON edges(to_id, edge_type);
```

**Why these additions matter:**

- `qualified` lets `find_definition` disambiguate between two `process_data` symbols in different modules without forcing the caller to specify `scope`. The R10 "ambiguous symbol" row still triggers when even `qualified` collides — it just becomes rarer.
- `metadata` is the source of truth for `db_indexed_sha` and `generated_at` (both required on every R6 artifact) and for `schema_version`. When the schema changes in v2, the agent reads `schema_version` and either migrates or refuses.
- Foreign keys with `ON DELETE CASCADE` mean a `clean` query (R11c) and a stale-reindex (R11b) can both `DROP TABLE nodes` and the edges go with it. SQLite needs `PRAGMA foreign_keys = ON` per-connection to enforce this — that's a Bash-allow-list-permitted pragma.

**Rejected alternative — denormalized graph in a single table.** Storing edges as JSON arrays inside `nodes` would simplify ingestion but kill recursive CTEs. CTEs need a flat `from_id`/`to_id` shape to traverse efficiently.

**Rejected alternative — separate tables per `edge_type`.** Five tables (`calls`, `imports`, `extends`, etc.) would make some queries marginally faster but would force the recursive CTE to know which table to read for each query type. Single `edges` table with a `WHERE edge_type = 'CALLS'` filter is simpler and the index on `(from_id, edge_type)` makes it just as fast.

### Q2 — Indexer Worker Concurrency

**Decision: single-threaded for v1.**

The recommendation in the requirements doc is right and the trade-off is one-sided enough that I will not belabor it. SQLite serializes writes at the file level — even with WAL mode (see Q6), a worker pool would mostly just spend its time in `BEGIN IMMEDIATE` contention, not actually parsing in parallel. The R9 60s soft cap on indexer wall-clock is the right place to revisit this: if real repos routinely trip the soft cap, v2 can introduce a producer-consumer split (worker pool parses, single writer commits) without changing the schema.

The single-threaded indexer also makes the **R10 "concurrent indexer invocations" edge case** trivial — SQLite's file-level locking serializes the writers, the second invocation either waits or returns a `build in progress` caveat, and there is no extra coordination layer to design.

**Rejected alternative — worker pool with shared connection.** Faster on paper, much harder to reason about. Not worth the complexity for v1.

**Rejected alternative — process-per-language.** Spawning one Python process to parse Python files and one Node process to parse TS files in parallel sounds attractive but adds an orchestration layer (process supervision, output marshaling, partial-failure handling) that v1 does not need.

### Q3 — Query Rendering Markdown Templates

**Decision: one template per query type, all sharing a common header and footer.** Templates are below. The agent body inlines them so the planner does not have to invent them.

Every report opens with a **header** stamping `db_indexed_sha`, `generated_at`, and the query that was asked. Every report closes with a **footer** stamping any precision caveats, truncation notes, and Tier-2-or-Tier-3 escalation markers. The middle differs per query type.

#### Common header

```markdown
## Code Intelligence Report — `<query_type>`

- **Symbol:** `<symbol>` (`<kind>`, `<language>`)
- **Scope:** `<scope or 'project-wide'>`
- **Depth:** `<depth or 'n/a'>`
- **Indexed at SHA:** `<db_indexed_sha>`
- **Generated:** `<generated_at>` (ISO-8601 UTC)
- **Precision:** `<ast | regex | tree-sitter | mixed>`
```

#### Common footer

```markdown
### Caveats

- <Tier-2 precision note, if any partition is regex-grade>
- <truncation note, if results exceeded `max_results`>
- <Tier-1 runtime missing note, if applicable>
- <ambiguity note, if the symbol resolved to >1 candidate>

### Provenance

- DB path: `.code-intel/index.sqlite`
- Indexer wall-clock: `<seconds>s`
- Files scanned: `<count>`
- Languages seen: `<comma-separated list>`
```

#### Per-query body

| Query | Body shape |
| :--- | :--- |
| `find_definition` | One-row table: `Name`, `Kind`, `File:Line`, `Signature`, `Language`. Below it, a fenced code block with the source snippet (lines `line_start..min(line_start+8, line_end)`). |
| `find_callers` | Sectioned by depth. Each depth level renders a table with columns: `Caller`, `File:Line`, `Snippet (one line)`, `Precision`. Snippets are quoted with backticks; long snippets truncated to 80 chars with `…`. |
| `find_dependencies` | Two tables: **Imports** (`Imported Symbol`, `From File`, `At Line`, `Edge Precision`) and **Calls** (`Called Symbol`, `Defined In`, `At Line`, `Edge Precision`). Sorted by file then line. |
| `impact_analysis` *(keystone)* | Four sections in order: (1) **Direct callers** (depth=1 table, identical to `find_callers` depth=1); (2) **Transitive callers** (depths 2..N, collapsed to a tree-like indented list); (3) **Implementers** (table — only populated if the symbol is a class/interface); (4) **Test exposure** (file paths matching `test_*` / `*_test.*` / `*.spec.*` heuristic that import or call the symbol). Each section has a one-line **risk summary** at the top. |
| `find_implementations` | Single table: `Implementer`, `File:Line`, `Edge Type` (`EXTENDS`/`IMPLEMENTS`/`OVERRIDES`), `Precision`. Sorted by `Edge Type` then `File:Line`. |
| `execution_flow` | Indented call tree, depth-bounded by `max_depth` (default 2, hard cap 5). Each node rendered as `  <name>  (<file>:<line>, <precision>)`. Cycles are marked `[CYCLE → already shown above]`. |

**Citation format.** All file references use the pattern `` `path/to/file.py:42` `` (relative path, colon, 1-based line number). This matches how the executor and code-reviewer already cite files in their reports — consumers do not have to learn a new format.

**Truncation notes.** When any table is truncated by `max_results`, append a footer line: `_Truncated: showing N of M results. Re-run with `max_results: <larger>` or narrow `scope`._`

**Tier-2 caveats.** Any row whose `precision` column is `regex` is rendered with a `~` glyph next to the citation: `` `auth/middleware.py:42`~ ``. This is unobtrusive enough not to clutter Tier-1-clean reports but visible enough that downstream agents can grep for it.

**Rejected alternative — single freeform template per query.** Faster to author but defeats the point of having a deterministic API. Consumers (executor, code-reviewer, etc.) need to be able to count on the section ordering so their integration prompts can reference specific sections.

### Q4 — Tier-3 Escalation Prompt UX

**Decision: an explicit, single-paragraph prompt that explains why, what, and the cost — accepts only `yes` (case-insensitive) as confirmation; everything else (including empty input) is treated as decline and the agent proceeds with current data plus a precision caveat.**

The prompt copy is below. It is intentionally not chatty — Tier-3 escalation is a moment of friction, and friction should be brief.

```
[code-intel] Tier-3 escalation available

The query you asked — `<query_type>` for symbol `<symbol>` (language: <lang>) —
would benefit meaningfully from a tree-sitter parse. The current Tier-2 (regex)
result is usable but imprecise:

  <one-sentence concrete imprecision, e.g. "polymorphic dispatch in Java/C# means
  find_implementations may miss override relationships across compilation units">

Installing tree-sitter and re-indexing would cost roughly:
  - <T> seconds of wall-clock for the install (one-time, per machine)
  - <U> seconds of wall-clock for the re-index (now)
  - <V> MB of disk for the tree-sitter binary and grammars

To proceed with the install and re-index, reply `yes` (case-insensitive).
Anything else — including an empty reply — proceeds with the current Tier-2
data plus a precision caveat in the report.
```

The phrasing has three deliberate properties:

1. **It tells the user *why* before it tells them *what*.** Without the imprecision sentence, the user has no way to decide whether the precision matters for *their* question. The agent picks the imprecision sentence from a small lookup table keyed on `(query_type, language)` — see Tier Cascade Logic below.
2. **It surfaces the costs concretely.** Wall-clock and disk numbers come from a per-language lookup table baked into the agent body (e.g., `tree-sitter-rust` ≈ 50 MB, `tree-sitter-java` ≈ 80 MB). They do not have to be precise — they have to be in the right order of magnitude so the user is not surprised.
3. **It picks `yes` as the only positive confirmation.** Accepting "any non-empty string" is the kind of flexibility that quietly turns "I was just typing notes" into a `pip install`. Strict-confirmation is the prevention-first choice.

**Rejected alternative — accept any non-empty confirmation.** Reduces friction but invites accidental installs. The whole point of Tier-3 is that the install is non-trivial.

**Rejected alternative — silent escalation with a post-hoc note.** Violates the "never install silently" hard constraint in R4.

**Rejected alternative — multi-turn dialog (ask install, then ask which language, then ask which grammar).** Too chatty for an agent that is being dispatched in the middle of someone else's workflow. Single prompt, single response.

### Q5 — JSON Brief Schema Validation

**Decision: strict — refuse on unknown fields, missing required fields, or type mismatches. Refusal returns the usage card from R3.**

Strict validation is the prevention-first choice. The cost of being strict is that a typo (`symbo` instead of `symbol`) gets a refusal instead of being silently ignored, and the user has to re-issue the brief. The benefit is that the consumer never sees a response computed against a misinterpreted brief — there is no class of bugs where the orchestrator thought it asked for `find_callers` and `code-intel` answered as if it had been asked something else.

**Authoritative JSON schema (described in prose, encoded in the agent body):**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "code-intel brief",
  "type": "object",
  "additionalProperties": false,
  "required": ["query_type", "symbol"],
  "properties": {
    "query_type": {
      "type": "string",
      "enum": [
        "find_definition", "find_callers", "find_dependencies",
        "impact_analysis", "find_implementations", "execution_flow",
        "reindex", "clean"
      ]
    },
    "symbol":          { "type": "string", "minLength": 1 },
    "scope":           { "type": "string" },
    "depth":           { "type": "integer", "minimum": 1, "maximum": 5 },
    "output_mode":     { "type": "string", "enum": ["inline", "disk", "both"] },
    "max_results":     { "type": "integer", "minimum": 1, "maximum": 200 },
    "max_depth":       { "type": "integer", "minimum": 1, "maximum": 5 },
    "max_files":       { "type": "integer", "minimum": 1, "maximum": 5000 },
    "max_wall_clock_s": { "type": "integer", "minimum": 1, "maximum": 600 }
  }
}
```

Notes on the schema:

- `additionalProperties: false` is what makes validation strict.
- `query_type` includes `reindex` and `clean` (the R11 escape hatches) as enum values. They share the brief shape; for `clean`, `symbol` is required by the schema but ignored at runtime (set it to `"<n/a>"`).
- The `max_*` upper bounds are the R9 *hard* caps. A request to set `max_files: 10000` is refused at validation time, not silently clamped — that matches R9's explicit posture.
- `depth` and `max_depth` are intentionally separate. `depth` is the *requested* traversal depth for queries that take one (`find_callers`, `impact_analysis`, `execution_flow`). `max_depth` is the *cap* — useful when the orchestrator wants to defend itself against runaway CTEs without specifying an exact depth.

The agent body validates by sketch:

```python
# Pseudocode — actual implementation is the executor's job.
brief = parse_json_fenced_block(input)
if brief is None:
    refuse_with_usage_card("malformed: no JSON-fenced block found")
violations = validate_against_schema(brief, BRIEF_SCHEMA)
if violations:
    refuse_with_usage_card(f"malformed: {violations}")
# proceed
```

**Rejected alternative — permissive (ignore unknown fields).** Forward-compatible but invites silent typos. R10 is explicit that prevention-first beats silent fallback.

**Rejected alternative — strict for known fields, warn on unknown.** A warning that the consumer never reads is just a permissive validator. Either refuse or do not, no half measures.

### Q6 — SQLite WAL vs Default Journal Mode

**Decision: WAL mode.** Add `*.sqlite-wal` and `*.sqlite-shm` to the `.gitignore` line for `.code-intel/` (which already covers them since `.code-intel/` is the entry).

WAL mode is the right choice for the `code-intel` workload for two specific reasons. First, the **staleness-check + reindex** pattern (R11b) involves long writes (the reindex) overlapping with short reads (a query that runs *during* the reindex by another orchestrator). Default rollback-journal mode would block readers during the reindex; WAL mode lets them proceed against the pre-reindex snapshot, which is the right semantics — a reader at SHA `abc` sees a consistent view even while a writer is rebuilding for SHA `def`.

Second, WAL mode is friendlier to **interrupted writes**. If the indexer is killed mid-rebuild (say, `/ops` Phase 4 cleanup, an OS interrupt, or a Tier-3 escalation timeout), the WAL file is replayable and SQLite recovers automatically on the next open. With rollback-journal mode, the recovery story is rougher.

The cost of WAL is two sidecar files (`-wal` and `-shm`) that live next to `index.sqlite`. Both are already permitted under `.code-intel/**` per the R8a write-allowlist, so no allowlist change is needed. The R8b SQLite operations also do not need to change — `sqlite3 .code-intel/index.sqlite "PRAGMA journal_mode=WAL;"` is a normal read/write SQLite command.

**One additional R8b note:** the agent must be able to issue `PRAGMA journal_mode=WAL;`, `PRAGMA foreign_keys=ON;`, and `PRAGMA synchronous=NORMAL;` on connection open. These are read/write pragmas executed against `.code-intel/index.sqlite` — they fall under "SQLite operations" in R8b and do not require a separate allowlist entry.

**Write-path enforcement uses glob matching, not a literal allow-list (addresses C-ADD-2).** The R8a refuse-and-halt check compares each candidate `Write` path against a *glob set*, not a literal path set. The canonical glob set is:

- `.code-intel/**` — covers `index.sqlite`, `index.sqlite-wal`, `index.sqlite-shm`, `runs/<run-id>/**`, and any future SQLite or indexer artifact under that root.
- `docs/code-intel/**` — covers durable, human-opt-in reports.
- `_tmp_*` — covers temporary files emitted at the repo root (e.g., `_tmp_indexer-skipped.log` and any `_tmp_*` artifact SQLite itself drops during WAL operation).

The agent must NOT use a literal-path allow-list. A literal set would, for example, permit `.code-intel/index.sqlite` but refuse `.code-intel/index.sqlite-wal` — which crashes the indexer on first run, since WAL mode writes the sidecar before any other write. Glob matching is canonical; the `**` recursion is what makes future-additions-under-`.code-intel/` automatically permitted without allowlist churn. The agent body's lane-enforcement section (per the Agent Body Skeleton, section 6.2) must spell the glob set out verbatim.

**Rejected alternative — default rollback-journal mode.** Simpler (no sidecars) but worse concurrency. The simplification does not buy enough to outweigh the concurrency loss.

**Rejected alternative — `PRAGMA journal_mode=MEMORY`.** Avoids sidecars entirely but means an interrupted write corrupts the database. R10 already has a "DB corrupted" row, but inviting more corruption is not the right v1 trade.

### Q7 — Project Language Profile Detection

**Decision: a two-pass algorithm — manifest sniff first, file-extension sweep second, both contribute to a single language profile that drives Tier-1 runtime probing.**

Pure manifest sniffing misses projects that have source code but no manifest at the root (e.g., a Bash scripts directory, a polyglot monorepo where one language has no manifest). Pure extension sweeping is noisy — `.js` in `node_modules/` is not project source. The two-pass approach combines them:

```python
# Pseudocode for the language-profile pass.

LANGUAGE_MANIFESTS = {
  'python':     ['pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', 'Pipfile'],
  'typescript': ['tsconfig.json', 'package.json'],   # package.json with .ts files
  'javascript': ['package.json'],
  'rust':       ['Cargo.toml'],
  'go':         ['go.mod'],
  'csharp':     ['*.csproj', '*.sln'],
  'java':       ['pom.xml', 'build.gradle', 'build.gradle.kts'],
  'php':        ['composer.json'],
  'dart':       ['pubspec.yaml'],
  'ruby':       ['Gemfile'],
}

EXTENSION_MAP = {
  '.py':   'python',
  '.ts':   'typescript', '.tsx': 'typescript',
  '.js':   'javascript', '.jsx': 'javascript', '.mjs': 'javascript', '.cjs': 'javascript',
  '.rs':   'rust',
  '.go':   'go',
  '.cs':   'csharp',
  '.java': 'java', '.kt': 'java',           # Kotlin folded into java tier for v1
  '.php':  'php',
  '.dart': 'dart',
  '.rb':   'ruby',
  '.sh':   'bash', '.bash': 'bash',
  '.ps1':  'powershell', '.psm1': 'powershell',
}

def detect_language_profile(repo_root):
    profile = {}  # language -> {via_manifest: bool, file_count: int}

    # Pass 1 — manifest sniff (fast, glob-based). Iteration is alphabetical
    # by language name to guarantee a stable probe order across runs.
    for lang in sorted(LANGUAGE_MANIFESTS.keys()):
        for m in LANGUAGE_MANIFESTS[lang]:
            hits = glob(f"**/{m}", excluded=HARDCODED_EXCLUDES)
            if hits:
                profile.setdefault(lang, {}).update({'via_manifest': True})
                break

    # Pass 2 — extension sweep (counts files per language for prioritization).
    # Iteration is alphabetical by language name so the file_count writes land
    # in a deterministic order.
    for ext, lang in sorted(EXTENSION_MAP.items(), key=lambda kv: (kv[1], kv[0])):
        count = len(glob(f"**/*{ext}", excluded=HARDCODED_EXCLUDES))
        if count > 0:
            profile.setdefault(lang, {})['file_count'] = count

    return profile
```

The profile drives Tier-1 runtime probing. For each language present in the profile (manifest *or* extension count > 0), the agent runs a capability detection probe:

- `python`: `which python` (or `python --version`) — Tier-1 if present.
- `typescript`: `which tsc` and `which node` — Tier-1 if both present.
- `javascript`: `which node` — Tier-1 if present.
- All other languages: Tier-1 unavailable in v1, fall through to Tier-2 (Grep heuristics).

The profile is stored in `metadata.languages_seen` and `metadata.tier1_runtimes` so consumers can see at a glance what mode they are reading.

**Stable probe order (addresses C-ADD-3).** Both passes iterate languages **alphabetically by language name** (`csharp`, `dart`, `go`, `java`, `javascript`, `php`, `python`, `ruby`, `rust`, `typescript`, …). The same rule applies to the Tier-1 runtime probes that follow — the probe loop walks the profile keys in `sorted()` order. This guarantees that two runs against the same repo produce the same `metadata.languages_seen` and `metadata.tier1_runtimes` strings, which matters because those strings end up in every R6 report header. If two manifests in the same language entry both hit (e.g., a Python project with both `pyproject.toml` and `setup.py`), the **tiebreaker is manifest specificity** — the earliest entry in that language's manifest list wins, since the lists in `LANGUAGE_MANIFESTS` are pre-sorted from most-specific to least-specific (e.g., `pyproject.toml` before `requirements.txt`). The executor must preserve the within-list order when transcribing the table into the agent body.

**Edge case: empty repository.** Both passes return an empty profile. The indexer builds an empty database, persists metadata, and any query returns `Symbol not found`. Per R10 this is a refuse-not-failure.

**Edge case: polyglot project where manifest says Python but file-extension sweep finds 90% TypeScript.** The profile contains both languages with the file counts. Tier-1 probing happens for both, in alphabetical order (so `python` is probed before `typescript`). The file-count signal informs no behavior in v1, but is logged in `metadata.languages_seen` as a hint for future tuning.

**Rejected alternative — manifest-only.** Misses repos with code but no manifest, and the deploy artifacts directory in this very project (no manifest, multiple `.ps1` files) would be invisible.

**Rejected alternative — extension-only.** Noisy; excludes-list bears too much weight; cannot distinguish "package.json with TypeScript" from "package.json with vanilla JS" without parsing the manifest anyway.

**Rejected alternative — file-count-weighted probe order.** Tempting (probe the largest language first) but non-deterministic across runs whose file counts shift slightly. Alphabetical wins on stability.

### Q8 — Per-Project Configuration File

**Decision: no config file in v1.** Hardcoded excludes (below) ship in the agent body. v2 introduces `.code-intel/config.toml` *only if* real projects produce concrete needs that the hardcoded list cannot cover.

The recommendation in the requirements doc is correct — adding a config file before any project has demonstrated a need is YAGNI. The hardcoded list below covers every directory I can find in this repo and the typical projects the user works in. If a project has an unusual layout (a `vendor/` directory containing first-party code, a non-default Python venv name), the user can either rename the directory to a standard name (cheap, one-time) or wait for v2.

**Hardcoded excludes (matched against repo-relative path components):**

```
node_modules/
.git/
.hg/
.svn/
__pycache__/
.pytest_cache/
.mypy_cache/
.ruff_cache/
.venv/
venv/
env/
dist/
build/
out/
target/        # Rust, Java
obj/           # .NET intermediate
bin/           # .NET output
.gradle/
.idea/
.vscode/
.next/
.nuxt/
.cache/
coverage/
.code-intel/   # the agent's own state
.ops-state/    # team manager state
```

The exclude check is path-component-aware: a directory named `node_modules` anywhere in the tree is excluded, but a file named `node_modules.md` is not. This matches how `tooling/deploy.ps1` already handles excludes (per the recent fix in commit `7d7aaae` — "match exclude patterns against relative path, not filename").

Two excludes worth calling out:

- **`.code-intel/`** — the indexer must not index its own database. Recursive embarrassment.
- **`.ops-state/`** — the team manager's state files contain JSON snippets that look like code to a regex but are not. Excluding them avoids false positives in Tier-2.

**Rejected alternative — `.code-intel/config.toml` for v1.** Adds a parsing surface, a documentation surface, and a class of "but my config says X" support questions, all before any project has produced a concrete need. v2 is cheap to add when there is one.

**Rejected alternative — environment-variable overrides.** Same problem with less discoverability.

### Q9 — Cursor Variant

**Decision: single body, no Cursor variant for v1.** The agent file is `agents/code-intel.md`. No `code-intel.cursor.md`, no transform script.

Of the 19 existing agents, *zero* have a Cursor variant. The transform machinery in `tooling/transform-cursor-*.{ps1,sh}` is per-skill, not per-agent. Adding a Cursor variant for `code-intel` would be inventing a pattern that does not exist for this kind of artifact.

If a Cursor-specific divergence shows up later — say, Cursor's Bash tool restricts certain commands the agent relies on — that is a real signal to add a variant *then*, with a real diff to justify it. v1 with a single body is the lower-risk path.

The deploy manifest already deploys `agents/*.md` to both `~/.claude/agents/` and `~/.cursor/agents/` with `transform: true` for the Cursor channel. The transform is a no-op for files without Cursor-specific markup. So the same body lands in both environments without any new tooling.

**Rejected alternative — proactive Cursor variant.** No concrete divergence justifies the doubled maintenance surface. v2 if needed.

### Q10 — Indexer Skipped-File Log Lifecycle

**Decision: per-run overwrite at `_tmp_indexer-skipped.log`.** The file is written at the start of every indexer run (whether full reindex or initial build), appended-to during the run as files are skipped, and is subject to the standard `_tmp_*` batch cleanup at run checkpoints.

The recommendation in the requirements doc is correct. `_tmp_*` files are batch-cleaned at run checkpoints anyway, so any "persist across runs" semantics would be defeated by the cleanup protocol. Per-run overwrite makes the file's contents a *snapshot of the most recent indexer run*, which is what a debugging consumer would actually want.

The log entries follow this format:

```
<ISO-8601 timestamp>  <reason>  <file_path>
2026-04-26T14:32:01Z  unreadable (permission denied)   subdir/locked-file.py
2026-04-26T14:32:01Z  unreadable (binary content)      assets/sample.bin
2026-04-26T14:32:02Z  exceeded individual file size    huge/generated.json
```

The `reason` field is a short fixed-vocabulary string (one of `unreadable`, `binary`, `oversize`, `parse_error`) followed by an optional parenthetical. Consumers can grep for the fixed vocabulary; the parenthetical is for human eyes only.

When the soft-cap warning fires (R9), the indexer also emits a one-line summary at the end:

```
2026-04-26T14:35:00Z  summary  43 files skipped during indexing run (4933 indexed)
```

**Rejected alternative — append-across-runs.** The file would grow unbounded without a rotation mechanism, and the `_tmp_*` cleanup would defeat it anyway.

**Rejected alternative — write to `.code-intel/skipped.log` (persistent location).** Would persist correctly but conflates *transient debugging output* with *index state*. Keep them separate; the index state is the SQLite DB.

---

## SQLite Schema (Authoritative)

Re-stated here as a single block so the planner can hand it to the executor verbatim:

```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous  = NORMAL;

CREATE TABLE IF NOT EXISTS nodes (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  kind        TEXT    NOT NULL,
  name        TEXT    NOT NULL,
  qualified   TEXT,
  file_path   TEXT    NOT NULL,
  line_start  INTEGER NOT NULL,
  line_end    INTEGER NOT NULL,
  signature   TEXT,
  language    TEXT    NOT NULL,
  precision   TEXT    NOT NULL,
  CHECK (kind IN ('function','class','method','file','module','interface')),
  CHECK (precision IN ('ast','regex','tree-sitter'))
);

CREATE TABLE IF NOT EXISTS edges (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  from_id     INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  to_id       INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  edge_type   TEXT    NOT NULL,
  precision   TEXT    NOT NULL,
  CHECK (edge_type IN ('CALLS','IMPORTS','EXTENDS','IMPLEMENTS','OVERRIDES')),
  CHECK (precision IN ('ast','regex','tree-sitter'))
);

CREATE TABLE IF NOT EXISTS metadata (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_nodes_name      ON nodes(name);
CREATE INDEX IF NOT EXISTS idx_nodes_file      ON nodes(file_path);
CREATE INDEX IF NOT EXISTS idx_nodes_qualified ON nodes(qualified);
CREATE INDEX IF NOT EXISTS idx_edges_from      ON edges(from_id, edge_type);
CREATE INDEX IF NOT EXISTS idx_edges_to        ON edges(to_id, edge_type);
```

Required `metadata` keys at end of every successful indexer run:

| Key | Example | Purpose |
| :--- | :--- | :--- |
| `schema_version` | `"1"` | Migration trigger |
| `db_indexed_sha` | `"a3f7c12"` | Stamped on every R6 artifact |
| `generated_at` | `"2026-04-26T14:35:00Z"` | Stamped on every R6 artifact |
| `indexer_wall_clock_s` | `"42"` | R9 soft-cap monitoring |
| `languages_seen` | `"python,typescript,bash"` | Q7 profile output |
| `tier1_runtimes` | `"python,node,tsc"` | What was probed and found |
| `file_count` | `"4933"` | R9 hard-cap check |

---

## Recursive CTE Templates

One template per query. The `?` placeholders are bind parameters supplied by the query handler. These are *sketches* — the executor's job is to harden them (parameter binding, error handling, depth-cap enforcement). The point here is to show feasibility.

### `find_definition`

```sql
SELECT id, kind, name, qualified, file_path, line_start, line_end,
       signature, language, precision
FROM nodes
WHERE name = ?
  AND (? IS NULL OR file_path GLOB ?)   -- optional scope as glob
ORDER BY (precision = 'ast') DESC,       -- prefer AST-grade matches
         file_path, line_start
LIMIT ?;                                  -- max_results, default 200
```

### `find_callers`

```sql
WITH RECURSIVE callers(target_id, caller_id, depth) AS (
  -- Seed: direct callers (depth 1).
  SELECT e.to_id, e.from_id, 1
  FROM edges e
  WHERE e.to_id IN (SELECT id FROM nodes WHERE name = ?)
    AND e.edge_type = 'CALLS'

  UNION

  -- Step: callers of callers, up to depth.
  SELECT c.target_id, e.from_id, c.depth + 1
  FROM callers c
  JOIN edges e ON e.to_id = c.caller_id
  WHERE e.edge_type = 'CALLS' AND c.depth < ?  -- max_depth
)
SELECT n.id, n.name, n.file_path, n.line_start, n.signature,
       n.precision, c.depth
FROM callers c
JOIN nodes n ON n.id = c.caller_id
ORDER BY c.depth, n.file_path, n.line_start
LIMIT ?;
```

### `find_dependencies`

```sql
-- Outbound edges from the target symbol (direct only — depth=1).
SELECT n.kind, n.name, n.file_path, n.line_start, n.signature,
       e.edge_type, e.precision
FROM edges e
JOIN nodes src ON src.id = e.from_id
JOIN nodes n   ON n.id   = e.to_id
WHERE src.name = ?
  AND e.edge_type IN ('CALLS','IMPORTS')
ORDER BY e.edge_type, n.file_path, n.line_start
LIMIT ?;
```

### `impact_analysis` *(keystone)*

```sql
-- Section 1 + 2: transitive callers (CALLS edges, depth-bounded).
WITH RECURSIVE impact(target_id, reached_id, edge_path, depth) AS (
  SELECT e.to_id, e.from_id, e.edge_type, 1
  FROM edges e
  WHERE e.to_id IN (SELECT id FROM nodes WHERE name = ?)
    AND e.edge_type = 'CALLS'

  UNION

  SELECT i.target_id, e.from_id, e.edge_type, i.depth + 1
  FROM impact i
  JOIN edges e ON e.to_id = i.reached_id
  WHERE e.edge_type = 'CALLS' AND i.depth < ?
)
SELECT n.name, n.file_path, n.line_start, n.precision, i.depth
FROM impact i
JOIN nodes n ON n.id = i.reached_id
ORDER BY i.depth, n.file_path, n.line_start;

-- Section 3: implementers (separate CTE — see find_implementations).
-- Section 4: test exposure (LIKE-based heuristic on file_path).
SELECT DISTINCT n.file_path, n.name, n.line_start
FROM nodes n
JOIN edges e ON e.from_id = n.id
WHERE e.to_id IN (SELECT id FROM nodes WHERE name = ?)
  AND (n.file_path LIKE 'test_%'
       OR n.file_path LIKE '%/test_%'
       OR n.file_path LIKE '%_test.%'
       OR n.file_path LIKE '%/tests/%'
       OR n.file_path LIKE '%.spec.%')
ORDER BY n.file_path, n.line_start;
```

### `find_implementations`

```sql
-- Anything that EXTENDS, IMPLEMENTS, or OVERRIDES the target.
SELECT n.kind, n.name, n.qualified, n.file_path, n.line_start,
       e.edge_type, e.precision
FROM edges e
JOIN nodes tgt ON tgt.id = e.to_id
JOIN nodes n   ON n.id   = e.from_id
WHERE tgt.name = ?
  AND e.edge_type IN ('EXTENDS','IMPLEMENTS','OVERRIDES')
ORDER BY e.edge_type, n.file_path, n.line_start
LIMIT ?;
```

### `execution_flow`

```sql
WITH RECURSIVE flow(start_id, current_id, depth, path) AS (
  SELECT n.id, n.id, 0, n.name
  FROM nodes n
  WHERE n.name = ?

  UNION

  SELECT f.start_id, e.to_id, f.depth + 1, f.path || ' -> ' || tgt.name
  FROM flow f
  JOIN edges e   ON e.from_id = f.current_id
  JOIN nodes tgt ON tgt.id    = e.to_id
  WHERE e.edge_type = 'CALLS'
    AND f.depth < ?
    AND instr(f.path || ' -> ' || tgt.name, tgt.name || ' -> ' || tgt.name) = 0
    -- crude cycle guard; full cycle handling is the renderer's job
)
SELECT n.name, n.file_path, n.line_start, n.precision, f.depth, f.path
FROM flow f
JOIN nodes n ON n.id = f.current_id
ORDER BY f.depth, n.file_path
LIMIT ?;
```

---

## Agent Body Skeleton

The agent body is read by every spawned `code-intel` instance. It must be *deliberately small* — the larger it grows, the more tokens every dispatch costs. Target: 300–400 lines, structured as below.

```text
1. YAML frontmatter (name, model, description, tools)
2. One-line role statement and "you are not" disclaimer
3. Quick-reference card (`help` task)
4. When you're dispatched (orchestrator + standalone use)
5. Brief Format
   5.1 JSON-fenced (orchestrator) — schema reference (Q5)
   5.2 Labeled-prose (human) — field-by-field equivalence
   5.3 Malformed — refuse with usage card
6. Lane Boundaries
   6.1 Read-only on source code
   6.2 Write-allowlist enforced via glob matching: `.code-intel/**`,
       `docs/code-intel/**`, `_tmp_*` (per Q6 — addresses C-ADD-2)
   6.3 Refuse-and-halt on first violation (R8a verbatim)
7. Bash Scope
   7.1 Permitted (R8b allow-list verbatim)
   7.2 Forbidden (R8b deny-list verbatim)
   7.3 Refuse-and-halt on forbidden invocation
8. Lifecycle
   8.1 Build trigger — combination (R11a)
   8.2 Staleness check (R11b — every dispatch, full reindex)
   8.3 Cleanup (R11c)
9. Indexer Pipeline
   9.1 Phase enumeration (see Indexer Pipeline section below)
   9.2 Tier cascade reference (see Tier Cascade section below)
   9.3 Skipped-file log format (Q10)
10. Query Handlers
    10.1 find_definition  — CTE + render template
    10.2 find_callers     — CTE + render template
    10.3 find_dependencies — CTE + render template
    10.4 impact_analysis  — multi-CTE + four-section render template
    10.5 find_implementations — CTE + render template
    10.6 execution_flow   — CTE + indented-tree render template
11. Output Dispatch (R6 + R6b)
    11.1 Format detection (JSON-fenced ⇒ orchestrator path; labeled-prose ⇒ human path)
    11.2 output_mode override
    11.3 Required header/footer (db_indexed_sha, generated_at, caveats, provenance)
12. Tier-3 Escalation
    12.1 When to offer (lookup table on (query_type, language))
    12.2 Prompt copy (Q4 verbatim)
    12.3 Response handling (only `yes` proceeds; otherwise current data + caveat)
    12.4 Suppression in non-interactive contexts: if the brief was a
         JSON-fenced block (orchestrator path per R3), skip the prompt
         and proceed with current data plus caveat (addresses C-ADD-1)
13. Performance Enforcement
    13.1 R9 hard caps (file count, wall-clock, depth, results)
    13.2 Per-run overrides (max_*) — accept up to hard cap, refuse above
    13.3 Truncation rendering
14. Failure Matrix (R10 verbatim, table form)
15. Output Format examples
    15.1 Successful query (one example, find_callers)
    15.2 Refusal (usage card)
    15.3 Violation report (write-allowlist breach)
16. Constraints (no-compound-Bash, no-cd-prefix, etc.)
17. Handoff
    17.1 To /ops Phase 2.5b (return summary path)
    17.2 To human (inline report)
```

The CTE bodies in section 10 may be referenced as inline code blocks (preferred — keeps the agent self-contained) or by external reference if the executor judges the body too long. Recommendation: inline. The CTEs are short.

---

## `/ops` Phase 2.5b Integration Contract

This is the contract the team manager uses to dispatch `code-intel` and consume its output. It must be encoded in `skills/ops/SKILL.md` Phase 2.5b prose so future ops changes do not silently break it.

### What the team manager passes in

The team manager composes a JSON brief (per Q5 schema) and embeds it in the dispatch prompt:

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
  "max_wall_clock_s": 60
}
```

The JSON-fenced brief is the **sole and authoritative orchestrator-path signal** (per R3, the brief-format contract is the canonical caller-type detector — addresses C-ADD-1). A JSON-fenced brief comes only from orchestrators; a labeled-prose brief comes only from humans. The agent does not look for any additional `[context]` block, marker, or sentinel — earlier drafts of this ADD proposed one, but it would have conflicted with the existing `## Context` Markdown heading in `/ops`'s standard agent-briefing format (`skills/ops/SKILL.md:486-506`). Reusing the brief format itself as the signal avoids inventing a second contract.

Run-scoped context the team manager wants to surface to a human reading the dispatch log (e.g., `run_id`, `files_touched`, `predicate_match`, the executor brief excerpt) belongs in the **`## Context` Markdown section of the standard agent brief** (per `skills/ops/SKILL.md:486-506`), *not* in any `[context]` block. The agent reads that Markdown for human-readable error messages but does not act on it programmatically — Q5's strict validator only cares about the JSON-fenced block.

### What `code-intel` returns

For `output_mode: "disk"` (the orchestrator default), the agent returns this JSON-fenced response back to the team manager:

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

For `output_mode: "inline"`, the response includes a `report_inline` field (full Markdown) and *omits* `report_path`. For `output_mode: "both"`, both are populated *but the `report_inline` field carries only the summary*, not the full report — per R6b the "both" mode returns summary plus path, not duplicate full content.

The team manager then attaches `report_path` to the executor's task brief as a new line:

```text
Code Intelligence Context: see .code-intel/runs/<run-id>/impact_analysis-<symbol>.md
  - <one-line summary from the response>
  - <caveat 1, if any>
  - <caveat 2, if any>
```

The executor reads the report on demand. It does not have to ingest the full report into its context window upfront.

### Refusal handling

When `code-intel` returns `status: "refused"` (e.g., symbol not found, hard cap hit, malformed brief), the team manager records the refusal in the dispatch log, attaches the refusal reason to the executor's brief (so the executor knows the consultation was attempted but did not yield results), and proceeds. Phase 2.5b is *advisory* — its refusal does not block the executor.

---

## Tier Cascade Logic

The tier cascade is the heart of the indexer. Pseudocode below; the executor's job is to harden it.

```python
# Per file, after the language profile (Q7) is established.

def index_file(file_path, language, runtimes):
    """
    Returns (nodes, edges, precision_used) for the file, or raises if unreadable.
    """
    # Tier 1 — precise AST.
    if language == 'python' and 'python' in runtimes:
        return parse_with_python_ast(file_path), 'ast'
    if language in ('typescript', 'javascript') and 'tsc' in runtimes:
        return parse_with_tsc(file_path, language), 'ast'

    # Tier 2 — Grep heuristics.
    if language in TIER_2_SUPPORTED:   # rust, go, csharp, java, php, dart, bash, powershell, ruby
        return parse_with_grep_heuristics(file_path, language), 'regex'

    # Unknown language — record file node only, no edges.
    return ([file_node_for(file_path, language='unknown')], []), 'regex'


def consider_tier3_escalation(query_type, language, results, runtimes, brief_format):
    """
    Called by the query handler after a query produces a partial-precision result.
    Returns True if Tier-3 should be offered to the user; False otherwise.
    """
    # Suppression in non-interactive contexts — JSON-fenced briefs come only
    # from orchestrators per R3 (addresses C-ADD-1). Falling through to
    # "proceed with current data + caveat" preserves prevention-first in
    # interactive contexts while keeping orchestrator dispatches deterministic.
    if brief_format == 'json-fenced':
        return False

    # The lookup table from Q4 — query/language combinations where tree-sitter
    # would meaningfully improve precision over Tier-2.
    TIER3_BENEFICIAL = {
        ('find_implementations', 'java'),   ('find_implementations', 'csharp'),
        ('find_implementations', 'rust'),
        ('execution_flow',       'java'),   ('execution_flow',       'csharp'),
        ('find_callers',         'rust'),
    }
    if (query_type, language) not in TIER3_BENEFICIAL:
        return False
    # Tree-sitter not yet installed for this language?
    if f'tree-sitter-{language}' in runtimes:
        return False
    # Results were Tier-2 (regex precision)?
    if not any(r.precision == 'regex' for r in results):
        return False
    return True
```

`precision` propagates from indexer to query response by storing it on every node and edge row (per the schema in Q1). The query renderers read those `precision` columns and surface the `~` glyph and the Tier-2 caveat in the report footer.

---

## Indexer Pipeline

The v1 indexer mirrors GitNexus's pipeline DAG conceptually but trims it to the minimum needed for the schema in Q1. Five phases, run in order, all single-threaded (Q2):

| Phase | Purpose | Output |
| :--- | :--- | :--- |
| **1. Scan** | Walk the repo (`Glob`) honoring hardcoded excludes (Q8). Build the file list. | List of `(file_path, language)` tuples; file count for R9 hard-cap check. |
| **2. Profile** | Manifest sniff + extension sweep (Q7). Probe Tier-1 runtimes via `which` / `--version` (R8b allowlist). | Language profile + runtime availability map. |
| **3. Parse** | For each file in the scan list, dispatch to Tier-1 (AST) or Tier-2 (Grep) per Tier Cascade Logic. Emit `nodes` and `edges` records. Skip-and-log unreadable files (Q10). | In-memory list of nodes and edges, per file. |
| **4. Cross-file resolve** | Resolve `IMPORTS` edges across files (e.g., `from x import y` in Python — match `y` in another file's `nodes` table). Resolve `EXTENDS`/`IMPLEMENTS`/`OVERRIDES` where Tier-1 produced enough information. | Updated edge records with `to_id` populated for cross-file references. Unresolved edges are dropped (logged in `_tmp_indexer-skipped.log` as `unresolved_edge`). |
| **5. Load** | Open SQLite (with the pragmas from Q6), `DROP TABLE` on stale-reindex (R11b) or `CREATE TABLE IF NOT EXISTS` on fresh build, `INSERT` nodes and edges in a single transaction, populate `metadata`. | Persisted database at `.code-intel/index.sqlite`. |

The phases are sequential; Phase N+1 cannot start until Phase N finishes for the whole repo. Within a phase, files are processed sequentially for v1 (Q2). Wall-clock is measured at the start of Phase 1 and stopped at the end of Phase 5; that elapsed time is what R9's 60s soft / 600s hard cap measures.

**Failure modes per phase** map cleanly onto R10:

- Phase 1 — file count > 5000 → refuse (R9 hard cap).
- Phase 2 — Tier-1 runtime missing → silent fallback to Tier-2 (R10) + caveat propagated to query responses.
- Phase 3 — file unreadable → skip + log (R10) + continue.
- Phase 4 — unresolved edge → drop + log + continue.
- Phase 5 — SQLite error → refuse + auto-recovery offer (R10 "DB corrupted" row).

---

## Open Implementation Risks

Things the executor and verifier should watch for that are not lane-violations of this ADD but are concrete risks the planner and reviewers should encode as test cases or guardrails.

1. **Recursive CTE depth on hub functions.** A deeply-called function (e.g., a logger) at depth 5 can blow up combinatorially. The 30s query timeout in R10 catches this, but the *experience* of waiting 30 seconds for a refusal is bad. Suggest the verifier add a test fixture that exercises a hub function and confirms the timeout fires cleanly.
2. **Tier-2 false positives in string literals.** A regex that hunts `def foo(...)` in Python will match a string literal containing those bytes. v1 accepts this — Tier-2 is *regex precision* by definition, and the `precision: regex` caveat is the user-facing signal. The verifier should confirm at least one Tier-2-only fixture surfaces the caveat correctly.
3. **`tsc --noEmit` is slow on large TypeScript projects.** A 1000-file TS project can spend 30+ seconds in `tsc` alone. Phase 3 wall-clock dominates. If this hits the 60s soft cap routinely, v2 can introduce per-file `tsc` invocation with a worker pool — but v1 accepts the slowdown.
4. **Cross-file resolve in Phase 4 is the riskiest phase.** Python's `from x.y import z` requires the resolver to understand package layout, namespace packages, and re-exports. A v1 implementation that handles only the common case (direct imports from the same package) will produce an incomplete graph for some projects. The R10 caveat "Tier-2 only" already covers some of this, but Tier-1 *precise-but-incomplete* is a new failure mode worth surfacing in the report footer when it happens.
5. **WAL sidecars on Windows.** `*.sqlite-wal` and `*.sqlite-shm` are normal files on POSIX but Windows occasionally locks them in ways that break `git clean -fdx`. Suggest documenting in the agent body that `clean` query closes the connection before deleting.
6. **`/ops` Phase 2.5b in nested-skill scenarios.** If `/ops` is invoked from inside `/ralph-loop` (which already happens in some workflows), the `code-intel` dispatch in Phase 2.5b would nest two layers deep. The current `/ops` nested-skill protocol (per `skills/ops/handoffs.md`) should handle this, but the planner should confirm the integration tests cover the nested case.
7. **Schema migration story for v2.** v1 has `schema_version = "1"` in metadata. When v2 changes the schema (adds a column, splits a table), the agent must either migrate or refuse-and-rebuild. Refuse-and-rebuild is the simpler v1.5 story; migration logic is a v2 problem. The planner should not over-design the migration in v1.
8. **Symbol-collision with builtin names.** `print`, `len`, `list` in Python or `Object`, `Array`, `Promise` in TypeScript will produce many spurious `find_definition` hits if the user queries them. v1 accepts this — the `kind` column (`function`/`class`/etc.) helps, and the user can always add `scope`. v2 might add a "skip builtins" option.
9. **The `runs/<run-id>/` directory under `.code-intel/`** — needs a cleanup policy. **User decision (post-ADD):** orchestrator-driven render artifacts now live at `.code-intel/runs/<run-id>/` (ephemeral, gitignored via parent `.code-intel/`); `/ops` Phase 4 cleans them per the existing handoff/run-scoped cleanup pattern. Durable, committable reports for human-driven persistent queries live at `docs/code-intel/<symbol>-<query>.md` instead. The path itself encodes the lifetime, so the unbounded-growth concern from v1 is resolved by the split.
10. **Capability-detection cache.** Q7's runtime probes (`which python`, `which node`, etc.) take a few hundred milliseconds each. If the indexer runs them on every dispatch, that is wasted wall-clock — most repos have stable runtime availability. Suggest the planner add a `metadata.tier1_runtimes_probed_at` key and re-probe only if older than the indexed SHA. v1 can ignore this; v2 should add it.

---

## Component Boundaries

Where the lines are. The `code-intel` module owns the SQLite database, the indexer pipeline, and the query handlers. Other agents *consume* its output; none of them touch the database directly.

- **`agents/code-intel.md` owns:**
  - The SQLite schema (Q1) and pragmas (Q6).
  - The indexer pipeline (all five phases).
  - All `Bash sqlite3` invocations against `.code-intel/index.sqlite`.
  - The Q3 rendering templates.
  - The Q4 Tier-3 escalation prompt and response handling.
  - The Q5 brief schema validation.
  - The Q7 language-profile detection algorithm.
  - The Q8 hardcoded excludes list.
  - The Q10 skipped-file log format.
  - All artifacts under `.code-intel/**` and `docs/code-intel/**`.

- **`skills/ops/SKILL.md` owns:**
  - Phase 2.5b dispatch decision (predicate `(ii) OR (iv)`).
  - The flags `--code-intel`, `--code-intel=off`, `--code-intel=always`.
  - Composition of the JSON brief from the executor's task context.
  - Attaching the resulting `report_path` to the executor's brief.
  - The dispatch-log entry for `code-intel` invocations.

- **The seven R7 consumer agents own:**
  - A "Code Intelligence Context" section in their definition that *reads* the report path and the summary.
  - Decisions about what to do with the report (executor: pre-edit risk awareness; debugger: starting points for investigation; etc.).
  - They do *not* invoke `code-intel` themselves — that is the team manager's job. The consumers only consume.

- **`tooling/deploy-manifest.json` owns:**
  - The deploy entry that copies `agents/code-intel.md` to `~/.claude/agents/` and `~/.cursor/agents/`.

- **`CLAUDE.md` Documentation Sync table owns:**
  - The mapping `agents/code-intel.md` → relevant skill/integration files.

These boundaries are deliberately narrow. The cross-cutting integration with the seven R7 agents is done through *the report itself* — a deterministic, citable Markdown file — not through any in-process API. That is the cheapest integration surface.

---

## Open Questions (Surfaced for the Planner / User)

The ten Q1–Q10 questions are *resolved* in this ADD. The questions below are things the planner or user should weigh in on before implementation:

1. **`.code-intel/runs/` cleanup policy** — RESOLVED post-ADD by user (2026-04-26): path moved from `docs/code-intel/.runs/` to `.code-intel/runs/` to colocate ephemeral render artifacts with the SQLite DB under the gitignored `.code-intel/` root. `/ops` Phase 4 cleans the run subdirectory. Durable opt-in reports persist at `docs/code-intel/<symbol>-<query>.md`.
2. **Capability-detection cache** — per Open Implementation Risk #10. Probably v2, but worth confirming with the user that re-probing every dispatch is acceptable for v1.
3. **`/ops` nested-skill testing depth** — per Open Implementation Risk #6. Suggest the planner add a specific integration test for "ops invoked from ralph-loop, code-intel dispatched in Phase 2.5b" to the v1 acceptance criteria.
4. **`code-reviewer-diff` integration framing** — R7 names this agent for integration but it is the *fallback* code reviewer. Confirm with the user whether the Code Intelligence Context section is identical to `code-reviewer.md`'s or scoped more narrowly to the diff hunks. This ADD assumes identical for v1.
5. **Tier-3 escalation in non-interactive contexts** — RESOLVED in revision pass (2026-04-26, addresses C-ADD-1). When `code-intel` is dispatched by `/ops` Phase 2.5b (a non-interactive context — the team manager is mid-loop), the Tier-3 prompt copy from Q4 cannot be answered by a human in real time. The agent detects orchestrator dispatch by **the brief format itself**: a JSON-fenced brief is, per R3, exclusively an orchestrator-path signal. When the brief format is JSON-fenced, the agent suppresses the Tier-3 prompt entirely and falls through to "proceed with current data plus caveat" silently. Labeled-prose briefs come exclusively from humans, so they preserve the interactive Tier-3 flow. This reuses the R3 brief-format contract as the authoritative caller-type detector — no new sentinel, no `[context]` block, no second contract. (Earlier drafts proposed a `[context]` block, but that conflicted with the existing `## Context` Markdown heading in `/ops`'s standard agent-briefing format at `skills/ops/SKILL.md:486-506`. R3 is now the single source of truth for caller-type detection.)

These five items can be resolved during planning or deferred to v2. They do not block the planner from breaking the work into tasks.

---

## Revision History

- **2026-04-26 — Initial ADD authored** by the architect agent, using the requirements doc at `docs/plan/code-intel-agent-requirements.md` and the handoff doc at `docs/plan/.handoffs/code-intel-agent-2026-04-26/handoff-000-plan-to-design.md` as input. All ten Q1–Q10 design questions resolved; five additional open questions surfaced for the planner or user.
- **2026-04-26 — Revision pass** by the architect agent, addressing critic findings C-ADD-1, C-ADD-2, C-ADD-3 from `docs/plan/code-intel-agent-critique.md`:
  - **C-ADD-1 (CRITICAL).** Replaced the `[context]` block proposal with a JSON-fenced-brief detection rule for orchestrator-dispatch suppression of the Tier-3 prompt. R3's brief-format contract is now the single authoritative caller-type detector. Updated the `/ops` Phase 2.5b Integration Contract section, surfaced Question 5, the Tier Cascade Logic pseudocode, and the Agent Body Skeleton (sections 11.1 and 12.4).
  - **C-ADD-2 (CRITICAL).** Added an explicit "Write-path enforcement uses glob matching, not a literal allow-list" paragraph to Q6, naming the canonical glob set (`.code-intel/**`, `docs/code-intel/**`, `_tmp_*`). Updated Agent Body Skeleton section 6.2 to reference the glob set verbatim.
  - **C-ADD-3 (MAJOR).** Added a stable probe-order rule to Q7: alphabetical by language name across both passes, with manifest-list order as the tiebreaker. Updated the pseudocode and the polyglot edge-case prose.
  - All four edits cite the corresponding critique ID inline. No restructuring or out-of-scope edits were made.
