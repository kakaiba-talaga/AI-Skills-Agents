# Kickoff

Sets up a new project's planning infrastructure from scratch. When you run `/kickoff`, it copies planning templates into your project, interviews you about what you're building, dispatches a chain of AI agents to design and plan the work, and hands off a ready-to-execute queue to `/next`.

Use it at the beginning of a new project before any code exists.

## How it works

```
Scaffold templates --> Interview --> [Architect] --> Plan --> [Critique] --> [Scope] --> Populate --> Configure --> Handoff to /next
                                        ^                        ^              ^
                                   complex only            complex only   optional
```

1. **Scaffold** — copies `plan/INDEX.md`, `plan/QUEUE.md`, `plan/BLOCKERS.md`, `plan/PLAN-STUB-TEMPLATE.md`, and `.claude/commands/next.md` into your project directory.
2. **Interview** — the `interviewer` agent gathers your project vision, scope boundaries, platforms, milestones, technical constraints, and acceptance criteria. Output lands in `docs/kickoff-requirements.md`.
3. **Architecture** *(complex projects only)* — the `architect` agent explores design alternatives and produces `docs/kickoff-architecture.md`.
4. **Plan** — the `planner` agent breaks the project into numbered plan documents (`plan/01-*.md`, `plan/02-*.md`, etc.), phases, and milestones.
5. **Critique** *(complex projects only)* — the `critic` agent validates the plan for feasibility and completeness. The planner revises up to twice if the critic rejects.
6. **Scope** *(optional, prompted)* — the `project-scoper` agent adds effort estimates and a gap analysis. Does not block the workflow if skipped or if it fails.
7. **Populate** — fills `plan/INDEX.md`, `plan/QUEUE.md`, and `plan/BLOCKERS.md` with concrete content from the planner's output. Creates individual plan stub documents from the template.
8. **Configure** — generates `.claude/settings.json` in the target project with tech-stack-derived Bash permissions, universal tool/shell/git permissions, and deny rules. If the file already exists, new entries are merged in.
9. **Handoff** — displays a summary of everything created (including the permissions configured) and tells you to run `/next` to begin executing.

## Quick start

```bash
# Standard kickoff — interview + auto-detect complexity
/kickoff

# Scaffold into a specific directory
/kickoff --dir ./my-project

# Skip architect and critic (force simple mode)
/kickoff --simple

# Force architect + critic regardless of project size
/kickoff --complex

# Scaffold template files only — no interview, no planning
/kickoff --dry-run

# Scaffold into a directory, dry run only
/kickoff --dry-run --dir ./my-project
```

## Flags

| Flag | Effect |
|---|---|
| `--dir <path>` | Target directory for scaffolded output. Defaults to the current working directory. |
| `--simple` | Skip architect and critic passes. Use for small, well-understood projects. |
| `--complex` | Force architect and critic passes regardless of auto-detect verdict. |
| `--dry-run` | Scaffold template files only. No interview, planning, or population. Stops after Phase 1. |
| `help` | Display a usage summary of flags and phases, then stop. |

**Complexity auto-detection** (when neither `--simple` nor `--complex` is passed):

| Project signals | Result |
|---|---|
| ≤ 2 milestones, single platform, no external integrations | Simple — architect + critic skipped |
| > 4 milestones, > 2 platforms, or significant integration complexity | Complex — architect + critic run |
| Anything else | Prompts: "Run the full architect + critic review? [Y/n]" |

## What gets created

After a full kickoff run, your project directory contains:

```
docs/
  kickoff-requirements.md       # Interview output — project requirements
  kickoff-architecture.md       # Architect output (complex only)
  kickoff-scoping.md            # Project-scoper output (Phase 5.5, opt-in only)

plan/
  INDEX.md                      # Master plan index — vision, milestones, acceptance criteria
  QUEUE.md                      # Ordered execution queue consumed by /next
  BLOCKERS.md                   # Hard gates and human-action items
  PLAN-STUB-TEMPLATE.md         # Template used to generate new plan docs mid-project
  01-<name>.md                  # Plan stub — one file per numbered plan
  02-<name>.md
  ...

.claude/commands/
  next.md                       # The /next command for phase-by-phase execution

.claude/
  settings.json                 # Tech-stack-derived permissions (Phase 6.5 Configure; merged if it already exists)
```

`--dry-run` creates only the `plan/` files and `.claude/commands/next.md`. It does not create the `docs/` files.

## Agent chain

Each phase dispatches a specific agent. Agents marked *conditional* only run based on complexity detection or user opt-in.

| Phase | Agent | Output | Conditional? |
|---|---|---|---|
| 2 — Interview | `interviewer` | `docs/kickoff-requirements.md` | No |
| 3 — Architecture | `architect` | `docs/kickoff-architecture.md` | Yes — complex only |
| 4 — Plan | `planner` | `plan/NN-*.md` files | No |
| 5 — Critique | `critic` | Revision notes fed back to planner | Yes — complex only |
| 5.5 — Scope | `project-scoper` | Effort estimates added to the plan | Yes — user opt-in |

The critic can send the plan back to the planner for revisions. This loops up to twice. If the plan still fails after two rounds, kickoff proceeds with a risk warning rather than blocking indefinitely.

The project-scoper is always optional — kickoff prompts you before dispatching it. If it fails or produces no output, kickoff logs a note and continues without blocking.

## Integration with `/next`

`/next` is the execution engine that works through the queue kickoff creates. After kickoff finishes:

1. `plan/QUEUE.md` contains one row per phase, ordered for execution.
2. Each row links to its plan document (`plan/NN-name.md`).
3. The `Current Position` header in `QUEUE.md` names the first phase to run.

Running `/next` picks up from that position. It reads the plan document, investigates the implementation approach, dispatches build and review agents, updates the queue when a phase completes, and advances to the next one.

You can run `/kickoff` and immediately follow with `/next` — the hand-off is designed to require no manual setup between them.

## Template markers

Template files use `<!-- KICKOFF:FIELD_NAME -->` HTML comment markers as insertion points. Phase 6 (Populate) finds each marker and replaces it with content from the planner's output.

If you use `--dry-run` and intend to populate the templates manually, these are the markers and what goes in each:

### `plan/INDEX.md`

| Marker | What to put there |
|---|---|
| `<!-- KICKOFF:PROJECT_NAME -->` | Project name (also update the `h1` title line) |
| `<!-- KICKOFF:VISION -->` | 2–4 sentence vision statement |
| `<!-- KICKOFF:PLATFORMS -->` | Markdown table rows — one per target platform |
| `<!-- KICKOFF:PLAN_DOCUMENTS -->` | Markdown table rows — one per numbered plan file |
| `<!-- KICKOFF:MILESTONES -->` | Milestone headings with version, name, and bullet deliverables |
| `<!-- KICKOFF:ACCEPTANCE_CRITERIA -->` | Checklist of non-negotiable v1.0 acceptance criteria |
| `<!-- KICKOFF:DEFERRED_ITEMS -->` | Table rows for deferred items, or `*(none)*` |

Also fill in the `> **Created:**` date in `YYYY-MM-DD` format.

### `plan/QUEUE.md`

| Marker | What to put there |
|---|---|
| `<!-- KICKOFF:CURRENT_POSITION -->` | First phase to execute (e.g., `Plan 01 — Phase 1.1`) |
| `<!-- KICKOFF:QUEUE_ENTRIES -->` | Full queue table — one row per phase, organized by milestone |

Also fill in the `> **Updated:**` date.

### `plan/BLOCKERS.md`

| Marker | What to put there |
|---|---|
| `<!-- KICKOFF:BLOCKERS -->` | Blocker entries using the format shown in the file, or `*(None at kickoff)*` |

Also fill in the `> **Updated:**` date.

### `plan/PLAN-STUB-TEMPLATE.md` (used to generate each plan doc)

| Marker | What to put there |
|---|---|
| `<!-- KICKOFF:PLAN_NUMBER -->` | Zero-padded number — e.g., `01`, `02` (replace all occurrences) |
| `<!-- KICKOFF:PLAN_NAME -->` | Human-readable plan name — e.g., `Project Scaffold` |
| `<!-- KICKOFF:PLAN_STATUS -->` | `PENDING` |
| `<!-- KICKOFF:CREATED_DATE -->` | Today's date in `YYYY-MM-DD` format |
| `<!-- KICKOFF:PLAN_OVERVIEW -->` | 2–4 sentence description of what the plan covers |
| `<!-- KICKOFF:PHASES -->` | Phase blocks from the planner's phase breakdown |
| `<!-- KICKOFF:DEFERRED_ITEMS -->` | Deferred items for this plan, or the placeholder row |

Stub files are named `plan/<NN>-<kebab-case-name>.md` — for example, `plan/01-project-scaffold.md`.

**Marker validation:** If any expected marker is missing from a template (because the file was edited after scaffolding), kickoff fails loudly and tells you which marker and file are affected. It does not write partial output. Re-scaffold or restore the marker, then retry.

## Error handling

| Phase | What happens on failure |
|---|---|
| **Scaffold** | Reports which files failed to copy. Stops — does not proceed to interview on a partial scaffold. |
| **Interview** | Prompts you to retry or proceed with partial requirements. Proceeding still requires a minimum set (project name, ≥1 milestone, ≥1 acceptance criterion) before the planner runs. |
| **Architecture** | Logs the failure, proceeds to planning with requirements only. Not a hard stop. |
| **Plan** | Escalates to you. Does not attempt populate without plan files on disk. |
| **Critique** | After 2 failed revision rounds, proceeds with a risk warning. |
| **Scope** | Logs "Scope estimates unavailable." Proceeds to populate without blocking. |
| **Populate** | Fails loudly if any marker is missing. Reports which files succeeded and which failed. Waits for you to fix before retrying. |
| **Configure** | If `.claude/settings.json` cannot be written, logs a warning and proceeds to handoff. Not a hard stop. |

## Conflict detection

If `plan/` or `.claude/commands/next.md` already exist in the target directory when you run kickoff, it stops and offers three options:

- **Overwrite** — replaces existing files.
- **Merge** — copies only files that do not already exist (safe, additive).
- **Abort** — stops without making any changes.

Your choice is required before kickoff proceeds.
