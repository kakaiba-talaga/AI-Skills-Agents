<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Cross-Memory Indexing Module

## 1. Index file format

Each scope directory that contains active memories maintains a `MEMORY.md` index file. The index lists every memory in that scope as a single line entry.

**Line template:**

```
- [<name>](<filename>.md) — <description>
```

Where:
- `<name>` is the memory's required `name` frontmatter field (human-readable title).
- `<filename>` is the memory's filename without the `.md` extension.
- `<description>` is the memory's required `description` frontmatter field (one-line summary).

**Example lines:**

```
- [No commit message trailers](feedback_no_commit_trailers.md) — never include Co-Authored-By or other trailers in git commits
- [Python testing preference](preference_python_pytest.md) — prefer pytest over unittest for all new Python projects
```

This format mirrors the existing per-project memory convention at `~/.claude/projects/<slug>/memory/MEMORY.md` verbatim. Style continuity is intentional — it preserves auto-injection compatibility for the Claude Code adapter and reduces cognitive overhead for users inspecting files directly.

**Additional rules:**

- **Encoding:** UTF-8.
- **Line ordering:** Most-recently-updated first, sorted by `updated_at` descending. On a tie, alphabetical by `name`.
- **Trailing newline:** The file MUST end with a single trailing newline (`\n`).
- No blank lines between entries. No section headers inside the file. The file is a flat list.

## 2. Scope directories that get a MEMORY.md

Three scope tiers each maintain a per-scope `MEMORY.md`. There is no global aggregate index at v1; it is deferred to a future version alongside keyword or embedding indexing.

1. **`~/.cross-memory/user-global/MEMORY.md`** — indexes all memories in the `user-global` scope. One file; covers the user's preferences, identity rules, and cross-project facts.

2. **`~/.cross-memory/projects/<slug>/MEMORY.md`** — indexes all memories for a specific project. One file per project slug. The `<slug>` is derived from the project's absolute path by replacing each occurrence of any character in `{:, \, /, space, .}` with a single `-`; letter case is preserved; leading dashes are preserved (not trimmed).

3. **`~/.cross-memory/harnesses/<harness>/MEMORY.md`** — indexes all memories for a specific harness. The harness tier may have **multiple files**, one per supported harness: `claude-code`, `cursor`, and `generic`. At v1 the supported set is:
   - `~/.cross-memory/harnesses/claude-code/MEMORY.md`
   - `~/.cross-memory/harnesses/cursor/MEMORY.md`
   - `~/.cross-memory/harnesses/generic/MEMORY.md`

   Each file is independent; a memory in `harnesses/cursor/` does not appear in `harnesses/claude-code/MEMORY.md`. The harness tier exists because some rules are harness-specific (e.g., Cursor-only keybinding preferences, Claude Code-specific lane rules).

The aggregate index across all three scopes is explicitly deferred. v1's `/cross-memory search` is grep-style and operates directly over the tree; the `recall` command substring-matches file contents. An aggregate index would only earn its cost alongside a real keyword or embedding index, which is post-v1 work.

## 3. Archive directory has no MEMORY.md

`~/.cross-memory/archive/` does **NOT** receive a `MEMORY.md`. Archived memories are not indexed.

Memories land in the archive when they are superseded (replaced by a newer version of the same name) or forgotten via `/cross-memory forget`. Once archived, a memory is considered non-active historical state. It is recoverable by walking the archive directory directly — filename pattern `<original-stem>-<YYYYMMDDTHHMMSSZ>.md` makes the original name and timestamp machine-readable without an index.

The `/cross-memory audit` subcommand can list archive contents on demand. No automated process reads or re-indexes archived memories.

**Rationale:** the archive is historical and non-active state. Indexing it would grow the archive's `MEMORY.md` unboundedly across the lifetime of the store, require the adapter's always-on tier to skip archived entries by flag, and add complexity to the read surface without benefit. The grep-style `search` and the audit command provide sufficient access when recovery is needed.

## 4. Update behavior

`MEMORY.md` is updated synchronously as part of every write operation. Adapters that maintain a sentinel-bounded region inside a harness-native `MEMORY.md` (e.g., the Claude Code adapter) apply a parallel update to that region; the canonical per-scope `MEMORY.md` is always updated first.

| Trigger | MEMORY.md change |
| :--- | :--- |
| `save` (new memory) | Append the new line to the appropriate scope's `MEMORY.md`, then re-sort the full file by `updated_at` descending. |
| `save` (supersede — same `name` collision) | Remove the predecessor's line from `MEMORY.md` (the predecessor moves to archive); add the new memory's line; re-sort. |
| `forget` | Remove the memory's line from `MEMORY.md` (the memory moves to archive). No re-sort required — removal preserves relative order. |
| `audit categorize` action (via audit) | When the user applies a category change via the audit flow, `updated_at` is refreshed on the memory file. Re-sort `MEMORY.md` by the new `updated_at`. The `description` in the line is not changed by categorization alone — only an explicit supersede changes the description. |

Re-sort runs in-place: read all lines, sort by `updated_at` of the referenced file (Glob + Read frontmatter), write the sorted list back. The sort is stable — ties resolve alphabetically by `name`.

## 5. Cross-references

- **Storage layout and scope paths:** Three scope directories (`user-global/`, `projects/`, `harnesses/`), the `archive/` directory, and the no-global-aggregate rule are described in `SKILL.md` → `## Config` → Lazy-provisioning sequence.
- **Slug derivation** for the `<slug>` portion in scope 2 (`projects/<slug>/`): replace each occurrence of any character in `{:, \, /, space, .}` with a single `-`; letter case preserved; leading dashes preserved. When the Claude Code adapter runs, it confirms its derived slug matches an entry in `~/.claude/projects/` before writing; if the slug does not match, the adapter halts and emits a structured violation report.
- **Harness detection** (which harness-scoped `MEMORY.md` is updated for a given session): hybrid detection with explicit precedence: CLI flag > `~/.cross-memory/config.yaml` `current_harness:` > `CROSS_MEMORY_HARNESS` env var > adapter manifest probe > generic fallback.
