# Cross-Memory

## Overview

A harness-portable memory layer with six subcommands (`save`, `recall`, `list`, `forget`, `search`, `audit`), an always-on injection tier that surfaces key memories at session start, and an opus-class agent for synthesis and audit. Memories live in the canonical store at `~/.cross-memory/` and are available across three scopes: `user-global` (cross-project, cross-harness), `project:<slug>` (current project only), and `harness:<name>` (current harness only). Harness adapters mirror canonical memories into Claude Code and Cursor native locations so they surface in every session without manual recall.

## Subcommands

| Subcommand | Purpose | Common flags |
| :--- | :--- | :--- |
| `save` | Persist a new memory to the canonical store. Runs parse → redact → confirm → write gates. Auto-propose fires on cue phrases like "from now on" or "remember that". | `--scope`, `--type`, `--no-redact` |
| `recall` | Retrieve memories by topic using case-insensitive substring matching across name, description, tags, and body. Results ordered by `updated_at` descending. | `--scope`, `--type`, `--tag` |
| `list` | Enumerate all memories with one-line summaries; no body rendering. Use to survey what is stored or find stale entries. | `--scope`, `--type`, `--stale-only` |
| `forget` | Archive the named memory and remove its index entry. The memory moves to `~/.cross-memory/archive/`; no hard delete at v1. | `--scope` (default `user-global`) |
| `search` | Grep-style full-text search over memory body content. Returns `<path>:<line>: <match>` triples; no rendering or synthesis. | `--scope`, `--type` |
| `audit` | Dispatch the cross-memory agent to scan for staleness, duplicates, contradictions, redaction misses, and uncategorized memories. Output renders to chat only — no on-disk artifact. | `--staleness-days` |

For the full flag list and gate semantics of each subcommand, see:
- [Subcommand: save](SKILL.md#subcommand-save)
- [Subcommand: recall](SKILL.md#subcommand-recall)
- [Subcommand: list](SKILL.md#subcommand-list)
- [Subcommand: forget](SKILL.md#subcommand-forget)
- [Subcommand: search](SKILL.md#subcommand-search)
- [Subcommand: audit](SKILL.md#subcommand-audit)

## Storage Layout

```
~/.cross-memory/
├── user-global/
│   ├── MEMORY.md           # Index for user-global memories
│   └── <type>_<slug>.md    # Individual memory files
├── projects/
│   └── <project-slug>/
│       ├── MEMORY.md
│       └── <type>_<slug>.md
├── harnesses/
│   ├── claude-code/
│   │   ├── MEMORY.md
│   │   └── <type>_<slug>.md
│   ├── cursor/
│   │   ├── MEMORY.md
│   │   └── <type>_<slug>.md
│   └── generic/
│       ├── MEMORY.md
│       └── <type>_<slug>.md
├── archive/                # Superseded and forgotten predecessors
└── config.yaml             # Skill configuration
```

**Three scopes:**

- **`user-global`** — memories that apply across every project and every harness (preferences, identity rules, cross-project facts). Stored at `~/.cross-memory/user-global/`.
- **`project:<slug>`** — memories scoped to a single project, where `<slug>` is derived from the project's absolute path by replacing each occurrence of `:`, `\`, `/`, space, and `.` with `-`. Stored at `~/.cross-memory/projects/<slug>/`.
- **`harness:<name>`** — memories scoped to a specific harness (`claude-code`, `cursor`, or `generic`). Stored at `~/.cross-memory/harnesses/<name>/`. Useful for harness-specific keybindings, workflow rules, or adapter-level preferences.

The entire directory tree is provisioned lazily on first use — no manual setup required.

## Privacy and Redaction

Every memory body passes through a three-stage redaction pipeline before any disk write:

1. **Pass A — `<private>` strip.** Any content wrapped in `<private>...</private>` is replaced with `[REDACTED:private]`. This pass always runs; no flag can disable it.
2. **Pass B — regex denylist.** Eight pattern categories are detected and replaced automatically: `api-key`, `password`, `bearer-token`, `jwt`, `aws-secret`, `env-block`, `private-key-header`, `user-tagged-secret`.
3. **Confirmation gate.** The post-redaction candidate is displayed before any write is committed. When redaction fired, the default answer is N; you must type `y` or `Y` to proceed.

The **`--no-redact`** flag bypasses Pass B (the regex layer) for the current save only. It has no effect on Pass A — `<private>` markup is always honored. When `--no-redact` is set and Pass B would have matched, you must type the exact phrase `save unredacted` to confirm; a simple `y` does not suffice. This friction is intentional: pattern false-positives are real, but the confirmation phrase makes accidental bypass of a genuine secret structurally difficult.

See [redaction.md](redaction.md) for the full pattern table, the bounded-fallback rule for unmatched `<private>` open tags, and the `--no-redact` typed-phrase flow.

## Always-On Tier

At session start, the active harness adapter runs a filter over the canonical store and writes a `[CROSS-MEMORY]` block into a sentinel-bounded region of the harness-native `MEMORY.md`:

```
<!-- cross-memory:begin -->
[CROSS-MEMORY]

User Profile:
- <bullet>

Project Knowledge:
- <bullet>
<!-- cross-memory:end -->
```

The adapter owns only the bytes between the sentinel markers. Content outside those markers is preserved byte-identically across all cross-memory operations.

**Default-on filter rules** — memories are selected automatically when they match any of these:

- `user-global` scope, type in `{preference, rule, fact}` → appears in **User Profile**.
- `project:<current-slug>` scope, type in `{feedback, project, rule}` → appears in **Project Knowledge**.
- `harness:<current-harness>` scope, type in `{rule, feedback}` → folded into **User Profile**.
- Any memory tagged `always-on` across any scope → included regardless of type.

The block is capped at `max_inject_chars` (default 2048 bytes). When the block would exceed the budget, sub-sections are dropped in priority order: Project Knowledge drops before User Profile; the `[CROSS-MEMORY]` header is never dropped.

See [SKILL.md — Always-on tier](SKILL.md#always-on-tier) for the full filter spec and size-budget drop protocol.

## Audit

`/cross-memory audit` dispatches the cross-memory agent (opus-class) to scan the canonical store and return a structured report rendered directly to chat. No on-disk audit artifact is written at v1.

**What the audit flags:**

- **Staleness** — memories whose `verified_at` field is older than `staleness_threshold_days` (default 90 days).
- **Duplicates** — memories with overlapping name slugs or substantially overlapping content across scopes.
- **Contradictions** — memory pairs that share tags but have conflicting bodies.
- **Redaction misses** — body content that matches a denylist pattern but was not redacted (e.g., a pattern added to the denylist after the memory was originally saved).
- **Missing-category curation** — memories with no `category` field set, flagged for optional categorization.

**Per-finding actions** — after the report renders, you can act on any finding by typing the action name followed by the memory identifier (e.g., `refresh feedback_strict_lane_boundaries`):

| Action | What it does |
| :--- | :--- |
| `refresh` | Sets `verified_at` to today's UTC date. |
| `archive` | Moves the memory to `~/.cross-memory/archive/`. |
| `forget` | Runs the full `/cross-memory forget` flow. |
| `redact-now` | Re-runs the redaction pipeline and supersedes the memory with the redacted version. |
| `categorize` | Sets the memory's `category` field to a value from the category enum. |

Every action goes through the standard write-path confirmation gate before any change is applied. The agent never auto-applies recommendations.

See [agents/cross-memory.md](../../agents/cross-memory.md) and [SKILL.md — Subcommand: audit](SKILL.md#subcommand-audit).

## Configuration

`~/.cross-memory/config.yaml` — created automatically on first use with the defaults below.

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `staleness_threshold_days` | integer | `90` | Memories with `verified_at` older than this many days are flagged stale by `recall`, the always-on tier, and `audit`. |
| `max_inject_chars` | integer | `2048` | Maximum bytes for the `[CROSS-MEMORY]` injection block. |
| `adapter` | string | (auto-detected) | Override harness auto-detection. Accepted values: `claude-code`, `cursor`, `generic`. |

**Note:** When running cross-memory inside a project that doesn't already have global Bash permissions for `file`, `readlink`, `stat`, and `test`, you may receive interactive permission prompts on first use. To suppress these, add the following to your project's `.claude/settings.json` (or your user-global `~/.claude/settings.json`):

```json
{
  "permissions": {
    "allow": [
      "Bash(file *)",
      "Bash(readlink *)",
      "Bash(stat *)",
      "Bash(test *)"
    ]
  }
}
```

The cross-memory agent uses these for read-only path resolution and existence checks during the audit flow. The cross-memory skill itself does not invoke Bash.

## Examples

```bash
# Save an explicit user-global preference
/cross-memory save --scope user-global --type preference "Always run pytest with -xvs."
# → displays confirmation prompt; type y to confirm
```

```
# Auto-proposed save after "from now on we use ruff for linting"
# Skill proposes:
┌─────────────────────────────────────────────────────────────┐
│ I'd like to save this as a memory. Confirm?                 │
│                                                             │
│ Scope: user-global    Type: preference    Tags: []          │
│ Name:  from-now-on-we-use-ruff-for-linting                  │
│                                                             │
│ Body (redacted candidate):                                  │
│ ─────                                                       │
│ from now on we use ruff for linting                         │
│ ─────                                                       │
│                                                             │
│ Save this memory? [y/N]                                     │
└─────────────────────────────────────────────────────────────┘
# Type y to confirm
```

```bash
# Recall memories by topic
/cross-memory recall "python testing"
# → returns matching memories ordered by scope + updated_at, with staleness banners if applicable

# List user-global rules only
/cross-memory list --scope user-global --type rule

# Forget a memory (moves to archive, not hard-deleted)
/cross-memory forget feedback_strict_lane_boundaries
# → prompts: Forget memory 'feedback_strict_lane_boundaries'? [y/N]

# Search verbatim text across memory bodies
/cross-memory search "lane boundaries"
# → returns ~/.cross-memory/user-global/feedback_strict_lane_boundaries.md:3: ...lane boundaries...

# Audit the full store
/cross-memory audit

# Audit with a tighter staleness window
/cross-memory audit --staleness-days 60
```

## FAQ

**Q: How does cross-memory differ from Claude Code's native `~/.claude/projects/<slug>/memory/`?**

Cross-memory is the canonical store; `~/.claude/projects/<slug>/memory/` is a mirror written by the Claude Code adapter after every `save` and `forget`. Files in `~/.cross-memory/` survive harness changes and are portable across Claude Code, Cursor, and any other environment. The harness-native location is regenerated on demand from the canonical store; it is never the source of truth.

**Q: What happens to my existing Claude Code memory files when I start using cross-memory?**

Nothing changes immediately. The adapter refuses to overwrite any file that has neither a `mirrored_from` frontmatter field nor a sidecar manifest entry — pre-existing natively authored files are classified as `native` and are skipped. They remain byte-identical until you explicitly supersede them via `/cross-memory save`.

**Q: Can I share memories with a team?**

Not at v1. The three scopes are user-global, project, and harness — there is no team-shared scope. If you want manual sharing, add memories to a project scope (`project:<slug>`) and commit `~/.cross-memory/projects/<slug>/` to a shared repository.

**Q: How do I export my memories?**

Not at v1. Memories are plain Markdown files at `~/.cross-memory/`; copy the directory manually until `/cross-memory export` ships in a future release.

**Q: Why is there no on-disk audit report?**

Audit output grows linearly with audit cadence; persisting it would require a retention policy. The audit is a diagnostic, not a record. If you want a snapshot, save the chat output via your harness's standard transcript-save.
