Audit project documentation against the current codebase and update stale, inaccurate, or incomplete sections. Arguments: $ARGUMENTS

Parse the arguments as follows:

- If `--report-only` is present, detect and report staleness without applying any edits. Still present the full findings report using the output template.
- Treat the first **non-flag** token that looks like a path or directory as the **scope** (prefix filter). Only audit docs related to that scope. If no scope is given, audit all project documentation.
- Always **exclude** `.venv/`, `node_modules/`, `__pycache__/`, `.git/`, `.pytest_cache/`, and vendored/third-party directories from the doc discovery.

## Documentation map

Check for an existing doc-to-code map in this order: (1) a "Documentation Sync" or "Documentation map" section in `<project-root>/CLAUDE.md`, (2) `.cursor/rules/documentation-sync.mdc` (may exist from a Cursor setup). Use the first found. If neither exists, infer relationships from file names, directory co-location, and content references, and record the inferred map for rule generation in step 5.

## Staleness severity levels

| Severity | Meaning |
| :--- | :--- |
| **Stale** | Doc contradicts current code. |
| **Incomplete** | Code has new features/options not mentioned in the doc. |
| **Orphaned** | Doc describes something that no longer exists in the codebase. |
| **Drift** | Diagram and prose disagree with each other. |

## Workflow

1. **Discover documentation** — Glob for `**/*.md`, `**/*.mdc`, `**/*.mermaid`, `**/*.rst` from the project root; apply exclusions and scope filter. Pair `*.mermaid` with `*.md` sharing the same base name. Announce: **`Doc Sync`** N file(s) to audit: ...
2. **Detect staleness** — For each doc, read it and its associated code/config. Flag sections where the doc no longer matches the code. For diagrams, check whether the companion prose matches. Build a staleness report with severity per finding.
3. **Present findings** — Send a **`Doc Sync`**-first message with findings grouped by file. Ask the user to confirm which to fix (default: all). If `--report-only`, skip to step 5 after presenting.
4. **Apply updates** — For each confirmed finding, make targeted edits. Preserve tone, structure, and detail level. For Mermaid diagrams, update nodes/edges/labels. Re-read after editing. Update multiple docs consistently when they reference the same concept. Skip this step entirely if `--report-only`.
5. **Summary and rule generation** — Present a final **`Doc Sync`**-first message with the summary template. If no documentation map was found at step 1 (neither in `CLAUDE.md` nor `.cursor/rules/documentation-sync.mdc`), offer to append a "Documentation Sync" section to `<project-root>/CLAUDE.md` using the inferred doc-to-code map (create the file if it doesn't exist). The section should include the map table and standard rules (targeted edits, preserve tone, check diagrams, defer during debugging/experimental and Ralph Wiggum Loop). Ask the user to choose: "Append the documentation sync section to CLAUDE.md.", "Let me review and adjust before appending.", or "Skip for now."

## Parallelization

For large doc sets (10+ files), group docs by code area and run up to 4 parallel sub-tasks, one per group. Each sub-task runs step 2 for its group and returns a partial staleness report. Merge before step 3.

## Output template

```text
## Doc sync summary

- **Scope**: [directory / all / explicit paths]
- **Docs scanned**: [count]
- **Result**: [N finding(s) fixed | M finding(s) skipped | all clean]

### Files updated
- [path]: [brief change note]

### Findings skipped (if any)
- [path — section]: [reason]

### New gaps discovered (if any)
- [description of undocumented code or missing docs]
```

## Constraints

- Do not create new documentation files unless the user explicitly asks.
- Do not restructure or reformat docs beyond what is needed for accuracy.
- Do not remove content unless it is clearly orphaned and the user confirms.
- Keep Mermaid diagrams syntactically valid — verify after edits.
- If the project has no documentation map (neither in `CLAUDE.md` nor `.cursor/rules/documentation-sync.mdc`), offer to append one to `CLAUDE.md` in step 5 (see rule generation above). This is the only file the skill may create or modify without the user explicitly asking — but it still requires user confirmation before writing.
- Defer documentation updates when the change appears to be debugging, experimental, or exploratory — for example: adding/removing print statements or logging for troubleshooting, commenting out code to isolate a bug, temporary workarounds marked with TODO/FIXME/HACK, changes the user explicitly describes as "trying something" or "testing". Resume doc sync once the change is finalized or the user confirms the approach is permanent.
- Defer documentation updates when the Ralph Wiggum Loop skill is active (i.e. the assistant message carries the **`Ralph Loop`** badge, a state file with `status: active` exists, or the `/ralph-loop` command is running). Loop iterations are incremental and may be reverted or refined. Sync docs only after the loop completes (`status: done`) or the user explicitly pauses/exits the loop.
- No compound Bash commands — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls instead — use parallel calls for independent commands.
- No `cd` prefix — the working directory is already the project root. Run commands directly instead of `cd "/path/to/project" && command`.
- Use relative paths from the project root — never use absolute paths in Bash commands. Use `.venv/3.11/Scripts/python.exe`, `data/output/`, etc. Only use absolute paths for resources genuinely outside the project (e.g., `~/.claude/`).
- Temporary files go in the **project root** (e.g., `_tmp_test.py`, `_tmp_payload.json`) — never in `/tmp/`, `%TEMP%`, or any path outside the project. Paths outside the project trigger sensitive-file prompts. Use the `_tmp_` prefix. Delete only the files you created, one `rm` per file. Never `rm _tmp_*` — the glob also removes another agent's scratch files and prior runs' artifacts, some of which cannot be regenerated.

## Output tagging

**`Doc Sync`** appears on the **opening line** of each assistant turn only. Do **not** prefix every bullet or heading in the same turn.

The **first line** of each assistant turn for this command MUST begin with: **`Doc Sync`**

Use **at least two user-facing turns** for non-trivial audits: discovery/scope, then findings, then summary. If constrained to one turn, first line = **`Doc Sync`** + short progress sentence, **then** the summary block.

**Anti-pattern:** Running the entire audit silently and sending one message with only the summary. Avoid this.

**Format:** **`Doc Sync`** (bold backtick-wrapped) as the **first element** on the **opening line** of the turn.

Examples:

- **`Doc Sync`** Found 14 documentation files (12 prose, 2 diagrams) across 6 code areas. Confirming scope...
- **`Doc Sync`** Staleness report: 5 findings across 3 files (2 stale, 2 incomplete, 1 drift).
- **`Doc Sync`** Audit complete — 4 findings fixed, 1 skipped.
