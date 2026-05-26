# Cross-Memory

## Overview

A harness-portable memory layer with nine subcommands (`init`, `save`, `recall`, `list`, `forget`, `search`, `audit`, `doctor`, `reflect`), an always-on injection tier that surfaces key memories at session start, and an opus-class agent for synthesis, audit, and candidate distillation. Memories live in the canonical store at `~/.cross-memory/` and are available across three scopes: `user-global` (cross-project, cross-harness), `project:<slug>` (current project only), and `harness:<name>` (current harness only). Harness adapters mirror canonical memories into Claude Code and Cursor native locations so they surface in every session without manual recall.

## Subcommands

| Subcommand | Purpose | Common flags |
| :--- | :--- | :--- |
| `init` | Bootstrap `~/.cross-memory/` and the harness sentinel block. | `--harness`, `--scope`, `--json`, `--verbose` |
| `save` | Persist a new memory to the canonical store. Runs parse → redact → confirm → write gates. Auto-propose fires on cue phrases like "from now on" or "remember that". | `--scope`, `--type`, `--no-redact` |
| `recall` | Retrieve memories by topic using case-insensitive substring matching across name, description, tags, and body. Results ordered by `updated_at` descending. | `--scope`, `--type`, `--tag` |
| `list` | Enumerate all memories with one-line summaries; no body rendering. Use to survey what is stored or find stale entries. | `--scope`, `--type`, `--stale-only` |
| `forget` | Archive the named memory and remove its index entry. The memory moves to `~/.cross-memory/archive/`; no hard delete at v1. | `--scope` (default `user-global`) |
| `search` | Grep-style full-text search over memory body content. Returns `<path>:<line>: <match>` triples; no rendering or synthesis. | `--scope`, `--type` |
| `audit` | Dispatch the cross-memory agent to scan for staleness, duplicates, contradictions, redaction misses, and uncategorized memories. Output renders to chat only — no on-disk artifact. | `--staleness-days` |
| `doctor` | Read-only structural and integration health check across the canonical store, sentinel blocks, mirrors, and redaction surface. | `--pre-deploy`, `--post-deploy`, `--check`, `--harness`, `--json`, `--verbose` |
| `reflect` | Propose memory candidates distilled from git history, plan docs, handoffs, and (Claude Code only) session transcripts. Renders an interactive candidate report; nothing is saved without explicit confirmation. | `--from-session`, `--since-last-reflect`, `--from`, `--scope`, `--staleness-days`, `--verbose` |

For the full flag list and gate semantics of each subcommand, see:
- [Subcommand: init](subcommand-init.md)
- [Subcommand: save](subcommand-save.md)
- [Subcommand: recall](subcommand-recall-list-search.md)
- [Subcommand: list](subcommand-recall-list-search.md)
- [Subcommand: forget](subcommand-forget.md)
- [Subcommand: search](subcommand-recall-list-search.md)
- [Subcommand: audit](subcommand-audit.md)
- [Subcommand: doctor](subcommand-doctor.md)
- [Subcommand: reflect](subcommand-reflect.md)

## Bare invocation

Running `/cross-memory` with no subcommand prints the structured usage block (same as `/cross-memory help`). On fresh installs — when `~/.cross-memory/` is absent, or when the active harness's sentinel block is missing or empty — a first-run hint is appended:

```
Tip: run /cross-memory init to bootstrap this project.
```

The hint is harness-aware. Under Cursor and generic harnesses (where the sentinel block is a documented v1 no-op), the hint fires only when `~/.cross-memory/` itself is absent, not on every post-init invocation. The skill never auto-runs `init` from bare invocation — state changes always require an explicit subcommand.

See [SKILL.md → Bare-invocation sequence](SKILL.md#bare-invocation-sequence) for the full predicate.

## Init

`/cross-memory init` provisions the canonical store and populates the harness sentinel block. Run it once after installing cross-memory; it is safe to re-run at any time.

**What init does (in order):**

1. Provisions `~/.cross-memory/` via the lazy-provisioning sequence (creates the directory tree and `config.yaml` with defaults). If the directory already exists, this step is a no-op.
2. Detects the active harness via the five-step adapter-selection chain.
3. Probes the harness-native `MEMORY.md` for reachability and verifies sentinel markers are present.
4. Runs the always-on tier filter, formats the `[CROSS-MEMORY]` injection block, and writes it between the sentinel markers in the harness-native `MEMORY.md`.
5. Prints a one-line summary.

**Flags:**

| Flag | Description |
| :--- | :--- |
| `--harness <name>` | Override harness auto-detection (`claude-code`, `cursor`, `generic`). |
| `--scope <spec>` | Restrict the always-on filter to a single scope. |
| `--json` | Emit a machine-readable JSON object (schema version 1) instead of the summary line. |
| `--verbose` | Print per-step trace lines before the summary. |

There is no `--repair`, `--force`, or `--reset` flag. Init is additive only — it provisions what is absent and leaves existing files untouched.

**Success summary line shape:**

```
cross-memory initialized: harness=<name>, store=<state>, sentinel=<state> (<bytes>), <count> always-on entries
```

Example on a fresh install:

```
cross-memory initialized: harness=claude-code, store=provisioned, sentinel=updated (0 bytes), 0 always-on entries
```

**Empty-write note.** A fresh store with no user-global memories produces `sentinel=updated (0 bytes), 0 always-on entries`. This is a successful pass — the sentinel markers are written; the region between them is intentionally empty because the always-on filter found no entries to inject. It is not a failure or warning condition.

**Idempotency.** Init is safe to run repeatedly. If the store already exists and the sentinel content would be byte-identical, the summary reports `store=already-present, sentinel=already-current (no change)`.

**Cursor / generic harnesses.** `update_sentinel_block` is a documented v1 no-op on Cursor and generic harnesses. Init still runs all five steps, but the sentinel write is skipped and the summary reports `sentinel=skipped (cursor adapter no-op at v1)` or `sentinel=skipped (not-applicable)`. This is correct behavior.

See [subcommand-init.md](subcommand-init.md) for full step definitions, per-harness behavior tables, JSON schema, and the idempotency contract.

## Skill companion index

Tiered companion loading keeps the hub `SKILL.md` in context while subcommand bodies load **only** when the active invocation matches a row in the index. Bare invocation and `help` load **no** subcommand companions (do not bulk-read `subcommand-doctor.md`, `subcommand-reflect.md`, or other large files on every call).

| Active subcommand | Typical companions | Notes |
| :--- | :--- | :--- |
| `init` | `adapter-selection.md`, `subcommand-init.md`, `always-on-tier.md`, `injection-block.md` | Hard MUST on tier + injection block |
| `save` | `adapter-selection.md`, `schema-validator.md`, `redaction.md`, `subcommand-save.md` | Hard MUST on `schema-validator.md` |
| `recall` / `list` / `search` | `subcommand-recall-list-search.md` (one § only) | Section-scoped read |
| `forget` | `adapter-selection.md`, `subcommand-forget.md` | |
| `audit` | `subcommand-audit.md` | Dispatches cross-memory agent |
| `doctor` | `adapter-selection.md`, `subcommand-doctor.md` | |
| `reflect` | `adapter-selection.md`, `reflect-decline-ledger.md`, `subcommand-reflect.md` | |

`/ops` Phase 3 dispatch loads `brief-injector.md` for per-brief injection — never on `/cross-memory` subcommands. Full table, orchestrator-only rows, and missing-file rules: [indexing.md §6 — Skill companion index](indexing.md#6-skill-companion-index).

## Storage Layout

```
~/.cross-memory/
├── user-global/
│   ├── MEMORY.md           # Index for user-global memories
│   └── <type>_<slug>.md    # Individual memory files
├── projects/
│   └── <project-slug>/
│       ├── MEMORY.md
│       └── <type>_<slug>.md
├── harnesses/
│   ├── claude-code/
│   │   ├── MEMORY.md
│   │   └── <type>_<slug>.md
│   ├── cursor/
│   │   ├── MEMORY.md
│   │   └── <type>_<slug>.md
│   └── generic/
│       ├── MEMORY.md
│       └── <type>_<slug>.md
├── archive/                # Superseded and forgotten predecessors
└── config.yaml             # Skill configuration
```

**Three scopes:**

- **`user-global`** — memories that apply across every project and every harness (preferences, identity rules, cross-project facts). Stored at `~/.cross-memory/user-global/`.
- **`project:<slug>`** — memories scoped to a single project, where `<slug>` is derived from the project's absolute path by replacing each occurrence of `:`, `\`, `/`, space, and `.` with `-`. Stored at `~/.cross-memory/projects/<slug>/`.
- **`harness:<name>`** — memories scoped to a specific harness (`claude-code`, `cursor`, or `generic`). Stored at `~/.cross-memory/harnesses/<name>/`. Useful for harness-specific keybindings, workflow rules, or adapter-level preferences.

The entire directory tree is provisioned lazily on first use — no manual setup required.

## Privacy and Redaction

Every memory body passes through a three-stage redaction pipeline before any disk write:

1. **Pass A — `<private>` strip.** Any content wrapped in `<private>...</private>` is replaced with `[REDACTED:private]`. This pass always runs; no flag can disable it.
2. **Pass B — regex denylist.** Eight pattern categories are detected and replaced automatically: `api-key`, `password`, `bearer-token`, `jwt`, `aws-secret`, `env-block`, `private-key-header`, `user-tagged-secret`.
3. **Confirmation gate.** The post-redaction candidate is displayed before any write is committed. When redaction fired, the default answer is N; you must type `y` or `Y` to proceed.

The **`--no-redact`** flag bypasses Pass B (the regex layer) for the current save only. It has no effect on Pass A — `<private>` markup is always honored. When `--no-redact` is set and Pass B would have matched, you must type the exact phrase `save unredacted` to confirm; a simple `y` does not suffice. This friction is intentional: pattern false-positives are real, but the confirmation phrase makes accidental bypass of a genuine secret structurally difficult.

See [redaction.md](redaction.md) for the full pattern table, the bounded-fallback rule for unmatched `<private>` open tags, and the `--no-redact` typed-phrase flow.

## Always-On Tier

At session start, the active harness adapter runs a filter over the canonical store and writes a `[CROSS-MEMORY]` block into a sentinel-bounded region of the harness-native `MEMORY.md`:

```
<!-- cross-memory:begin -->
[CROSS-MEMORY]

User Profile:
- <bullet>

Project Knowledge:
- <bullet>
<!-- cross-memory:end -->
```

The adapter owns only the bytes between the sentinel markers. Content outside those markers is preserved byte-identically across all cross-memory operations.

**Default-on filter rules** — memories are selected automatically when they match any of these:

- `user-global` scope, type in `{preference, rule, fact}` → appears in **User Profile**.
- `project:<current-slug>` scope, type in `{feedback, project, rule}` → appears in **Project Knowledge**.
- `harness:<current-harness>` scope, type in `{rule, feedback}` → folded into **User Profile**.
- Any memory tagged `always-on` across any scope → included regardless of type.

The block is capped at `max_inject_chars` (default 2048 bytes). When the block would exceed the budget, sub-sections are dropped in priority order: Project Knowledge drops before User Profile; the `[CROSS-MEMORY]` header is never dropped.

See [always-on-tier.md](always-on-tier.md) for the full filter spec and size-budget drop protocol.

## Brief-Time Injection

When an orchestrating skill (such as `/ops`) dispatches a subagent, the brief injector fires once per qualifying dispatch and places the relevant subset of standing rules under a `## Project Knowledge` heading in the agent's brief. This is distinct from the always-on tier: the always-on tier fires once at session bootstrap to populate the harness-native `MEMORY.md`, while the brief injector fires per-dispatch to carry durable rules into the agent's isolated context.

Two levers gate what gets injected:

- **Lever 1 — orchestrator predicate.** The dispatching skill decides *whether* to inject at all, based on the run-level override flag (`--memory-inject=off|auto|always`), whether the agent type is in the mechanical-agents exemption list, and whether the prior handoff already carried the section.
- **Lever 2 — agent-type tag intersection.** When injection fires, the selector applies a tag intersection step on top of the always-on tier filter output, retaining only memories whose `tags[]` array carries the dispatched agent type as a positive tag or no agent-type tags at all. A memory tagged `exclude:<agent>` is dropped for that agent type regardless of other tags.

The injector is a thin composer over `always-on-tier.md` and `injection-block.md`: it calls the always-on tier filter unchanged, applies the agent-type tag intersection on top, passes the result to the injection-block formatter, then strips the `[CROSS-MEMORY]` header line before returning the bytes to the orchestrator. Empty bytes signal "skip injection." The per-dispatch character budget is governed by `max_brief_inject_chars` (default `4096`), a separate config field from the sentinel-block budget `max_inject_chars` (default `2048`).

See [brief-injector.md](brief-injector.md) for the full function signature, composition steps, tag vocabulary, budget rule, selector timeout rule, sentinel marker emission rule, and failure modes.

## Audit

`/cross-memory audit` dispatches the cross-memory agent (opus-class) to scan the canonical store and return a structured report rendered directly to chat. No on-disk audit artifact is written at v1.

**What the audit flags:**

- **Staleness** — memories whose `verified_at` field is older than `staleness_threshold_days` (default 90 days).
- **Duplicates** — memories with overlapping name slugs or substantially overlapping content across scopes.
- **Contradictions** — memory pairs that share tags but have conflicting bodies.
- **Redaction misses** — body content that matches a denylist pattern but was not redacted (e.g., a pattern added to the denylist after the memory was originally saved).
- **Missing-category curation** — memories with no `category` field set, flagged for optional categorization.

**Per-finding actions** — after the report renders, you can act on any finding by typing the action name followed by the memory identifier (e.g., `refresh feedback_strict_lane_boundaries`):

| Action | What it does |
| :--- | :--- |
| `refresh` | Sets `verified_at` to today's UTC date. |
| `archive` | Moves the memory to `~/.cross-memory/archive/`. |
| `forget` | Runs the full `/cross-memory forget` flow. |
| `redact-now` | Re-runs the redaction pipeline and supersedes the memory with the redacted version. |
| `categorize` | Sets the memory's `category` field to a value from the category enum. |

Every action goes through the standard write-path confirmation gate before any change is applied. The agent never auto-applies recommendations.

See [agents/cross-memory.md](../../agents/cross-memory.md) and [subcommand-audit.md](subcommand-audit.md).

## Doctor

`/cross-memory doctor` runs a read-only health check across the canonical store, sentinel blocks, mirror files, and redaction surface. It never writes, repairs, or auto-corrects — it reports what it finds and leaves the decision to the operator.

**Four invocation modes:**

| Mode | How to invoke | What runs |
| :--- | :--- | :--- |
| Default | `/cross-memory doctor` | Groups A, B, C, D in full; `adapter-detection` from Group E |
| Pre-deploy | `/cross-memory doctor --pre-deploy` | Six checks validating local state before a deploy run |
| Post-deploy | `/cross-memory doctor --post-deploy` | Five checks validating a deployed state across harnesses |
| Targeted | `/cross-memory doctor --check <name>` | Exactly the named check(s) or group(s); repeatable |

`--pre-deploy` and `--post-deploy` are mutually exclusive. `--check` cannot be combined with either mode flag.

**Five check groups:**

| Group | Identifier | Checks | What it covers |
| :--- | :--- | :--- | :--- |
| A | `canonical-integrity` | 5 | Frontmatter parse, slug derivation, index/file consistency, duplicate slugs, archive not indexed |
| B | `mirror-consistency` | 3 | Mirror sidecar agreement, canonical source existence, collision classification |
| C | `sentinel-markers` | 3 | Marker count, bytes fingerprint, region parse (Claude Code only; `not-applicable` on Cursor/generic at v1) |
| D | `redaction-surface` | 3 | Denylist parse, sampling scan, override-flag audit |
| E | `deploy-target-prep` + `cross-harness-validation` | 2 + 3 | Manifest coverage, stale artifacts; cross-harness round-trip, adapter detection, SC behavioral walk |

**JSON output.** Pass `--json` for a machine-readable report (schema version 1) with `overall`, per-section verdicts, and per-check findings. The top-level `harness` and `harness_selection_step` fields use the same shape as init's JSON output.

**Exit codes** (meaningful only when `--json` is set):

| Verdict | Exit code |
| :--- | :--- |
| `pass` | 0 |
| `not-applicable` | 0 |
| `warn` | 1 |
| `fail` | 2 |
| `error` | 3 |

Under the human-readable report the skill always exits 0 — chat output is the feedback channel.

See [subcommand-doctor.md](subcommand-doctor.md) for full check definitions, finding shapes, PASS/WARN/FAIL criteria, the post-deploy walk procedures, and the verdict aggregation rule.

## Reflect

`/cross-memory reflect` proposes memory candidates distilled from artifacts you have already created — git history, plan docs, handoffs, and (under Claude Code) session transcripts. The skill ingests those sources, dispatches the cross-memory agent with `intent: distill`, renders an interactive candidate table, and lets you decide what to save, decline, or edit. Nothing is written to the canonical store without explicit confirmation.

### Command syntax

```
/cross-memory reflect \
  [--from-session <session-id>] \
  [--since-last-reflect] \
  [--from <path>] \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--staleness-days <N>] \
  [--verbose]
```

### Source pipeline

Reflect ingests up to four source types per run. Sources 3, 4, and 5 are available on every harness. Source 1 requires Claude Code.

| Source | What it reads | How to activate | Harness |
| :--- | :--- | :--- | :--- |
| Source 1 — session transcripts | `.jsonl` session files from `~/.claude/projects/<active-slug>/` | `--from-session <id>` or `--since-last-reflect` | Claude Code only |
| Source 3 — git history + working tree | `git log`, `git diff --stat`, documentation-convention log, directory layout probe; working-tree config files (`pyproject.toml`, `package.json`, etc.) | Always active | All harnesses |
| Source 4 — plan docs, handoffs, dispatch logs | Globs `docs/plan/**/*.md`, `docs/cross-memory/handoff*`, `docs/ops-dispatch-log*`; bounded to 50 files per glob | Always active | All harnesses |
| Source 5 — explicit seed | File or directory passed via `--from <path>`; multiple `--from` flags union into one set | `--from <path>` | All harnesses |

When no flags are passed, reflect ingests Sources 3 and 4 only. Passing `--from-session` or `--since-last-reflect` adds Source 1; passing `--from` adds Source 5.

**Source 1 flags under non-Claude-Code harnesses.** Under Cursor or generic, `--from-session` and `--since-last-reflect` produce an immediate parse-time error before any agent dispatch:

```
error: --from-session and --since-last-reflect are Claude-Code-only flags; current harness is <name>
```

**Source 5 redaction note.** Source 5 content is read at distill time and may surface in the body-preview column of the candidate report before any redaction pass. Curate `--from` paths carefully — do not pass a path that contains secrets or proprietary information unless you intend it to appear in candidate previews.

### Report shape

The candidate report has two parts rendered to chat.

**Environment header** — six fields printed before the table:

1. Active harness.
2. Active project slug.
3. Sources scanned this run.
4. Raw candidates generated (before filtering).
5. Candidates dropped by filter (with per-reference-set breakdown).
6. Candidates surfaced (raw minus dropped).

**Candidate table** — eight columns:

| Column | Description |
| :--- | :--- |
| `id` | Run-local identifier (e.g., `c1`). Does not persist across runs. |
| `type` | Memory type proposed by the agent (e.g., `preference`, `rule`). |
| `category` | One of four locked taxonomy categories: `architectural-decisions`, `conventions-implicit-in-code`, `workflow-patterns-from-successful-runs`, `user-preferences-from-feedback-patterns`. |
| `scope` | Proposed memory scope: `user-global`, `project:<slug>`, or `harness:<name>`. |
| `proposed-name` | Slug for the would-be memory file name. |
| `body-preview` | Up to 160 characters of the candidate body. |
| `source-evidence` | Pointer to the evidence that produced this candidate. |
| `flags` | `would-supersede` when the proposed name matches an existing canonical memory; empty otherwise. |

Candidates are sorted by `category` lexicographically, then by `proposed-name` within each category.

### Interactive loop

After the report renders, the skill enters a command loop. Every action requires a confirmation prompt with default N.

| Command | What it does |
| :--- | :--- |
| `save <id>` | Routes the candidate through the v1 save pipeline (Gate 3 redact → Gate 4 write). If the candidate carries `would-supersede`, the v1.1 supersede flow fires first. |
| `decline <id>` | Appends an entry to the per-project decline ledger at `~/.cross-memory/projects/<slug>/reflect_declined.md`. Created lazily on first decline. |
| `edit <id>` | Opens a field-tweak surface for `proposed-name`, `body`, `tags`, and `scope`. On confirmation, the edited candidate re-enters Gate 3 before write. |
| `done` | Exits the loop, writes `state.toml` with `reflect.last_reflect_at` and a run summary, and emits candidate counts (surfaced / saved / declined / unactioned). |

Candidates neither saved nor declined before `done` are not written anywhere and receive no special treatment on subsequent runs.

### Anti-redundancy filter

Before surfacing candidates, the skill applies a deterministic post-generation filter. The filter measures three overlap signals between each candidate and each reference entry. A candidate is dropped when **any one** signal crosses its threshold against **any one** reference entry.

| Signal | How it is measured | Default threshold | Config field |
| :--- | :--- | :--- | :--- |
| Slug overlap | Character-level similarity between the candidate slug and the reference slug, normalized to `[0.0, 1.0]`. | `0.85` | `reflect.slug_overlap_threshold` |
| Tag overlap | Jaccard similarity: `\|A ∩ B\| / \|A ∪ B\|` over the candidate and reference tag sets. | `0.8` | `reflect.tag_overlap_threshold` |
| Body-token Jaccard | Jaccard over the first 200 lowercased, stopword-filtered tokens of each body. | `0.7` | `reflect.body_token_jaccard_threshold` |

The filter runs against **three deterministic reference sets** and applies **one LLM-prompt-applied exclusion corpus** at a separate stage before deterministic scoring begins.

- **Set A — canonical store.** Memories in `~/.cross-memory/` relevant to the candidate's scope. Filter-reason tag: `canonical-redundancy`.
- **Set B — archive.** Retired memories in `~/.cross-memory/archive/`. Filter-reason tag: `archive-redundancy`.
- **Set C — decline ledger.** Entries in `~/.cross-memory/projects/<slug>/reflect_declined.md`. Filter-reason tag: `declined-redundancy`. Decline-ledger precedence: a candidate matched by Set C is dropped before the supersede check ever runs.
- **Set D — exclusion corpus (LLM-prompt-applied, not signal-scored).** The `## What NOT to save in memory` section of `~/.claude/CLAUDE.md`. This free-text rule corpus has no slug, tag set, or body tokens suitable for Jaccard comparison, so the three deterministic signals do not apply to it. Instead, Set D is supplied to the agent as a system-prompt input during raw-candidate generation. The agent uses it to suppress candidates before they enter the pool the deterministic filter sees. If the section is missing or unreadable, the skill emits a structured warning and the filter proceeds with Sets A, B, and C only; the reflect run does not abort.

The filter is fully deterministic: given identical inputs and reference sets, two consecutive reflect runs produce byte-identical candidate sets in the same order.

Pass `--verbose` to see per-candidate filter decisions, including the signal that tripped, the raw score, the reference entry matched, and the filter-reason tag.

### Supersede flag

When the agent detects that a candidate closely overlaps an existing canonical entry, it sets `would-supersede` in the `flags` column. Typing `save <id>` on a flagged candidate routes through the v1.1 supersede flow (diff rendering + archive + Gate 3 confirmation) before writing. A candidate can pass the filter and still carry `would-supersede`, because the supersede check uses a stricter overlap threshold than the drop threshold. No memory is silently replaced — the flag in the report and the supersede confirmation prompt are both required.

### Decline ledger and state file

| File | Path | Created |
| :--- | :--- | :--- |
| Decline ledger | `~/.cross-memory/projects/<slug>/reflect_declined.md` | Lazily on the first `decline <id>` action |
| Per-project state | `~/.cross-memory/projects/<slug>/state.toml` | At the end of the first successful reflect run |

The decline ledger stores: `declined_at`, `candidate_id`, `proposed_name`, `category`, `scope`, `tags`, `body_preview`, `source_evidence`, `run_id`. It is append-only; no pruning mechanism exists at v1.2.

The state file stores `reflect.last_reflect_at`, `reflect.last_reflect_candidate_count`, and `reflect.last_reflect_run_id`. Both `init` (Step 4.5) and `doctor` (footer) read `last_reflect_at` to decide whether to emit a staleness hint.

### Staleness hint in init and doctor

Both `init` and `doctor` emit a suggestive nudge when `last_reflect_at` in `state.toml` is older than `reflect_staleness_threshold_days` (default 30 days):

```
Tip: it is been N days since reflect ran — run /cross-memory reflect to surface candidates.
```

The hint suppresses when `state.toml` is absent, unparseable, or `last_reflect_at` is unset (including first-ever invocations). Neither `init` nor `doctor` ever auto-invokes reflect — the nudge is informational only. The staleness threshold can be overridden for a single reflect run with `--staleness-days <N>`.

### Cross-harness applicability

| Capability | Claude Code | Cursor | Generic |
| :--- | :--- | :--- | :--- |
| `reflect` subcommand | Full | Full (Sources 3+4+5 only) | Full (Sources 3+4+5 only) |
| `--from-session`, `--since-last-reflect` | Available | Parse-time error | Parse-time error |
| `--from <path>` | Available | Available | Available |
| Report loop, ledger, supersede, filter | Full | Full | Full |
| Staleness hint in `init` and `doctor` | Full | Full | Full |
| `state.toml` write | Full | Full | Full |

The only Claude-Code-only surface is Source 1 (transcript ingestion via `--from-session` and `--since-last-reflect`). All other reflect behavior is harness-agnostic.

> **v1.3 deferral.** The `--non-interactive` flag, structured `--json` output, `--context` injection, and an external-trigger / post-run-hook contract (for integration with `/ops` or CI) are deferred to v1.3. The flag grammar is intentionally extensible — `--non-interactive` can be added without restructuring the routing flow.

See [subcommand-reflect.md](subcommand-reflect.md) for full flag definitions, source-pipeline staging details, the interactive-loop gate semantics, filter tokenization rules, and the cross-harness matrix.

## Configuration

`~/.cross-memory/config.yaml` — created automatically on first use with the defaults below.

> **Note:** `~/.cross-memory/config.yaml` is user-installed and is **not** part of the deploy manifest. Deploying cross-memory does not write or overwrite this file. If your existing `config.yaml` does not define the `reflect:` namespace, the skill uses the documented defaults for all `reflect.*` fields at runtime — no migration or manual edit is required.

**Core fields:**

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `staleness_threshold_days` | integer | `90` | Memories with `verified_at` older than this many days are flagged stale by `recall`, the always-on tier, and `audit`. |
| `max_inject_chars` | integer | `2048` | Maximum bytes for the `[CROSS-MEMORY]` injection block. |
| `adapter` | string | (auto-detected) | Override harness auto-detection. Accepted values: `claude-code`, `cursor`, `generic`. |

**reflect: namespace** — groups the three anti-redundancy filter thresholds and the staleness-hint threshold used by the `reflect` subcommand:

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `reflect.slug_overlap_threshold` | float | `0.85` | Normalized slug similarity threshold. A candidate is dropped when its slug similarity to any reference entry meets or exceeds this value. |
| `reflect.tag_overlap_threshold` | float | `0.8` | Jaccard similarity threshold over tag sets. A candidate is dropped when its tag overlap with any reference entry meets or exceeds this value. |
| `reflect.body_token_jaccard_threshold` | float | `0.7` | Jaccard similarity over the first 200 lowercased, stopword-filtered body tokens. A candidate is dropped when its body similarity to any reference entry meets or exceeds this value. |
| `reflect_staleness_threshold_days` | integer | `30` | Days since the last reflect run before `init` and `doctor` emit a staleness hint. Override for a single run with `--staleness-days <N>`. |

The filter applies the three `reflect.*` signals as a disjunction — one trip is enough to drop a candidate. Configure per-machine in `~/.cross-memory/config.yaml` under the `reflect:` key if different thresholds fit your workflow.

**Note:** When running cross-memory inside a project that doesn't already have global Bash permissions for `file`, `readlink`, `stat`, and `test`, you may receive interactive permission prompts on first use. To suppress these, add the following to your project's `.claude/settings.json` (or your user-global `~/.claude/settings.json`):

```json
{
  "permissions": {
    "allow": [
      "Bash(file *)",
      "Bash(readlink *)",
      "Bash(stat *)",
      "Bash(test *)"
    ]
  }
}
```

The cross-memory agent uses these for read-only path resolution and existence checks during the audit flow. The cross-memory skill itself does not invoke Bash.

## Examples

```bash
# Save an explicit user-global preference
/cross-memory save --scope user-global --type preference "Always run pytest with -xvs."
# → displays confirmation prompt; type y to confirm
```

```
# Auto-proposed save after "from now on we use ruff for linting"
# Skill proposes:
┌─────────────────────────────────────────────────────────────┐
│ I'd like to save this as a memory. Confirm?                 │
│                                                             │
│ Scope: user-global    Type: preference    Tags: []          │
│ Name:  from-now-on-we-use-ruff-for-linting                  │
│                                                             │
│ Body (redacted candidate):                                  │
│ ─────                                                       │
│ from now on we use ruff for linting                         │
│ ─────                                                       │
│                                                             │
│ Save this memory? [y/N]                                     │
└─────────────────────────────────────────────────────────────┘
# Type y to confirm
```

```bash
# Bootstrap the store on a new machine
/cross-memory init
# → cross-memory initialized: harness=claude-code, store=provisioned, sentinel=updated (0 bytes), 0 always-on entries

# Bootstrap with verbose output
/cross-memory init --verbose

# Recall memories by topic
/cross-memory recall "python testing"
# → returns matching memories ordered by scope + updated_at, with staleness banners if applicable

# List user-global rules only
/cross-memory list --scope user-global --type rule

# Forget a memory (moves to archive, not hard-deleted)
/cross-memory forget feedback_strict_lane_boundaries
# → prompts: Forget memory 'feedback_strict_lane_boundaries'? [y/N]

# Search verbatim text across memory bodies
/cross-memory search "lane boundaries"
# → returns ~/.cross-memory/user-global/feedback_strict_lane_boundaries.md:3: ...lane boundaries...

# Audit the full store
/cross-memory audit

# Audit with a tighter staleness window
/cross-memory audit --staleness-days 60

# Run the default health check
/cross-memory doctor

# Run a targeted check
/cross-memory doctor --check sentinel-markers

# Run the pre-deploy check set (for CI / before deploying)
/cross-memory doctor --pre-deploy

# Get a machine-readable doctor report
/cross-memory doctor --json

# Reflect using git history and plan docs (default — Sources 3 + 4)
/cross-memory reflect

# Reflect from a single session transcript (Claude Code only)
/cross-memory reflect --from-session <session-id>

# Reflect from all sessions since the last reflect run (Claude Code only)
/cross-memory reflect --since-last-reflect

# Reflect and seed an additional explicit path
/cross-memory reflect --from docs/cross-memory/v1.2-reflection-architecture.md

# Reflect with a tighter staleness window (affects which sessions --since-last-reflect scans)
/cross-memory reflect --staleness-days 14

# Reflect with per-candidate filter trace
/cross-memory reflect --verbose
```

## FAQ

**Q: How does cross-memory differ from Claude Code's native `~/.claude/projects/<slug>/memory/`?**

Cross-memory is the canonical store; `~/.claude/projects/<slug>/memory/` is a mirror written by the Claude Code adapter after every `save` and `forget`. Files in `~/.cross-memory/` survive harness changes and are portable across Claude Code, Cursor, and any other environment. The harness-native location is regenerated on demand from the canonical store; it is never the source of truth.

**Q: What happens to my existing Claude Code memory files when I start using cross-memory?**

Nothing changes immediately. The adapter refuses to overwrite any file that has neither a `mirrored_from` frontmatter field nor a sidecar manifest entry — pre-existing natively authored files are classified as `native` and are skipped. They remain byte-identical until you explicitly supersede them via `/cross-memory save`.

**Q: Can I share memories with a team?**

Not at v1. The three scopes are user-global, project, and harness — there is no team-shared scope. If you want manual sharing, add memories to a project scope (`project:<slug>`) and commit `~/.cross-memory/projects/<slug>/` to a shared repository.

**Q: How do I export my memories?**

Not at v1. Memories are plain Markdown files at `~/.cross-memory/`; copy the directory manually until `/cross-memory export` ships in a future release.

**Q: Why is there no on-disk audit report?**

Audit output grows linearly with audit cadence; persisting it would require a retention policy. The audit is a diagnostic, not a record. If you want a snapshot, save the chat output via your harness's standard transcript-save.
