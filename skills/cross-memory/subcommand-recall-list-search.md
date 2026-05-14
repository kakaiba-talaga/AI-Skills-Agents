<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Subcommand: recall / list / search

These three subcommands are the read-side query surface of the cross-memory skill. They share the same filter-flag vocabulary (minus the positional argument for `list`) and are grouped here because their output ordering rules, empty-result message shapes, and archive-exclusion semantics are near-identical.

## Subcommand: recall

Retrieve memories from the canonical store by topic. Uses case-insensitive substring matching across multiple fields; no ranking, no fuzzy match.

### Command syntax

```
/cross-memory recall <topic> \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--type <feedback|project|preference|fact|rule>] \
  [--category <project-config|architecture|error-solution|preference|learned-pattern|conversation|other>] \
  [--tag <tag>] \
  [--include-stale]
```

`<topic>` is a required positional argument. At least one character must be provided.

### Match strategy

For each memory file in `~/.cross-memory/` (excluding `archive/`), the skill tests whether `<topic>` appears (case-insensitive substring match) in any of the following fields:

| Field | Where to check |
| :--- | :--- |
| `name` | Frontmatter |
| `description` | Frontmatter |
| `tags` | Frontmatter array — topic is tested against each tag element |
| Body | Full body text after the closing `---` of the frontmatter block |

A memory is included in results if any one of the four fields matches. All four checks run on every candidate file; partial matches (substring anywhere in the field) qualify.

### Filter flags

Filter flags narrow the candidate set **before** the topic match is applied. A memory must pass all provided filters to be considered.

| Flag | Effect | Notes |
| :--- | :--- | :--- |
| `--scope <s>` | Retain only memories whose `scope` frontmatter field equals `<s>` exactly | Accepts the same values as `--scope` in `save`: `user-global`, `project:<slug>`, `harness:<name>` |
| `--type <t>` | Retain only memories whose `type` field equals `<t>` | Must be a valid type enum value; invalid values emit the same validation error string as the `save` gate |
| `--category <c>` | Retain only memories whose `category` field equals `<c>` | Must be a valid category enum value; memories with no `category` field are treated as `category: other` at filter time (per `schema-validator.md` default rules) |
| `--tag <tag>` | Retain only memories whose `tags` array contains `<tag>` (case-insensitive) | Can be repeated to require multiple tags; each `--tag` narrows further (AND semantics) |
| `--include-stale` | No-op at v1 — stale memories are always included in results | Flag is reserved for a future opt-out variant; parsing it is required (unknown-flag error must not fire), but its presence has no effect on the result set |

### Output ordering

Results are sorted by `updated_at` descending (most recently updated first). The sort is a string comparison against the ISO-8601 UTC timestamp in the frontmatter; because ISO-8601 timestamps sort lexicographically in UTC, no date parsing is required.

### Staleness banner

For each matched memory where `verified_at` is present and `(now - verified_at) > staleness_threshold_days` (default 90, configurable in `~/.cross-memory/config.yaml`), the rendered body is prefixed with a one-line banner:

```
(stale: last verified <N> days ago)
```

Where `<N>` is the integer number of days elapsed since `verified_at`. The banner is **inline** — prepended to the body text as part of the rendered output the user sees. It is not a separate frontmatter field and is not written to disk. Memories with no `verified_at` field are treated as not stale — no banner is applied.

### Body rendering

Two cosmetic transforms apply when rendering the body for display:

1. **`[REDACTED:private]` → `…`** — per `~/.claude/skills/cross-memory/redaction.md` (cosmetic ellipsis on recall render). The on-disk form remains `[REDACTED:private]`; only the displayed output uses `…`. This is a recall-time visual transform; the stored bytes are never modified.
2. **Other `[REDACTED:<category>]` placeholders** — rendered literally. The bracketed placeholder text is shown as-is; no substitution is applied.

### Path output

For each matching memory, the canonical file path is rendered on the line immediately before the body:

```
~/.cross-memory/<scope-dir>/<filename>
(stale: last verified <N> days ago)        ← only if staleness threshold exceeded
<rendered body>
```

The path line allows the user to locate and edit the file directly.

### Empty results

If no memories match the topic (after applying all filters), the skill outputs:

```
no memories matched topic '<topic>'
```

When one or more filter flags are also present, the message is extended:

```
no memories matched topic '<topic>' [with filters: --scope user-global --type fact]
```

The `[with filters: ...]` suffix lists only the flags the user provided, in the order they appeared on the command line.

### Cross-references

- **Enum values and validation error strings**: `schema-validator.md`.
- **`staleness_threshold_days` config field**: `## Config` section above.
- **Cosmetic ellipsis rule (`[REDACTED:private]` → `…`)**: `~/.claude/skills/cross-memory/redaction.md`.
- **Match strategy (no indexing at v1)**: `recall` and `search` use `Glob` + `Grep` against the tree directly; no pre-built index.
- **`[CROSS-MEMORY]` injection block (always-on tier)**: the adapter renders the always-on memories as a sentinel-bounded block inside the harness-native `MEMORY.md`.

---

## Subcommand: list

Enumerate memories from the canonical store. Returns a filterable one-line summary per memory; no body rendering. Use case: "show me everything I have saved under this project" or "show me stale memories".

### Command syntax

```
/cross-memory list \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--type <feedback|project|preference|fact|rule>] \
  [--category <project-config|architecture|error-solution|preference|learned-pattern|conversation|other>] \
  [--tag <tag>] \
  [--stale-only]
```

No positional argument — `list` shows all memories that pass the applied filters. Substring matching is not performed; the full filtered set is returned.

### Filter flags

Filter flags narrow the candidate set. A memory must pass all provided filters to appear in the output. The flag set is the same as `recall` minus the positional `<topic>` argument.

| Flag | Effect | Notes |
| :--- | :--- | :--- |
| `--scope <s>` | Retain only memories whose `scope` frontmatter field equals `<s>` exactly | Accepts `user-global`, `project:<slug>`, `harness:<name>` |
| `--type <t>` | Retain only memories whose `type` field equals `<t>` | Must be a valid type enum value; invalid values emit the same validation error string as the `save` gate |
| `--category <c>` | Retain only memories whose `category` field equals `<c>` | Memories with no `category` field are treated as `category: other` at filter time (per `schema-validator.md` default rules) |
| `--tag <tag>` | Retain only memories whose `tags` array contains `<tag>` (case-insensitive) | Can be repeated; each `--tag` narrows further (AND semantics) |
| `--stale-only` | Retain only memories where `verified_at` is present and `(now - verified_at) > staleness_threshold_days` | Memories with no `verified_at` field are treated as not stale and are excluded from `--stale-only` results; threshold is from `~/.cross-memory/config.yaml` (default 90 days) |

### Output format

One line per matching memory, in the form:

```
<name> — <description> — <scope> — <tags> — <staleness>
```

Where `<staleness>` is either `stale: N days` (if the staleness threshold is exceeded) or `ok`. No body text, no frontmatter block is rendered — summary fields only.

### Output ordering

Results are sorted by `updated_at` descending (most recently updated first). Sort is a string comparison against the ISO-8601 UTC timestamp in the frontmatter; ISO-8601 timestamps sort lexicographically in UTC, so no date parsing is required.

### Archive excluded

The `~/.cross-memory/archive/` directory is never listed. Archived memories are soft-deleted predecessors that have been superseded; they are recoverable via the `audit` subcommand only, not via `list`.

### Empty results

If no memories match the applied filters, the skill outputs:

```
no memories matched [filters]
```

Where `[filters]` lists the flags the user provided. If no filter flags were provided, the message is simply `no memories matched`.

### Cross-references

- **Enum values and validation error strings**: `schema-validator.md`.
- **`staleness_threshold_days` config field**: `## Config` section above.
- **Archive directory layout**: `## Config` → Lazy-provisioning sequence above.

---

## Subcommand: search

Grep-style full-text search across memory body content. Returns raw matched lines with their source path and line number; no body rendering, no frontmatter rendering, no synthesis. Distinct from `recall`, which is topic-targeted and may invoke synthesis.

### Command syntax

```
/cross-memory search <query> \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--type <feedback|project|preference|fact|rule>]
```

`<query>` is a required positional argument. At least one character must be provided.

### Match style

For each memory file in scope, every line in the memory body that contains `<query>` as a case-insensitive substring is returned as a triple:

```
<canonical-path>:<line-number>: <matched-line-text>
```

Where:

- `<canonical-path>` is the full path to the memory file (e.g., `~/.cross-memory/user-global/preference_pytest-not-unittest.md`).
- `<line-number>` is the 1-based line number within that file.
- `<matched-line-text>` is the raw text of the matched line, exactly as stored on disk.

No frontmatter fields are searched — only the body content after the closing `---` of the frontmatter block. No body rendering or cosmetic transforms are applied; the output is the raw on-disk bytes of matched lines.

### Filter flags

`--scope` and `--type` narrow the candidate file set before the body scan. Only these two flags are supported — `--category` and `--tag` are not available for `search` because search is content-driven, not metadata-driven.

| Flag | Effect | Notes |
| :--- | :--- | :--- |
| `--scope <s>` | Scan only files whose `scope` frontmatter field equals `<s>` exactly | Accepts `user-global`, `project:<slug>`, `harness:<name>` |
| `--type <t>` | Scan only files whose `type` frontmatter field equals `<t>` | Must be a valid type enum value; invalid values emit the same validation error string as the `save` gate |

### Archive excluded

The `~/.cross-memory/archive/` directory is excluded from search by default. Archived memories are superseded predecessors that are no longer canonical; including them in search results would surface stale or contradicted content. If a search across archived memories is needed, use the `audit` subcommand, which can inspect the archive on demand.

### Empty results

If no lines match the query (after applying all filters), the skill outputs:

```
no matches for query '<query>'
```

When one or more filter flags are also present, the message is extended:

```
no matches for query '<query>' [in scope]
```

Where `[in scope]` describes the active filters (e.g., `in scope: user-global`).

### Cross-references

- **Enum values and validation error strings**: `schema-validator.md`.
- **Archive directory layout**: `## Config` → Lazy-provisioning sequence above.
- **Indexing decision (no index at v1; Glob + Grep on demand)**: `search` scans file content directly using `Glob` + `Grep`; no pre-built index.
