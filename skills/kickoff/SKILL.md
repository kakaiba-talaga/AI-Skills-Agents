Scaffold a new project's planning infrastructure, interview the user, dispatch planning agents, and populate template files ready for `/next` to execute. Arguments: $ARGUMENTS

Parse the arguments as follows:

- `help` — display a usage summary of flags and phases, then stop.
- `--dir <path>` — target directory for scaffold output. Defaults to the current working directory.
- `--complex` — force architect + critic passes regardless of auto-detect verdict.
- `--simple` — skip architect and critic passes regardless of auto-detect verdict.
- `--dry-run` — scaffold template files only; do not interview, plan, or populate.

If `help` is the argument, display a brief summary of the above flags and the 7 phases, then stop.

---

## Output Tagging

**`Kickoff`** appears on the **opening line** of each assistant turn only. Do **not** prefix every bullet or heading in the same turn.

The **first line** of each assistant turn for this command MUST begin with: **`Kickoff`**

Continuation lines within the same turn (sub-items, indented details, bullet lists, tables) do NOT repeat the badge. Only the opening line carries it.

Apply the badge on turns that contain: phase announcements, status/progress messages, interview prompts, agent dispatch notifications, error messages, and the final handoff summary.

**Format:** **`Kickoff`** (bold backtick-wrapped) as the **first element** on the **opening line** of the turn.

---

## Scope Classification Gate

After Phase 2 (Interview) completes, classify the project scope. This determines whether architect and critic passes run.

**Override flags always win.** If `--complex` or `--simple` was passed, apply it immediately without running the heuristic.

**Auto-detect heuristic** (only when no override flag is present):

| Signal | Classification |
| :--- | :--- |
| ≤ 2 milestones AND single platform AND no external integrations | **simple** — skip architect + critic |
| > 4 milestones OR > 2 platforms OR significant integration complexity | **complex** — run architect + critic |
| Anything else (borderline) | Ask the user: "This project looks moderately complex. Run the full architect + critic review? [Y/n]" |

Record the classification verdict before proceeding to Phase 3.

---

## Phase 1 — Scaffold

**Goal:** Copy template files into the target directory so all subsequent phases have a home for their output.

1. Resolve the target directory from `--dir <path>` or default to cwd.
2. **Conflict detection:** Check whether `plan/` or `.claude/commands/next.md` already exist in the target directory.
   - If either exists, present the user with three options:
     - **Overwrite** — replace existing files (destructive).
     - **Merge** — copy only files that do not already exist (safe, additive).
     - **Abort** — stop without making changes.
   - Wait for the user's choice before proceeding.
3. Copy the following from `~/.claude/skills/kickoff/project-template/` into the target directory, preserving directory structure:
   - `plan/INDEX.md`
   - `plan/QUEUE.md`
   - `plan/BLOCKERS.md`
   - `plan/PLAN-STUB-TEMPLATE.md`
   - `.claude/commands/next.md`
4. **Post-scaffold verification:** Read each target file back to confirm it exists. If any file is missing, report which ones failed and stop — do not proceed to interview.
5. If `--dry-run` was passed, display the list of scaffolded files and stop. Do not proceed to Phase 2.

---

## Phase 2 — Interview

**Goal:** Gather structured requirements from the user via the `interviewer` agent.

Dispatch the `interviewer` agent with a brief that covers:

- Project vision — what is being built, who it is for, what problem it solves.
- Scope boundaries — what is explicitly in scope and out of scope for v1.
- Target platforms — how many, which ones, any platform-specific constraints.
- Key milestones — major shippable checkpoints and rough sequencing.
- Technical constraints — languages, frameworks, existing systems to integrate with.
- External dependencies — third-party APIs, services, credentials, or human approvals needed.
- Acceptance criteria — the non-negotiable conditions that define project success.

The interviewer writes a requirements document to `docs/kickoff-requirements.md` in the target directory. This file is the source of truth for all downstream phases.

After the interviewer agent returns, verify that `docs/kickoff-requirements.md` exists in the target directory. If it is missing, apply the error handling rules below.

The requirements document feeds the Scope Classification Gate and Phases 3–6.

---

## Phase 3 — Architecture (conditional)

**Runs only when scope = complex (or `--complex` flag was passed).**

If scope is simple, skip this phase and proceed directly to Phase 4.

Dispatch the `architect` agent with the requirements document (`docs/kickoff-requirements.md`) as input. The architect produces an Architecture Decision Document (ADD) at `docs/kickoff-architecture.md` in the target directory.

After the architect returns, verify that `docs/kickoff-architecture.md` exists. If it is missing, apply error handling rules below.

The ADD supplements the requirements document as input to Phase 4.

---

## Phase 4 — Plan

**Goal:** Produce a structured execution plan compatible with the `/next` workflow.

Dispatch the `planner` agent with:

- `docs/kickoff-requirements.md` (always)
- `docs/kickoff-architecture.md` (only if Phase 3 ran)

The planner must produce:

- Numbered plan documents: `01-<name>.md`, `02-<name>.md`, etc. (zero-padded, kebab-case names). Written to the target directory's `plan/` folder.
- A milestones list with plan assignments.
- A phase execution sequence compatible with `plan/QUEUE.md` format.
- Any blockers or human-action gates identified during planning.

The planner writes all output to disk. Phase 6 (Populate) reads from disk — planner output in chat only is not sufficient.

After the planner returns, verify that at least one numbered plan file exists in `plan/`. If none exist, apply error handling rules below.

---

## Phase 5 — Critique (conditional)

**Runs only when scope = complex (or `--complex` flag was passed).**

If scope is simple, skip this phase and proceed to Phase 5.5.

Dispatch the `critic` agent to review the planner's output. The critic evaluates plan completeness, dependency correctness, milestone feasibility, and alignment with requirements.

**Verdict routing:**

| Verdict | Action |
| :--- | :--- |
| **ACCEPT** | Proceed to Phase 5.5. |
| **REVISE** | Return to Phase 4. Dispatch `planner` again with the critic's revision notes appended to the brief. Maximum 2 revision rounds. |
| **REJECT** | Treat as REVISE. If this is the second REJECT/REVISE, proceed to Phase 5.5 with a warning: "Plan was not approved after 2 revision rounds. Proceeding with risk noted." |

Track the revision count. After 2 failed rounds, do not loop again — proceed and note the risk.

---

## Phase 5.5 — Scope (optional)

Dispatch the `project-scoper` agent to enrich the plan with effort estimates and gap analysis.

The scoper's output is **informational, not blocking**. It adds estimates to the plan but does not restructure it. Gap findings are presented to the user as advisory information.

Before dispatching, ask the user: "Would you like effort estimates and a gap analysis from the project-scoper? This adds a short analysis pass but does not block the workflow. [Y/n]"

If the user opts out, skip this phase and proceed to Phase 6.

If the scoper fails or produces no output, log a note ("Scope estimates unavailable — proceeding without them") and proceed to Phase 6 without blocking.

---

## Phase 6 — Populate

**Goal:** Fill the scaffolded template files with planner output.

This is the core output phase. Read all planner output from disk, then apply the following writes.

### Marker Validation

Before writing, verify that each expected `<!-- KICKOFF:FIELD_NAME -->` marker is present in its target file. If any marker is missing, fail loudly:

> "Marker KICKOFF:<NAME> not found in <file>. Cannot populate. Check that the template was not modified after scaffold."

Do not proceed with partial population. Fix the missing marker or re-scaffold, then retry.

### INDEX.md

Replace the following markers in `plan/INDEX.md`:

| Marker | Content |
| :----- | :------ |
| `<!-- KICKOFF:PROJECT_NAME -->` | Project name (also update the `h1` title line) |
| `<!-- KICKOFF:VISION -->` | 2–4 sentence vision statement from requirements |
| `<!-- KICKOFF:PLATFORMS -->` | Markdown table rows for each target platform |
| `<!-- KICKOFF:PLAN_DOCUMENTS -->` | Markdown table rows — one row per numbered plan file |
| `<!-- KICKOFF:MILESTONES -->` | Milestone headings with version, name, and bullet deliverables |
| `<!-- KICKOFF:ACCEPTANCE_CRITERIA -->` | Checklist of non-negotiable v1.0 acceptance criteria |
| `<!-- KICKOFF:DEFERRED_ITEMS -->` | Table rows for any items deferred during planning, or *(none)* |

Also fill in the `> **Created:**` date with today's date in `YYYY-MM-DD` format.

### QUEUE.md

Replace the following markers in `plan/QUEUE.md`:

| Marker | Content |
| :----- | :------ |
| `<!-- KICKOFF:CURRENT_POSITION -->` | The first phase in the queue (e.g., `Plan 01 — Phase 1.1`) |
| `<!-- KICKOFF:QUEUE_ENTRIES -->` | Full queue table — one row per phase, organized by milestone |

Also fill in the `> **Updated:**` date with today's date.

### BLOCKERS.md

Replace the following marker in `plan/BLOCKERS.md`:

| Marker | Content |
| :----- | :------ |
| `<!-- KICKOFF:BLOCKERS -->` | Blocker entries from planning, using the template format in the file, or *(None at kickoff)* |

Also fill in the `> **Updated:**` date with today's date.

### Plan Stub Documents

For each numbered plan the planner identified, create a stub document using `plan/PLAN-STUB-TEMPLATE.md` as the template. Copy the template, then replace:

| Marker | Content |
| :----- | :------ |
| `<!-- KICKOFF:PLAN_NUMBER -->` | Zero-padded number (e.g., `01`, `02`) — replace all occurrences |
| `<!-- KICKOFF:PLAN_NAME -->` | Human-readable plan name (e.g., `Project Scaffold`) |
| `<!-- KICKOFF:PLAN_STATUS -->` | `PENDING` |
| `<!-- KICKOFF:CREATED_DATE -->` | Today's date in `YYYY-MM-DD` format |
| `<!-- KICKOFF:PLAN_OVERVIEW -->` | 2–4 sentence description of what the plan covers |
| `<!-- KICKOFF:PHASES -->` | Phase blocks populated from the planner's phase breakdown |
| `<!-- KICKOFF:DEFERRED_ITEMS -->` | Deferred items for this plan, or the placeholder row |

**Stub naming:** `plan/<NN>-<kebab-case-name>.md` (e.g., `plan/01-project-scaffold.md`).

Write each stub to disk. After all stubs are written, read each one back to confirm it exists.

---

## Phase 6.5 — Configure

**Goal:** Generate `.claude/settings.json` in the target project directory with a comprehensive set of permissions, deny rules, tool permissions, shell utilities, and optional plugin entries — all derived from the detected tech stack.

### Signal Sources

Read the following to detect the tech stack:

- `docs/kickoff-requirements.md` — look for languages, frameworks, and build tools mentioned in the technical constraints and requirements sections.
- The numbered plan files in `plan/` — look for any additional tooling or runtime references the planner identified.

### Tech Stack → Bash Permissions Mapping

Apply the following mapping for each detected signal. A signal matches if the corresponding language, framework, or tool is mentioned in the source documents (case-insensitive).

| Tech stack signal | Permission entries to include |
| :--- | :--- |
| Python | `Bash(python *)`, `Bash(pip *)`, `Bash(pytest *)` |
| Node.js / JavaScript | `Bash(npm *)`, `Bash(npx *)`, `Bash(node *)` |
| TypeScript | `Bash(npm *)`, `Bash(npx *)`, `Bash(tsc *)` |
| Rust | `Bash(cargo *)`, `Bash(rustc *)` |
| Go | `Bash(go *)` |
| C# / .NET | `Bash(dotnet *)` |
| Java | `Bash(mvn *)`, `Bash(gradle *)` |
| PHP | `Bash(composer *)`, `Bash(php *)` |
| Ruby | `Bash(bundle *)`, `Bash(ruby *)`, `Bash(rake *)` |
| Docker | `Bash(docker *)` |
| Terraform / IaC | `Bash(terraform *)` |

Deduplicate entries — if TypeScript is detected alongside Node.js, `Bash(npm *)` and `Bash(npx *)` appear only once in the final list.

### Tech Stack → Plugins Mapping

Check the tech stack signals against the table below. Include an `enabledPlugins` object in the output only when at least one signal matches. If no signal matches, omit `enabledPlugins` entirely.

| Tech stack signal | Plugin entries |
| :--- | :--- |
| Frontend (React, Vue, Angular, Svelte, Next.js, HTML/CSS, Tailwind) | `"frontend-design@claude-plugins-official": true` |

### Universal Tool Permissions

Always include the following tool entries in `allow`, regardless of detected tech stack:

```
"Agent", "Edit", "Glob", "Grep", "Read", "Skill", "Write",
"WebFetch", "WebSearch",
"TaskCreate", "TaskGet", "TaskList", "TaskOutput", "TaskStop", "TaskUpdate",
"EnterPlanMode", "ExitPlanMode"
```

### Universal Shell Utilities

Always include the following shell command entries in `allow`, regardless of detected tech stack:

```
"Bash(cat *)", "Bash(cp *)", "Bash(echo *)", "Bash(find *)",
"Bash(grep *)", "Bash(head *)", "Bash(ls *)", "Bash(mkdir *)",
"Bash(mv *)", "Bash(rm *)", "Bash(sed *)", "Bash(sort *)",
"Bash(tail *)", "Bash(touch *)", "Bash(wc *)", "Bash(which *)"
```

### Universal Git Permissions

Always include the following git entries in `allow`, regardless of detected tech stack:

```
"Bash(git status)", "Bash(git log *)", "Bash(git diff *)",
"Bash(git branch *)", "Bash(git stash *)"
```

### Universal Deny Rules

Always include the following `deny` array, regardless of detected tech stack:

```json
"deny": [
  "Bash(git branch -D *)",
  "Bash(git push --force *)",
  "Bash(git push origin main*)",
  "Bash(git push origin master*)",
  "Bash(git reset --hard*)",
  "Bash(rm -rf *)"
]
```

### Settings Structure

Write `.claude/settings.json` in the target project directory with this structure:

```json
{
  "permissions": {
    "allow": [
      // tool permissions (universal)
      "Agent", "Edit", "Glob", "Grep", "Read", "Skill", "Write",
      "WebFetch", "WebSearch",
      "TaskCreate", "TaskGet", "TaskList", "TaskOutput", "TaskStop", "TaskUpdate",
      "EnterPlanMode", "ExitPlanMode",
      // shell utilities (universal)
      "Bash(cat *)", "Bash(cp *)", "Bash(echo *)", "Bash(find *)",
      "Bash(grep *)", "Bash(head *)", "Bash(ls *)", "Bash(mkdir *)",
      "Bash(mv *)", "Bash(rm *)", "Bash(sed *)", "Bash(sort *)",
      "Bash(tail *)", "Bash(touch *)", "Bash(wc *)", "Bash(which *)",
      // git permissions (universal)
      "Bash(git status)", "Bash(git log *)", "Bash(git diff *)",
      "Bash(git branch *)", "Bash(git stash *)",
      // tech-stack-derived Bash permissions
      "Bash(<tech-stack-tool> *)"
    ],
    "deny": [
      "Bash(git branch -D *)",
      "Bash(git push --force *)",
      "Bash(git push origin main*)",
      "Bash(git push origin master*)",
      "Bash(git reset --hard*)",
      "Bash(rm -rf *)"
    ]
  },
  "enabledPlugins": {
    // only present if tech stack signals match a plugin entry above
  }
}
```

The `allow` array must contain only strings; no duplicates. Omit the `enabledPlugins` key entirely when no plugin signals are detected.

### Conflict Handling

Before writing, check whether `.claude/settings.json` already exists in the target directory.

- **File does not exist:** Create it fresh with the structure above.
- **File exists:** Read it first. Merge the generated `allow` entries into the existing `allow` array — add only entries not already present. Merge the generated `deny` entries into the existing `deny` array the same way. If `enabledPlugins` was generated and the key is absent from the existing file, add it; if the key already exists, merge only the new plugin entries. Preserve all other keys and values in the existing file exactly as they are. Do not overwrite the file wholesale; write back the merged result.

After writing, read the file back to confirm it was written correctly.

### Failure Handling

If the file cannot be written (e.g., `.claude/` directory does not exist and cannot be created), log a warning and proceed to Phase 7 without blocking:

> "Warning: Could not write `.claude/settings.json` — proceeding without it."

Record which permissions were skipped so Phase 7 can report them.

---

## Phase 7 — Handoff

Display a completion summary containing:

- **Files scaffolded:** list of all files created or populated, including `.claude/settings.json`.
- **Plans generated:** count and names of stub documents created.
- **Phases queued:** total number of phases across all plans.
- **Effort estimate:** total from project-scoper, or "N/A — scoper skipped" if Phase 5.5 was skipped.
- **First 3 phases in queue:** preview of what `/next` will execute first.
- **Permissions configured:** list the tech stack signals that were detected and the corresponding permission entries added to `.claude/settings.json`. If the file already existed and was merged, note which entries were new additions. If the file could not be written, note the failure here.

End with the instruction:

> "Your project plan is ready. Run `/next` to begin executing the first phase."

---

## Constraints

- **No compound Bash commands** — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls; use parallel calls for independent commands.
- **No `cd` prefix** — the working directory is already the project root. Run commands directly.
- **Relative paths only** — use absolute paths only for resources outside the project (e.g., `~/.claude/`).
- **Temporary files** — use `_tmp_` prefix in the project root (e.g., `_tmp_planner-output.md`). Clean up in batch with `rm _tmp_*` at phase checkpoints.
- **Do not modify files outside the target directory** — the kickoff skill reads its own templates from `~/.claude/skills/kickoff/project-template/` and writes to the target directory. No other directories are touched.
- **Do not commit** — the kickoff skill never runs git commands. Committing the scaffolded files is the user's responsibility.

---

## Error Handling

Per-phase failure modes and recovery:

| Phase | Failure | Recovery |
| :---- | :------ | :------- |
| **Phase 1 — Scaffold** | A template file fails to copy or cannot be verified | Report which files are missing. Stop — do not proceed to interview on a partial scaffold. |
| **Phase 2 — Interview** | Interviewer fails or `docs/kickoff-requirements.md` is not written | Present whatever was gathered from the conversation so far. Ask the user: "The interviewer did not complete successfully. Retry the interview, or proceed with partial requirements?" Do not auto-proceed. |
| **Phase 3 — Architecture** | Architect fails or `docs/kickoff-architecture.md` is not written | Log "Architecture phase failed — skipping ADD." Proceed to Phase 4 with requirements only, noting the absence of an ADD in the planner brief. |
| **Phase 4 — Plan** | Planner fails or no plan files are written to disk | Escalate to the user. Do not attempt Phase 5 or 6 without plan output on disk. |
| **Phase 5 — Critique** | Critic issues REVISE or REJECT twice | Proceed to Phase 5.5 with a warning: "Plan was not approved after 2 revision rounds. Proceeding with risk noted." |
| **Phase 5.5 — Scope** | Project-scoper fails or produces no output | Log "Scope estimates unavailable." Proceed to Phase 6 without blocking. |
| **Phase 6 — Populate** | A marker is missing from a template file | Fail loudly with the marker name and file. Do not write partial output. Show which files succeeded and which failed. Wait for user to resolve before retrying. |
