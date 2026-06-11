<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Subcommand: init

Bootstrap `~/.cross-memory/` and register the active harness sentinel block. Init is additive only — it never deletes, overwrites, or repairs existing files.

## Command syntax

```
/cross-memory init \
  [--harness <claude-code|cursor|generic>] \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--json] \
  [--verbose]
```

No positional arguments. The flags `--harness`, `--scope`, `--json`, and `--verbose` are defined in `## Shared flag parsing` above. There is no `--repair`, `--force`, or `--reset` flag — any modification to existing files is out of scope for init.

## Step 1 — Provisioning

Invoke the lazy-provisioning sequence documented in `## Config → Lazy-provisioning sequence`. Init calls that sequence eagerly on every invocation; the same sequence that normally fires lazily on first save is executed up front.

If `~/.cross-memory/` already exists, the provisioning sequence exits at its check step (step 1 of that sequence: "If present, skip provisioning") and step 1 of init is a no-op. No directories are created, no config file is written, and no index files are touched.

Init does **not** duplicate the directory-creation or config-write logic — it delegates entirely to the documented lazy-provisioning path. The authoritative directory tree and default field values are maintained in `## Config → Lazy-provisioning sequence`; init adds no new provisioning logic of its own.

**Verbose trace (when `--verbose` is set):**

```
[init] step 1: ~/.cross-memory/ already exists; provisioning skipped
[init] step 1: ~/.cross-memory/ absent; running lazy-provisioning sequence
```

## Step 2 — Adapter detection

Run the five-step precedence chain in `adapter-selection.md` (CLI flag → config field → env var → manifest probe → generic fallback) to determine the active harness. Record both the chosen harness name and the precedence step that won; both are included in the step 5 summary line (documented in a later task) and in the `harness_selection_step` field of the `--json` output.

This step makes no writes. It calls the same selection logic invoked at the start of every other subcommand.

**Verbose trace (when `--verbose` is set):**

```
[init] step 2: harness=claude-code (selected via: adapter probe)
```

The step-label vocabulary (`cli flag`, `config field`, `env var`, `adapter probe`, `generic fallback`) matches the table in `adapter-selection.md § Selection logging and observability`.

## Step 3 — Reachability probe

Run two check primitives from `## Check-name vocabulary` in read-only mode:

- **`adapter-detection`** — re-runs the adapter selection chain and confirms the harness resolves consistently. Any divergence between this result and step 2's result is a structured warning.
- **`sentinel-marker-count`** — reads the active project's harness-native `MEMORY.md` (if reachable) and verifies exactly one begin-marker and one end-marker are present.

The probe target is harness-specific:

| Harness | Reachability target | slug derivation |
| :--- | :--- | :--- |
| `claude-code` | `~/.claude/projects/<slug>/memory/` | slug derived from the current project's canonical path; same derivation as the save and recall paths |
| `cursor` | `~/.cursor/projects/<slug>/memory/` | same slug-derivation logic applied to the Cursor project path |
| `generic` | *(no target)* | step 3 is a no-op for the generic harness |

For the `claude-code` and `cursor` harnesses, the probe verifies two things in order:

1. The `memory/` directory at the harness path is reachable (directory-existence check).
2. The active project's `MEMORY.md` within that directory is reachable (file-existence check).

**Failure isolation.** A failed reachability check produces a structured warning and continues. The canonical store provisioned in step 1 is not rolled back. The warning is recorded in the invocation's warning list, which step 5 will include in the summary output. The summary line will report `harness target: unreachable` so the user knows the sentinel block in step 4 will be skipped (that skip behavior is documented in the step 4 task). Check identifiers match the vocabulary in `## Check-name vocabulary` — do not invent new names.

**Verbose trace (when `--verbose` is set):**

```
[init] step 3: harness target ~/.claude/projects/<slug>/memory/ reachable
[init] step 3: harness target unreachable; warning recorded, continuing
[init] step 3: generic harness; reachability probe skipped
```

## Step 4 — Always-on filter + sentinel write

**Sequencing rule.** The five init steps are sequential, but a warning at step 3 does not abort the sequence. The always-on filter runs regardless of step 3's outcome. The sentinel-block write is skipped only when the adapter has nothing to write to (unreachable harness target or cursor no-op). The step 5 summary still prints in all cases.

**What step 4 does:**

1. Invoke the always-on tier filter (see `always-on-tier.md`) to produce the ordered entry list for the current session. The filter is harness-agnostic — it reads the three canonical scope index files and applies the four entry-selection rules regardless of which adapter is active.
2. Pass the filter's output list to the injection-block formatter (see `injection-block.md`) to produce the `[CROSS-MEMORY]` content bytes. The formatter renders the `User Profile:`, `Project Knowledge:`, and `Relevant Memories:` sub-sections, applies the `max_inject_chars` size budget, and returns the bytes that will be placed between the sentinel markers. It does not emit the markers themselves.
3. Dispatch `active_adapter.update_sentinel_block(content)` with those bytes. The call shape is identical to the dispatch used in the save and forget flows (see `subcommand-save.md § Mirror hook — standard save` and `adapter-claude-code.md § 6`).

After the write, init runs `sentinel-region-content-parses` (from `## Check-name vocabulary` Group C) as a self-check to confirm the bytes just written parse as a valid `[CROSS-MEMORY]` injection block. If this check reports `fail`, init fails fast and emits a structured violation report before step 5.

**Per-harness behavior:**

| Harness | Sentinel write | Self-check result |
| :--- | :--- | :--- |
| `claude-code` | `update_sentinel_block(content)` writes the populated `[CROSS-MEMORY]` block into the harness-native `MEMORY.md` sentinel region at `~/.claude/projects/<slug>/memory/MEMORY.md` | `sentinel-region-content-parses` returns `pass` or `fail` |
| `cursor` | `update_sentinel_block` is a documented no-op at v1 (`adapter-cursor.md § 6`). The always-on filter still runs and the summary still prints, but no sentinel-block bytes are written. The summary line reports `sentinel=skipped (cursor adapter no-op at v1)`. | `sentinel-region-content-parses` returns `not-applicable` (see `## Check-name vocabulary` Group C — `not-applicable` means the check does not apply on this harness surface rather than pass or fail) |
| `generic` | Same no-op as cursor — no sentinel surface exists | `sentinel-region-content-parses` returns `not-applicable` |

**Failure-isolation rule.** When step 3 recorded a reachability warning (harness target unreachable), step 4 skips the `update_sentinel_block` dispatch entirely and does not run the `sentinel-region-content-parses` self-check. The always-on filter and injection-block formatter still run — their output is retained for the step 5 summary's `always-on entries` count. The canonical store provisioned in step 1 is not affected. The step 5 summary reports `sentinel=skipped (harness target unreachable)`.

**Implementation note.** On a fresh `~/.cross-memory/` with no user-global memories, the always-on filter produces an empty entry list. The injection-block formatter returns empty bytes (no sub-sections, no header content). Init writes those empty bytes between the sentinel markers — the markers themselves are still written. Step 5 reports `0 always-on entries`. This is a successful empty write, not a failure. The `sentinel-region-content-parses` self-check treats an empty-but-structurally-valid block as `pass`.

**Verbose trace (when `--verbose` is set):**

```
[init] step 4: always-on filter: 3 entries selected
[init] step 4: injection-block formatter: 412 bytes
[init] step 4: sentinel block written (claude-code)
[init] step 4: self-check sentinel-region-content-parses: pass
[init] step 4: always-on filter: 0 entries selected
[init] step 4: injection-block formatter: 0 bytes (empty block)
[init] step 4: sentinel block written (claude-code, 0 bytes between markers)
[init] step 4: self-check sentinel-region-content-parses: pass
[init] step 4: sentinel write skipped (cursor adapter no-op at v1)
[init] step 4: self-check sentinel-region-content-parses: not-applicable
[init] step 4: sentinel write skipped (harness target unreachable)
```

## Step 4.5 — Reflect staleness check

After the step 4 verbose trace is emitted and before the step 5 summary line, init reads the per-project state file to determine whether a reflect-staleness hint is warranted.

**Read target:** `~/.cross-memory/projects/<slug>/state.toml` — the same slug derived in steps 2–4.

**Staleness computation:**

1. Attempt to read and parse `state.toml`.
2. If `state.toml` is absent, unparseable, or `reflect.last_reflect_at` is unset, suppress the hint silently and continue to step 5. No warning is emitted and no structured violation is recorded.
3. If `reflect.last_reflect_at` is set, compute `delta_days = (now - last_reflect_at)` rounded to integer days.
4. Compare `delta_days` against `reflect_staleness_threshold_days` from the config (default `30`).
5. If `delta_days > reflect_staleness_threshold_days`, emit the following hint to chat:

```
Tip: it is been N days since reflect ran — run /cross-memory reflect to surface candidates.
```

Where `N` is the computed `delta_days` integer.

**Suppress rule.** The hint is suppressed (no output, no side effects) when any of the following hold: `state.toml` is absent; `state.toml` cannot be parsed; `reflect.last_reflect_at` is not present in the parsed result; or `delta_days <= reflect_staleness_threshold_days`.

**Never auto-invokes reflect.** This hint is suggestive only — `init` does not dispatch the cross-memory agent or auto-run `/cross-memory reflect` based on the staleness check. The user must explicitly invoke `/cross-memory reflect` to proceed.

**Verbose trace (when `--verbose` is set):**

```
[init] step 4.5: state.toml found
[init] step 4.5: reflect.last_reflect_at = 2025-12-01T00:00:00Z
[init] step 4.5: delta_days = 163; threshold = 30; hint fired
[init] step 4.5: state.toml absent; staleness hint suppressed
[init] step 4.5: state.toml unparseable; staleness hint suppressed
[init] step 4.5: reflect.last_reflect_at unset; staleness hint suppressed
[init] step 4.5: delta_days = 10; threshold = 30; hint suppressed
```

The verbose trace records: (1) whether `state.toml` was found; (2) whether `reflect.last_reflect_at` was set; (3) the computed `delta_days`; (4) the threshold value; (5) whether the hint fired or was suppressed.

## Step 5 — Summary output (human / JSON / verbose)

Step 5 emits the invocation result. It makes no writes; it only reads the state accumulated by steps 1–4 and formats it. The summary always prints, regardless of whether earlier steps produced warnings or skips.

### Human-readable summary

The summary line shape is:

```
cross-memory initialized: harness=<name>, store=<state>, sentinel=<state> (<bytes>), <count> always-on entries
```

**State values:**

- `store` is one of:
  - `provisioned` — step 1 created `~/.cross-memory/` and wrote a fresh config.
  - `already-present` — step 1 found the directory already existed; nothing was created.

- `sentinel` is one of:
  - `updated (<N> bytes)` — step 4 wrote `N` bytes between the sentinel markers. `N` may be zero (see empty-write note below).
  - `already-current (no change)` — step 4 computed the same bytes as the markers already contained; no write was performed.
  - `skipped (<reason>)` — step 4 did not write. The reason string is one of:
    - `cursor adapter no-op at v1`
    - `harness target unreachable`
    - `not-applicable` (generic harness)

**Concrete examples:**

```
cross-memory initialized: harness=claude-code, store=provisioned, sentinel=updated (1843 bytes), 12 always-on entries
cross-memory initialized: harness=claude-code, store=already-present, sentinel=already-current (no change), 12 always-on entries
cross-memory initialized: harness=cursor, store=provisioned, sentinel=skipped (cursor adapter no-op at v1), 5 always-on entries
cross-memory initialized: harness=generic, store=already-present, sentinel=skipped (not-applicable), 0 always-on entries
```

**Empty-write disambiguation.** A successful init on a fresh `~/.cross-memory/` with no user-global memories produces:

```
cross-memory initialized: harness=claude-code, store=provisioned, sentinel=updated (0 bytes), 0 always-on entries
```

This is a **successful pass**. The sentinel markers were written; the region between them is intentionally empty because the always-on filter returned no entries. This is not a failure or warning condition.

### JSON output (`--json`)

When `--json` is passed, step 5 prints a JSON object instead of the human summary line. The schema version is `1`. Keys appear in this order:

```json
{
  "schema_version": 1,
  "timestamp_utc": "2026-05-09T14:23:01Z",
  "harness": "claude-code",
  "harness_selection_step": "cli-flag",
  "active_project_slug": "ai-skills-agents",
  "store": {
    "provisioned": true,
    "path": "/home/user/.cross-memory"
  },
  "sentinel": {
    "updated": true,
    "bytes": 1843,
    "path": "/home/user/.claude/projects/ai-skills-agents/memory/MEMORY.md"
  },
  "always_on_entries": 12,
  "warnings": []
}
```

**`harness_selection_step` enum.** This field reports which step in the five-step precedence chain selected the harness. Allowed values, in precedence order:

| Value | Meaning |
| :--- | :--- |
| `cli-flag` | `--harness` flag was present on the command line |
| `config-field` | `harness` field in `~/.cross-memory/config.yaml` was set |
| `env-var` | `CROSS_MEMORY_HARNESS` environment variable was set |
| `manifest-probe` | harness was auto-detected via adapter manifest probe (step 4 of the selection chain) |
| `generic-fallback` | no prior step matched; generic adapter selected |

A user who sees `harness=generic` unexpectedly can read `harness_selection_step` to understand which detection step was the furthest the chain reached, without needing to re-run with `--verbose`.

**`warnings` array.** Each element is a structured warning object capturing a non-fatal issue from steps 3 or 4:

```json
{ "step": 3, "code": "harness-target-unreachable", "message": "~/.claude/projects/<slug>/memory/ not found" }
```

Shape: `{ step: 3 | 4, code: <string>, message: <string> }`. The `code` field uses the same identifier vocabulary as `## Check-name vocabulary`. An empty `warnings` array means all steps completed without non-fatal issues.

**Empty-write in JSON.** When the always-on filter returns zero entries and step 4 writes empty bytes, the JSON reflects this as a successful pass:

```json
{
  "sentinel": { "updated": true, "bytes": 0, "path": "..." },
  "always_on_entries": 0
}
```

`sentinel.updated: true` and `sentinel.bytes: 0` together signal a successful empty write. This is not an error; `warnings` will be empty.

**Cross-tool key note.** The fields `harness`, `harness_selection_step`, and `timestamp_utc` use the same field names and value shapes as the doctor JSON schema. Additions or renames to these three keys must be applied consistently to both subcommands.

### Verbose mode (`--verbose`)

When `--verbose` is set, step 5 prints each step's trace on its own line, then the summary line. The full trace for a successful init looks like:

```
[init] step 1: ~/.cross-memory/ already exists; provisioning skipped
[init] step 2: harness=claude-code (selected via: cli flag)
[init] step 3: harness target reachable; sentinel markers found
[init] step 4: filter computed 12 always-on entries; sentinel block updated (1843 bytes)
[init] step 5: cross-memory initialized: harness=claude-code, store=already-present, sentinel=updated (1843 bytes), 12 always-on entries
```

The trace for a fresh install with an empty store:

```
[init] step 1: ~/.cross-memory/ absent; running lazy-provisioning sequence
[init] step 2: harness=claude-code (selected via: adapter probe)
[init] step 3: harness target reachable; sentinel markers found
[init] step 4: filter computed 0 always-on entries; sentinel block updated (0 bytes)
[init] step 5: cross-memory initialized: harness=claude-code, store=provisioned, sentinel=updated (0 bytes), 0 always-on entries
```

The step-5 trace line is identical to the human summary line, prefixed with `[init] step 5:`. When `--json` and `--verbose` are both set, the step traces still print as plain text and the final output line is the JSON object.

## Idempotency contract

Init is safe to run repeatedly with no state changes between runs. The per-step behavior is:

1. **Step 1** is a no-op if `~/.cross-memory/` already exists. The provisioning sequence exits at its own guard, no files are created or overwritten, and `store` reports `already-present` in the summary.
2. **Steps 2 and 3** are read-only. They call the adapter-selection chain and the reachability probe respectively, neither of which writes anything.
3. **Step 4** produces byte-identical sentinel-block content across runs when no canonical-store changes have occurred between them. The always-on filter draws from the same canonical memories on each run; if the filter output is unchanged, the computed bytes are unchanged, and step 4 skips the write entirely. `sentinel` reports `already-current (no change)` in the summary.
4. **Step 5** prints to chat. It has no on-disk effect. The `timestamp_utc` field emitted in the `--json` output (see `## Step 5 — Summary output (human / JSON / verbose)`) is run-scoped — it changes on every invocation. It lives only in the chat-only JSON object and does not appear inside the sentinel-bounded region; the byte-identical sentinel-content guarantee is therefore unaffected by the timestamp.

The human summary distinguishes the two idempotent-path states explicitly — `store=already-present` and `sentinel=already-current (no change)` — so a user running init defensively (e.g., after pulling a new harness config) can confirm at a glance that nothing changed unexpectedly. See `## Step 5 — Summary output (human / JSON / verbose)` for the full state vocabulary.

## What init does NOT do

- **No codebase-fact distillation.** Init makes zero LLM calls. The `--discover` flag (which would trigger an LLM-driven pass to extract project facts from the codebase) is deferred to a future release.
- **No agent dispatch.** Init runs entirely in the skill body. The cross-memory agent's lane allowlist is not touched by v1.1; init's writes are skill-side only.
- **No save.** Init does not create or modify any canonical memory file under `~/.cross-memory/`. The always-on filter reads from canonical memories but never writes to them.
- **No `--repair` or `--force`.** Bad-state diagnosis and repair are doctor's lane. Init is additive only — it provisions what is absent and leaves everything else untouched.
- **No telemetry.** Same posture as v1: no usage data, no network calls, no analytics.
- **No deploy.** Init is not invoked by `tooling/deploy.{ps1,sh}` and does not invoke them.
- **No project-scope provisioning.** The project-scope `MEMORY.md` for the active project is still created lazily on first save, exactly as today. Init does not create or write project-scope memory files.

## Reuse of doctor's check primitives

Init does not import or call doctor's checks at runtime. The shared contract is a documentation contract: any check identifier that appears in both subcommands means the **same finding** regardless of which subcommand surfaces it. The identifiers are defined in `## Check-name vocabulary`; each entry below cites the group it belongs to.

**Three reuse points:**

1. **After step 1 (provisioning).** Once the canonical store has been provisioned (or confirmed already-present), init optionally runs two Group A checks in read-only mode to confirm the freshly-provisioned store is in the expected state:
   - `canonical-archive-not-indexed` — asserts `~/.cross-memory/archive/MEMORY.md` does not exist.
   - `canonical-memory-md-consistency` — verifies each scope's `MEMORY.md` index matches the on-disk file set.
   Both are read-only probes. A failure here surfaces as a structured warning in the step 5 summary; init does not abort.

2. **Step 3 (reachability probe).** Init runs two checks from `## Check-name vocabulary` against the harness-native file:
   - `adapter-detection` (Group E) — re-runs the adapter selection chain and confirms the harness resolves consistently against the step 2 result.
   - `sentinel-marker-count` (Group C) — reads the active project's harness-native `MEMORY.md` and verifies exactly one begin-marker and one end-marker are present.
   Both are read-only. See `## Step 3 — Reachability probe` for failure-isolation and verbose-trace details.

3. **After step 4 (sentinel write).** Before printing the step 5 summary, init runs `sentinel-region-content-parses` (Group C) as a self-check against the file it just wrote, to confirm the bytes parse as a valid `[CROSS-MEMORY]` injection block. If this check reports `fail`, init fails fast and emits a structured violation report rather than proceeding to step 5. See `## Step 4 — Always-on filter + sentinel write` for the full behavior table.

**Consistency guarantee.** A sentinel-marker corruption that init reports during its step 3 probe is the same finding doctor would surface under `--check sentinel-marker-count`: both subcommands use the same check identifier from `## Check-name vocabulary`, and the identifier is the contract.

**Per-harness applicability of the step 4 self-check.** The Group C checks `sentinel-region-bytes-fingerprint` and `sentinel-region-content-parses` return `not-applicable` under the Cursor harness at v1, because `update_sentinel_block` is a documented no-op there (see `## Check-name vocabulary` Group C). Init's step 4 self-check therefore returns `not-applicable` under Cursor — and init still **succeeds**, with the skip noted in the summary line per the state vocabulary in `## Step 5 — Summary output (human / JSON / verbose)`.

## Cross-references

- **Lazy-provisioning sequence** (step 1 delegate): `## Config → Lazy-provisioning sequence` above.
- **Adapter selection chain** (step 2): `adapter-selection.md`.
- **Reachability check primitives** (step 3): `## Check-name vocabulary` (`adapter-detection` in Group E; `sentinel-marker-count` in Group C).
- **Always-on tier filter** (step 4): `always-on-tier.md`.
- **Injection-block formatter** (step 4): `injection-block.md`.
- **Sentinel write operation and call shape** (step 4): `adapter-claude-code.md § 6`; Cursor no-op: `adapter-cursor.md § 6`.
- **Step 4 self-check** (`sentinel-region-content-parses` per-harness applicability): `## Check-name vocabulary` Group C above.
- **Shared flags** (`--harness`, `--scope`, `--json`, `--verbose`): `## Shared flag parsing` above.
- **Selection logging vocabulary**: `adapter-selection.md § Selection logging and observability`.
