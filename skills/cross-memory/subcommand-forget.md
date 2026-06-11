<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Subcommand: forget

Archives the named memory and removes its index entry from the scope's `MEMORY.md`. The memory is not permanently deleted — it is moved to `~/.cross-memory/archive/` and remains recoverable. This is the only removal operation at v1; there is no "hard delete."

## Command syntax

```
/cross-memory forget <name> [--scope <s>]
```

`<name>` is a required positional argument — the memory's `name` slug (the value of the `name` frontmatter field, which is also the slug portion of the canonical filename). `--scope` defaults to `user-global`; accepted values are `user-global`, `project:<slug>`, and `harness:<name>`.

## Step 1 — Lookup

Resolve the canonical path:

```
~/.cross-memory/<scope-dir>/<type>_<name>.md
```

Where `<scope-dir>` follows the same scope-to-directory mapping used by `save` and `list`. Because the `<type>` prefix is part of the filename, the skill must enumerate all files in the scope directory whose stem ends with `_<name>` to find the match (there must be exactly one, because the name slug is unique within a scope per the Gate 4 collision rule).

If no matching file is found, output:

```
no memory named '<name>' in scope '<scope>'
```

and abort without further action.

## Step 2 — Confirmation

Display the memory's `name`, `type`, `category` (if set), and `scope`, then prompt:

```
Forget memory '<name>'? It will be archived but not auto-deleted. [y/N]
```

Default is `N`. Any input other than `y` or `Y` (case-insensitive) aborts without changes.

## Step 3 — Archive

On `y` or `Y` (case-insensitive), move the canonical file to:

```
~/.cross-memory/archive/<original-stem>-<YYYYMMDDTHHMMSSZ>.md
```

Where `<original-stem>` is the canonical filename without the `.md` extension, and the timestamp is UTC at the moment of the archive write (format: `YYYYMMDDTHHMMSSZ`, e.g., `20260508T143201Z`). This is the same archive mechanism used by the supersede branch of `save`.

**Do NOT set `superseded_by`** in the archive copy. The `superseded_by` field is exclusively for archived predecessors that were replaced by a new canonical memory. A forgotten memory has no successor — it is gone from the active store, not replaced. Adding `superseded_by` would misrepresent the reason for archival and would corrupt the supersede chain. The archive copy retains its original frontmatter without modification.

Echo the archive path to the user:

```
archived: ~/.cross-memory/archive/<original-stem>-<YYYYMMDDTHHMMSSZ>.md
```

## Step 4 — MEMORY.md update

Remove the memory's index line from the scope's `MEMORY.md`. The indexing module's line-removal rule applies: find the single line that references the canonical filename (by the `[name](path)` link pattern used when the memory was indexed) and delete it. Blank lines immediately surrounding the removed line are preserved; do not compact the file's vertical spacing. If no matching line is found (the memory was never indexed, or the index entry was already removed), skip this step silently — it is not an error.

For `project:<slug>` scope, the relevant `MEMORY.md` is the scope's own index file. The harness-native `MEMORY.md` (e.g., `~/.claude/projects/<slug>/memory/MEMORY.md`) is managed separately by the mirror-remove hook in Step 5.

## Step 5 — Mirror-remove hook

After the canonical archive in Step 3 succeeds, the forget flow determines the active adapter (via the precedence chain in `adapter-selection.md`) and dispatches:

```
active_adapter.mirror_remove(memory)
```

Where `memory` is the metadata of the archived memory (its `type`, `name`, `scope`, and the canonical path it occupied before archiving). The dispatch runs _after_ the canonical archive — the canonical operation is committed first and mirror removal follows unconditionally.

### Success path

The active adapter deletes the harness-native mirror file (e.g., `~/.claude/projects/<slug>/memory/<type>_<name>.md`) and removes its entry from the sidecar manifest. A brief removal confirmation is appended to the user-facing output (e.g., "mirror removed from `~/.claude/projects/<slug>/memory/<type>_<name>.md`").

### Failure paths

**Mirror file absent** — the adapter checks for the mirror file and finds it is not present (already removed by the user or a prior forget). This is not an error. The adapter records the absence and the skill continues without emitting a warning.

**Structured violation from the adapter** — for example, a sidecar/frontmatter disagreement is detected. The canonical archive is not rolled back. The skill emits a structured warning describing what failed and what the user can do to resolve it. The forget subcommand returns success.

**`generic-fallback` no-op** — the generic adapter returns its standard structured result (`harness: generic`, no mirror removed). The skill records this result and emits no warning — this is the expected silent path (see `## Mirror failure handling` above).

**Unexpected exception** — if the adapter raises a truly unhandled error, the skill catches it, emits a structured warning naming the exception, and returns success. The canonical archive is preserved.

### Sentinel block update (forget)

After `active_adapter.mirror_remove(memory)` succeeds, the forget flow updates the harness-native `MEMORY.md` sentinel region:

1. Invoke the always-on tier filter to produce the updated entry list (the forgotten memory is now archived, so the always-on tier may shrink).
2. Invoke the injection-block formatter on the filter's output to produce the updated content bytes.
3. Call `active_adapter.update_sentinel_block(content)` to overwrite the sentinel region with the smaller content.

This call follows the same canonical-first failure-isolation rules as `mirror_remove`: a failure here is a structured warning, not an error. The canonical archive still succeeds and `mirror_remove` is not rolled back.

## Atomicity

The archive move (Step 3) and the `MEMORY.md` update (Step 4) both follow the write-to-temp-then-rename pattern documented in `subcommand-save.md § Atomicity contract`. Readers always see either the pre-forget or the post-forget state of any affected file — never a torn intermediate.

## Cross-references

- **Atomicity contract** (write-to-temp-then-rename semantics, platform notes, readers-side guarantee): `subcommand-save.md § Atomicity contract`.
- **Archive filename pattern and timestamp format**: `subcommand-save.md § Supersede branch, Step 4`.
- **`superseded_by` field rules (only on supersede, never on forget)**: `schema-validator.md` and `subcommand-save.md § Supersede branch, Step 4`.
- **Scope-directory mapping**: `## Config` section above.
- **Indexing line-removal rule**: `subcommand-save.md § Gate 4 — Write`.
- **Active adapter selection and precedence**: `adapter-selection.md`.
- **Mirror failure handling principles**: `## Mirror failure handling` above.
- **`mirror_remove` operation contract** (removal steps, post-removal directory state, and absence handling): `adapter-claude-code.md § 4`, `adapter-cursor.md § 4`, `adapter-generic.md § 4`.
