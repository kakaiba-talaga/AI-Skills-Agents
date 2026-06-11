<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Always-on tier

The always-on tier is a session-bootstrap filter that selects which memories surface automatically in the `[CROSS-MEMORY]` injection block at the start of every new session. It runs once per session, after the active harness adapter has been detected and the active project's slug has been determined. Its output is a filtered, deduplicated, staleness-decorated list of memory entries consumed by the injection-block formatter, which renders those entries as the `[CROSS-MEMORY]` block and writes them into the sentinel-bounded region of the harness-native `MEMORY.md`.

The filter is harness-agnostic: it consumes the adapter interface (the active harness and project slug already resolved by detection time) and does not need to know how the resulting block will be spliced into any particular harness's file layout.

## Trigger

The always-on tier filter is invoked once at session bootstrap, after:

1. The harness adapter has been detected (resolving the active harness identifier: `claude-code`, `cursor`, or `generic`).
2. The active project's slug has been determined from the current working directory, derived per the slug rule in `adapter-claude-code.md` § 2.

No subcommand invocation is required. The filter fires automatically as part of the adapter's session-start sequence.

## Inputs

| Input | Source | Notes |
| :--- | :--- | :--- |
| Active harness identifier | Harness detection (CLI flag → config field → env var → adapter probe → generic fallback) | One of `claude-code`, `cursor`, `generic` |
| Active project slug | Current working directory → slug-derivation rule | See `indexing.md` § 5 for the exact derivation; `adapter-claude-code.md` § 2 for the Claude Code implementation |
| `staleness_threshold_days` | `~/.cross-memory/config.yaml`, field `staleness_threshold_days` | Integer; default `90`; used for staleness banner computation |

## Inclusion rules

Four rules determine which memory entries are selected. Rules are applied in order; the results are merged into a single list before deduplication.

1. **User-global, type in {preference, rule, fact}.** Walk `~/.cross-memory/user-global/MEMORY.md`. Select entries whose `type` frontmatter field is one of `preference`, `rule`, or `fact`. These are the user's persistent identity — preferences, hard rules, and objective facts that apply across every project and every harness.

2. **Project:current-slug, type in {feedback, project, rule}.** Walk `~/.cross-memory/projects/<active-slug>/MEMORY.md`. Select entries whose `type` frontmatter field is one of `feedback`, `project`, or `rule`. Only the active project's scope is walked — other project scopes are not examined. If the active project slug is absent (the adapter could not determine the current project), this rule contributes zero entries and the filter continues.

3. **Harness:current-harness, type in {rule, feedback}.** Walk `~/.cross-memory/harnesses/<active-harness>/MEMORY.md`. Select entries whose `type` frontmatter field is one of `rule` or `feedback`. These are harness-specific standing rules that apply in every session under that harness.

4. **Tag = `always-on`, across all scopes.** Walk all three scope index files (`~/.cross-memory/user-global/MEMORY.md`, `~/.cross-memory/projects/<active-slug>/MEMORY.md`, and `~/.cross-memory/harnesses/<active-harness>/MEMORY.md`). Select entries whose `tags` array contains `always-on` (case-insensitive match), regardless of type. This is an explicit opt-in mechanism — the user can force any memory into the always-on tier by tagging it `always-on`.

## Deduplication

The deduplication key is the memory file's absolute canonical path (e.g., `~/.cross-memory/user-global/rule_no-commit-trailers.md`). If the same canonical path appears in the merged list more than once — for example, because a memory tagged `always-on` also matches a type-based inclusion rule — it is retained exactly once in the output.

When a canonical path appears via multiple routes, no precedence resolution is required: the underlying file is the same in all cases. The deduplication step simply removes duplicate path references and preserves one entry per canonical path. The entry's scope, type, description, tags, and staleness state all come from the canonical file — there is nothing to merge.

**The archive directory is never walked.** Memories in `~/.cross-memory/archive/` are excluded from all four rules. The archive scope has no `MEMORY.md` index file, so it is structurally unreachable by the filter. Memories move to the archive on `forget` or supersede; once archived they no longer appear in the always-on tier regardless of their type or tags.

## Staleness banner

For each entry in the filtered, deduplicated list, the filter checks whether the entry's `verified_at` frontmatter field indicates a stale memory:

- If `verified_at` is present and `(today_utc - verified_at) > staleness_threshold_days`, a staleness banner is appended inline to the entry's description field.
- The banner format is: `(stale: last verified <N> days ago)` where `<N>` is the integer number of days elapsed since `verified_at`.
- The banner lives at the end of the `description` string and travels with the bullet into the injection block. It is not a separate frontmatter field and is never written to disk — it is a rendering-time annotation applied only when building the output list.
- If `verified_at` is absent, the entry is treated as not stale. No banner is applied. Absence of `verified_at` is not an error.

**Example:** if `staleness_threshold_days` is `90` and a memory's `verified_at` was 113 days ago, the description `"Use pytest for all new Python tests"` becomes `"Use pytest for all new Python tests (stale: last verified 113 days ago)"` in the output entry.

## Output

The filter produces an ordered list of structured entries. Each entry is a tuple:

```
(scope, type, name, description_with_banner, tags)
```

Where:

- `scope` — the memory's `scope` frontmatter field (e.g., `user-global`, `project:D--Repositories-Personal-Git-AI-Skills-Agents`, `harness:claude-code`).
- `type` — the memory's `type` frontmatter field (one of the five type enum values from `## Schema validator`).
- `name` — the memory's `name` frontmatter field.
- `description_with_banner` — the memory's `description` frontmatter field with the staleness banner appended inline, or the bare `description` if no banner applies.
- `tags` — the memory's `tags` frontmatter array (flat list of strings; may be empty).

The list order is: user-global entries first (Rule 1), then project entries (Rule 2), then harness entries (Rule 3), then any additional entries that entered solely via the `always-on` tag (Rule 4) that did not already appear from Rules 1–3. Within each group, entries are ordered by `updated_at` descending (most recently updated first).

This list is consumed by the injection-block formatter, which formats the entries into the three sub-sections (`User Profile:`, `Project Knowledge:`, `Relevant Memories:`) and applies the size budget. The always-on filter does not own block layout — that is the injection-block formatter's responsibility (see `injection-block.md`).

## Edge cases

| Scenario | Behavior |
| :--- | :--- |
| A scope's `MEMORY.md` is missing | Treat as an empty list. The rule for that scope contributes zero entries. No error is raised; the filter continues with the remaining rules. |
| `verified_at` is absent from a memory's frontmatter | Treat as not stale. No staleness banner is applied. |
| The user-global scope is empty | Rule 1 contributes zero entries. The filter still runs and the remaining rules are evaluated normally. |
| The active project slug is unavailable | Rule 2 is skipped entirely. Its `MEMORY.md` path cannot be determined without a slug, so it contributes zero entries. |
| All three scope index files are empty or missing | The filter produces an empty list. The injection-block formatter receives an empty list and decides whether to render an empty block or skip the block entirely — the filter does not make that call. |
| A memory has `tag: always-on` AND matches a type-based rule | The memory appears in the merged list from two routes (the type rule and Rule 4). Deduplication retains it once. One entry, not two. |
| A memory's type matches a type rule but the memory is in the archive directory | Excluded. The filter walks only the three canonical scope index files. `~/.cross-memory/archive/` has no `MEMORY.md` and is never walked. |

## Cross-references

- **Slug derivation rule** (how the active project slug is computed from the current working directory): `adapter-claude-code.md` § 2.
- **Claude Code slug derivation and pre-flight confirmation**: `adapter-claude-code.md` § 2.
- **Scope index file layout** (which paths carry a `MEMORY.md` and the line format used): `~/.claude/skills/cross-memory/indexing.md` § 1–2.
- **Skill companion index** (this file loads only on `/cross-memory init`, not on bare invocation, `help`, `recall`, or other subcommands): `indexing.md` § 6.
- **`staleness_threshold_days` config field**: `## Config` section above.
- **Injection-block formatter** (consumes this filter's output list and produces the `[CROSS-MEMORY]` block bytes, including sub-section layout, size-budget enforcement, and sentinel-bounded write): see `injection-block.md`.
- **Adapter interfaces** (how the filter's output is handed off to the harness-specific sentinel write): `adapter-claude-code.md` § 6 (`update_sentinel_block`).
