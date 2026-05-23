<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Cross-Memory Adapter — Cursor

This adapter mirrors canonical memories (which live under `~/.cross-memory/`) into Cursor's native per-project memory layout at `~/.cursor/projects/<slug>/memory/`, and manages a sidecar manifest that tracks every mirror it has written. Mirroring is strictly one-directional: **canonical → mirror**. The canonical store at `~/.cross-memory/` is always the source of truth; this adapter writes to Cursor's native paths and never reads from them as authoritative state.

> **v1 path note.** The target path `~/.cursor/projects/<slug>/memory/` is the v1 default, chosen to mirror the structure of Claude Code's native per-project memory layout. Cursor's exact native memory directory convention is not fully documented at v1 and is subject to refinement after integration testing against a real Cursor session. The adapter writes to this location and the sidecar records it, so any path adjustment discovered during integration testing requires only a path constant update — the surrounding operation logic does not change.

---

## Operation Interface Table

| Operation | One-line description | Target path(s) touched | Triggering event |
| :--- | :--- | :--- | :--- |
| `slug_derivation` | Derives the project slug from the absolute project path | `~/.cursor/projects/` (read-only probe) | Before any mirror write |
| `mirror_write` | Writes a mirror copy of a canonical memory into the Cursor-native memory directory | `~/.cursor/projects/<slug>/memory/<type>_<name>.md`; `~/.cursor/cross-memory-mirrors.json` | After every canonical `save` (new or supersede) |
| `mirror_remove` | Deletes a mirror copy and its sidecar manifest entry | `~/.cursor/projects/<slug>/memory/<type>_<name>.md`; `~/.cursor/cross-memory-mirrors.json` | After every `forget` |
| `detect_collisions` | Classifies every file in the mirror directory as native, stale-mirror, or user-edited | `~/.cursor/projects/<slug>/memory/` (read); `~/.cursor/cross-memory-mirrors.json` (read) | During `audit` |
| `update_sentinel_block` | No-op at v1 — see section 6 below | — | — |

---

## 1. Detection

The adapter declares itself active when at least one of the following two signals is present. Both signals are probed on every adapter detection pass; the first positive result stops the probe.

### Signal 1 — Environment variable family

Cursor sets one or more environment variables prefixed with `CURSOR_`. The adapter checks for the presence of any variable whose name begins with `CURSOR_` (for example, `CURSOR_SESSION_ID`, `CURSOR_WORKSPACE_ID`, or any future addition to the family). The check is a prefix test on the variable name, not an exact match — any `CURSOR_*` variable is sufficient.

On platforms where env inspection is available, this check is the fastest signal and is performed first.

### Signal 2 — Marker-directory probe

The adapter checks for the existence of the directory `~/.cursor/`. If the directory is present, the adapter treats this as evidence that Cursor has been installed and is the active harness. This probe succeeds even when the `CURSOR_*` env vars are absent (for example, in a shell session started outside the Cursor launcher).

### Precedence within this adapter

Probe both signals. The first positive signal activates the adapter and sets the harness identity to `cursor`. If both signals are absent, this adapter does not activate; control passes to the generic fallback.

### Precedence across all adapters

The overall harness-detection order (from highest to lowest priority) is governed by the full precedence chain documented in `SKILL.md → ## Adapter selection`: CLI flag → `current_harness` config field → `CROSS_MEMORY_HARNESS` env var → adapter manifest probe (Claude Code first, then Cursor, then generic) → generic fallback. This adapter is probed only when the first three levels produce no result, and only after the Claude Code adapter has declined to activate.

---

## 2. Slug Derivation

The slug is the directory name used to store per-project state under `~/.cursor/projects/`. Cross-memory derives it from the absolute path of the active project using the same rule as the Claude Code adapter.

### Rule

The rule is defined in full in `indexing.md → ## 5. Cross-references` (slug derivation paragraph) and in `adapter-claude-code.md → ## 2. Slug Derivation → Rule`. This adapter applies that same rule without modification: replace each occurrence of any character in `{ :, \, /, space, . }` with a single `-`; letter case is preserved; leading dashes are not trimmed.

**Why the same rule.** Cross-harness predictability requires that the slug derived for a given project path be identical regardless of which adapter is active. If the Cursor adapter used a different derivation, a memory saved under Claude Code and then recalled under Cursor would fail to locate its mirror — the two slugs would not match. Predictability beats harness-specific prettiness: users who inspect `~/.cursor/projects/` or `~/.cross-memory/projects/` can apply the same mental rule to navigate both trees.

### Pre-flight confirmation

Before executing any mirror write, derive the slug from the active project path and confirm the slug appears verbatim in `~/.cursor/projects/`. If it is absent, the canonical write proceeds normally but the mirror write is skipped for the current session. Emit the same structured violation report defined in `adapter-claude-code.md → ## 2. Slug Derivation → Pre-flight confirmation`, substituting the Cursor-side paths.

---

## 3. mirror_write

Called after every canonical `save` (new write or supersede). Copies the canonical memory file into the Cursor-native memory directory as a mirror.

### Target path

```
~/.cursor/projects/<slug>/memory/<type>_<name>.md
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

`~/.cursor/cross-memory-mirrors.json` is a flat JSON object where each key is the mirror's absolute path and each value is a record with three fields:

```json
{
  "~/.cursor/projects/<slug>/memory/<type>_<name>.md": {
    "canonical_source": "~/.cross-memory/projects/<slug>/<type>_<name>.md",
    "harness_slug": "<slug>",
    "mirrored_at": "2026-05-08T14:32:01Z"
  }
}
```

The `mirrored_at` timestamp is UTC ISO-8601, stamped at the moment the mirror write completes. The sidecar is updated atomically alongside each `mirror_write` — read the current JSON, upsert the new entry, write the updated JSON back before the operation is considered complete.

### Bootstrap

Before writing the mirror file:

1. If `~/.cursor/projects/<slug>/memory/` does not exist, create it (including any missing intermediate directories).
2. If `~/.cursor/cross-memory-mirrors.json` does not exist, create it as an empty JSON object `{}`, then append the new entry.

Both bootstrap steps are idempotent — running them when the paths already exist is a no-op.

---

## 4. mirror_remove

Called after every `/cross-memory forget`. Removes the Cursor-native mirror and its sidecar manifest entry.

### Removal steps

1. Derive the mirror target path using the same `<type>_<name>` pattern as `mirror_write`.
2. If the mirror file exists at `~/.cursor/projects/<slug>/memory/<type>_<name>.md`, delete it. If the file is absent (already removed by the user or a prior forget), this is not an error — record the absence and continue.
3. Remove the corresponding entry from `~/.cursor/cross-memory-mirrors.json`. If no entry exists for the derived mirror path, this is also not an error — skip silently.

### Post-removal directory state

After deletion, if `~/.cursor/projects/<slug>/memory/` is empty, leave it as-is. Do not auto-prune the empty directory. Cursor manages its own directory lifecycle; the adapter does not remove directories it did not exclusively own.

---

## 5. detect_collisions

Called during `/cross-memory audit`. Inspects every file in `~/.cursor/projects/<slug>/memory/` and classifies each file as one of three states. The full classification logic and defense-in-depth rules are identical to those in `adapter-claude-code.md → ## 5. detect_collisions`; this section provides a brief restatement for readability and documents the Cursor-side paths.

### Three-state classification

**native** — The file has no `mirrored_from` frontmatter field AND has no entry in `~/.cursor/cross-memory-mirrors.json`. The user authored this file natively in Cursor. Cross-memory must not overwrite it; the audit reports it as native and skips it.

**stale-mirror** — The file has a `mirrored_from` frontmatter field pointing at a canonical path that no longer exists, OR the sidecar has an entry for the file but the canonical source path in that entry no longer exists. Cross-memory should clean up: delete the mirror file and remove the sidecar entry. The audit prompts the user before executing the cleanup.

**user-edited** — The file has a `mirrored_from` frontmatter field resolving to an existing canonical file, AND the sidecar manifest has a matching entry — but the mirror's body content has diverged from the canonical's body content. The audit warns the user and offers three choices: overwrite the mirror with the canonical content, skip (leave the mirror as-is), or back up the mirror body as a new or superseding canonical entry.

### Defense-in-depth disagreement path

If the two signals disagree — the file has `mirrored_from` in its frontmatter but the sidecar has no matching entry, or the sidecar has an entry but the file has no `mirrored_from` field — this is a corrupted-state path. The adapter refuses to classify the file and emits a structured violation report:

```
cross-memory violation: mirror-state disagreement
  file path      : ~/.cursor/projects/<slug>/memory/<type>_<name>.md
  frontmatter    : mirrored_from <present | absent>
  sidecar entry  : <present | absent>
  action         : file skipped; no automatic repair attempted

Resolve by inspecting the file and sidecar manually. Either restore the missing
signal or delete the file and remove the sidecar entry to start fresh.
```

The file is not modified, not deleted, and not classified — it is skipped for the duration of the current audit pass.

---

## 6. update_sentinel_block

**This operation is a no-op at v1.**

Cursor does not expose an editable `MEMORY.md`-equivalent file that the adapter can manage with sentinel markers at v1. The sentinel-bounded rewrite pattern used by the Claude Code adapter is specific to Claude Code's injection surface, where `MEMORY.md` in the project memory directory is automatically included in every session context.

Cursor's equivalent session-start always-on injection mechanism is not fully specified at v1 and is pending integration testing. When Cursor's native auto-inject surface is confirmed during integration testing, this operation may be implemented in a future revision to manage a sentinel-bounded region in that surface. Until then, always-on tier injection in Cursor relies on the user running `/cross-memory recall` explicitly at session start, which is consistent with the generic fallback behavior.

If Cursor's integration testing reveals a specific surface (for example, a `.cursor/rules/*.mdc` file or a project-level context injection file), this section should be updated to document the bootstrap, rewrite-update, refuse-and-halt, and no-marker-append behaviors following the same pattern as `adapter-claude-code.md → ## 6. update_sentinel_block(content)`.

### Trust-model disclosure — brief-injector bypass

This is a trust-model disclosure, not a fix or a workaround. The brief-injector (`skills/cross-memory/brief-injector.md`) reads `~/.cross-memory/**` directly at dispatch time, bypassing this no-op surface. Under v1, Cursor subagents dispatched via the Agent tool see `## Project Knowledge` in their briefs even though the top-level Cursor session does not see `[CROSS-MEMORY]`. A maintainer reading this adapter without this disclosure could assume the sentinel-block surface is the only injection path and be surprised by subagent behavior. Once Cursor's `update_sentinel_block` is implemented in a future release, the disclosure can be downgraded to "the brief-injector still bypasses the sentinel surface even though the top-level turn now also sees it."

---

## Cross-references

- **Canonical write layout and scope paths:** `SKILL.md → ## Config → Lazy-provisioning sequence`.
- **Slug derivation rule (full definition):** `indexing.md → ## 5. Cross-references` and `adapter-claude-code.md → ## 2. Slug Derivation`.
- **Harness detection precedence (full chain):** `SKILL.md → ## Adapter selection`.
- **Three-state collision classification and defense-in-depth disagreement path:** `adapter-claude-code.md → ## 5. detect_collisions`.
- **Mirror hook wiring in the save and forget flows:** `SKILL.md → ## Subcommand: save → Mirror hook — standard save` and `SKILL.md → ## Subcommand: forget → Step 5 — Mirror-remove hook`.
- **Schema validator (`mirrored_from` field rules):** `SKILL.md → ## Schema validator → Optional fields`.
- **Sibling adapters:** `adapter-claude-code.md` (Claude Code harness) and `adapter-generic.md` (no-op fallback). This adapter manages only its own harness namespace (`~/.cursor/` for the Cursor adapter, `~/.claude/` for the Claude Code adapter). It does not read, write, or delete files in any sibling adapter's namespace; cross-adapter cleanup is not performed.
