<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Cross-Memory Adapter — Claude Code

This adapter mirrors canonical memories (which live under `~/.cross-memory/`) into Claude Code's native per-project memory layout at `~/.claude/projects/<slug>/memory/`, and manages the sentinel-bounded `[CROSS-MEMORY]` region inside `~/.claude/projects/<slug>/memory/MEMORY.md` for always-on context injection. Mirroring is strictly one-directional: **canonical → mirror**. The canonical store at `~/.cross-memory/` is always the source of truth; this adapter writes to Claude Code's native paths and never reads from them as authoritative state.

---

## Operation Interface Table

| Operation | One-line description | Target path(s) touched | Triggering event |
| :--- | :--- | :--- | :--- |
| `slug_derivation` | Derives the Claude Code project slug from the absolute project path | `~/.claude/projects/` (read-only probe) | Before any mirror write |
| `mirror_write` | Writes a mirror copy of a canonical memory into the harness-native memory directory | `~/.claude/projects/<slug>/memory/<type>_<name>.md`; `~/.claude/cross-memory-mirrors.json` | After every canonical `save` (new or supersede) |
| `mirror_remove` | Deletes a mirror copy and its sidecar manifest entry | `~/.claude/projects/<slug>/memory/<type>_<name>.md`; `~/.claude/cross-memory-mirrors.json` | After every `forget` |
| `detect_collisions` | Classifies every file in the mirror directory as native, stale-mirror, or user-edited | `~/.claude/projects/<slug>/memory/` (read); `~/.claude/cross-memory-mirrors.json` (read) | During `audit` |
| `update_sentinel_block` | Rewrites the bytes between the cross-memory sentinel markers in `MEMORY.md` | `~/.claude/projects/<slug>/memory/MEMORY.md` | After every canonical write, forget, or audit refresh that changes the always-on tier |

---

## 1. Detection

The adapter declares itself active when at least one of the following two signals is present. Both signals are probed on every adapter detection pass; the first positive result stops the probe.

### Signal 1 — Environment variable family

Claude Code sets one or more environment variables prefixed with `CLAUDE_CODE_`. The adapter checks for the presence of any variable whose name begins with `CLAUDE_CODE_` (for example, `CLAUDE_CODE_VERSION`, `CLAUDE_CODE_ENTRYPOINT`, or any future addition to the family). The check is a prefix test on the variable name, not an exact match — any `CLAUDE_CODE_*` variable is sufficient.

On platforms where env inspection is available, this check is the fastest signal and is performed first.

### Signal 2 — Marker-file probe

The adapter checks for the existence of the directory `~/.claude/`. If the directory is present, the adapter treats this as evidence that Claude Code has been installed and is the active harness. This probe succeeds even when the `CLAUDE_CODE_*` env vars are absent (e.g., in a shell session started outside the Claude Code launcher).

### Precedence within this adapter

Probe both signals. The first positive signal activates the adapter and sets the harness identity to `claude-code`. If both signals are absent, this adapter does not activate; control passes to the next adapter in the harness-detection precedence chain.

### Precedence across all adapters

The overall harness-detection order (from highest to lowest priority) is governed by the full precedence chain documented in `SKILL.md → ## Adapter selection`: CLI flag → `current_harness` config field → `CROSS_MEMORY_HARNESS` env var → adapter manifest probe (Claude Code first, then Cursor, then generic) → generic fallback. This adapter is probed only when the first three levels produce no result.

---

## 2. Slug Derivation

The slug is the directory name Claude Code uses to store per-project state under `~/.claude/projects/`. Cross-memory derives the slug from the absolute path of the active project using the following rule.

### Rule

Replace **each occurrence** of any character in the set `{ :, \, /, space, . }` with a single `-`. Letter case is preserved exactly. Leading dashes are **not** trimmed — if the input path begins with `/`, the derived slug begins with `-`.

The five characters in the replacement set, and only those five, are replaced. All other characters — letters, digits, hyphens already present in the path, and any Unicode — pass through unchanged. Consecutive separator characters each contribute exactly one `-`; there is no collapsing of adjacent replacements.

**Why this rule, stated plainly.** Claude Code derives slugs from project paths deterministically on its own side. Cross-memory must reproduce the same result to locate the correct `~/.claude/projects/<slug>/` directory. Any deviation — trimming a leading dash, collapsing consecutive replacements, changing case — would produce a slug that does not match Claude Code's directory listing, which breaks the mirror lookup entirely. Predictability beats prettiness: the rule is simple enough that it can be applied mentally, verified with a single `ls`, and tested against every observed slug on the live filesystem.

### Pre-flight confirmation

Before executing any mirror write, derive the slug from the active project path and run `ls ~/.claude/projects/` to confirm the slug appears verbatim in the listing.

If the derived slug is present in the listing, proceed.

If the derived slug is absent but a near-match is present (for example, the listing shows a slug that is missing a trailing component, or has different separator count), **do not guess**. The canonical write proceeds normally; the mirror write is skipped for the current session. Emit a structured violation report to the user:

```
cross-memory violation: slug mismatch
  derived slug : <derived-slug>
  nearest match: <nearest-match-in-listing> (if any)
  active path  : <absolute-project-path>

The mirror write has been skipped. The canonical memory was saved successfully.
Resolve the mismatch by confirming the project path is correct, then retry.
```

### Worked examples

Four examples demonstrate the rule and the pre-flight bail path.

**Example 1 — Windows drive-letter path (this project)**

```
Input  : D:\Repositories\Personal\Git\AI-Skills-Agents
Replace: D : → D-
         \ → -
         Repositories\ → Repositories-
         Personal\ → Personal-
         Git\ → Git-
         AI-Skills-Agents (hyphens already in path — unchanged)

Output : D--Repositories-Personal-Git-AI-Skills-Agents
```

This slug was verified live against `~/.claude/projects/` on 2026-05-08 — it appears verbatim in the listing.

**Example 2 — Unix absolute path**

```
Input  : /home/alice/code/my-app
Replace: / (leading) → -
         home/ → home-
         alice/ → alice-
         code/ → code-
         my-app (hyphen already present — unchanged)

Output : -home-alice-code-my-app
```

The leading slash becomes a leading dash. No trimming occurs — `-home-alice-code-my-app` is the correct slug.

**Example 3 — Unix path with a literal leading dash in a folder name**

```
Input  : /home/alice/-special-project
Replace: / (leading) → -
         home/ → home-
         alice/ → alice-
         - (literal, first char of folder name) → -
         special-project (hyphens already present — unchanged)

Output : -home-alice--special-project
```

> **Clarification of Example 3.** The two consecutive dashes between `alice` and `special` come from exactly two sources: the `/` before `-special-project` is in the replacement set and becomes one dash; the literal `-` that opens the folder name `special-project` is **not** in the replacement set (`{ :, \, /, space, . }`) and passes through unchanged. That gives `-` (slash replacement) + `-` (literal hyphen, preserved) = `--`. The hyphens inside `special-project` are likewise literal and pass through unchanged. Slug derivation is strictly character-by-character with no collapsing or expansion of adjacent dashes.

**Example 4 — Pre-flight bail path (derived slug does not match live listing)**

```
Input  : /home/alice/my-project.git
Replace: / (leading) → -
         home/ → home-
         alice/ → alice-
         my-project.git: . → -

Output (derived): -home-alice-my-project-git
```

The pre-flight confirmation step runs `ls ~/.claude/projects/`. The live listing shows `-home-alice-my-project` (no `-git` suffix — perhaps the harness derived the slug before the `.git` extension was present, or it uses a different derivation). The derived slug `-home-alice-my-project-git` is absent from the listing; a near-match `-home-alice-my-project` exists. The adapter bails:

```
cross-memory violation: slug mismatch
  derived slug : -home-alice-my-project-git
  nearest match: -home-alice-my-project (if any)
  active path  : /home/alice/my-project.git

The mirror write has been skipped. The canonical memory was saved successfully.
Resolve the mismatch by confirming the project path is correct, then retry.
```

The canonical write proceeds normally; only the mirror write is skipped for this session.

---

## 3. mirror_write

Called after every canonical `save` (new write or supersede). Copies the canonical memory file into the Claude Code harness-native memory directory as a mirror.

### Target path

```
~/.claude/projects/<slug>/memory/<type>_<name>.md
```

Where `<type>` and `<name>` are taken from the canonical memory's frontmatter fields of those names. The filename format is identical to the canonical filename — this makes the mirror directory a structural mirror of the canonical scope directory, differing only in location and the addition of the `mirrored_from` frontmatter field.

### Frontmatter on the mirror file

The mirror file carries all frontmatter fields from the canonical file, plus one additional field:

```yaml
mirrored_from: ~/.cross-memory/projects/<slug>/<type>_<name>.md
```

The `mirrored_from` value is the absolute canonical path. This field is set only on mirror copies and must never appear on canonical files (per the schema enforced by `SKILL.md → ## Schema validator → Optional fields`).

All other frontmatter fields — `name`, `description`, `type`, `scope`, `tags`, `created_at`, `updated_at`, and any optional fields set on the canonical — are copied verbatim. The mirror's body content is also copied verbatim.

### Sidecar manifest

`~/.claude/cross-memory-mirrors.json` is a flat JSON object where each key is the mirror's absolute path and each value is a record with three fields:

```json
{
  "~/.claude/projects/<slug>/memory/<type>_<name>.md": {
    "canonical_source": "~/.cross-memory/projects/<slug>/<type>_<name>.md",
    "harness_slug": "<slug>",
    "mirrored_at": "2026-05-08T14:32:01Z"
  }
}
```

The `mirrored_at` timestamp is UTC ISO-8601, stamped at the moment the mirror write completes. The sidecar is updated atomically alongside each `mirror_write` — read the current JSON, upsert the new entry, write the updated JSON back before the operation is considered complete.

### Read path

The per-memory mirror file at `~/.claude/projects/<slug>/memory/<type>_<name>.md` is in the directory Claude Code uses for its native per-project memory layout. Claude Code's native session-bootstrap injects the contents of `MEMORY.md` (the index file in that directory) verbatim into the session context. The per-memory mirror files are referenced from `MEMORY.md`'s index lines (the index contains `- [<name>](<filename>.md) — <description>` links to each memory file). The model can follow those links to access individual memories on demand.

The always-on tier `[CROSS-MEMORY]` block is a separate mechanism — it lives inside `MEMORY.md` itself (between the sentinel markers) and is therefore part of the verbatim auto-injection. The per-memory mirror files complete the read path indirectly (via MEMORY.md links); the always-on block reaches the model directly via MEMORY.md's verbatim injection.

### Bootstrap

Before writing the mirror file:

1. If `~/.claude/projects/<slug>/memory/` does not exist, create it (including any missing intermediate directories).
2. If `~/.claude/cross-memory-mirrors.json` does not exist, create it as an empty JSON object `{}`, then append the new entry.

Both bootstrap steps are idempotent — running them when the paths already exist is a no-op.

---

## 4. mirror_remove

Called after every `/cross-memory forget`. Removes the harness-native mirror and its sidecar manifest entry.

### Removal steps

1. Derive the mirror target path using the same `<type>_<name>` pattern as `mirror_write`.
2. If the mirror file exists at `~/.claude/projects/<slug>/memory/<type>_<name>.md`, delete it. If the file is absent (already removed by the user or a prior forget), this is not an error — record the absence and continue.
3. Remove the corresponding entry from `~/.claude/cross-memory-mirrors.json`. If no entry exists for the derived mirror path, this is also not an error — skip silently.

### Post-removal directory state

After deletion, if `~/.claude/projects/<slug>/memory/` is empty, **leave it as-is**. Do not auto-prune the empty directory. Claude Code manages its own directory lifecycle; the adapter does not remove directories it did not exclusively own.

---

## 5. detect_collisions

Called during `/cross-memory audit`. Inspects every file in `~/.claude/projects/<slug>/memory/` and classifies each file as one of three states. The check uses both the file's frontmatter and the sidecar manifest entry for defense in depth — neither signal alone is trusted.

### Three-state classification

**native**

The file has no `mirrored_from` frontmatter field AND has no entry in `~/.claude/cross-memory-mirrors.json`. The user authored this file natively in Claude Code. Cross-memory must not overwrite it. The audit reports it as native and skips it.

**stale-mirror**

The file has a `mirrored_from` frontmatter field pointing at a canonical path that no longer exists (the canonical file was deleted or moved since the mirror was written), OR the file has an entry in the sidecar manifest but the canonical source path in that entry no longer exists. Cross-memory should clean up: delete the mirror file and remove the sidecar entry. The audit prompts the user before executing the cleanup.

**user-edited**

The file has a `mirrored_from` frontmatter field that resolves to an existing canonical file, AND the sidecar manifest also has a matching entry — but the mirror's body content has diverged from the canonical's body content. The comparison is content-based: the full body text after the closing `---` of the frontmatter block is compared verbatim, ignoring only differences in the `mirrored_at` sidecar timestamp (which is stored in the sidecar, not in the file body). If the bodies differ, the file is user-edited. The audit warns the user and offers three choices: overwrite the mirror with the canonical content, skip (leave the mirror as-is), or back up the mirror body to a canonical memory (treating the user's edit as a new or superseding canonical entry).

### Defense-in-depth disagreement path

If the two signals disagree — the file has `mirrored_from` in its frontmatter but the sidecar has no matching entry, or the sidecar has an entry but the file has no `mirrored_from` field — this is a corrupted-state path, not a normal collision. The adapter refuses to classify the file and emits a structured violation report:

```
cross-memory violation: mirror-state disagreement
  file path      : ~/.claude/projects/<slug>/memory/<type>_<name>.md
  frontmatter    : mirrored_from <present | absent>
  sidecar entry  : <present | absent>
  action         : file skipped; no automatic repair attempted

Resolve by inspecting the file and sidecar manually. Either restore the missing
signal or delete the file and remove the sidecar entry to start fresh.
```

The file is not modified, not deleted, and not classified — it is skipped for the duration of the current audit pass.

---

## 6. update_sentinel_block(content)

Rewrites the cross-memory-managed region inside `~/.claude/projects/<slug>/memory/MEMORY.md`. This operation is called after every event that changes the always-on tier: a canonical `save`, a canonical `forget`, or an audit refresh. The adapter owns only the bytes between the sentinel markers; everything else in `MEMORY.md` is preserved byte-identically.

### Sentinel markers

The two markers are:

```
<!-- cross-memory:begin -->
<!-- cross-memory:end -->
```

These are HTML comments. They are inert in markdown renderers but visible in Claude Code's raw-text injection of `MEMORY.md`, which means the `[CROSS-MEMORY]` block they delimit surfaces in every session.

### Bootstrap

If `~/.claude/projects/<slug>/memory/MEMORY.md` does not exist, `update_sentinel_block(content)` performs two steps atomically:

1. **Create** the file with an empty sentinel block:

   ```
   <!-- cross-memory:begin -->

   <!-- cross-memory:end -->
   ```

   The file ends with a single trailing newline. There is one blank line between the markers. The adapter does NOT add any native Claude Code index lines during bootstrap.
2. **Immediately apply the rewrite-update** with the `content` argument, filling the between-marker region.

The end result is: `<!-- cross-memory:begin -->\n<content>\n<!-- cross-memory:end -->\n`. Steps 1 and 2 are a single atomic call — `update_sentinel_block(content)` on a non-existent file both creates the file and populates it in one operation.

### Rewrite-update (normal path)

When the file already exists and contains exactly one `<!-- cross-memory:begin -->` line and exactly one `<!-- cross-memory:end -->` line:

1. Read the entire file content.
2. Locate the byte offset of the begin-marker line and the end-marker line.
3. Replace the bytes between the end of the begin-marker line and the start of the end-marker line (exclusive of both marker lines) with the new `content`.
4. Write the result back to the file.
5. Verify correctness: a SHA-256 of the file content with the between-sentinel region masked to empty bytes must equal the SHA-256 computed from the pre-update file content with the same region masked. If this check fails, the write is considered corrupted — restore the original bytes and emit a violation report.

The SHA-256 verification enforces that the bytes outside the sentinel-bounded region are byte-identical before and after the update. This is the guarantee that protects native Claude Code index lines from being altered.

**User-facing note.** The bytes between the sentinel markers are adapter-managed. Any user edits to that region will be overwritten on the next save, forget, or audit refresh that touches the always-on tier. Users who want to edit MEMORY.md directly should add their content **outside** the sentinel block — that content is preserved byte-identically across all cross-memory operations.

### Refuse-and-halt: single marker present

If the file exists and contains exactly one of the two markers (begin without end, or end without begin), this is corrupted state. The adapter refuses the write, leaves the file unmodified, and emits a structured violation report:

```
cross-memory violation: sentinel marker missing
  file path       : ~/.claude/projects/<slug>/memory/MEMORY.md
  present marker  : <!-- cross-memory:begin --> | <!-- cross-memory:end -->
  missing marker  : <!-- cross-memory:end --> | <!-- cross-memory:begin -->
  action          : write refused; file not modified

To resolve: either restore the missing marker line to the file in the correct
position, or delete MEMORY.md entirely to bootstrap fresh on the next write.
```

### Refuse-and-halt: multiple markers of the same kind

If the file contains more than one `<!-- cross-memory:begin -->` line or more than one `<!-- cross-memory:end -->` line, the adapter refuses the write and emits a structured violation report:

```
cross-memory violation: duplicate sentinel marker
  file path        : ~/.claude/projects/<slug>/memory/MEMORY.md
  duplicate marker : <!-- cross-memory:begin --> | <!-- cross-memory:end -->
  count            : <N>
  action           : write refused; file not modified

To resolve: open MEMORY.md and remove the duplicate marker line(s)
so exactly one begin and exactly one end marker remain.
```

Where `<N>` is the count of duplicate marker lines found, and the `duplicate marker` field names whichever marker is duplicated (or both, if both are duplicated).

### No-marker append (non-empty file without sentinel block)

If the file exists, is non-empty, and contains neither marker, treat this as a native `MEMORY.md` that predates cross-memory installation. Do not overwrite native content. Instead, append the bootstrap block at the end of the file:

1. If the file's final byte is not `\n`, append `\n`.
2. Append `\n` (this produces a blank-line separator between the original content and the bootstrap block).
3. Append the bootstrap block per the Bootstrap section above:

   ```
   <!-- cross-memory:begin -->

   <!-- cross-memory:end -->
   ```

4. Immediately apply the rewrite-update with the `content` argument, now that both markers are present.

This case is explicitly documented here so users who already have a populated `MEMORY.md` are not surprised: their existing native index lines are preserved above the appended sentinel block.

---

## Cross-references

- **Canonical write layout and scope paths:** `SKILL.md → ## Config → Lazy-provisioning sequence` and `indexing.md → ## 2. Scope directories that get a MEMORY.md`.
- **Slug derivation rule:** documented in full in this file (§2 above) and summarized in `indexing.md → ## 5. Cross-references`.
- **Harness detection precedence (full chain):** `SKILL.md → ## Adapter selection`.
- **Mirror hook wiring in the save and forget flows:** `SKILL.md → ## Subcommand: save → Mirror hook — standard save` and `SKILL.md → ## Subcommand: forget → Step 5 — Mirror-remove hook`.
- **Schema validator (`mirrored_from` field rules):** `SKILL.md → ## Schema validator → Optional fields`.
- **Always-on tier filter** (the filter that selects which memories qualify for the injection block): `SKILL.md → ## Always-on tier`.
- **Injection block format and size-budget enforcement** (the formatter's output contract, sub-section layout, and drop protocol): `SKILL.md → ## Injection block`.
- **Sibling adapters:** `adapter-cursor.md` (Cursor harness) and `adapter-generic.md` (no-op fallback). This adapter manages only its own harness namespace (`~/.claude/` for the Claude Code adapter, `~/.cursor/` for the Cursor adapter). It does not read, write, or delete files in any sibling adapter's namespace; cross-adapter cleanup is not performed.
