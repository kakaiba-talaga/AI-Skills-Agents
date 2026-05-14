<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Subcommand: audit

Scan the canonical cross-memory store for staleness, duplicates, contradictions, redaction misses, and missing-category curation; render a structured five-section report directly to chat; and offer per-finding actions (refresh, archive, forget, redact-now, categorize) gated by the standard write-path confirmation. No file is written to disk for the audit report.

### Command syntax

```
/cross-memory audit [--staleness-days <N>]
```

`--staleness-days <N>` overrides the `staleness_threshold_days` config field for the duration of this invocation. Any other value passed is validated as a positive integer; a non-integer or negative value aborts with a structured error.

### Default values

The staleness threshold defaults to the `staleness_threshold_days` config field (default `90`). When `--staleness-days <N>` is passed, that value supersedes the config field for this invocation only. See `## Config` for the field definition and the config file location.

### Step 1 — Build the brief

Compose the labeled-prose brief per the `## Brief Format` section in `agents/cross-memory.md`. The effective staleness threshold `<N>` is the CLI flag value if `--staleness-days` was passed, else the `staleness_threshold_days` config field value, else `90`.

```
## Task
Audit the cross-memory store for staleness, duplicates, contradictions, redaction misses, and missing-category curation.

## Scope
- ~/.cross-memory/** (read)
- ~/.claude/projects/<active-slug>/memory/MEMORY.md (read; for sentinel-block refresh)
- ~/.claude/projects/<active-slug>/memory/<type>_<slug>.md (read; for mirror collision detection)

## Acceptance Criteria
1. A structured report rendered to chat with the five sections: Stale memories, Duplicates, Contradictions, Redaction misses, Recommended actions.

## Constraints
[Shared Brief Constraints — see skills/ops/SKILL.md#shared-brief-constraints]
- intent: audit
- staleness_threshold_days: <N>
```

### Step 2 — Dispatch the cross-memory agent

Dispatch via the Agent tool with `subagent_type: cross-memory` and the brief built in Step 1. The agent is `model: opus` and reads its own definition at `agents/cross-memory.md` as its first action; the skill does not paste the agent body into the dispatch prompt. The agent inherits the per-agent self-read prompt template documented in `agents/cross-memory.md`.

### Step 3 — Render the agent's report

The agent's return value is a fenced markdown block matching the `## Output Contract — audit` shape in `agents/cross-memory.md`: five sections (Stale memories, Duplicates, Contradictions, Redaction misses, Recommended actions). The skill renders this block directly to chat.

No file is written to disk for the audit report. There is no `~/.cross-memory/audit-reports/` directory; the lazy-provisioning sequence in `## Config` does not create one. The environment block of the report names the active harness and the precedence step that selected it, consistent with the selection-logging behavior described in `adapter-selection.md`.

### Step 4 — Per-finding actions

After rendering the report, the skill presents the available per-finding actions. The user picks an action by typing the action name followed by the memory identifier (e.g., `refresh feedback_strict_lane_boundaries`). The skill never auto-applies any action — every action goes through its respective confirmation gate before any change is made.

| Action | What it does | Confirmation gate |
| :--- | :--- | :--- |
| `refresh` | Sets the memory's `verified_at` frontmatter field to today's ISO-8601 UTC date | Standard write-path confirmation (mirror of save Gate 3-4): display the updated frontmatter, prompt `[y/N]`, require `y` or `Y` to proceed |
| `archive` | Moves the memory file to `~/.cross-memory/archive/<scope>/<original-stem>-<timestamp>.md` | Standard write-path confirmation: display the target archive path, prompt `[y/N]`, require `y` or `Y` to proceed |
| `forget` | Dispatches the full `/cross-memory forget <name>` flow | Standard forget-flow confirmation: `Forget memory '<name>'? It will be archived but not auto-deleted. [y/N]` — require `y` or `Y` (case-insensitive) |
| `redact-now` | Re-runs the redaction pipeline on the body and supersedes the memory with the redacted version | Standard save Gate 2-4 (redaction scan → confirm → write), treating the supersede branch as the write path |
| `categorize` | Sets the memory's `category` frontmatter field to a user-chosen value from the five-value enum | Standard save Gate 3-4: display the updated frontmatter with the chosen category, prompt `[y/N]`, require `y` or `Y` to proceed |

On any input other than a recognized action-plus-identifier, the skill re-displays the action menu. The session ends when the user issues an empty line or types `done`.

### Cross-references

- **Gate 3-4 write-path confirmation pattern**: `subcommand-save.md`.
- **Full forget flow**: `subcommand-forget.md`.
- **Agent brief format and output contract**: `agents/cross-memory.md` (`## Brief Format` and `## Output Contract — audit`).
- **`staleness_threshold_days` config field**: `## Config` above.
- **Harness selection and audit environment block**: `adapter-selection.md` (the audit report's environment block names the active harness and the step that selected it).
