# Active Skill Detection — Cross-Memory Row

## What this diff does

Adds one row to the **Active Skill Detection** table in `~/.claude/CLAUDE.md`, registering the `/cross-memory` skill so the re-invoke reminder fires mid-session when the skill lapses.

New row:

| Skill | Badge | Typical mid-run signals |
| :--- | :--- | :--- |
| `/cross-memory` | **`Cross-Memory`** | Subcommand activity (save/recall/list/forget/search/audit), confirmation gates, audit reports, supersede flow |

Insertion point: between `/commit-message` and `/doc-sync` — consistent with the alphabetical ordering of the lower block in that table.

## How to apply

From your home directory (`C:\Users\Maris Reyes`), run:

```powershell
patch -p0 -i "D:\Repositories\Personal\Git\AI-Skills-Agents\docs\cross-memory\handoff\cross-memory-active-skill-detection.diff"
```

Or apply manually: open `~/.claude/CLAUDE.md`, locate the Active Skill Detection table, and insert the new row between the `/commit-message` and `/doc-sync` rows.

## Before applying

Verify the patch still applies cleanly against your current `~/.claude/CLAUDE.md`:

```powershell
patch -p0 --dry-run -i "D:\Repositories\Personal\Git\AI-Skills-Agents\docs\cross-memory\handoff\cross-memory-active-skill-detection.diff"
```

If the dry-run reports a failure (e.g., "Hunk FAILED"), your local `CLAUDE.md` has diverged from the version this diff was generated against. In that case, apply the row manually using the table above.

## Generation metadata

- Generated: 2026-05-09
- Against: `~/.claude/CLAUDE.md` — Active Skill Detection table, lines 37-49
- Insertion: after line 46 (`/commit-message` row), before line 47 (`/doc-sync` row)
- Badge source: `skills/cross-memory/SKILL.md` — `## Output Tagging` section
- `~/.claude/CLAUDE.md` was NOT modified — this is a read-only source for this task.
