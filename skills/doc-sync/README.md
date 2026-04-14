# Doc Sync

Audits project documentation against the current codebase and fixes what's stale, incomplete, or orphaned. Covers Markdown, reStructuredText, Mermaid diagrams, and MDC files.

## How it works

```
Discover docs --> Detect staleness --> Present findings --> Apply updates --> Summary & rule generation
```

1. Globs for documentation files and pairs them with the code they describe
2. Reads each doc alongside its associated code to find mismatches
3. Presents findings grouped by file with severity levels
4. Applies targeted edits you approve (preserving tone and structure)
5. Offers to generate a doc-to-code map in CLAUDE.md for future syncs

## Quick start

```bash
# Audit all project documentation
/doc-sync

# Audit docs related to a specific directory
/doc-sync src/api/

# Report only -- find issues but don't fix anything
/doc-sync --report-only

# Report only for a specific scope
/doc-sync --report-only src/auth/
```

## Flags

| Flag | Effect |
|---|---|
| `--report-only` | Detect and report staleness without applying any edits |
| `<path>` | Scope the audit to docs related to a specific directory or file |

## What it finds

Every finding is classified by severity:

| Severity | Meaning | Example |
|---|---|---|
| **Stale** | Doc contradicts current code | README says `--verbose` flag exists, but it was removed |
| **Incomplete** | Code has features the doc doesn't mention | New `--format json` option added but not documented |
| **Orphaned** | Doc describes something that no longer exists | Section about `legacy_auth` module that was deleted |
| **Drift** | Diagram and prose disagree with each other | Mermaid flowchart shows 3 steps but prose describes 4 |

## What it audits

**File types discovered:**
- `**/*.md` -- Markdown documentation
- `**/*.rst` -- reStructuredText
- `**/*.mdc` -- MDC rule files
- `**/*.mermaid` -- Mermaid diagrams (paired with same-name `.md` files)

**Always excluded:**
- `.venv/`, `node_modules/`, `__pycache__/`, `.git/`, `.pytest_cache/`
- Vendored and third-party directories

## Documentation map

The skill looks for an existing doc-to-code map that tells it which docs describe which code. It checks in order:

1. A "Documentation Sync" or "Documentation map" section in `<project-root>/CLAUDE.md`
2. `.cursor/rules/documentation-sync.mdc` (from a Cursor setup)

If neither exists, relationships are inferred from file names, directory co-location, and content references. After the audit, the skill offers to save the inferred map to CLAUDE.md so future syncs are faster and more accurate.

## Workflow details

### Step 1: Discovery

Globs for doc files, applies exclusions and scope filter, pairs Mermaid diagrams with their companion Markdown files. Reports what was found.

### Step 2: Staleness detection

For each doc, reads it alongside its associated code/config. Compares function signatures, CLI flags, config keys, module names, and workflow descriptions against what actually exists in the codebase. For diagrams, checks whether nodes and edges match the companion prose.

For large doc sets (10+ files), groups by code area and runs up to 4 parallel sub-tasks.

### Step 3: Findings presentation

Groups findings by file, shows severity for each, and asks you to confirm which to fix. Default: fix all. If `--report-only`, stops here.

### Step 4: Apply updates

For each confirmed finding:
- Makes targeted edits (not full rewrites)
- Preserves the doc's existing tone, structure, and detail level
- Updates Mermaid diagrams (nodes, edges, labels) and verifies syntax
- Updates multiple docs consistently when they reference the same concept

### Step 5: Summary and rule generation

Presents the final summary. If no documentation map was found in step 1, offers to append one to CLAUDE.md with three options:
- Append the documentation sync section to CLAUDE.md
- Let me review and adjust before appending
- Skip for now

## Smart deferral

The skill knows when NOT to sync docs:

**Defers during debugging/experimental work:**
- Adding/removing print statements or logging for troubleshooting
- Commenting out code to isolate a bug
- Temporary workarounds marked with TODO/FIXME/HACK
- Changes the user describes as "trying something" or "testing"

**Defers during Ralph Loop iterations:**
- When the Ralph Loop skill is active (badge present, state file with `status: active`)
- Loop iterations are incremental and may be reverted
- Syncs docs only after the loop completes or the user explicitly exits

## Output format

Every message starts with the **`Doc Sync`** badge. The final summary includes:

```
## Doc sync summary

- **Scope**: src/api/ (scoped)
- **Docs scanned**: 8
- **Result**: 4 finding(s) fixed | 1 finding(s) skipped | 0 new gaps

### Files updated
- docs/api.md: Updated endpoint list, removed deprecated /v1/auth section
- README.md: Added --format flag documentation

### Findings skipped (if any)
- docs/architecture.md — deployment section: User chose to skip

### New gaps discovered (if any)
- src/api/webhooks.py has no documentation
```

Non-trivial audits always produce at least two messages: discovery/scope, then findings, then summary. The skill never runs silently and dumps a single report.

## Examples

### Basic auditing

```bash
# Audit everything
/doc-sync

# Audit docs in a specific area
/doc-sync src/auth/

# Audit docs for a specific file's area
/doc-sync src/api/routes.ts
```

### Report-only mode

```bash
# Find issues but don't touch anything
/doc-sync --report-only

# Report on a specific directory
/doc-sync --report-only src/api/

# Report on the whole project before deciding what to fix
/doc-sync --report-only
```

### Scoped audits

```bash
# Only docs related to the API
/doc-sync src/api/

# Only docs related to authentication
/doc-sync src/auth/

# Only docs related to the CLI
/doc-sync src/cli/

# Only docs related to database models
/doc-sync src/models/

# Only docs in the docs/ directory itself
/doc-sync docs/
```

### After code changes

```bash
# After renaming a module -- find docs that reference the old name
/doc-sync

# After adding new CLI flags -- find docs that are now incomplete
/doc-sync src/cli/

# After deleting a feature -- find orphaned docs
/doc-sync --report-only

# After a large refactor -- full audit
/doc-sync
```

### With other skills

```bash
# After Ralph Loop completes -- sync docs for what changed
/doc-sync

# After code review fixes -- update related docs
/doc-sync src/api/

# Before a release -- full audit, report first
/doc-sync --report-only
```
