<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Cross-Memory Adapter — Generic Fallback

This adapter is the last stop in the harness-detection chain. It has no harness-native memory layout to write to, so every operation is a no-op by design. The canonical store at `~/.cross-memory/` is written normally; only the harness-native mirroring and injection steps are absent. The skill remains fully usable in any environment that supports `/cross-memory save` and `/cross-memory recall` directly — the user just does not receive the always-on cross-session injection tier that the Claude Code and Cursor adapters provide.

---

## Operation Interface Table

| Operation | One-line description | Target path(s) touched | Triggering event |
| :--- | :--- | :--- | :--- |
| `slug_derivation` | No-op — canonical store uses standard slug derivation; this adapter does not call it | None | N/A |
| `mirror_write` | No-op — no harness-native mirror directory exists; returns structured result indicating no mirror was written | None | After every canonical `save` (no-op) |
| `mirror_remove` | No-op — no mirror was written by this adapter; returns immediately without touching any path | None | After every `forget` (no-op) |
| `detect_collisions` | Returns an empty report — no mirrors are managed by this adapter | None | During `audit` |
| `update_sentinel_block` | No-op — no harness-native `MEMORY.md` is managed by this adapter | None | After canonical write, forget, or audit refresh (no-op) |

---

## 1. Detection

The generic adapter activates under any one of four conditions. The first matching condition wins; the remaining conditions are not evaluated.

**Explicit CLI flag.** The user passes `--harness=generic` to any cross-memory subcommand. This flag has the highest priority and overrides both the config field and the environment variable for the current session.

**Config field.** The `~/.cross-memory/config.yaml` field `current_harness: generic` is set. This is the stable per-user mechanism for pinning to the generic adapter across sessions.

**Environment variable.** The environment variable `CROSS_MEMORY_HARNESS=generic` is set. This is useful for shell-aliased launchers or CI environments where the config file is not available.

**Implicit fallback.** None of the above conditions are met, and the manifest-probe pass for both the Claude Code and Cursor adapters returns negative. The generic adapter activates automatically in this case — it requires no positive signal of its own.

The full harness-detection precedence chain (CLI flag → `current_harness` config field → `CROSS_MEMORY_HARNESS` env var → adapter manifest probe → generic fallback) is documented in `SKILL.md → ## Adapter selection`.

---

## 2. Slug Derivation

The generic adapter does not perform slug derivation. It has no per-harness directory layout to write to, so there is no slug to resolve.

The canonical-store write path under `~/.cross-memory/projects/<slug>/` still uses slug derivation — but that responsibility belongs to the canonical write layer, not to this adapter. The derivation rule (replace each occurrence of `{:, \, /, space, .}` with a single `-`; preserve letter case; preserve leading dashes) is documented in `indexing.md → ## 5. Cross-references`. This adapter does not call it.

---

## 3. mirror_write

No-op. When the canonical `save` succeeds and the mirror hook is invoked, the generic adapter returns immediately without writing any file. The canonical memory is saved successfully at `~/.cross-memory/projects/<slug>/` regardless.

The adapter returns a structured result to the caller so that the skill can log the outcome:

```
mirror_write result:
  harness      : generic
  mirror written: false
  reason       : no harness-native mirror directory; generic adapter is active
```

No disk work is performed. No sidecar manifest is created or updated.

---

## 4. mirror_remove

No-op. When `/cross-memory forget` triggers the mirror-remove hook, the generic adapter returns immediately without deleting any file.

If a mirror file was written by a previous adapter session (for example, the user previously ran with the Claude Code adapter), that mirror remains on disk. The generic adapter has no record of where it was written and makes no attempt to locate or delete it. Cleanup in this scenario is the responsibility of the adapter that created the mirror: run `/cross-memory forget` again under the original adapter to remove its mirror explicitly.

---

## 5. detect_collisions

Returns an empty report. The generic adapter manages no mirrors, so there are no mirror files to inspect and no collision states to classify. The audit receives a zero-entry collision report and continues with any other checks.

---

## 6. update_sentinel_block

No-op. The generic adapter manages no harness-native `MEMORY.md`. There is no sentinel-bounded `[CROSS-MEMORY]` region to rewrite. Always-on context injection is not available under the generic adapter; users access memories by running `/cross-memory recall` explicitly.

---

## 7. When the Generic Adapter Is the Right Choice

There are several situations where the generic adapter is appropriate or preferable.

**Minimal-permissions environments.** The generic adapter never writes outside `~/.cross-memory/`. If the environment restricts writes to harness-managed directories, or if the user prefers not to grant cross-memory access to `~/.claude/` or `~/.cursor/`, the generic adapter keeps the skill functional with the smallest possible footprint.

**Sandboxed CI runs.** In automated pipelines where cross-memory is used to pass recalled context into a prompt, mirror writes would leave stray files in the CI runner's home directory. Pinning `CROSS_MEMORY_HARNESS=generic` avoids that entirely without disabling the skill.

**Harness-specific testing.** When testing the Claude Code or Cursor adapter behavior itself, mirror writes from the generic adapter would muddy the filesystem state under test. Running a second session under `--harness=generic` keeps the canonical store writable while the mirror paths remain untouched.

**Environments without Claude Code or Cursor.** If neither harness is installed, the implicit fallback activates the generic adapter automatically. The skill works the same way — the user just invokes `/cross-memory recall` explicitly rather than relying on always-on injection.

---

## Cross-references

- **Canonical write layout and scope paths:** `SKILL.md → ## Config → Lazy-provisioning sequence` and `indexing.md → ## 2. Scope directories that get a MEMORY.md`.
- **Slug derivation rule:** `indexing.md → ## 5. Cross-references`.
- **Harness detection precedence (full chain):** `SKILL.md → ## Adapter selection`.
- **Mirror hook wiring in the save and forget flows:** `SKILL.md → ## Subcommand: save → Mirror hook — standard save` and `SKILL.md → ## Subcommand: forget → Step 5 — Mirror-remove hook`.
- **Sibling adapters:** `adapter-claude-code.md` (Claude Code harness) and `adapter-cursor.md` (Cursor harness).
