<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# State File Schema

## Cursor: dual-layer board

When the active harness is **Cursor**, ops uses a JSON board file plus `TodoWrite` for IDE display. **Only the board file is authoritative** for `resume`, timing, dependencies, and handoffs. Every status mutation (a change written to the state file) must follow the Write → Read verify → TodoWrite ritual in `phase-dispatch.md` § **Cursor: state file sync (mandatory)**. Updating `TodoWrite` without writing the board file in the same turn is a protocol violation.

## Directory Conventions

- `.ops-state/` holds one board file per run (supports concurrent/sequential runs without collision)
- `.ops-state/` should be in `.gitignore` (ephemeral (short-lived; this run only) runtime state, not project content)
- Cleaned up on successful completion (same lifecycle as ralph-loop's `.ralph-state/`)

## State File Structure

The state file JSON structure:

```json
{
  "run_id": "auth-middleware-2026-04-14",
  "state_dir": ".ops-state/",
  "plan_file": "docs/plan/auth-middleware-plan.md",
  "tasks": [
    {
      "id": "task-0",
      "subject": "Plan auth middleware implementation",
      "description": "Break down auth feature into subtasks",
      "description_ref": "docs/plan/auth-middleware-plan.md#task-plan-auth-middleware",
      "status": "completed",
      "agent_type": "planner",
      "stage": "plan",
      "priority": 1,
      "estimated_minutes": 5,
      "estimate_source": "ops",
      "blocked_by": [],
      "started_at": "2026-04-14T10:00:00Z",
      "completed_at": "2026-04-14T10:03:00Z",
      "duration_seconds": 180,
      "model_used": "opus",
      "attempts": 1,
      "adaptation": null,
      "handoff_file": null,
      "_internal": false
    },
    {
      "id": "task-1",
      "subject": "Implement auth middleware",
      "description": "Auth middleware + tests in src/auth/",
      "description_ref": "docs/plan/auth-middleware-plan.md#task-implement-auth-middleware",
      "status": "pending",
      "agent_type": "executor",
      "stage": "implement",
      "priority": 1,
      "estimated_minutes": 15,
      "estimate_source": "ops",
      "blocked_by": ["task-0"],
      "started_at": null,
      "completed_at": null,
      "duration_seconds": null,
      "model_used": null,
      "attempts": 0,
      "adaptation": null,
      "handoff_file": null,
      "_internal": false
    }
  ],
  "pending_nested_skill": null,
  "memory_inject_banner_emitted": false
}
```

### pending_nested_skill

Root-level field tracking whether the team manager is currently inside a nested-skill invocation.

**Type:** `null` or object.

**When null (or absent):** No nested skill is pending. This is the steady-state value.

**When set (object):**

```json
{
  "skill": "/deslop",
  "invoked_at": "2026-04-19T14:22:03Z",
  "resume_phase": "phase-3-deslop-stage",
  "resume_notes": "integrations.md steps 5-6: if deslop made changes, re-dispatch verifier; if no changes, proceed to code-review stage"
}
```

Field meanings:

- `skill` — the nested skill invoked (e.g., `"/deslop"`, `"/clickup"`). Matches the skill identifier.
- `invoked_at` — ISO-8601 UTC timestamp of invocation. Enables future stale-marker detection.
- `resume_phase` — short identifier of where the team manager must resume. Allowed values (open set): `"phase-1-intake"`, `"phase-3-dispatch"`, `"phase-3-deslop-stage"`, `"phase-3-save-followup"`.
- `resume_notes` — one-line human-readable instruction the team manager re-reads when clearing the marker.

**Lifecycle:** `null` → set on write-before → consumed and acted upon on clear-after → `null`.

**Backward compatibility:** The `pending_nested_skill` field is additive (optional; older files simply omit it). State files written before this field was introduced will not have it. The team manager treats absence as equivalent to `null`. No migration is required.

### worktrees_created

Root-level field tracking worktrees this run created, used for provenance (origin — which run created it)-safe cleanup in Phase 4.

**Type:** `array` (default `[]` when absent).

**Element shape:**

```json
{
  "path": "/absolute/path/to/worktree",
  "added_at": "2026-04-14T10:05:00Z"
}
```

Field meanings:

- `path` — absolute path to the worktree directory, as returned by `git worktree add`. Used for exact-match provenance verification during cleanup.
- `added_at` — ISO-8601 UTC timestamp recorded immediately after `git worktree add` succeeds. Used to confirm the worktree falls within this run's time window.

**Write lifecycle:** The team manager appends an entry to `worktrees_created` each time a worktree is created. This happens in Phase 1.5 when `--worktree` is set and git-master creates worktrees, or at any other point during the run where git-master creates additional worktrees on the team manager's behalf. The entry is written immediately after the git-master confirms the worktree was created.

**Backward compatibility:** Additive field. State files written before this field was introduced will not have it; the team manager treats absence as `[]`. No migration is required.

---

### memory_inject_banner_emitted

Root-level field tracking whether the Cursor first-time memory-injection awareness banner has been emitted in the current session.

**Type:** `boolean` (default `false` when absent).

**When `false` (or absent):** The banner has not yet fired this session. The first dispatch that fires injection under the Cursor harness will emit the banner and set this field to `true`.

**When `true`:** The banner has already fired this session. Suppress subsequent banner emissions even if more injection-eligible dispatches follow.

**Behavior:** The team manager writes `memory_inject_banner_emitted: true` immediately after emitting the banner, before the dispatch that triggered it proceeds. Under Claude Code, this field remains `false` (the banner is suppressed because there is no trust-model inversion to disclose — the top-level turn already sees `[CROSS-MEMORY]`).

**Backward compatibility:** Additive field. State files written before this field was introduced will not have it; the team manager treats absence as `false`. No migration is required.

## Task Description Fields

Each task uses one of two description modes — never both simultaneously:

### `description_ref` (plan-doc pointer mode)

Used when `plan_file` is set (pipeline runs with a persisted plan document).

- **Format:** `"docs/plan/<name>-plan.md#task-<slug>"` — a markdown anchor pointing to the task's section in the plan doc.
- **Anchor convention:** lowercase, hyphen-separated, matching the section heading (e.g., heading `## Task: Implement Auth Middleware` → anchor `#task-implement-auth-middleware`).
- **`description` field:** Keep as a short one-line summary ≤ 100 chars (e.g., `"Auth middleware + tests in src/auth/"`). This is for display only — not the full prose.
- **Resolution algorithm (Phase 3 Step 3):** Before dispatching an agent, the team manager reads the plan doc file, locates the section matching the anchor (grep for the heading), and extracts the full section content (description, acceptance criteria, implementation notes, file list). This resolved content populates the Context, Scope, and Acceptance Criteria sections of the agent brief. The agent prompt is always fully self-contained after resolution — the agent never receives a bare pointer.

### `description_inline` (inline mode)

Used when `plan_file` is null — trivial-path runs or runs without a persisted plan doc.

- **Format:** Full task prose: description, acceptance criteria, notes, file list — everything needed to brief the agent without reading another file.
- **Resolution:** No resolution step needed. Used directly in the agent brief's Context, Scope, and Acceptance Criteria sections.
- **`description` field:** May duplicate `description_inline` summary or be omitted. `description_inline` is the authoritative source.

#### Example (`description_inline` mode)

```json
{
  "id": "task-0",
  "subject": "Add null-check to login handler",
  "description": "Guard against null user object in login handler",
  "description_inline": "Add a null-check for the user object in `src/auth/login.py` before the session is created. Acceptance criteria: a `pytest` run with a null-user fixture must pass. Files: `src/auth/login.py`, `tests/test_login.py`.",
  "status": "pending",
  "agent_type": "executor",
  "stage": "implement",
  "priority": 1,
  "estimated_minutes": 10,
  "estimate_source": "ops",
  "blocked_by": [],
  "started_at": null,
  "completed_at": null,
  "duration_seconds": null,
  "model_used": null,
  "attempts": 0,
  "adaptation": null,
  "handoff_file": null,
  "_internal": false
}
```

### Choosing the mode

| Condition | Mode | Set `description_ref`? | Set `description_inline`? |
| :--- | :--- | :---: | :---: |
| `plan_file` is set (pipeline run) | Pointer | Yes | No |
| `plan_file` is null (trivial or no plan doc) | Inline | No | Yes |

---

## State Cache Semantics

The team manager maintains an in-memory snapshot (cache) of the state file to avoid reading the full JSON on every Phase 3 loop iteration. The file on disk remains the source of truth — the cache is a read optimization only.

### Invalidation events

The cache is invalidated (state file re-read from disk) on these events:

1. **Bootstrap** — before the first dispatch of each loop invocation.
2. **Task completed** — immediately after Phase 3 Step 4 writes task completion to disk.
3. **Resume or status subcommand** — always re-read on `resume` or `status`; external changes may have occurred since the last session.
4. **User mid-run command** — after processing `add`, `drop`, `reprioritize`, `do #N next`, or `skip`.
5. **Nested skill return** — after any nested-skill call returns, the cache is invalidated. The state file on disk may have been written by the team manager in the same turn (via the write-before step of the `pending_nested_skill` ritual) and must be re-read before processing the return. See the Nested Skill Protocol section of SKILL.md.

Between these events, the team manager operates on the cached snapshot and does not re-read the disk.

### Safety note

If the user manually edits the state file JSON between invalidation events (out-of-band edit), those changes will not be visible until the next invalidation trigger. Manual out-of-band (made outside the team manager, e.g. a hand edit) edits are not a supported workflow — the state file is written exclusively by the team manager. If the user needs to intervene, use the supported mid-run commands (`add`, `drop`, `reprioritize`) which trigger an invalidation.
