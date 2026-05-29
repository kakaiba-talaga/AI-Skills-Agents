<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Subcommand: doctor

Read-only structural and integration health check. Doctor inspects the canonical store, sentinel blocks, redaction surface, mirror consistency, and adapter-detection state. It never writes, repairs, or auto-corrects.

### Command syntax

```
/cross-memory doctor \
  [--pre-deploy | --post-deploy] \
  [--check <name>] \
  [--harness <claude-code|cursor|generic>] \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--json] \
  [--verbose]
```

No positional arguments. The flags `--harness`, `--scope`, `--json`, and `--verbose` are defined in `## Shared flag parsing` above — their semantics are not redefined here.

### Mutual-exclusion rules

The three mode flags interact with the following constraints:

- `--pre-deploy` and `--post-deploy` are **mutually exclusive** with each other. Passing both is an error:

  ```
  error: --pre-deploy and --post-deploy are mutually exclusive
  ```

- `--check <name>` is **mutually exclusive** with both `--pre-deploy` and `--post-deploy`. Combining `--check` with either mode flag is an error:

  ```
  error: --check cannot be combined with --pre-deploy or --post-deploy
  ```

  `--check` is **repeatable**: multiple `--check name1 --check name2` arguments on a single invocation are valid and select the union of the named checks.

- An unrecognized check name passed to `--check` fails fast:

  ```
  error: unknown check name 'foo'. See ## Check-name vocabulary for valid names.
  ```

### Mode selection and default check sets

Doctor operates in one of four modes depending on which flags are present. Each mode selects a distinct set of checks to run.

#### Default mode (no flags)

When neither `--pre-deploy`, `--post-deploy`, nor `--check` is present, doctor runs a balanced read-only sweep covering the four groups most likely to surface regressions without requiring harness-side writes or cross-harness coordination.

**Default check groups:**

| Group | Checks run |
| :--- | :--- |
| Group A — `canonical-integrity` | All five checks |
| Group B — `mirror-consistency` | All three checks (read-only; no adapter writes) |
| Group C — `sentinel-markers` | All three checks (per-harness applicability applies) |
| Group D — `redaction-surface` | All three checks |
| Group E — `deploy-target-prep` and `cross-harness-validation` | `adapter-detection` only |

**Excluded from default:** `deploy-manifest-coverage`, `stale-shipped-artifacts`, `cross-harness-roundtrip`, `sc-behavioral-walk`. These are either CI-context-specific (deploy-manifest coverage, stale artifacts) or require a second harness to be active (cross-harness round-trip, SC behavioral walk).

**Wall-clock budget.** The default mode must complete in under **5 seconds** on a healthy 100-memory store. New check additions to any default-mode group must be measured against this budget before being included in the default set.

Check identifiers used above are defined in `## Check-name vocabulary`. Cross-reference each by group when adding new default-mode checks.

#### Pre-deploy mode (`--pre-deploy`)

Selects the six-check shorthand for validating the local repository state before a deploy run. All six checks are read-only. This mode is appropriate as a pre-flight step in CI or before running `tooling/deploy.{ps1,sh}`.

| Check name | Group |
| :--- | :--- |
| `canonical-frontmatter-parse` | Group A — `canonical-integrity` |
| `canonical-memory-md-consistency` | Group A — `canonical-integrity` |
| `sentinel-marker-count` | Group C — `sentinel-markers` |
| `redaction-denylist-parses` | Group D — `redaction-surface` |
| `deploy-manifest-coverage` | Group E — `deploy-target-prep` |
| `stale-shipped-artifacts` | Group E — `deploy-target-prep` |

Full check definitions, finding shapes, and PASS/WARN/FAIL criteria are documented in `### Check definitions (full table)` below.

#### Post-deploy mode (`--post-deploy`)

Selects the five-check shorthand for validating a deployed state. Designed to run after `tooling/deploy.{ps1,sh}` completes, using the second harness as the invoking context.

| Check name | Group | Notes |
| :--- | :--- | :--- |
| `mirror-canonical-source-exists` | Group B — `mirror-consistency` | |
| `mirror-detect-collisions` | Group B — `mirror-consistency` | |
| `sentinel-region-content-parses` | Group C — `sentinel-markers` | Per-harness applicability applies |
| `adapter-detection` | Group E — `cross-harness-validation` | |
| `sc-behavioral-walk` | Group E — `cross-harness-validation` | `cross-harness-roundtrip` is invoked from the second harness as part of the SC-2 walk |

`cross-harness-roundtrip` is not listed as a standalone entry in `--post-deploy` because it is driven by `sc-behavioral-walk`'s SC-2 sub-walk from the second harness. See `## Check-name vocabulary` Group E for the `sc-behavioral-walk` per-harness applicability matrix.

**Single-harness invocation note.** When `--post-deploy` is invoked with only one harness (e.g., `--post-deploy --harness claude-code` without a corresponding second-harness invocation), `cross-harness-roundtrip` and the SC-2 sub-finding inside `sc-behavioral-walk` return `not-applicable` with `reason: "cross-harness round-trip requires a second harness; not invoked under single-harness post-deploy"`. Both are excluded from overall-verdict aggregation in this case.

Full check definitions, finding shapes, and PASS/WARN/FAIL criteria are documented in `### Check definitions (full table)` below.

#### Post-deploy walk (Claude Code)

The following six-step procedure constitutes the operator-facing validation walk for a single-harness Claude Code post-deploy invocation. Execute the steps in order; each step is a prerequisite for the next.

1. **Provision a healthy canonical store.** Confirm that `~/.cross-memory/` exists and contains at least one project-scope memory (type `project`, scope `project:<slug>`). If the store is absent, run `/cross-memory init` first.

2. **Invoke the post-deploy check.** Run:

   ```
   /cross-memory doctor --post-deploy --harness claude-code
   ```

3. **Assert mirror checks pass.** Verify that `mirror-canonical-source-exists` and `mirror-sidecar-frontmatter-agreement` both return `pass`. A failure here indicates the sidecar manifest or the canonical source path is inconsistent — resolve the inconsistency before proceeding.

4. **Assert sentinel check passes.** Verify that `sentinel-region-content-parses` returns `pass`. A `fail` here means the bytes between the sentinel markers are malformed; re-run `/cross-memory init` to rewrite the sentinel block, then re-invoke the post-deploy check.

5. **Assert the SC behavioral sub-findings.** Verify that the following six `sc-behavioral-walk` sub-findings all return `pass` under `--harness claude-code`: SC-1, SC-3, SC-4, SC-5, SC-15, SC-16. SC-2 returns `not-applicable` in a single-harness invocation — see the single-harness note above — and is excluded from aggregation here.

6. **Assert overall verdict.** Confirm the overall verdict is `pass`. Any `warn` or `fail` finding must be resolved before the deployment is considered healthy.

#### Post-deploy walk (Cursor)

The following six-step procedure constitutes the operator-facing validation walk for a Cursor post-deploy invocation. Execute the steps in order; each step is a prerequisite for the next. Step 0 of the cross-harness gate (a save performed in Claude Code) must have completed before this walk begins.

1. **Confirm the canonical store is healthy.** The Step 0 Claude Code save should have landed a canonical file at `~/.cross-memory/`. Confirm the file exists and is accessible from the Cursor harness session before continuing.

2. **Invoke the post-deploy check.** Run:

   ```
   /cross-memory doctor --post-deploy --harness cursor
   ```

3. **Assert mirror and adapter checks pass.** Verify that `mirror-canonical-source-exists`, `mirror-detect-collisions`, and `adapter-detection` all return `pass`. A failure in `mirror-canonical-source-exists` or `mirror-detect-collisions` indicates a sidecar or canonical source inconsistency; a failure in `adapter-detection` indicates the harness selection chain did not resolve to `cursor` — resolve each before proceeding.

4. **Assert sentinel checks return `not-applicable`.** Verify that `sentinel-marker-count` and `sentinel-region-content-parses` both return `not-applicable`. Cursor's `update_sentinel_block` is a documented v1 no-op (`adapter-cursor.md § 6`), so no sentinel markers are written and no region exists to inspect. A `fail` here would indicate an unexpected marker in the Cursor-side `MEMORY.md` — see `## Check-name vocabulary` Group C for the `not-applicable` criteria.

5. **Assert the cross-harness round-trip passes.** Verify that `cross-harness-roundtrip` returns `pass` with the canonical path of the test memory landed by the Step 0 Claude Code save. This constitutes a behavioral walk of SC-2: a memory saved in harness A (Claude Code) is locatable via `recall` in harness B (Cursor).

6. **Assert the SC behavioral sub-findings.** Verify that the `sc-behavioral-walk` findings are: SC-2, SC-3, SC-4, SC-5 return `pass`; SC-1, SC-15, and SC-16 return `not-applicable` with `reason: "cursor injection surface (update_sentinel_block) is a documented v1 no-op"`. The overall `sc-behavioral-walk` verdict is `pass` because `not-applicable` is treated as `pass` under the `not-applicable = pass` aggregation rule (see `### Output formats and exit codes`). Confirm the overall doctor verdict is `pass`.

**Cursor slash-command parity note.** Cursor slash-command parity (whether `/cross-memory <subcommand>` parses correctly in Cursor's composer) is verified at deploy time as part of the cross-harness gate. If `/cross-memory <subcommand>` does not parse in Cursor's composer, a `tooling/transform-cursor-cross-memory.{ps1,sh}` transform is required; that transform is a deferred contingent path and is not part of the v1.1 deliverable.

### Targeted check mode (`--check <name>`)

When one or more `--check <name>` flags are present (and neither `--pre-deploy` nor `--post-deploy` is set), doctor runs exactly the named checks — no implicit additions. Multiple checks can be passed in a single invocation:

```
/cross-memory doctor --check canonical-frontmatter-parse --check sentinel-marker-count
```

`--check <name>` accepts either an **individual check identifier** from `## Check-name vocabulary` (e.g., `--check sentinel-marker-count`) or a **Group identifier** (e.g., `--check sentinel-markers`), which resolves to the full set of checks in that group. The five valid Group identifiers are:

- `canonical-integrity` — all five Group A checks
- `mirror-consistency` — all three Group B checks
- `sentinel-markers` — all three Group C checks
- `redaction-surface` — all three Group D checks
- `deploy-target-prep` — both Group E pre-deploy checks

The cross-harness-validation Group is post-deploy-only and its checks (`cross-harness-roundtrip`, `adapter-detection`, `sc-behavioral-walk`) do not run under targeted mode; passing `cross-harness-validation` as a `--check` argument is rejected at parse time.

An unrecognized `--check` argument — one that matches neither an individual check identifier nor a valid Group identifier — is rejected at parse time:

```
error: unknown check name 'foo'. See ## Check-name vocabulary for valid names.
```

When a named check's per-harness applicability determines it does not apply to the active harness (for example, `sentinel-region-content-parses` under `--harness cursor` at v1), the check returns `not-applicable` rather than `pass` or `fail`. Output formats and exit-code semantics for `not-applicable` are documented in `### Output formats and exit codes` below.

### Group A — canonical-integrity (5 checks)

These checks verify the internal consistency of the canonical store at `~/.cross-memory/`. All five are read-only and apply under every harness.

| Check name | Description | Finding shape | PASS | WARN | FAIL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `canonical-frontmatter-parse` | Parses every `.md` file in the canonical store against the schema validator. Catches malformed YAML, missing required fields, and invalid enum values before they can corrupt downstream reads. | `{ file: string, error: string }` | All files parse without error | — | Any file's frontmatter is malformed or is missing a required field. Finding includes the offending file path and the parser error message. |
| `canonical-slug-derivation` | For every project-scope file, derives the expected slug from the file's parent directory name and compares it to the `name` field in frontmatter. A mismatch means the file was likely moved or renamed without updating its frontmatter. | `{ file: string, expected_slug: string, actual_slug: string }` | All derivations match | — | Any derivation does not match. Finding includes the file path, the slug derived from the directory name (expected), and the slug recorded in frontmatter (actual). |
| `canonical-memory-md-consistency` | For each scope directory (`user-global/`, `project/<slug>/`, `harness/<name>/`), compares the file list in `MEMORY.md` against the `.md` files on disk. Detects orphans (entry in `MEMORY.md` with no corresponding file on disk) and missing entries (file on disk absent from `MEMORY.md`). | `{ scope: string, orphans: string[], missing: string[] }` | No orphans and no missing entries in any scope | — | Any orphan or missing entry exists. Finding lists the scope path, orphan entries, and missing entries. |
| `canonical-no-duplicate-slugs` | Within each scope directory, asserts that no two files share the same slug (derived from the `name` frontmatter field). Duplicate slugs create ambiguous recall results and can cause one file to shadow another. | `{ scope: string, slug: string, files: string[] }` | All slugs are unique within each scope | — | Any two files in the same scope share a slug. Finding lists the duplicate slug and the full paths of both files. |
| `canonical-archive-not-indexed` | Asserts that `~/.cross-memory/archive/MEMORY.md` does not exist. Per the invariant in `indexing.md` § 3, the archive directory is intentionally not indexed — archived memories are historical state accessed by direct directory traversal, not by an index. A `MEMORY.md` in the archive would be written only by an out-of-spec tool and must be flagged. | `{ archive_path: string }` | `~/.cross-memory/archive/MEMORY.md` is absent | — | `~/.cross-memory/archive/MEMORY.md` exists. Finding includes the archive path that was found. |

### Group B — mirror-consistency (3 checks)

These checks verify the consistency of adapter-managed mirror copies against the canonical store. All three are read-only. Group B reuses each adapter's existing read-only `detect_collisions` contract — no new adapter operations are introduced by doctor at v1.1.

| Check name | Description | Finding shape | PASS | WARN | FAIL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `mirror-sidecar-frontmatter-agreement` | For every mirror file recorded in the adapter sidecar, verifies that the mirror file's `mirrored_from` frontmatter field matches the canonical source path recorded in the sidecar entry. A mismatch indicates the mirror was written with a stale or incorrect source reference. | `{ mirror_path: string, sidecar_canonical: string, frontmatter_mirrored_from: string }` | Every mirror file's `mirrored_from` field agrees with the sidecar's recorded canonical source path | — | Any mirror file's `mirrored_from` field is absent or does not match the sidecar entry. Finding lists the mirror path, the canonical source from the sidecar, and the value found in frontmatter. |
| `mirror-canonical-source-exists` | For every sidecar entry, verifies that the recorded `canonical_source` path exists on disk. A missing source means the canonical file was deleted or moved outside the canonical store without updating the sidecar. | `{ sidecar_entry: string, canonical_source: string }` | Every sidecar entry's canonical source file exists on disk | — | Any canonical source path referenced in the sidecar is absent from disk. Finding lists the broken sidecar entry and the canonical path that was not found. |
| `mirror-detect-collisions` | Calls each active adapter's read-only `detect_collisions` contract and reports the three-state classification for every mirror file: `native` (file exists only as a mirror, no user edits), `stale-mirror` (mirror is older than the canonical source), or `user-edited` (mirror has been modified independently since it was written). Doctor reports the classification and **takes no action** — no overwriting, no quarantining, no merging. | `{ mirror_path: string, classification: "native" \| "stale-mirror" \| "user-edited" }` | No collisions found, or all collisions are classified as `native` | One or more collisions classified as `stale-mirror` or `user-edited`. These states are informational — doctor does not take corrective action. Finding lists each collision with its classification. | — |

### Group C — sentinel-markers (3 checks)

These checks verify the integrity of the sentinel-bounded `[CROSS-MEMORY]` injection region in the harness-native `MEMORY.md`. Per-harness applicability is load-bearing for this group.

**Harness applicability summary.** The Claude Code adapter's `update_sentinel_block` writes and maintains the sentinel region. The Cursor adapter's `update_sentinel_block` is a documented no-op at v1 (`adapter-cursor.md § 6`). The generic adapter's `update_sentinel_block` is equally a no-op (`adapter-generic.md § 6`). Therefore:

- Under `--harness claude-code` — all three checks run normally.
- Under `--harness cursor` at v1 — all three checks return `not-applicable` because no sentinel region exists to inspect.
- Under `--harness generic` at v1 — all three checks return `not-applicable` for the same reason.

| Check name | Description | Finding shape | PASS | WARN | FAIL | `not-applicable` (cursor / generic at v1) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `sentinel-marker-count` | Reads the active project's harness-native `MEMORY.md` and counts begin-marker and end-marker occurrences. Exactly one of each is required; zero or more than one indicates a structural corruption that will cause the injection block to be misread or skipped. | `{ harness: string, file_path: string, begin_count: number, end_count: number }` — `file_path` is the harness-native `MEMORY.md` whose markers were inspected | Exactly one begin marker and exactly one end marker are present | — | Any count other than exactly one of each. Finding includes the harness name, the inspected file path, and the actual counts found. | `reason: "cursor adapter update_sentinel_block is a v1 no-op; sentinel markers are not written"`. Generic: same reason, citing `adapter-generic.md § 6`. |
| `sentinel-region-bytes-fingerprint` | At v1.1, operates as an intra-run check only. Computes a SHA-256 fingerprint of the bytes **outside** the sentinel region (i.e., the user-managed content above the begin marker and below the end marker) at run start, then again at run end, and compares the two. A mismatch indicates that the skill modified bytes it should not have touched — only the bytes between the markers are ever written by the skill. | `{ harness: string, start_fingerprint: string, end_fingerprint: string }` (fingerprints truncated to first 16 hex characters in human output) | Start and end fingerprints are identical | — | Fingerprints differ. Finding includes the harness name and both truncated fingerprints. | `reason: "cursor adapter update_sentinel_block is a v1 no-op; no sentinel region exists to fingerprint around"`. Generic: same reason. |
| `sentinel-region-content-parses` | Reads the bytes between the sentinel markers and asserts they parse as a valid `[CROSS-MEMORY]` injection block. An empty region (zero bytes) is also a valid state and returns PASS. A region whose content is malformed — for example, truncated mid-entry or containing bytes from a non-cross-memory write — returns FAIL. | `{ harness: string, parser_error: string \| null }` | Content between the markers parses as a valid injection block (or the region is empty) | — | Content does not parse. Finding includes the harness name and the parser error message. | `reason: "cursor adapter update_sentinel_block is a v1 no-op; no sentinel region to parse"`. Generic: same reason. |

#### Group C and init's step-4 self-check

The Group C checks double as init's step-4 self-check primitives. After init writes the sentinel block under `--harness claude-code`, it immediately runs `sentinel-marker-count` and `sentinel-region-content-parses` as read-only self-checks against the file it just wrote. If either check would report `fail`, init fails fast and emits a structured violation report rather than proceeding to the step 5 summary. Under `--harness cursor` or `--harness generic`, init's step 4 reports `sentinel=skipped` and these two self-checks return `not-applicable` rather than running — so init always succeeds on those harnesses regardless of Group C state. See `subcommand-init.md § Reuse of doctor's check primitives` for the full step-4 behavior table.

### Group D — redaction-surface (3 checks)

These checks verify that the redaction layer is healthy and that no sensitive content has slipped through into the canonical store. All three are read-only. They apply under every harness.

| Check name | Description | Finding shape | PASS | WARN | FAIL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `redaction-denylist-parses` | Verifies that `redaction.md` is present at the deployed path and that the denylist table parses as expected. This is a boolean structural check — it does not scan any memory content; it only confirms the denylist itself is intact and loadable before any scan-dependent check runs. Finding always includes the path checked; if parsing fails, the parser error is included. | `{ path: string, parser_error: string \| null }` | `redaction.md` is present and the denylist table parses without error | — | `redaction.md` is absent from the deployed path, or the denylist table is present but cannot be parsed. Finding includes the path checked and the parser error if any. |
| `redaction-sampling-scan` | Samples N memories per scope (default 10, capped at 30) and scans each memory body against the Pass-B regex set from `redaction.md`. Sampling is non-deterministic; the finding records the sample size and seed (or the full sample list) for reproducibility. Each suspicious match is emitted as a separate finding entry — the match is never reported verbatim; only a redacted excerpt is included. Doctor does not modify any memory regardless of findings. | `{ file: string, scope: string, regex_name: string, redacted_excerpt: string }` per match; `{ sample_size: number, seed: string \| null, sample_list: string[] }` for the run summary | No regex matches across all sampled memories | One or more matches found across the sample. Each match is an independent finding with the file path, scope name, regex name, and a redacted excerpt. This is informational — operators must inspect and resolve matches manually using `forget` or `save --no-redact` with the corrected body. | — |
| `redaction-overridden-flag-audit` | Surfaces every memory whose frontmatter contains `redaction_overridden_at`. Override timestamps indicate a deliberate operator decision to bypass the redaction gate; this check makes those decisions visible in the doctor report so they can be reviewed periodically. Doctor does not remove or modify any override. | `{ file: string, scope: string, override_timestamp: string, override_reason: string \| null }` per overridden memory | No memories with `redaction_overridden_at` set in frontmatter | One or more memories with `redaction_overridden_at` set. Each override is a separate finding with the file path, scope, override timestamp, and override reason if present in frontmatter. This is informational — operators may have legitimate reasons to override. | — |

### Group E pre-deploy — deploy-target-prep (2 checks)

These checks are intended to run before deploying a new version of the cross-memory skill. They verify that the deployment manifest and installed artifacts are consistent with the repo. Both are read-only.

| Check name | Description | Finding shape | PASS | WARN | FAIL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `deploy-manifest-coverage` | Globs the patterns defined in `tooling/deploy-manifest.json` and asserts that all eight cross-memory files are covered: six skill files (`SKILL.md`, `redaction.md`, `indexing.md`, `adapter-claude-code.md`, `adapter-cursor.md`, `adapter-generic.md`), the agent definition (`agents/cross-memory.md`), and the redaction reference. Also confirms that exclusion patterns in the manifest do not unintentionally drop any of the eight files. Finding lists which file(s) are missing from manifest coverage when the check fails. | `{ uncovered_files: string[] }` | All eight cross-memory files are covered by at least one manifest glob, and no exclusion pattern removes them. | — | One or more of the eight files is not covered by any manifest glob, or is covered but then removed by an exclusion pattern. Finding lists each uncovered or excluded-out file path. |
| `stale-shipped-artifacts` | Globs `~/.claude/skills/cross-memory/`, `~/.cursor/skills/cross-memory/`, and `~/.claude/agents/cross-memory.md` for files that have no source counterpart in the repo. This check assumes cross-harness directory reads are read-only and accessible from either harness session — it does not require switching harnesses to perform the glob. Doctor does not delete any stale artifact. Finding lists each stale path and the missing repo counterpart. | `{ stale_path: string, missing_repo_counterpart: string }` per stale file | No stale files found in any of the three target locations. | One or more stale files found (i.e., a file is present in a deploy target but has no matching source file in the repo). Each stale file is a separate finding. This is informational — doctor does not delete. | — |

### Group E post-deploy — cross-harness-validation (3 checks)

These checks validate that the deployed skill behaves correctly across harness boundaries. They are intended to run after a successful deploy and are the primary integration gate for the v1.1 acceptance criteria.

| Check name | Description | Finding shape | PASS | WARN | FAIL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `cross-harness-roundtrip` | Run from harness B after a save has been performed in harness A. Walks SC-2 behaviorally: issues a `recall` from harness B and confirms the memory saved under harness A can be located via the canonical store. Single PASS/FAIL per run. Finding always includes: harness A name, harness B name, the save target path probed, and the recall result. | `{ harness_a: string, harness_b: string, save_target_path: string, recall_result: "found" \| "not-found" }` | Recall in harness B successfully locates the memory saved in harness A. | — | Recall in harness B fails to locate the memory. Finding includes the path that was probed. |
| `adapter-detection` | Re-runs the five-step adapter selection chain (see `adapter-selection.md`) and reports which step resolved the active harness. The five steps, in precedence order, are: `cli-flag` → `config-field` → `env-var` → `manifest-probe` → `generic-fallback`. The generic fallback is always defined, so the chain cannot silently fail to select a harness. Always emits a single finding with the winning step name and the resolved harness name. | `{ winning_step: "cli-flag" \| "config-field" \| "env-var" \| "manifest-probe" \| "generic-fallback", harness: string }` | A harness was resolved via any of the five steps. (The `generic-fallback` is a valid PASS — it means the harness was not explicitly configured, which is allowed.) | — | The adapter selection chain itself errors before any step can resolve (the generic fallback should prevent this; a FAIL here indicates a structural error in the chain logic). |
| `sc-behavioral-walk` | Walks the seven contract-only-verified scenarios (SC-1, SC-2, SC-3, SC-4, SC-5, SC-15, SC-16) as small in-place behavioral checks. Each scenario emits its own sub-finding with a verdict of `pass`, `fail`, `warn`, or `not-applicable`. The per-harness applicability matrix below determines whether each SC is walked, delegated to `cross-harness-roundtrip`, or returned as `not-applicable`. | Array of `{ sc: string, verdict: "pass" \| "fail" \| "warn" \| "not-applicable", reason: string \| null }` — one entry per SC | All walked SCs return `pass` (and any `not-applicable` SCs are treated as `pass` for aggregation). | Any walked SC returns `warn`. | Any walked SC returns `fail`. |

#### `sc-behavioral-walk` per-harness applicability matrix

| SC | What it verifies | Under `--harness claude-code` | Under `--harness cursor` |
| :--- | :--- | :--- | :--- |
| SC-1 | User-global preference surfaces in a different project | Walked behaviorally — confirms `[CROSS-MEMORY]` block in the harness-native file contains the user-global entry. | **`not-applicable`** — Cursor's `update_sentinel_block` is a documented v1 no-op (`adapter-cursor.md` § 6); the `[CROSS-MEMORY]` block this check inspects does not exist on the Cursor side. |
| SC-2 | Cross-harness round-trip | Delegates to `cross-harness-roundtrip` (post-deploy). Walked behaviorally. | Delegates to `cross-harness-roundtrip` (post-deploy). Walked behaviorally — exercises canonical-store + mirror surfaces that Cursor implements. |
| SC-3 | Auto-propose flow surfaces a memory candidate | Walked behaviorally. | Walked behaviorally. |
| SC-4 | Save / recall round-trip on canonical store | Walked behaviorally. | Walked behaviorally. |
| SC-5 | List / forget / search round-trip on canonical store | Walked behaviorally. | Walked behaviorally. |
| SC-15 | `<private>` redaction suppresses content from the always-on tier output | Walked behaviorally — confirms redacted content does not appear in the populated `[CROSS-MEMORY]` block. | **`not-applicable`** — the `[CROSS-MEMORY]` block is itself absent at v1; redaction itself remains contract-verified via Group D `redaction-sampling-scan`. |
| SC-16 | `[CROSS-MEMORY]` injection block format is correct | Walked behaviorally — `sentinel-region-content-parses` is the same primitive. | **`not-applicable`** — same reason as SC-1. |

Under `--harness claude-code` the walk emits **seven** sub-findings, one per SC, each with verdict `pass` / `fail` / `warn`. Under `--harness cursor` the walk emits **four behavioral** sub-findings (SC-2, SC-3, SC-4, SC-5) plus **three** `not-applicable` sub-findings (SC-1, SC-15, SC-16) each with `reason: "cursor injection surface (update_sentinel_block) is a documented v1 no-op"`. Doctor's overall-verdict aggregation treats `not-applicable` as `pass`, so an otherwise-healthy Cursor walk still returns overall `pass`. Cross-reference `### Output formats and exit codes` below for the formal aggregation rule.

### Adapter detection delegation

The `adapter-detection` check contains **no precedence logic of its own**. It delegates entirely to the five-step chain defined in `adapter-selection.md`. Any future change to harness selection logic — adding a step, reordering existing steps, changing timeout behavior — must be made in `adapter-selection.md` only. Init and doctor both call that chain; neither duplicates it.

The check emits a single finding with two fields: `harness` (the resolved harness name, one of `claude-code`, `cursor`, `generic`) and `harness_selection_step` (the enum value naming which step in the chain won). The allowed values for `harness_selection_step`, in precedence order, are: `cli-flag`, `config-field`, `env-var`, `manifest-probe`, `generic-fallback`.

This `harness` + `harness_selection_step` pair is surfaced in the following places. A user who sees an unexpected harness in any output can read `harness_selection_step` to understand which detection step was the furthest the chain reached, without needing to re-run with `--verbose`.

| Surface | Section | What it shows |
| :--- | :--- | :--- |
| Init human-readable summary | `subcommand-init.md § Step 5 — Summary output → Human-readable summary` | `harness=<name>` in the summary line |
| Init JSON output | `subcommand-init.md § Step 5 — Summary output → JSON output` | `harness` and `harness_selection_step` as top-level keys |
| Init verbose trace | `subcommand-init.md § Step 5 — Summary output → Verbose mode` | `harness=<name> (selected by <step>)` on the step-2 trace line |
| Doctor human report | `### Output formats and exit codes → Human-readable report` | `harness` listed in the per-check finding under `adapter-detection` |
| Doctor JSON output | `### Output formats and exit codes → JSON report` | `harness` and `harness_selection_step` as top-level keys |

### Output formats and exit codes

#### Human-readable report (default)

Doctor emits a structured markdown report to chat. The report contains one section per check group, a per-section verdict line, and a final overall verdict line.

Shape:

```
## cross-memory doctor

### canonical-integrity
<finding per check, one line each>
verdict: PASS

### sentinel-markers
<finding per check, one line each>
verdict: WARN  — <brief reason>

### sentinel-markers
verdict: NOT-APPLICABLE  — cursor injection surface is a documented v1 no-op

...

---
Overall: WARN
```

Per-section verdict is one of `PASS`, `WARN`, `FAIL`, `NOT-APPLICABLE` (upper-case in the human report). The overall verdict at the bottom is the worst per-section verdict under the aggregation rule below.

#### JSON report (`--json`)

When `--json` is passed, doctor prints a single JSON object instead of the markdown report. The schema version is `1`. Keys appear in this order:

```json
{
  "schema_version": 1,
  "timestamp_utc": "2026-05-09T14:23:01Z",
  "harness": "claude-code",
  "harness_selection_step": "cli-flag",
  "active_project_slug": "ai-skills-agents",
  "overall": "warn",
  "sections": [
    {
      "name": "canonical-integrity",
      "verdict": "pass",
      "findings": [
        { "check": "canonical-frontmatter-parse", "verdict": "pass" },
        { "check": "canonical-memory-md-consistency", "verdict": "pass" }
      ]
    },
    {
      "name": "sentinel-markers",
      "verdict": "warn",
      "findings": [
        { "check": "sentinel-marker-count", "verdict": "warn", "detail": "marker count=3, expected 2" }
      ]
    },
    {
      "name": "sentinel-markers",
      "verdict": "not-applicable",
      "reason": "cursor injection surface (update_sentinel_block) is a documented v1 no-op",
      "findings": [
        { "check": "sentinel-region-content-parses", "verdict": "not-applicable" }
      ]
    }
  ],
  "reflect_staleness_hint": {
    "fired": true,
    "days_since_last_reflect": 45,
    "threshold_days": 30,
    "message": "Tip: it is been 45 days since reflect ran — run /cross-memory reflect to surface candidates."
  }
}
```

When the hint suppresses (`fired` is `false`), the object is still present at the top level but `message` is **omitted entirely** — it is absent from the object, not set to `null`. Example when suppressed:

```json
{
  "reflect_staleness_hint": {
    "fired": false,
    "days_since_last_reflect": 12,
    "threshold_days": 30
  }
}
```

**Top-level keys (in order):**

| Key | Type | Description |
| :--- | :--- | :--- |
| `schema_version` | integer | Always `1` at v1.1. |
| `timestamp_utc` | string | ISO-8601 UTC timestamp of the run. |
| `harness` | string | Active harness name (`claude-code`, `cursor`, `generic`). |
| `harness_selection_step` | string | Which step in the five-step precedence chain selected the harness (same enum as init — see `subcommand-init.md § Step 5 — Summary output`). |
| `active_project_slug` | string | Slug of the active project, or `null` if no project context. |
| `overall` | string | Overall verdict (one of the five values below). |
| `sections` | array | One object per check group. |
| `reflect_staleness_hint` | object | Staleness nudge state. Always present; `message` is omitted when `fired` is `false`. See `### Reflect staleness hint` below. |

**`sections[]` object keys:**

| Key | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `name` | string | always | Check group identifier, e.g., `"canonical-integrity"`. |
| `verdict` | string | always | One of the five verdict values below. |
| `findings` | array | always | One finding object per check in the group. Finding shape is defined by each individual check. |
| `reason` | string | when `verdict == "not-applicable"` | Human-readable explanation of why this group does not apply to the active harness. Required — omitting it when verdict is `not-applicable` is a schema error. |

**Cross-tool key note.** The fields `harness`, `harness_selection_step`, and `timestamp_utc` use the same field names and value shapes as the init JSON schema (documented in `subcommand-init.md § Step 5 — Summary output`). Additions or renames to these three keys must be applied consistently to both subcommands.

#### Exit codes

Exit codes apply to the **overall** verdict and are only meaningful when `--json` is set. Under the human-readable report, the skill exits 0 regardless of verdict (chat output is the channel; non-zero exits would break the conversational surface).

| Overall verdict | Exit code | Meaning |
| :--- | :--- | :--- |
| `pass` | 0 | All checks passed (or were not-applicable). |
| `not-applicable` | 0 | Every section was not-applicable on this harness. Treated as success — this is correct behavior on this surface. |
| `warn` | 1 | At least one check surfaced a warning; nothing is broken but review is recommended. |
| `fail` | 2 | At least one check found a definite problem requiring action. |
| `error` | 3 | At least one check could not complete (e.g., unreadable file, unexpected exception). |

#### Verdict aggregation

**The `verdict` field is a string enum with five values:**

| Value | Meaning |
| :--- | :--- |
| `pass` | Check completed; no issues found. |
| `warn` | Check completed; non-critical issue found — review recommended. |
| `fail` | Check completed; definite problem found — action required. |
| `error` | Check could not complete due to an unexpected condition (e.g., unreadable file, parse exception). |
| `not-applicable` | Check does not apply to the active harness on this surface. This is not a problem. |

**Per-section verdict** is the worst of the per-check verdicts within that section, under the ordering:

```
not-applicable = pass  <  warn  <  fail  <  error
```

Concretely:

| Checks in section | Section verdict |
| :--- | :--- |
| `pass + not-applicable + pass` | `pass` |
| `not-applicable + warn` | `warn` |
| `not-applicable + fail` | `fail` |
| `not-applicable` (all checks not-applicable) | `not-applicable` |

A section composed entirely of inapplicable checks reports `not-applicable`. For **overall-verdict aggregation**, that section is treated as `pass` (i.e., `not-applicable` at the section level does not elevate the overall verdict above any worse section).

**Overall verdict** is the worst per-section verdict under the same ordering. A run where every section is either `pass` or `not-applicable` returns overall `pass` (exit code 0).

#### Read-only by default

Doctor is **read-only at v1.1**. There is no `--repair`, no `--fix`, and no auto-correction. The diagnostic-then-fix workflow is explicit: doctor reports findings; the user dispatches `audit`, `forget`, or `save` to address specific findings. This is a lane-policy constraint, not a missing feature — auto-repair would conflate diagnosis and mutation in a single command.

### Lane boundary

Doctor is **skill-only**. The cross-memory agent is not invoked by doctor, and doctor does not dispatch to any agent. Doctor runs entirely in the skill body and is **read-only** at v1.1 — there is no `--repair`, no `--fix`, and no auto-correction. The diagnostic-then-fix workflow stays explicit: doctor reports findings; the user dispatches `audit`, `forget`, or `save` to address specific findings.

### Cross-references

- **Check-name vocabulary** (stable identifier set): `## Check-name vocabulary` above.
- **Shared flag semantics** (`--harness`, `--scope`, `--json`, `--verbose`): `## Shared flag parsing` above.
- **Adapter selection chain** (consumed by `adapter-detection` check): `adapter-selection.md`.
- **Init's reuse of check primitives**: `subcommand-init.md § Reuse of doctor's check primitives`.
- **SC behavioral walk per-harness matrix**: `## Check-name vocabulary` Group E (`sc-behavioral-walk` row).

### Reflect staleness hint

After the overall-verdict line is emitted (in all four doctor modes: default, pre-deploy, post-deploy, and targeted), doctor reads the per-project state file and conditionally emits a staleness hint. The hint is a UX nudge — it is **not a doctor check**. It has no verdict (`pass`/`fail`/`warn`), is not part of any check group, and does not influence the overall doctor verdict. It closes AC8: the staleness hint fires when the threshold is crossed and suppresses when `last_reflect_at` is unset.

**Read target:** `~/.cross-memory/projects/<slug>/state.toml`.

**Staleness computation:**

1. Attempt to read and parse `state.toml`.
2. If `state.toml` is absent, unparseable, or `reflect.last_reflect_at` is unset, suppress the hint silently. No output is emitted and no structured finding is recorded.
3. If `reflect.last_reflect_at` is set, compute `delta_days = (now - last_reflect_at)` rounded to integer days.
4. Compare `delta_days` against `reflect_staleness_threshold_days` from the config (default `30`).
5. If `delta_days > reflect_staleness_threshold_days`, emit the following hint to chat:

```
Tip: it is been N days since reflect ran — run /cross-memory reflect to surface candidates.
```

Where `N` is the computed `delta_days` integer.

**Suppress rule.** The hint is suppressed (no output, no side effects) when any of the following hold: `state.toml` is absent; `state.toml` cannot be parsed; `reflect.last_reflect_at` is not present in the parsed result; or `delta_days <= reflect_staleness_threshold_days`.

**Position rule.** The hint emits **after** the overall-verdict line and **before** any `--json` payload is printed. The position is consistent across all four doctor modes (default / pre-deploy / post-deploy / targeted). In human-readable mode, the hint appears on its own line below the `Overall:` verdict. In `--json` mode, the hint is encoded in the `reflect_staleness_hint` top-level field (see `#### JSON report` above).

**Never auto-invokes reflect.** This hint is suggestive only — doctor does not dispatch the cross-memory agent or auto-run `/cross-memory reflect` based on the staleness check. The user must explicitly invoke `/cross-memory reflect` to proceed.
