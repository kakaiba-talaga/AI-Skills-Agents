Harness-portable memory layer with subcommands for init / save / recall / list / forget / search / audit / doctor / reflect. Memories live in ~/.cross-memory/ and mirror to harness-native locations where applicable. Arguments: $ARGUMENTS

Parse the arguments as follows:

- The first token after `/cross-memory` is the **subcommand**. Accepted values: `init`, `save`, `recall`, `list`, `forget`, `search`, `audit`, `doctor`, `reflect`. Any other first token is an error: emit `unknown subcommand: '<token>'. Valid subcommands: init, save, recall, list, forget, search, audit, doctor, reflect.` and stop.
- `help` — emit the structured usage block below, then stop. No hint is appended (regardless of canonical-store or sentinel-block state).
- Remaining tokens are parsed per the subcommand's `### Command syntax` section below.

Default behavior when no subcommand is given: run the bare-invocation sequence described below.

### Structured usage block

Used by both `help` and bare invocation:

```
usage: /cross-memory <subcommand> [flags]

Subcommands:
  init     Bootstrap ~/.cross-memory/ and the harness sentinel block
  save     Persist a memory (parse → redact → confirm → write)
  recall   Retrieve memories by topic
  list     Enumerate memories with one-line summaries
  forget   Archive a memory (no hard delete)
  search   Grep-style full-text search over memory bodies
  audit    Scan for staleness, duplicates, contradictions, redaction misses
  doctor   Read-only structural and integration health check
  reflect  Propose memory candidates distilled from git, plan docs, handoffs, and (Claude Code only) session transcripts

Run /cross-memory <subcommand> --help for per-subcommand details.
```

### Bare-invocation sequence

When invoked with no subcommand, the skill:

1. **Runs the probe (read-only, synchronous).** Determine the active harness via the precedence chain in `adapter-selection.md`. Then:
   - Check whether `~/.cross-memory/` exists (directory-existence check).
   - On Claude-Code-class harnesses (where `update_sentinel_block` is real at v1): additionally read the harness-native `MEMORY.md` once to count sentinel markers and inspect the bytes between them.
   - On Cursor-class and generic harnesses (where `update_sentinel_block` is a documented no-op at v1): skip the sentinel-block read. The sentinel-block predicate is suppressed for these harnesses so the hint does not fire on every invocation after a successful init.
   - The probe makes no writes, no network calls, and no state changes.

2. **Emits the structured usage block** (same block as `help`).

3. **Conditionally appends the first-run hint** after the usage block, in the same response:
   - **Under Claude-Code-class harnesses:** emit the hint if `~/.cross-memory/` is absent **or** if the active harness's sentinel block is missing or empty.
     - Hint text: `Tip: run /cross-memory init to bootstrap this project.`
   - **Under Cursor-class and generic harnesses:** emit the hint only if `~/.cross-memory/` is absent (sentinel-block predicate suppressed).
     - Hint text: `Tip: run /cross-memory init to bootstrap (Cursor injection surface deferred to post-v1).`
   - If neither condition applies (canonical store exists and — where applicable — the sentinel block is populated), the hint is suppressed.

4. **Stops.** The skill never auto-runs init from bare invocation. State changes always require an explicit subcommand.

**Probe scope:** the probe inspects only the **current** harness's sentinel block, not other harnesses' blocks. The harness is determined once at the start of step 1 and honored throughout.

## Schema validator

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/schema-validator.md` when the active subcommand is `save` (not on bare invocation or other subcommands) for the canonical frontmatter schema (required fields, optional fields, enum values, default rules, and literal reject error strings emitted by the validator). If the file is missing, proceed using the inline summary: every memory write validates `name`, `description`, `type`, `scope`, `tags`, `created_at`, `updated_at`; `type` ∈ {feedback, project, preference, fact, rule}; `scope` matches `user-global`, `project:<slug>`, or `harness:<name>`; reject with `validation error: ...` and abort the write.

---

## Config

### Config file location

Path: `~/.cross-memory/config.yaml`

Format: YAML, single document, top-level keys per the field table below.

### Fields

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `current_harness` | string | (auto-detected) | Active harness identifier: `claude-code`, `cursor`, or `generic`. Falls back to harness detection (CLI flag → config field → env var → manifest probe → generic) if absent. |
| `staleness_threshold_days` | integer | 90 | Memories with `verified_at` older than this many days are flagged stale by `recall`, the always-on tier injection block, and `audit`. |
| `reflect_staleness_threshold_days` | integer | 30 | Number of days since the last `reflect` run before `init` and `doctor` emit a staleness hint for the active project. Parallels `staleness_threshold_days` but drives the reflect-staleness nudge, not memory-verification staleness. If this field is absent from `~/.cross-memory/config.yaml`, the skill uses the default of `30` at read time — no migration is required when upgrading an existing config. Reasoned default; configure per-machine in `~/.cross-memory/config.yaml` if a different threshold fits your workflow. |
| `max_inject_chars` | integer | 2048 | Maximum bytes for the `[CROSS-MEMORY]` injection block. When the block exceeds this budget, the formatter drops sub-sections in priority order; see `injection-block.md § Size budget enforcement` for the full drop protocol. |

### reflect: namespace

The `reflect:` key in `config.yaml` groups the three anti-redundancy filter thresholds used by the `reflect` subcommand. The skill reads these values before dispatching the agent and passes the resolved thresholds into the brief; the agent does not read the config directly.

```yaml
reflect:
  slug_overlap_threshold: 0.85
  tag_overlap_threshold: 0.8
  body_token_jaccard_threshold: 0.7
```

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `reflect.slug_overlap_threshold` | float | 0.85 | Normalized similarity threshold applied to a candidate's proposed slug versus each reference entry's slug. A candidate is dropped when its slug similarity to any reference entry meets or exceeds this value. |
| `reflect.tag_overlap_threshold` | float | 0.8 | Jaccard similarity threshold applied to the candidate's tag set versus each reference entry's tag set (`\|A ∩ B\| / \|A ∪ B\|`). A candidate is dropped when its tag overlap with any reference entry meets or exceeds this value. |
| `reflect.body_token_jaccard_threshold` | float | 0.7 | Jaccard similarity threshold applied to the first 200 lowercased, stopword-filtered tokens of the candidate's body versus the same bounded sample of each reference entry. A candidate is dropped when its body-token similarity to any reference entry meets or exceeds this value. |

The filter applies these three signals as a disjunction: a candidate is dropped when **any one** of the three signals trips against **any one** reference entry — an OR of three independent single-signal checks, not an additive score.

If `~/.cross-memory/config.yaml` does not define the `reflect:` namespace or any field within it, the skill uses the documented defaults at read time. No migration is required when upgrading an existing config. These are reasoned defaults; configure per-machine in `~/.cross-memory/config.yaml` if different thresholds fit your workflow.

### Lazy-provisioning sequence

When `~/.cross-memory/` is absent on first save / recall / etc., the skill provisions it before proceeding:

1. **Check** for `~/.cross-memory/` existence. If present, skip provisioning.
2. **Create the directory tree** with these six subdirectories (relative to `~/.cross-memory/`):
   - `user-global/`
   - `projects/`
   - `harnesses/claude-code/`
   - `harnesses/cursor/`
   - `harnesses/generic/`
   - `archive/`
3. **Write the default `config.yaml`** with the four fields above set to their defaults.
4. **Initialize per-scope `MEMORY.md` files** as empty index files for `user-global/`, `harnesses/claude-code/`, `harnesses/cursor/`, `harnesses/generic/`. Project-scope `MEMORY.md` files are created lazily per-project on first save (since the project slug isn't known until a save targets it).
5. **Proceed** with the original operation (save / recall / etc.).

**The deploy pipeline (`tooling/deploy.{ps1,sh}`) does NOT provision `~/.cross-memory/`.** Provisioning is runtime, triggered by the first skill invocation. This keeps deploy idempotent and store creation user-driven.

### Cross-references

When `current_harness` is absent from the config, harness detection falls back to the full precedence chain documented in `adapter-selection.md`: CLI flag → config field → env var → manifest probe → generic fallback.

---

## Per-project state file

### Location and lazy-create semantics

Path: `~/.cross-memory/projects/<slug>/state.toml`, where `<slug>` is the active-project slug — the same slug derivation already used for project-scope memory storage throughout this skill.

This file is created on the **first successful** `/cross-memory reflect` run for the project. A project that has never run reflect has no `state.toml`; this is normal and expected. The file is not created at `init` time and is not created by any other subcommand.

### Schema

```toml
schema_version = 1

[reflect]
last_reflect_at = "2026-05-13T12:00:00Z"
last_reflect_candidate_count = 7
last_reflect_run_id = "reflect-2026-05-13-abcd"
```

| Field | Type | Description |
| :--- | :--- | :--- |
| `schema_version` | integer | Top-level schema version; `1` is the initial value shipped with this feature. |
| `reflect.last_reflect_at` | ISO-8601 UTC timestamp | Timestamp of the most recent successful reflect run. |
| `reflect.last_reflect_candidate_count` | integer | Count of candidates surfaced in that run (post-filter, pre-user-action). |
| `reflect.last_reflect_run_id` | string | Identifier of the run that wrote this state. |

### schema_version rules

`schema_version = 1` is the value written by this version of the skill. **Additive fields** (new keys added inside an existing table or at top-level) do **not** bump `schema_version` — old readers ignore unknown fields gracefully. **Breaking shape changes** (removing or renaming fields, restructuring tables) **do** bump it — old readers must refuse to parse a version higher than they know.

### Read-side fallback

When `state.toml` is **absent** or **unparseable**, the read returns "unset" for all fields. The staleness hint is suppressed, and any consumer treats the state as if reflect has never run for this project. A subsequent successful reflect run rewrites the file cleanly, recovering from any corruption.

### Write ownership

The skill (the `/cross-memory` command implementation) writes this file at the end of a successful reflect run. The cross-memory agent does not write this file.

---

## Reflect decline ledger

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/reflect-decline-ledger.md` when the active subcommand is `reflect` (not on bare invocation or other subcommands) for the per-project decline-ledger schema, file path, lazy-create semantics, append-only contract, and matching strategy. If the file is missing, proceed using the inline summary: the ledger lives at `~/.cross-memory/projects/<slug>/reflect_declined.md`; each decline appends one `---`-delimited entry with `declined_at`, `candidate_id`, `proposed_name`, `category`, `scope`, `tags`, `body_preview`, `source_evidence`, `run_id`; the skill writes the ledger, the agent reads it as Reference Set C.

---

## Adapter selection

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/adapter-selection.md` when the active subcommand is present (not bare invocation or `help`) for the five-step adapter-selection precedence chain (CLI flag → config field → env var → adapter probe → generic fallback), per-step error and warning behavior, the first-claim-wins probe rule, detection-timeout semantics, selection logging vocabulary, and edge cases. If the file is missing, proceed using the inline summary: parse `--harness` first (fail fast on invalid values); then check `current_harness` in `~/.cross-memory/config.yaml`; then `CROSS_MEMORY_HARNESS` env var; then probe registered adapters in order (`claude-code`, then `cursor`) with a 250 ms timeout each; fall back to `generic`. Selection records the winning step (`cli flag` / `config field` / `env var` / `adapter probe` / `generic fallback`) and surfaces it via `--verbose` and the audit environment block.

---

## Shared flag parsing

The following flags are accepted by `init` and `doctor` (and may appear on other subcommands where noted). They are defined once here; per-subcommand `### Command syntax` sections reference this section rather than redefining semantics.

### `--harness <claude-code|cursor|generic>`

Overrides adapter selection for the duration of the invocation. Semantics and precedence are identical to the `adapter-selection.md` five-step chain: when this flag is present and valid, it wins unconditionally as Step 1 of that chain. An unrecognized value fails fast:

```
error: unknown harness 'foo'. Valid values: claude-code, cursor, generic
```

The full precedence chain (CLI flag → config field → env var → manifest probe → generic fallback) is documented in `adapter-selection.md`. This flag is Step 1 of that chain — no new precedence logic is introduced here.

### `--scope <user-global|project:<slug>|harness:<name>>`

Restricts the subcommand's operation to a single scope. The accepted patterns are the same as the `scope` frontmatter field:

| Pattern | Example |
| :--- | :--- |
| `user-global` | `user-global` |
| `project:<slug>` | `project:D--Repositories-Personal-Git-AI-Skills-Agents` |
| `harness:<name>` | `harness:claude-code` |

A bare `project` or `harness` without a colon-and-slug suffix is invalid. When `--scope` is omitted, scope defaults to the subcommand's own default (documented per subcommand in `### Command syntax`).

### `--json`

Requests machine-readable output. When present, the subcommand emits its result as a JSON document to stdout instead of the default human-readable prose. The exact JSON shape is defined per subcommand in its own `### Command syntax` section. The flag is parsed at invocation time, before any subcommand logic executes; an unknown value after `--json` is not an error (the flag is boolean — it takes no argument).

### `--verbose`

Requests additional diagnostic output. When present, the harness selection step is printed on the first output line of the invocation, per `adapter-selection.md § Selection logging and observability`. Subcommands may emit additional per-step detail when `--verbose` is set; this is documented per subcommand. The flag is boolean — it takes no argument.

### Cross-references

- **`--harness` precedence chain**: `adapter-selection.md`.
- **`--scope` field semantics**: `schema-validator.md § Scope enum`.
- **`--verbose` harness logging**: `adapter-selection.md § Selection logging and observability`.
- **Per-subcommand JSON shapes**: `subcommand-init.md` and `subcommand-doctor.md`.

---

## Subcommand: init

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/subcommand-init.md` when the active subcommand is `init` (not on bare invocation or other subcommands) for the full init flow (Steps 1–5 — provisioning, adapter detection, reachability probe, always-on filter + sentinel write, reflect-staleness check, summary output in human / JSON / verbose), the per-harness behavior tables, idempotency contract, the "what init does NOT do" boundary list, and the reuse-of-doctor's-check-primitives section. If the file is missing, proceed using the inline summary: init delegates to the lazy-provisioning sequence in `## Config`, runs the adapter-selection chain, probes the harness-native `MEMORY.md` for reachability, invokes the always-on tier filter and injection-block formatter, dispatches `active_adapter.update_sentinel_block(content)` (no-op on cursor/generic at v1), reads the per-project `state.toml` to fire the reflect-staleness hint when `delta_days > reflect_staleness_threshold_days`, and emits a one-line summary (or schema-version-1 JSON under `--json`). Init is additive only — never deletes, overwrites, or repairs.

---

## Subcommand: doctor

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/subcommand-doctor.md` when the active subcommand is `doctor` (not on bare invocation or other subcommands). Invariant: read-only health check; no agent dispatch; PASS/WARN/FAIL/NOT-APPLICABLE per section plus aggregated verdict (`--json` exit codes only). If the file is missing, run checks by name from `## Check-name vocabulary` only.

---

## Subcommand: reflect

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/subcommand-reflect.md` when the active subcommand is `reflect` (not on bare invocation or other subcommands). Invariant: dispatches `cross-memory` with `intent: distill`; skill writes `state.toml` on successful `done`. If the file is missing, stop — do not run reflect without the companion.

---

## Mirror failure handling

Two dispatch points invoke adapter operations: the `save` subcommand calls `mirror_write` after the canonical write, and the `forget` subcommand calls `mirror_remove` after the canonical archive. Both share the same three governing principles:

1. **The canonical store is the source of truth.** Mirror operations always run _after_ the canonical operation succeeds. A mirror failure never rolls back the canonical write or archive — the canonical result stands regardless.
2. **Adapter-side failures surface as structured warnings, not errors.** When an adapter returns a violation or raises an unexpected exception, the skill emits a user-facing warning describing what failed and what the user can do to resolve it. The subcommand still returns success because the canonical operation succeeded.
3. **The `generic-fallback` no-op is the expected silent path.** When the generic adapter is active, it returns a structured "no mirror written / removed; harness=generic" result. The skill records this result and emits no warning — this is correct behavior, not a degraded state.

---

## Subcommand: save

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/subcommand-save.md` when the active subcommand is `save` (not on bare invocation or other subcommands) for the full save flow (Gates 1–4 parse / redact / confirm / write, the supersede branch with collision detection through Step 7 mirror hook, the standard-save mirror hook, and the auto-propose flow with its enumerated cue patterns). If the file is missing, proceed using the inline summary: save runs four sequential gates and never writes without an explicit `[y/N]` confirmation. Defaults: `--scope user-global`, `--type feedback`, `--tags []`, redaction on. Pass A `<private>` strip runs unconditionally; Pass B regex denylist requires the typed phrase `save unredacted` to bypass when patterns match. The mirror hook fires `active_adapter.mirror_write(memory)` after Gate 4 and follows canonical-first failure-isolation per `## Mirror failure handling`.

---

## Subcommand: recall

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/subcommand-recall-list-search.md` § Subcommand: recall when the active subcommand is `recall` (not on bare invocation or other subcommands) for the full recall reference (case-insensitive substring match across name / description / tags / body, filter flags, output ordering, staleness banner, body rendering rules including the `[REDACTED:private]` → `…` cosmetic transform, empty-result messages). If the file is missing, proceed using the inline summary: recall takes a required `<topic>` positional, walks `~/.cross-memory/` excluding `archive/`, returns matched memories sorted by `updated_at` descending, applies a `(stale: last verified N days ago)` banner when `verified_at` exceeds the staleness threshold.

---

## Subcommand: list

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/subcommand-recall-list-search.md` § Subcommand: list when the active subcommand is `list` (not on bare invocation or other subcommands) for the full list reference (no positional argument, `--stale-only` flag, output format `<name> — <description> — <scope> — <tags> — <staleness>`, archive exclusion). If the file is missing, proceed using the inline summary: list returns one-line summaries of all memories that pass the applied filters, sorted by `updated_at` descending, with no body rendering and `~/.cross-memory/archive/` excluded.

---

## Subcommand: search

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/subcommand-recall-list-search.md` § Subcommand: search when the active subcommand is `search` (not on bare invocation or other subcommands) for the full search reference (grep-style match style, `<path>:<line>: <text>` triple output, two-flag filter set `--scope` and `--type`, archive exclusion, empty-result messages). If the file is missing, proceed using the inline summary: search takes a required `<query>` positional, scans body content only (not frontmatter), returns raw matched lines with canonical path and 1-based line number, excludes `~/.cross-memory/archive/` by default.

---

## Subcommand: forget

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/subcommand-forget.md` when the active subcommand is `forget` (not on bare invocation or other subcommands) for the full forget flow (Step 1 lookup, Step 2 confirmation, Step 3 archive to `~/.cross-memory/archive/<stem>-<YYYYMMDDTHHMMSSZ>.md`, Step 4 MEMORY.md index removal, Step 5 mirror-remove hook with sentinel-block update). If the file is missing, proceed using the inline summary: forget takes a required `<name>` positional, defaults `--scope user-global`, prompts `Forget memory '<name>'? It will be archived but not auto-deleted. [y/N]`, archives via move (never hard-delete), does NOT set `superseded_by` on the archive copy (that field is supersede-only), and dispatches `active_adapter.mirror_remove(memory)` after the canonical archive succeeds.

---

## Subcommand: audit

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/subcommand-audit.md` when the active subcommand is `audit` (not on bare invocation or other subcommands) for the full audit flow (Step 1 build the agent brief with `intent: audit` and the effective staleness threshold, Step 2 dispatch the `cross-memory` agent, Step 3 render the five-section report (Stale memories / Duplicates / Contradictions / Redaction misses / Recommended actions), Step 4 per-finding actions `refresh` / `archive` / `forget` / `redact-now` / `categorize` each gated by standard write-path confirmation). If the file is missing, proceed using the inline summary: audit takes only `--staleness-days <N>` as an override flag, dispatches the agent with the labeled-prose brief documented in `agents/cross-memory.md`, renders the agent's report directly to chat without writing to disk, and applies no action without explicit user confirmation.

---

## Check-name vocabulary

The identifiers below are stable check names used by `--check <name>` in the `doctor` subcommand and referenced by the `init` subcommand's success-confirm step. Renaming any identifier is a breaking change. New checks are pure-add.

Each name belongs to one of five groups. Checks within a group run in declared order when the group is selected.

### Group A — canonical-integrity

| Check name | What it does |
| :--- | :--- |
| `canonical-frontmatter-parse` | Verifies every memory file's frontmatter parses against the schema validator. |
| `canonical-slug-derivation` | Verifies every project-scope file's slug derivation matches the file's directory name. |
| `canonical-memory-md-consistency` | Verifies each scope's `MEMORY.md` indexes match the on-disk file set — no orphans, no missing entries. |
| `canonical-no-duplicate-slugs` | Asserts no two files within the same scope directory share the same slug. |
| `canonical-archive-not-indexed` | Asserts `~/.cross-memory/archive/MEMORY.md` does not exist. |

### Group B — mirror-consistency

| Check name | What it does |
| :--- | :--- |
| `mirror-sidecar-frontmatter-agreement` | Verifies each sidecar-recorded mirror file has a `mirrored_from` frontmatter field pointing at the recorded canonical source. |
| `mirror-canonical-source-exists` | Verifies each sidecar entry's `canonical_source` path exists on disk. |
| `mirror-detect-collisions` | Reports the three-state classification (native / stale-mirror / user-edited) over each adapter's mirror directory without taking action. |

### Group C — sentinel-markers

| Check name | What it does |
| :--- | :--- |
| `sentinel-marker-count` | Verifies exactly one begin and one end sentinel marker are present in the active project's harness-native `MEMORY.md`. |
| `sentinel-region-bytes-fingerprint` | Computes a SHA-256 of the bytes outside the sentinel region at run start and compares against the same bytes at run end to detect unintended mutation. |
| `sentinel-region-content-parses` | Asserts the bytes between the sentinel markers parse as a valid `[CROSS-MEMORY]` injection block. |

### Group D — redaction-surface

| Check name | What it does |
| :--- | :--- |
| `redaction-denylist-parses` | Verifies `redaction.md` is present at the deployed path and the denylist table parses as expected. |
| `redaction-sampling-scan` | Samples N memories per scope (default 10, capped at 30) and scans their bodies with the Pass-B regex set. |
| `redaction-overridden-flag-audit` | Surfaces every memory with `redaction_overridden_at` set. |

### Group E — deploy-target-prep and cross-harness-validation

| Check name | What it does |
| :--- | :--- |
| `deploy-manifest-coverage` | Verifies `tooling/deploy-manifest.json` globs cover all cross-memory files and no files are unintentionally excluded. |
| `stale-shipped-artifacts` | Identifies artifacts in `~/.claude/skills/cross-memory/` and `~/.cursor/skills/cross-memory/` that have no source counterpart in the repo. |
| `cross-harness-roundtrip` | Run from harness B after a save in harness A; confirms recall can locate the canonical file across harnesses. |
| `adapter-detection` | Re-runs the adapter selection chain and reports which step won. |
| `sc-behavioral-walk` | Walks the cross-harness SCs as in-place behavioral checks; per-harness applicability is defined in `subcommand-doctor.md`. |

### Cross-references

- **Full check definitions** (findings shapes, per-harness applicability, exit-code meanings): `subcommand-doctor.md`.
- **Init's use of check primitives**: `subcommand-init.md`.
- **Adapter selection chain**: `adapter-selection.md`.

---

## Always-on tier

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/always-on-tier.md` when the active subcommand is `init` (not on bare invocation or other subcommands) for the always-on tier filter spec (trigger conditions, inputs, the four inclusion rules — user-global by type, project by type, harness by type, `tag=always-on` opt-in — deduplication, staleness banner application, output tuple shape `(scope, type, name, description_with_banner, tags)`, and edge cases). If the file is missing, proceed using the inline summary: the filter fires once at session bootstrap after adapter detection, walks the three canonical scope index files, merges and dedups by canonical path, applies a staleness banner to entries whose `verified_at` exceeds the threshold, and produces an ordered list consumed by the injection-block formatter.

---

## Injection block

> **Reference:** You MUST Read `~/.claude/skills/cross-memory/injection-block.md` when the active subcommand is `init` (not on bare invocation or other subcommands) for the injection-block formatter spec (output contract — bytes go between sentinel markers, formatter does not emit the markers — block structure with `User Profile:` and `Project Knowledge:` sub-sections, sub-section sourcing rules, bullet format with the 120-character cap including staleness-banner truncation rule, size-budget enforcement via `max_inject_chars` with drop priority, sub-section atomicity, within-sub-section bullet trimming, and edge cases). If the file is missing, proceed using the inline summary: the formatter is a renderer only — it consumes the ordered entry list from the always-on tier filter and produces UTF-8 bytes constrained by `max_inject_chars` (default 2048); it never emits the sentinel-marker lines themselves; Project Knowledge drops before User Profile when the budget is exceeded; bullets within a sub-section drop bottom-to-top before whole-sub-section drop.

---

## Brief-time injection

> **Reference:** See `~/.claude/skills/cross-memory/brief-injector.md` for the brief-time injection spec (ops orchestrator only — do not load on `/cross-memory` subcommand invocations, including bare invocation) (parameterized selector function signature with all seven context-object parameters, Lever 1 — the orchestrator predicate that decides WHEN to inject by checking whether `## Project Knowledge` is already present in the outbound brief, Lever 2 — the D2-B agent-type tag intersection that decides WHAT to include by filtering the always-on tier output through the dispatched agent's type tags, the `## Project Knowledge` output destination in the subagent brief, the header-strip rule, the budget rule using `max_brief_inject_chars`, the selector timeout rule, the sentinel-marker emission rule, and the twelve failure-mode scenarios). If the file is missing, proceed using the inline summary: the selector is called by the orchestrator before each subagent dispatch; Lever 1 fires only when the outbound brief does not already contain a `<!-- project-knowledge:carried -->` sentinel; Lever 2 filters the always-on tier entry list to entries whose tags do not include `exclude:<agent-type>` for the dispatched agent type; the result renders under a `## Project Knowledge` heading appended to the brief, with the sentinel on its own line at the bottom.

---

## Context Resilience

If the conversation thread is summarized, compacted, or interrupted mid-flow, recover by:

1. **Re-read this file** at `~/.claude/skills/cross-memory/SKILL.md` to restore the full subcommand specifications and gate semantics.
2. **If a save was in progress** (Gate 3 confirmation pending or Gate 4 write underway), do NOT assume the file was written. Re-examine `~/.cross-memory/<scope-dir>/` for partial files or stale staging artifacts. If the canonical file exists with the expected `name` slug, the save completed; if not, treat the prior invocation as aborted.
3. **If `MEMORY.md` appears out of sync** (an entry references a file that no longer exists, or a file is on disk but absent from the index), regenerate the affected scope's `MEMORY.md` from the files actually present per `~/.claude/skills/cross-memory/indexing.md` line format.
4. **Emit a recovery message** with the **`Cross-Memory`** badge naming what was recovered and what is still in flight.

## Constraints

- No compound Bash commands — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls instead — use parallel calls for independent commands.
- No `cd` prefix — the working directory is already the project root. Run commands directly instead of `cd "/path/to/project" && command`.
- Use relative paths from the project root — never use absolute paths in Bash commands. Only use absolute paths for resources genuinely outside the project (e.g., `~/.cross-memory/`, `~/.claude/`).
- Temporary files go in the **project root** (e.g., `_tmp_test.py`, `_tmp_payload.json`) — never in `/tmp/`, `%TEMP%`, or any path outside the project. Paths outside the project trigger sensitive-file prompts. Use the `_tmp_` prefix. Do not delete individually — clean up in batch at checkpoints with `rm _tmp_*`.
- **Never write to a memory file without passing the confirmation gate** — the Gate 3 confirmation (or auto-propose `[y/N]` prompt) must complete before any disk write occurs. There is no "silent save" path.
- **Never hard-delete** — the only removal operation is archive (move to `~/.cross-memory/archive/`). Permanent deletion is out of scope at v1.
- **Canonical → mirror direction only** — never read from a mirror copy as authoritative state. The canonical `~/.cross-memory/` store is the source of truth; adapters write *to* harness-native locations, not *from* them.

## Output Tagging

**`Cross-Memory`** appears on the **opening line** of each assistant turn only. Do **not** prefix every bullet or heading in the same turn.

The **first line** of each assistant turn for this command MUST begin with: **`Cross-Memory`**

Continuation lines within the same turn (sub-items, indented details, bullet lists, tables) do NOT repeat the badge. Only the opening line carries it.

Apply the badge on the opening line of turns that contain: save confirmations, recall results, list output, forget confirmations, search results, audit output, status/progress messages, validation errors, and auto-propose proposals.

**Format:** **`Cross-Memory`** (bold backtick-wrapped) as the **first element** on the **opening line** of the turn.
