<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Dispatch Decision Log Spec

The team manager maintains an optional persistent audit trail at `docs/ops-dispatch-log.md` so the **Subagent Dispatch Decision Framework** (see `tool-restrictions.md`) can be audited for real-world adherence.

## Opt-in via `--dispatch-log`

The dispatch log is **off by default**. It is written only when the user invokes `/ops` with the `--dispatch-log` flag (the flag is sticky (applies to this run only; not remembered next time) only for the run; it does not persist across invocations).

When the flag is not set: skip every append step below entirely. Do not create, open, or touch `docs/ops-dispatch-log.md` — the file may already exist from previous flagged runs; leave it alone.

When the flag IS set: follow this spec for the full run, including all nested phases (Trivial Dispatch, Brainstorm Gate, Phase 1a, Phase 2.5, Phase 3, and any re-dispatch on failure).

## File location and retention

- **Path:** `docs/ops-dispatch-log.md`. The team manager creates it on first append if missing (a seed header is already committed in the project as a template).
- **Retention:** persistent — **never cleaned up at Phase 4**, regardless of whether the flag was set this run. Committed to git.
- **Append-only:** never modify past entries. Archival rotation is not automatic; the user may manually move old sections to `docs/ops-dispatch-log-archive-<year>.md` if the file grows unwieldy.

## When to append an entry (only when `--dispatch-log` is set)

- **Every agent dispatch** — Phase 3 Step 3, Trivial Dispatch Step 4, Brainstorm Gate dispatches, Phase 1a scoper/critic dispatches, Phase 2.5 preflight (checks run before dispatch) dispatches, and every other `Agent(...)` call the team manager issues. One entry per dispatch, before the agent runs. Parallel batches → one entry per agent in the batch.
- **Framework-guided direct-tool choices** — when the team manager pauses at a research/reading decision, consults the Subagent Dispatch Decision Framework in `tool-restrictions.md`, and deliberately picks a direct tool (`Read` / `Grep` / `Glob`), append a `research-direct` entry. Do NOT log routine file reads where no framework decision was weighed (e.g., resolving `description_ref` is routine; weighing whether to spawn `scout` for a broad code question is not).

## Entry format

One bullet per decision, grouped under a `## <run-id>` heading. Run-id is the team manager's existing `<plan-slug>-<ISO-date>` identifier from the state file.

```
- `<ISO-8601 UTC timestamp>` — **<kind>**: <short description>. Framework row: `<row name or "n/a">`. <optional one-line notes>
```

### Kinds

| Kind | Use for | Framework row |
| :--- | :--- | :--- |
| `work-dispatch` | Specialist agent for work per delegate-first (executor, verifier, code-reviewer, documentor, git-master, ssh-executor, …) | `n/a` |
| `research-dispatch` | `scout` (in-domain) / harness `general-purpose` (out-of-domain) agent for reading or exploration | matching row from the framework |
| `research-direct` | Deliberate direct `Read` / `Grep` / `Glob` after consulting the framework | matching row from the framework |
| `parallel-batch` | Multiple agents dispatched in one message for independent threads | `2+ independent research threads` (plus the row of each individual dispatch if useful) |

### Example

```
## auth-middleware-2026-04-25

- `2026-04-25T09:12:03Z` — **work-dispatch**: executor "Implement auth middleware (src/auth/)". Framework row: `n/a`.
- `2026-04-25T09:14:47Z` — **research-direct**: Read `docs/plan/auth-middleware-plan.md` with offset/limit. Framework row: `Known file + narrow question`. Resolving description_ref for task-1.
- `2026-04-25T09:30:12Z` — **parallel-batch**: scout ×3 (test patterns, config loading, session middleware). Framework row: `2+ independent research threads`.
- `2026-04-25T09:42:55Z` — **work-dispatch**: verifier "Run test suite against auth changes". Framework row: `n/a`.
```

## Append procedure

1. Before the dispatch (or immediately before the direct-tool call), determine the entry's kind, framework row (if applicable), and short description.
2. If `docs/ops-dispatch-log.md` does not exist, create it with the seed header.
3. If the current run-id is not already a `## <run-id>` section in the file, append a new one.
4. Append the entry bullet under the run's section.
5. Write the file.

Use `Edit` (append at the end of the run's section) or `Write` (full rewrite of the file) — whichever is cleaner given the current state. `Bash(echo '...' >> docs/ops-dispatch-log.md)` is also permitted — the log file is team-manager infrastructure, not project content, so the direct-write restriction does not apply (same rationale as `.ops-state/`).

## Audit usage

The `/ops` skill does not automatically audit the log. When the user (or team manager per a stored project memory) decides to audit, invoke `/ops "audit the dispatch log"` and the team manager:

1. Reads `docs/ops-dispatch-log.md`.
2. Reads the framework table in `tool-restrictions.md`.
3. For each `research-dispatch` and `research-direct` entry, verifies the chosen action matches the framework row's prescription. For `work-dispatch` entries, verifies the agent matches delegate-first (not a framework question but still checkable).
4. Reports: match rate, notable mismatches (especially rows where the team manager's behavior consistently diverges from the framework), any row that appears mis-calibrated in light of usage, suggested refinements to the framework.
5. Writes the audit report to `docs/framework-audits/subagent-dispatch-audit-<date>.md`.

If the log is empty or has too few entries for a meaningful audit, report that explicitly rather than manufacture findings.
