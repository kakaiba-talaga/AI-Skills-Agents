<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Subcommand: reflect

Propose memory candidates distilled from git history, working-tree state, plan docs, handoffs, and (under Claude Code only) session transcripts. The skill ingests the requested source set, dispatches the cross-memory agent with `intent: distill`, renders an audit-style candidate report to chat, and then enters an interactive loop where the user saves, declines, or edits each candidate. On `done`, the skill writes the updated per-project state file and emits a run summary. No memory is written to disk without explicit user confirmation.

## Command syntax

```
/cross-memory reflect \
  [--from-session <session-id>] \
  [--since-last-reflect] \
  [--from <path>] \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--staleness-days <N>] \
  [--verbose]
```

No positional arguments.

## Flag definitions

- `--from-session <session-id>` — read a single session transcript from the Claude Code session directory. The session is identified by its session ID. **Claude Code only** — errors at parse time under Cursor or generic harnesses (see `## Claude-Code-only flag enforcement` below).

- `--since-last-reflect` — read all session transcripts newer than `reflect.last_reflect_at` in the per-project `state.toml`. Bounded to 20 sessions per invocation; sessions older than the bound are reported as truncated. **Claude Code only** — same enforcement as `--from-session`.

- `--from <path>` — explicit source path to ingest as a seed document. Always available under all harnesses. Multiple `--from` flags are valid and select the union of all named paths.

- `--scope <user-global|project:<slug>|harness:<name>>` — restricts the candidate generation scope. Defaults to `project:<active-slug>` when omitted. `user-global` and `harness:<name>` are legal but unusual — most invocations are project-scoped.

- `--staleness-days <N>` — overrides the `reflect_staleness_threshold_days` config field for this invocation only. Does not write the override back to the config file. Validated as a positive integer; a non-integer or negative value aborts with a structured error.

- `--verbose` — emits per-candidate filter decisions in the output and a verbose source-ingestion trace.

## Mutual-exclusion rules

`--from-session` and `--since-last-reflect` are **mutually exclusive** with each other. Both flags invoke transcript ingestion (Source 1). Passing both on a single invocation is an error caught at parse time:

```
error: --from-session and --since-last-reflect are mutually exclusive
```

When neither `--from-session`, `--since-last-reflect`, nor `--from` is present, `reflect` ingests Sources 3 (git history and working tree) and 4 (plan docs and handoffs) by default under all harnesses.

## Claude-Code-only flag enforcement

`--from-session` and `--since-last-reflect` are only valid under the Claude Code harness. Under Cursor or generic harnesses, either flag triggers an immediate parse-time error with the exact message:

```
error: --from-session and --since-last-reflect are Claude-Code-only flags; current harness is <name>
```

Where `<name>` is the active harness identifier (`cursor` or `generic`). No agent dispatch, no `state.toml` write, and no ledger modification occurs when this error fires. The error fires only when the flags are actually used — under `--help`, the flags appear in the usage block for all harnesses.

## Routing flow

Per-invocation steps in the skill body:

1. **Parse flags.** Reject mutually-exclusive combinations and harness-mismatched flags with typed errors. Any invalid flag value aborts before any further action.
2. **Run the adapter selection chain** (same as every other subcommand) to determine the active harness. Reject `--from-session` and `--since-last-reflect` here if the harness is not `claude-code`.
3. **Run lazy provisioning** if `~/.cross-memory/` is absent, following the same first-run provisioning sequence as the `save` subcommand.
4. **Build the source input set** per the flag selections and source availability. Construct the labeled-prose brief with `intent: distill`.
5. **Dispatch the `cross-memory` agent** with `intent: distill` and the brief. The agent applies the deterministic anti-redundancy filter against the four reference sets and returns a structured candidate list.
6. **Receive the candidate list from the agent.** Render the audit-style candidate report to chat, including per-candidate `id`, type, category, scope, proposed name, body preview, source evidence, and any `would-supersede` flags.
7. **Enter the interactive loop.** Accept `save <id>` / `decline <id>` / `edit <id>` / `done`. Each `save` action routes through the standard write-path confirmation gate. Each `decline` action appends an entry to `~/.cross-memory/projects/<slug>/reflect_declined.md` (created lazily on first decline). Each `edit` action presents the candidate body for modification before confirmation.
8. **On `done`, write the updated `state.toml`** (`~/.cross-memory/projects/<slug>/state.toml`) with the current timestamp as `reflect.last_reflect_at`, and emit a run summary (candidates surfaced, saved, declined, unactioned).

## Source 3 — git history and working-tree staging

**Scanned by the skill before agent dispatch.** Source 3 is always active: it is ingested on every `reflect` invocation regardless of harness or flags. The skill runs four read-only Bash commands and writes all output to a single staging file (`_tmp_reflect_source3_<timestamp>.md`) before constructing the agent brief.

### Four read-only Bash commands

All four commands are non-destructive. The skill aborts Source 3 staging and skips the git commands if the working directory is not a git repository, recording the absence in the brief's `## Constraints` block.

1. **History scan** — `git log --pretty=format:"%H%n%an%n%ae%n%s%n%b%n---END---"`. Captures commit SHA, author name, author email, subject, and body for each commit in the scoped range. **Bound:** the last 90 days or the last 200 commits, whichever produces fewer commits. The skill computes the oldest commit SHA at or before the bound and uses it as the `<oldest-in-range>` anchor for command 2.

2. **Diffstat scan** — `git diff --stat <oldest-in-range>..HEAD`. Produces file-level change counts across the bounded range, providing file-churn signals to the agent without transferring full diffs.

3. **Documentation-conventions log** — `git log -- .cursor/rules/ .claude/ CLAUDE.md skills/ agents/`. Filtered to commits that touch documentation and convention files. Bounded to the same 90-day/200-commit range as command 1. Provides evidence of documentation practice patterns distinct from general commit history.

4. **Directory layout probe** — a read-only top-level directory listing. Produces project-shape signals (`src/`, `tests/`, `docs/`, etc.) without traversing subdirectories. This is a shell command, not a git command, but belongs to the same read-only pre-dispatch scan.

### Working-tree convention probes

The skill reads the presence and partial content of the following files if they exist on disk. Absent files are noted as absent in the staging output; the agent receives the full list with present/absent status for each entry.

- `pyproject.toml`
- `package.json`
- `.editorconfig`
- `tsconfig.json`
- `ruff.toml`
- `mypy.ini`
- `.github/workflows/**`
- `tooling/deploy-manifest.json`
- Lint configs (e.g., `.eslintrc*`, `.pylintrc`, `tox.ini`)
- Formatter configs (e.g., `.prettierrc*`, `black.toml`)

### Staging file and agent handoff

The skill writes all Source 3 output (git command results + working-tree probe results) into `_tmp_reflect_source3_<timestamp>.md` in the project root before dispatching the agent. The timestamp is in `YYYYMMDD-HHMMSS` format. This staging file is part of the skill's `_tmp_*` lifecycle — the file is cleaned up at the end of the reflect run.

The agent receives the staging file path via the brief's `source_3_git_history` and `source_3_working_tree` constraint fields and reads the file during its distillation pass. The agent may also write its own `_tmp_*` working files during filter computation; those are separate from the skill's staging file and are likewise cleaned up at run end.

## Source 4 — plan docs, handoffs, and dispatch logs

**Scanned by the skill via glob before agent dispatch.** Source 4 is always active: it is ingested on every `reflect` invocation alongside Source 3, regardless of harness or flags. The skill collects matched paths and passes them to the agent via the brief's `source_4_*` constraint fields. The agent reads each file lazily during its distillation pass — Source 4 files are not pre-loaded into the staging file.

### Globs

The skill runs the following three globs against the working directory:

1. `docs/plan/**/*.md`
2. `docs/cross-memory/handoff*` — matches `handoff*.md`, `handoffs/`, and `handoff/` subtrees.
3. `docs/ops-dispatch-log*`

### Bound and truncation

Each glob is bounded to **50 files**. If a glob matches more than 50 files, the skill takes the 50 most-recently-modified files and records the remainder as skipped. The brief's `source_4_*` constraint block includes a `truncated:` field listing the count of skipped files per glob. The run summary surfaced to the user notes that some Source 4 files were skipped and shows the per-glob truncated counts.

If a glob matches zero files, the skill records the absence in the brief's `## Constraints` block. Zero matches on all three globs does not abort the reflect run; the agent proceeds with Sources 3 and 5 (if present).

## Source 5 — explicit seed via `--from`

**Always available under any harness.** `--from <path>` accepts a file or directory path. Multiple `--from` arguments are valid; their path sets are unioned into a single Source 5 collection.

### Path validation

The skill validates each `--from` path before constructing the agent brief. If a path does not exist or is not readable, the skill emits the following error verbatim and exits without dispatching the agent or writing any state:

```
error: --from path <path> does not exist or is not readable
```

All paths in the union set are validated before any agent dispatch. The first invalid path encountered produces the error; validation does not continue past the first failure.

### Bound

Source 5 is bounded to **100 paths total** (the combined union set across all `--from` arguments) or **10 MB total content size**, whichever limit is reached first. If either bound is exceeded, the skill errors with a clear message identifying which bound was hit and exits without dispatching the agent.

### Redaction

Source 5 content is read by the agent during distillation but is **not pre-redacted by the skill** before agent dispatch. The redaction pipeline applies only at Gate 2 of the `save <id>` flow. The body-preview in the candidate report may surface unredacted content from the source path; users should curate `--from` paths carefully — do not pass a path containing secrets or proprietary information unless you intend it to surface in candidate previews.

## Source 1 — Claude Code session transcripts (Claude Code harness only)

**Opt-in; Claude Code harness only.** Source 1 ingests session transcript files (`.jsonl`) from the active project's Claude Code directory. Two flag shapes activate it:

1. `--from-session <id>` — reads exactly one session transcript file. The skill resolves the file at `~/.claude/projects/<active-slug>/<id>.jsonl`.
2. `--since-last-reflect` — reads all `.jsonl` files in `~/.claude/projects/<active-slug>/` whose modification time is newer than `state.toml`'s `reflect.last_reflect_at` field. If more than 20 session files qualify, the skill takes the 20 most recently modified and discards the rest (20-session bound).

> **Path correction note.** The transcript path documented here is corrected against an upstream documentation reference that uses a `sessions/` subdirectory (`sessions/<id>.jsonl`). The actually-installed Claude Code stores `.jsonl` files at the top level of `~/.claude/projects/<active-slug>/` — there is no `sessions/` subdirectory in the installed layout. A future doc-sync pass will patch the upstream reference; for v1.2 implementation, use the corrected path documented here.

### Structural pre-check

The skill executes the following pre-check for each resolved session file **before** constructing the agent brief:

1. Verify the file exists at the resolved path.
2. Verify the file parses as one JSON object per line (the `.jsonl` format — each line must be individually valid JSON).
3. Verify that each JSON object contains the minimal expected key set needed to extract message content.

If any step of the pre-check fails for a session, the skill emits the following warning verbatim and continues the reflect run without that session:

```
warning: transcript ingestion pre-check failed for session <id>: <reason>. Falling back to Sources 3 + 4 only.
```

The reflect run does not abort. Sessions that pass the pre-check are included; sessions that fail are skipped. If all requested sessions fail the pre-check, the run continues with Sources 3, 4, and 5 (if `--from` was also supplied).

### Unset `last_reflect_at` fallback

When `--since-last-reflect` is used but `state.toml`'s `reflect.last_reflect_at` field is unset (for example, on the first-ever reflect run for this project), the skill falls back to "last 30 days of sessions" and emits:

```
info: state.toml.reflect.last_reflect_at unset; --since-last-reflect falls back to last 30 days of sessions.
```

The 20-session bound applies to this fallback set as well.

### Format fragility and risk acknowledgment

The `.jsonl` transcript format is **non-public** and may change between Claude Code releases without notice. The structural pre-check plus graceful fallback is the contract that lets a reflect run survive a format change: if Claude Code ships a breaking format revision, the pre-check will catch it, emit the warning above, and the run will continue with Sources 3, 4, and 5. No state is written for failed sessions; no agent dispatch is blocked by a single session failure.

## Report rendering

After the agent returns, the skill renders the candidate report to chat. The report has two parts: an environment header followed by the candidate table.

### Environment header

Printed before the candidate table. Six fields, in order:

1. **harness** — the active harness (`claude-code`, `cursor`, or `generic`).
2. **active project** — the active project slug.
3. **sources scanned** — the list of source numbers actually ingested this run (e.g., `Sources 3, 4` or `Sources 1, 3, 4, 5`).
4. **raw candidates generated** — the count from the agent's distill output, before the anti-redundancy filter is applied.
5. **candidates dropped by filter** — the count removed by the filter, with a parenthetical breakdown by reference set (e.g., `3 (2 canonical-overlap, 1 archive-overlap)`).
6. **candidates surfaced** — raw candidates generated minus candidates dropped by filter.

### Candidate table columns

Eight columns, byte-aligned with the agent's `## Output Contract — distill`:

| Column | Description |
| :--- | :--- |
| `id` | Candidate identifier for the current run (e.g., `c1`, `c2`). IDs do not persist across runs. |
| `type` | Candidate type as returned by the agent (e.g., `preference`, `rule`, `project`). |
| `category` | One of the four locked taxonomy categories: `architectural-decisions`, `conventions-implicit-in-code`, `workflow-patterns-from-successful-runs`, `user-preferences-from-feedback-patterns`. |
| `scope` | Memory scope — `user-global`, `project:<slug>`, or `harness:<name>`. |
| `proposed-name` | The slug the agent proposes for the would-be memory file name. |
| `body-preview` | Up to 160 characters of the candidate body, truncated with `…` if longer. |
| `source-evidence` | Pointer to the evidence that produced this candidate (e.g., `"Source 1 — transcript <session-id>:<line-range>"`, `"Source 3 — git log: <sha-or-range>"`, `"Source 4 — <glob-matched-path>"`). |
| `flags` | Zero or more flags; currently `would-supersede` when the proposed name matches an existing canonical memory. Empty cell when no flags apply. |

The four `category` values above are the reflect distillation taxonomy (used during candidate generation); they are distinct from the `category` frontmatter enum on stored memory files, which is defined in `schema-validator.md`.

### Sort order

Candidates are rendered in deterministic order: sorted first by `category` (lexicographic on the four locked category names), then by `proposed-name` lexicographically within each category. This order is stable across runs given identical input — it does not depend on agent output ordering.

### Empty-project edge case

When the raw candidate count is 0 — meaning no sources had distillable content — the skill prints the following line and exits cleanly:

```
No candidates surfaced. Either the source set was empty or the project has no extractable patterns yet. Run again after more commits / plan docs accumulate, or use --from to seed an explicit path.
```

The interactive loop is skipped. `state.toml` is **not** written — no `last_reflect_at` update, no `reflect_declined.md` creation.

### All-filtered edge case

When the raw candidate count is greater than 0 but the surfaced count is 0 — meaning the filter dropped every candidate — the skill prints a redundancy summary and exits cleanly:

```
All N candidates were filtered out as redundant: M canonical-overlap, K archive-overlap, J declined-overlap, L excluded-by-rule. No new candidates to review.
```

The interactive loop is skipped. Unlike the empty-project case, `state.toml` **is** updated: `last_reflect_at` advances to the current timestamp because the reflect run completed successfully and the filter ran. The user's next `init` or `doctor` will reset the staleness clock.

## Interactive command loop

After the candidate report is rendered, the skill enters a loop that accepts four commands. Each action requires a confirmation prompt with default N; user types Y to proceed. Pressing Enter without typing Y aborts the action and returns to the prompt — no state change occurs.

### Commands

**`save <id>`**

Routes the candidate through the existing Gate 3 (redaction check) and Gate 4 (write) of the v1 save pipeline — the same path taken by a direct `/cross-memory save` invocation. No new write path is introduced. The candidate is written to the canonical store under the proposed scope and name. If the proposed name matches an existing canonical entry, the `would-supersede` flag is already present in the report; the user must still confirm at Gate 3 before the supersede proceeds (supersede flagging detail is documented separately).

**`decline <id>`**

The skill appends a structured entry to `~/.cross-memory/projects/<slug>/reflect_declined.md` following the M1 ledger schema (fields: `declined_at`, `candidate_id`, `proposed_name`, `category`, `scope`, `tags`, `body_preview`, `source_evidence`, `run_id`). The file is created lazily on the first decline within a project; if no candidate has ever been declined, the file does not exist and is not pre-provisioned. The skill owns this write — the agent does not touch the file.

**`edit <id>`**

Opens a minimal field-tweak surface presenting the four editable fields of the candidate: `proposed-name`, `body`, `tags`, and `scope`. The user modifies one or more fields. On confirmation (Y at the confirmation prompt), the edited candidate re-enters Gate 3 (redaction) of the save pipeline; if it passes redaction the save proceeds to Gate 4 (write). On abort (N or Enter at the confirmation prompt), no state change occurs — the candidate remains in the in-memory report with its original field values and the user can re-action it before typing `done`.

**`done`**

Exits the interactive loop. The skill writes `state.toml` exactly once at this point — regardless of how many candidates were saved or declined during the loop — with three fields under `[reflect]`:

- `last_reflect_at` — the current UTC timestamp (ISO-8601).
- `last_reflect_candidate_count` — the surfaced candidate count for this run (raw candidates generated minus candidates dropped by filter).
- `last_reflect_run_id` — the run identifier for this session.

The skill then emits a run summary: candidates surfaced, saved, declined, unactioned.

### Unactioned candidates

Candidates that the user neither saved nor declined before typing `done` are not written to any ledger. They do not appear in `reflect_declined.md` and are not counted against the canonical store. On subsequent runs, they may re-surface if the same source evidence still produces them — they receive no special treatment.

### r2 edge-case carve-out

The two edge cases from `## Report rendering` carry through to loop entry:

- **Empty-project** (raw candidate count == 0): the interactive loop is never entered. `state.toml` is not written and `last_reflect_at` does not advance.
- **All-filtered** (raw count > 0, surfaced count == 0): the interactive loop is never entered. `state.toml` is written once (the filter ran; this counts as a completed reflect run) and `last_reflect_at` advances.

In both edge cases the ledger (`reflect_declined.md`) is not touched.

## Supersede flagging

### The `would-supersede` flag

The `flags` column of the candidate table may contain `would-supersede <existing-id>` for any candidate that overlaps an existing canonical entry strongly enough to suggest the candidate is a refinement or replacement of that entry, not a brand-new memory. The flag is computed by the agent during distillation using the same three overlap signals as the anti-redundancy filter (slug overlap, tag overlap, and body-token Jaccard similarity). The supersede check is independent of the filter's drop threshold: the agent uses the same three signals to compute supersede candidacy; a higher-than-drop overlap against a canonical entry sets `would-supersede`. A candidate can therefore pass the filter (i.e., not be dropped as redundant) and still carry the `would-supersede` flag, because the supersede threshold is stricter than the drop threshold.

### Decline-ledger precedence

The decline-ledger redundancy check runs before the supersede check. If a candidate matches a previously declined entry in `reflect_declined.md`, it is dropped at the filter stage: the supersede check never sees it. The candidate does not surface in the report, no `would-supersede` flag is set, and the user is not prompted. This precedence prevents oscillation: a user who declined a candidate is not later prompted with a supersede variant of the same candidate.

### `save <id>` on a flagged candidate

When the user types `save <id>` on a candidate that carries `would-supersede`, the skill routes the save through the existing v1.1 supersede flow — the same flow that a direct `/cross-memory save --supersede` invocation already uses. No new supersede pipeline is created. The user sees the v1.1 supersede confirmation prompt (diff rendering, archive path, Gate 3 confirmation) and either accepts — which archives the canonical predecessor and writes the new entry at Gate 4 — or aborts with no state change.

### No silent supersedes

A save never silently replaces a canonical entry. If the agent computes a supersede candidate, the `would-supersede` flag must be present in the report before the user can act on the candidate. The v1.1 supersede confirmation prompt must fire before the archive and write proceed. Both gates — the flag in the report and the confirmation prompt — are required; neither can be bypassed. This closes the supersede-flagging requirement for the reflect subcommand.

## Anti-redundancy filter

The anti-redundancy filter runs as a deterministic post-generation pass immediately after the agent returns the raw candidate pool and before any candidate surfaces to the user. Its job is to drop candidates that duplicate — or closely overlap — material already in the canonical store, the archive, or the per-project decline ledger. The filter is entirely deterministic: given identical inputs and reference sets, two consecutive reflect runs produce byte-identical candidate sets in the same order (AC15).

### Three filter signals

The filter measures three overlap signals between each candidate and each reference entry. All three signals are bounded to `[0.0, 1.0]`.

1. **Slug overlap** — character-level overlap between the candidate's `proposed-name` and the reference entry's slug, normalized to `[0.0, 1.0]`. Default threshold: `0.85`, configurable via `~/.cross-memory/config.yaml` field `reflect.slug_overlap_threshold`.

2. **Tag overlap** — Jaccard similarity between the candidate's tag list and the reference entry's tag list — `|A ∩ B| / |A ∪ B|`, where A is the candidate's tag set and B is the reference entry's tag set. Range `[0.0, 1.0]`. Default threshold: `0.8`, configurable via `reflect.tag_overlap_threshold`.

3. **Body-token Jaccard** — Jaccard similarity over the first 200 tokens of the candidate body versus the first 200 tokens of the reference body, after lowercasing and stopword filtering. Default threshold: `0.7`, configurable via `reflect.body_token_jaccard_threshold`.

### Tokenization rule (body-token Jaccard)

The tokenization procedure is deterministic and applied identically to both the candidate body and the reference body before computing Jaccard similarity:

- Tokenize on whitespace and punctuation boundaries.
- Lowercase all tokens.
- Strip the canonical stopword list: `the`, `a`, `of`, `to`, `in`, `and`, `is`, `it`, `that`, `this`, `on`, `for`, `as`, `with`.
- Take only the first 200 tokens after stopword removal (deterministic truncation; consistent across runs).

### Disjunctive trip rule

The filter is disjunctive — one trip is enough. A candidate is dropped if ANY ONE signal crosses its threshold against ANY ONE reference entry. With three signals and N reference entries, the filter performs at most 3N comparisons per candidate; the first trip immediately drops the candidate without completing the remaining comparisons.

### Reference sets

The filter operates against four reference sets. Three are deterministic and consumed directly by the signal comparisons. One is an LLM-prompt-applied exclusion corpus that operates separately, before candidates enter the pool the deterministic filter sees.

**Set A — canonical store.** The entries in `~/.cross-memory/` filtered to the tiers relevant for the candidate's scope (`user-global`, `project:<slug>`, or `harness:<name>`). A candidate that crosses any threshold against any canonical entry is dropped. Filter-reason tag: `canonical-redundancy`.

**Set B — archive.** The entries in `~/.cross-memory/archive/`. Archived entries represent material that was once canonical and deliberately retired; a candidate that closely overlaps an archived entry is still a candidate for redundancy. Filter-reason tag: `archive-redundancy`.

**Set C — per-project decline ledger.** The entries recorded in `~/.cross-memory/projects/<slug>/reflect_declined.md`. A candidate that matches a previously declined entry is dropped without prompting the user. This prevents oscillation: a user who declined a candidate once is not presented with the same candidate on the next reflect run. Filter-reason tag: `declined-redundancy`.

**Set D — LLM-prompt-applied exclusion corpus (separate; not consumed by the deterministic filter).** Set D is the `## What NOT to save in memory` section of `~/.claude/CLAUDE.md`. This section is a free-text rule corpus: it produces no slug, no tag set, and no body suitable for Jaccard comparison — the three signals literally do not apply to it. Accordingly, Set D is not fed into the deterministic filter. Instead, it is supplied to the agent as a system-prompt input during raw-candidate generation (the distill step). The agent uses Set D categorically to suppress candidates before they enter the candidate pool the deterministic filter sees. Filter-reason tag when a candidate still surfaces despite the prompt corpus and needs a reason label: `excluded-by-rule`.

### Set D best-effort fallback

The Set D read is best-effort. If `~/.claude/CLAUDE.md` is missing, unreadable, or does not contain a heading matching `## What NOT to save in memory` (accounting for case drift), the skill emits a structured warning and the filter proceeds with the LLM-prompt exclusion corpus empty — raw-candidate generation receives an empty exclusion prompt. The three deterministic sets (A, B, C) continue to apply normally.

Example warning:

```
warning: ~/.claude/CLAUDE.md "What NOT to save in memory" section not found; LLM-prompt exclusion corpus empty. Deterministic filter (Sets A/B/C) operates normally.
```

### Per-reference-set filter-reason tags

| Reference set | Filter-reason tag |
| :--- | :--- |
| Set A — canonical store | `canonical-redundancy` |
| Set B — archive | `archive-redundancy` |
| Set C — decline ledger | `declined-redundancy` |
| Set D — LLM-prompt exclusion corpus | `excluded-by-rule` |

### `--verbose` filter decisions

When `--verbose` is set, the skill prints a per-candidate filter decision for every candidate the filter evaluates — both dropped candidates (with the trip signal and reason) and passed candidates (with "passed" status). For dropped candidates, the output includes the signal name, the raw score, the reference entry that was matched, and the filter-reason tag. Example output:

```
[filter] candidate id=c-001 proposed-name=poetry-virtual-env-convention
         dropped: body-token-jaccard=0.83 vs canonical/python-toolchain-setup
         reason: canonical-redundancy
```

### Determinism (AC15) and fixture reference

Two consecutive reflect runs with identical inputs and reference sets produce byte-identical candidate sets in the same order. This guarantee holds because all three signals are computed from deterministic inputs (slug strings, tag sets, and fixed 200-token windows), the reference sets are read from stable files, and the filter applies signals in a fixed traversal order (Set A, then Set B, then Set C). No stochastic ordering, no time-dependent randomness, and no LLM sampling occurs within the filter pass itself.

The fixture tree at `skills/cross-memory/test-fixtures/reflect/` provides controlled inputs for verifying this property. M3.verify.5 walks AC15 against those fixtures.

## Cross-harness applicability

The table below covers all twelve behavioral dimensions across the three supported harnesses.

| Component | Claude Code | Cursor | Generic |
| :--- | :--- | :--- | :--- |
| `/cross-memory reflect` subcommand | Full | Full (Sources 3 + 4 + 5 only) | Full (Sources 3 + 4 + 5 only) |
| `--from-session <id>` flag | Available | Errors at parse time: `error: --from-session and --since-last-reflect are Claude-Code-only flags; current harness is <name>` | Errors with same message |
| `--since-last-reflect` flag | Available | Same error as above | Same error as above |
| `--from <path>` flag | Available | Available | Available |
| `intent: distill` agent dispatch | Full | Full | Full |
| `reflect_declined.md` ledger | Full | Full | Full |
| Interactive report loop (save/decline/edit/done) | Full | Full | Full |
| Anti-redundancy filter (all four reference sets) | Full | Full | Full |
| Supersede flag on candidates | Full | Full | Full |
| Staleness nudge in `init` | Full | Full | Full |
| Staleness nudge in `doctor` | Full | Full | Full |
| `state.toml` write | Full | Full | Full |

**Headline:** the only Claude-Code-only surface is Source 1 (transcript ingestion via two flags). Everything else is harness-agnostic and behaves identically across all three harnesses.

### Flag-error behavior under non-Claude-Code harnesses

Both `--from-session` and `--since-last-reflect` appear in the universal `--help` output under all harnesses — the flag-help is not harness-gated. A user who moves between harnesses sees the same flag set described in help text regardless of which harness is active.

When either flag is invoked under a non-Claude-Code harness, the skill errors at parse time (before any agent dispatch, before any `state.toml` write, before any ledger touch) with the following message:

```
error: --from-session and --since-last-reflect are Claude-Code-only flags; current harness is <name>
```

where `<name>` is the resolved harness identifier (e.g., `cursor`, `generic`).

Under Cursor and generic harnesses, `reflect` runs on Sources 3 + 4 + 5 only (no Source 1 transcript ingestion) when neither flag is passed.

## `--non-interactive`, `--json`, and `--context` deferral

The `--non-interactive` flag, structured `--json` output, `--context` injection, and the corresponding exit-code contracts are deferred to v1.3. The argument grammar above is intentionally extensible: adding `--non-interactive` in v1.3 means adding it to the flag list; the eight-step routing flow is unaffected and does not need restructuring.

## Atomicity

All writes this subcommand makes to the canonical store follow the write-to-temp-then-rename pattern documented in `subcommand-save.md § Atomicity contract`. This applies to:

- **`state.toml` write** (on `done` — `~/.cross-memory/projects/<slug>/state.toml`)
- **`reflect_declined.md` append** (on `decline <id>` — `~/.cross-memory/projects/<slug>/reflect_declined.md`)
- **Canonical memory file and MEMORY.md writes** triggered by `save <id>`, which routes through Gate 4 of the save pipeline (see `subcommand-save.md § Gate 4 — Write` and `§ Atomicity contract`).

Readers always see either the pre-write or the post-write state of any canonical-store file — never a torn intermediate.

## Cross-references

- **Agent brief shape and output contract**: `agents/cross-memory.md` (`## Brief Format` and `## Output Contract — distill`).
- **Anti-redundancy filter and reference sets**: the brief's `## Constraints` block enumerates the four reference sets (canonical store, archive, declined ledger, excluded rule).
- **`reflect_declined.md` ledger**: created lazily at `~/.cross-memory/projects/<slug>/reflect_declined.md` on first decline; consulted by the agent as Reference Set C. Schema details in `reflect-decline-ledger.md`.
- **`state.toml` per-project state file**: `~/.cross-memory/projects/<slug>/state.toml`; `reflect.last_reflect_at` field read by the staleness hint in `subcommand-doctor.md § Reflect staleness hint`.
- **`reflect_staleness_threshold_days` config field**: `## Config` above.
- **Adapter selection chain**: `adapter-selection.md`.
- **Staleness hint fired by `doctor` and `init`**: `subcommand-doctor.md § Reflect staleness hint`.
