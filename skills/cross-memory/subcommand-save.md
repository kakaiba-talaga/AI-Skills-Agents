<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Subcommand: save

Persist a new memory entry to the canonical store. Runs four sequential gates: parse → redact → confirm → write.

### Command syntax

```
/cross-memory save \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--type <feedback|project|preference|fact|rule>] \
  [--category <project-config|architecture|error-solution|preference|learned-pattern|conversation|other>] \
  [--tags <tag1,tag2,...>] \
  [--name <slug>] \
  [--no-redact] \
  -- <body>
```

### Default values

| Flag | Default | Notes |
| :--- | :--- | :--- |
| `--scope` | `user-global` | Broadest, safest default. Project memories require explicit `--scope project:<slug>`. |
| `--type` | `feedback` | Most common origin type. |
| `--category` | *(absent)* | Not defaulted to `other` — absence is the canonical "uncategorized" signal per Schema validator default rules. |
| `--tags` | `[]` | Empty array. |
| `--name` | *(derived)* | First 40 characters of the body, slugified: lowercase, non-alphanumeric characters replaced with `-`. |
| `--no-redact` | `false` | Redaction is on by default. |

### Gate 1 — Parse

Parse all command-line arguments. Validate each flag value against its enum (type enum and category enum are defined in `schema-validator.md`). On any invalid value, emit the exact validation error string documented in that section and abort — no file is created.

Compose the in-memory candidate object: a `frontmatter` dict containing all required fields and any provided optional fields, and a `body` string containing the literal `-- <body>` text.

### Gate 2 — Redact

Pass the `body` through the redaction pipeline per `~/.claude/skills/cross-memory/redaction.md`:

1. **Pass A** — `<private>` strip: replace every `<private>...</private>` span with `[REDACTED:private]`. This pass always runs regardless of `--no-redact`.
2. **Pass B** — regex denylist: scan the body for the eight pattern categories (api-key, password, bearer-token, jwt, aws-secret, env-block, private-key-header, user-tagged-secret). Replace each match with `[REDACTED:<category>]`.

**When `--no-redact` is NOT set** (default): apply the Pass B replacements. If any Pass A or Pass B pattern fired, set `redacted: true` in the frontmatter.

**When `--no-redact` IS set and Pass B matched ≥1 pattern**: enter the typed-phrase confirmation flow defined in `redaction.md` `### --no-redact behavior`:

```
warning: --no-redact is set; Pass B would have redacted the following patterns:
  - <category>: <preview of matched text>
  - ...
Type 'save unredacted' to persist the unredacted memory, or anything else to cancel:
```

- **On exact phrase `save unredacted`** (case-sensitive): preserve the unredacted body; stamp `redaction_overridden_at: <ISO-8601 UTC timestamp>` in the frontmatter; persist `redacted: false` (unless Pass A fired, in which case `redacted: true` regardless).
- **On anything else**: abort the save with no disk write.

**When `--no-redact` IS set and Pass B matched nothing**: accept silently; no typed confirmation required.

### Gate 3 — Confirm

Display the post-redaction candidate — rendered frontmatter followed by body — and request final confirmation.

**When redaction fired** (`redacted: true` — any Pass A or Pass B pattern matched and `--no-redact` is false): render the distinct WARN UX box:

```
┌─ Sensitive pattern detected ─────────────────────┐
│ The following categories were redacted:         │
│   - <category1>                                  │
│   - <category2>                                  │
│                                                  │
│ Body preview (post-redaction):                   │
│   <first 3 lines of redacted body>               │
│                                                  │
│ Save anyway? [y/N]                               │
└──────────────────────────────────────────────────┘
```

The default answer is **N** (no silent commits — even on explicit save, when redaction fired the user must explicitly type `y` or `Y` (case-insensitive) to confirm). Any response other than `y` or `Y` aborts with no disk write.

**When no redaction fired** (clean explicit save — `redacted: false` or the field is absent): display the standard post-redaction candidate (rendered frontmatter followed by body) and prompt for confirmation. The default answer is **Y** (no surprise; the user explicitly invoked save and no patterns were detected). Any response other than `y` or `Y` (case-insensitive) aborts with no disk write.

### Gate 4 — Write

Resolve the canonical path from `--scope`:

| Scope | Canonical path |
| :--- | :--- |
| `user-global` | `~/.cross-memory/user-global/<filename>` |
| `project:<slug>` | `~/.cross-memory/projects/<slug>/<filename>` |
| `harness:<name>` | `~/.cross-memory/harnesses/<name>/<filename>` |

Where `<filename>` is `<type>_<name>.md`. The `<name>` portion in canonical and mirror filenames is the slugified version of the user-supplied `--name` argument, with the same character-replacement rule used elsewhere for slugs.

For `project:<slug>` scope: if the per-project directory and its `MEMORY.md` are absent, lazy-provision them now (see `## Config` → Lazy-provisioning sequence above).

Stamp frontmatter fields:
- `created_at: <ISO-8601 UTC now>`
- `updated_at: <ISO-8601 UTC now>` (equal to `created_at` at create time)
- `originSessionId: <active harness session ID>` (if available from the active harness)

Write the file to the resolved canonical path. Update the scope's `MEMORY.md` index per the line format and re-sort rules in `~/.claude/skills/cross-memory/indexing.md`:

```
- [<name>](<filename>.md) — <description>
```

Echo the canonical path to the user.

## Atomicity contract

All writes to the canonical store at `~/.cross-memory/**` follow a **write-to-temp-then-rename** pattern. This contract applies to every file written during Gate 4 and the Supersede branch: canonical memory files, archive copies, and the scope's `MEMORY.md` index file.

### Write procedure

1. **Write to a sibling temp file.** Before touching the canonical path, write the full intended content to a sibling temp file in the same directory, e.g. `<canonical-name>.tmp.<pid>` or `<canonical-name>.tmp` with a unique suffix that prevents collisions with concurrent writers.
2. **Flush (`fsync` or platform-equivalent).** Ensure the OS write buffers are committed to storage before proceeding. On POSIX, call `fsync(fd)` and close the file descriptor. On Windows, call `FlushFileBuffers`.
3. **Atomic rename to the canonical name.** Replace the canonical path in a single atomic filesystem operation.
   - **POSIX:** `rename(2)` is atomic for files within the same directory — a reader opening the canonical path sees either the old bytes or the new bytes, never a torn intermediate.
   - **Windows:** `MoveFileEx(src, dst, MOVEFILE_REPLACE_EXISTING)` provides atomic replace semantics for same-volume moves.
4. **Clean up** the temp file on failure before the rename. If a prior crash left a stale temp file, overwrite it rather than erroring.

### Readers-side guarantee

Readers always see either the **pre-save state** or the **post-save state** of any canonical-store file — never a torn intermediate. A reader that opens the canonical path while a write is in flight receives the previous complete content; the new content becomes visible only after the rename commits.

This guarantee makes the partial-write race impossible by construction. If the brief injector reads `~/.cross-memory/**` at the same moment a save is in progress, it sees a consistent snapshot, not partially written bytes.

### Scope of this contract

The contract applies to every write site that touches `~/.cross-memory/**` canonical paths:

- **Gate 4 — canonical memory file write** (new memory: `~/.cross-memory/<scope>/<type>_<name>.md`)
- **Gate 4 — MEMORY.md index update** (`~/.cross-memory/<scope>/MEMORY.md`)
- **Supersede branch Step 4 — archive write** (`~/.cross-memory/archive/<stem>-<timestamp>.md`)
- **Supersede branch Step 5 — new canonical write** (same path as Gate 4)
- **Supersede branch Step 6 — MEMORY.md update** (same path as Gate 4)

The `forget` subcommand's archive move and `MEMORY.md` update follow the same pattern (see `subcommand-forget.md`). The `reflect` subcommand's state and ledger writes follow the same pattern (see `subcommand-reflect.md`).

---

### Supersede branch

Triggered when Gate 4 detects a filename collision: the resolved canonical path `<type>_<name>.md` already exists in the target scope directory. If no collision is found, Gate 4 proceeds with the standard write path. If a collision is found, execution enters this branch instead.

#### Step 1 — Collision detection

Before opening the canonical file path for writing, check whether a file with the filename `<type>_<name>.md` already exists in the resolved scope directory. If yes → supersede branch. If no → standard write (no change to Gate 4 behaviour).

#### Step 2 — Diff rendering

Read the body of the existing canonical file. Apply the full redaction pipeline (Pass A + Pass B, per `~/.claude/skills/cross-memory/redaction.md`) to **both** the existing body and the new candidate body. Re-redacting the existing body accounts for any pattern additions to the denylist since it was originally saved.

Render a unified diff (`diff -u` style) between the two redacted bodies, existing on top, new on bottom. Display the diff to the user in a box alongside the existing file's `created_at` and `updated_at` values:

```text
┌─────────────────────────────────────────────────────────────┐
│ This would replace an existing memory:                      │
│                                                             │
│ ~/.cross-memory/<scope-dir>/<filename>.md                   │
│ Created: <created_at>  Updated: <updated_at>                │
│                                                             │
│ Diff (existing → proposed):                                 │
│ ─────                                                       │
│ - <removed lines from existing redacted body>               │
│ + <added lines from new redacted body>                      │
│ ─────                                                       │
│                                                             │
│ Supersede existing memory? [y/N]                            │
└─────────────────────────────────────────────────────────────┘
```

#### Step 3 — Confirmation UX

The default answer is **N** (the user is overwriting durable state; the destructive default must be conservative). Any response other than `y` or `Y` (case-insensitive) → abort, no disk write, emit "Supersede cancelled." On `y` or `Y` → continue to Step 4.

#### Step 4 — Archive predecessor

Move the existing canonical file to:

```
~/.cross-memory/archive/<original-stem>-<YYYYMMDDTHHMMSSZ>.md
```

Where `<original-stem>` is the original filename without the `.md` extension, and the timestamp is UTC at the moment of archive write (format: `YYYYMMDDTHHMMSSZ`, e.g., `20260508T143201Z`).

In the archive copy, set `superseded_by: <new-canonical-filename>` in the frontmatter. This field is **only** present on archived copies — it must never appear on canonical files (per Schema validator rules in `schema-validator.md`).

#### Step 5 — Write new canonical

Write the new memory to the original canonical path. Apply these frontmatter rules:

- **`created_at`**: preserve the predecessor's `created_at` value exactly. The superseding memory inherits the original creation timestamp — the memory is a continuation, not a fresh entry.
- **`updated_at`**: stamp to `<ISO-8601 UTC now>` (the supersede moment). This is the field that marks when the memory last changed.
- All other frontmatter fields come from the new memory's user-supplied arguments and redaction-derived flags (same as the standard write path).

#### Step 6 — Update MEMORY.md

Remove the predecessor's index line from the scope's `MEMORY.md`. Add the new memory's index line in its place. Re-sort all entries by `updated_at` descending per the rules in `~/.claude/skills/cross-memory/indexing.md`. The archive copy is **never** added to any `MEMORY.md`.

#### Step 7 — Mirror hook (supersede case)

After the canonical supersede completes successfully (Steps 4–6 done), the save flow determines the active adapter (via the precedence chain in `adapter-selection.md`) and dispatches three calls in order:

1. Call `active_adapter.mirror_remove(predecessor)` to remove the predecessor's harness-native mirror file and its sidecar manifest entry. The predecessor mirror removal runs first to prevent stale harness-native copies.
2. Call `active_adapter.mirror_write(successor)` to write the successor's mirror file and update the sidecar manifest. The direction is canonical → mirror; the canonical write has already committed before this call is made.
3. Invoke the always-on tier filter to produce the updated entry list, invoke the injection-block formatter on the filter's output to produce the updated content bytes, and call `active_adapter.update_sentinel_block(content)` to refresh the sentinel-bounded `MEMORY.md` region.

All three dispatches follow the same canonical-first failure-isolation rules as the standard-save mirror hook: a failure at any step is a structured warning, not an error, and the canonical supersede is not rolled back. The third dispatch (the `update_sentinel_block` splice) is mandatory and non-deferrable for the same reasons stated in `#### Sentinel block update (save)` below — a successful supersede must not skip it.

---

### Mirror hook — standard save

After Gate 4 completes successfully, the save flow determines the active adapter (via the precedence chain in `adapter-selection.md`) and dispatches:

```
active_adapter.mirror_write(memory)
```

Where `memory` is the metadata of the just-written canonical memory (its `type`, `name`, `scope`, and canonical file path). The direction is one-way: **canonical → mirror**. The mirror write always runs _after_ the canonical write — the canonical store is the source of truth and must be committed before any mirror is attempted.

#### Success path

The active adapter creates the harness-native mirror file, updates the sidecar manifest, and returns a structured result. The skill records the result and appends a brief write-confirmation to the user-facing output (e.g., "mirrored to `~/.claude/projects/<slug>/memory/<type>_<name>.md`").

#### Failure paths

**Structured violation from the adapter** — for example, the Claude Code adapter's pre-flight slug check fails (derived slug absent from `~/.claude/projects/`) or a sidecar/frontmatter disagreement is detected during a collision check. The canonical write is not rolled back. The skill emits a structured warning to the user:

```
mirror skipped: <short reason from adapter violation report>
The canonical memory was saved successfully. <Resolution hint from adapter.>
```

The save subcommand returns success.

**`generic-fallback` no-op** — the generic adapter returns its standard structured result (`harness: generic`, `mirror written: false`). The skill records this result and emits no warning — this is the expected silent path when no harness-native adapter is active (see `## Mirror failure handling` above).

**Unexpected exception** — if the adapter raises a truly unhandled error (not a structured violation), the skill catches it, emits a structured warning naming the exception, and returns success. The canonical write is preserved.

#### Sentinel block update (save)

After `active_adapter.mirror_write(memory)` succeeds, the save flow **must** update the harness-native `MEMORY.md` sentinel region. This refresh is a **required step of every successful save** — it is not optional and must not be deferred to `/cross-memory init` or any other command. Skipping or deferring it leaves the always-on injection block stale, meaning newly saved memories will not surface in session context until the next write event that does perform the refresh.

1. Invoke the always-on tier filter to produce the updated entry list (the newly saved memory may now qualify for the always-on tier).
2. Invoke the injection-block formatter on the filter's output to produce the updated content bytes.
3. Call `active_adapter.update_sentinel_block(content)` to splice those bytes into the harness-native `MEMORY.md`.

**Native-line preservation is already guaranteed.** The concern that calling `update_sentinel_block` might overwrite user-authored native index lines in `MEMORY.md` is addressed by two mechanisms in `adapter-claude-code.md § 6`: the SHA-256 byte-identical region check (which verifies that bytes outside the sentinel-bounded region are unchanged after every rewrite) and the no-marker-append case (which preserves all pre-existing content above the appended sentinel block when cross-memory is first installed). These guarantees are unconditional — concern about native lines is therefore not a valid reason to skip or defer the splice.

**`update_sentinel_block` is deterministic and idempotent.** Calling it twice with the same content produces the same bytes between the sentinel markers. It is invoked by `save`, `forget`, audit-refresh, and `init` alike — `init` is not the sole owner of this operation; it is one of several callers.

**Failure isolation — the only non-execution case.** If `update_sentinel_block` itself errors (for example, a corrupted sentinel state that causes a refuse-and-halt), the failure degrades to a structured warning and the canonical save is not rolled back. This error path is the only case in which the splice does not execute on a successful save. A successful save must not choose to defer the splice — the error path is not a discretionary exit.

#### Ordering guarantee

The `mirror_write` dispatch is deliberately placed _after_ Gate 4 completes. A failure at this step must never prevent or undo the canonical write. The three governing principles are stated in `## Mirror failure handling` above.

### Cross-references

- **Argument validation** (enum values, reject error strings): `schema-validator.md`.
- **Redaction pipeline** (Pass A, Pass B, `--no-redact` typed-phrase UX): `~/.claude/skills/cross-memory/redaction.md`.
- **MEMORY.md update format and re-sort rules**: `~/.claude/skills/cross-memory/indexing.md`.
- **Lazy provisioning of scope directories**: `## Config` → Lazy-provisioning sequence above.
- **Active adapter selection and precedence**: `adapter-selection.md`.
- **Mirror failure handling principles**: `## Mirror failure handling` above.
- **`mirror_write` operation contract** (target path, sidecar manifest, bootstrap, and violation report format): `adapter-claude-code.md § 3`, `adapter-cursor.md § 3`, `adapter-generic.md § 3`.

### Auto-propose flow

The auto-propose flow allows the skill to proactively suggest saving a memory when the user's message contains an explicit cue — without requiring the user to invoke `/cross-memory save` directly. This flow fires **only** on enumerated explicit cue patterns. It shares the same redaction pipeline as the explicit save flow.

#### Trigger surface

The assistant scans each user message for the following cue patterns (case-insensitive substring match):

```
remember that
save this preference
save this for later
don't forget
note that
from now on
make a note that
keep in mind that
```

Any user message containing one of these substrings triggers the auto-propose flow. No other detection strategy is used.

**No NLP heuristics.** The auto-propose flow fires **only** on the enumerated cue patterns above. The assistant's own judgment that a piece of content is "memorable" or "worth saving" does **NOT** trigger the flow. Heuristic LLM-based detection is explicitly excluded because it risks surprising the user with proposals on every interesting-sounding sentence and creates noise. Heuristic detection may be added in a later version once the explicit-trigger flow is validated.

#### Candidate drafting

When a cue fires, the assistant constructs a candidate memory from the user's message:

1. **Salient fact extraction** — strip the cue phrase itself and extract the substantive content the user intends to be remembered.
2. **`type` and `category` inference** — inferred from the cue pattern:
   - Cues indicating a preference (`"save this preference"`, `"from now on"`, `"keep in mind that"`) → `type: preference`, `category: preference`.
   - Cues indicating a rule or standing instruction (`"from now on"`) → `type: rule`.
   - Cues indicating a fact or note (`"remember that"`, `"note that"`, `"make a note that"`, `"don't forget"`, `"save this for later"`) → `type: fact`.
   - When a cue matches multiple categories, prefer the more specific inference.
3. **Name slug** — generated from the first 40 characters of the salient fact, slugified (lowercase; non-alphanumeric characters replaced with `-`).
4. **`scope` inference** — default `user-global`. If the cue or adjacent context references "this project", "for this repo", "in this codebase", or similar, infer `project:<slug>` using the active harness's project slug. If no slug is available, fall back to `user-global` and note the fallback to the user.

#### Redaction

Before presenting the candidate to the user, apply the full redaction pipeline per `~/.claude/skills/cross-memory/redaction.md` — identical to Gate 2 of the explicit save flow:

1. **Pass A** — `<private>` strip: replace every `<private>...</private>` span with `[REDACTED:private]`. Runs unconditionally.
2. **Pass B** — regex denylist: scan the body for the eight pattern categories. Replace each match with `[REDACTED:<category>]`.

If any Pass A or Pass B pattern fired, set `redacted: true` in the candidate frontmatter.

#### Confirmation UX

Display the post-redaction candidate to the user using the following box format:

```text
┌─────────────────────────────────────────────────────────────┐
│ I'd like to save this as a memory. Confirm?                 │
│                                                             │
│ Scope: <scope>    Type: <type>    Tags: <tags>              │
│ Name:  <name-slug>                                          │
│                                                             │
│ Body (redacted candidate):                                  │
│ ─────                                                       │
│ <redacted body>                                             │
│ ─────                                                       │
│                                                             │
│ Save this memory? [y/N]                                     │
└─────────────────────────────────────────────────────────────┘
```

The default answer is **N**. The auto-propose flow is a proactive suggestion, not the user's explicit command. Any response other than `y` or `Y` (case-insensitive) is treated as a decline.

#### On confirm (`y`)

Flow into **Gate 4 — Write** of the explicit save flow (see above). The path resolution, MEMORY.md update, and mirror hook proceed identically to a user-invoked `/cross-memory save`. No separate code path exists for the write step — auto-propose and explicit save converge at Gate 4.

#### On decline (anything not `y`)

Abort immediately. No file is written, no index entry is created, no mirror hook is called. No message is emitted other than silently dropping the proposal.

#### Cross-references

- **Redaction pipeline** (Pass A, Pass B): `~/.claude/skills/cross-memory/redaction.md`; mirrors Gate 2 of the explicit save flow.
- **Gate 4 — Write** (path resolution, MEMORY.md update, mirror hook): `### Gate 4 — Write` above.
