<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Preflight Validation

Before the first agent dispatch in Phase 3, the team manager dispatches a **verifier** agent to run a preflight validation, confirming the environment is ready. This prevents other agents from failing on first attempt due to missing interpreter, broken dependencies, or unavailable tools.

## When to Run

- **Phase 3 start** — always run before the first task dispatch in a new run.
- **`resume`** — run before re-dispatching if the environment may have changed since the last successful preflight. Skip if a successful preflight was completed earlier in the same session and no environment-affecting changes have occurred.
- **Non-code task runs** — if the plan contains only documentation or planning tasks (no code execution), reduce to critical checks only.

## Check Categories

Checks are grouped into three tiers. The tier determines what happens when a check fails.

### Critical Checks

Block all dispatch if any critical check fails. Do not attempt to auto-fix — report to the user and stop.

| Check | What to verify | How to discover |
| :--- | :--- | :--- |
| Language runtime | The project's primary interpreter/runtime exists and is executable | Read `CLAUDE.md` or project config for venv/runtime path. Check common patterns: `.venv/*/Scripts/python.exe`, `.venv/*/bin/python`, `node_modules/.bin/node`, etc. |
| Project root structure | Working directory contains expected root-level artifacts | Look for `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, or similar project markers |
| Git available | `git` command is available and the working directory is inside a git repository | Run `git rev-parse --is-inside-work-tree` |

### Standard Checks

Block dispatch if failed, but the agent may attempt a single auto-fix before reporting failure.

| Check | What to verify | Auto-fix |
| :--- | :--- | :--- |
| Dependencies installed | Key packages can be imported or resolved | Run the project's install command once (e.g., `pip install -e .`, `npm install`), then re-check |
| Config files present | Any config file explicitly referenced in the plan exists on disk | None — report the missing file path |
| Disk space | At least 500 MB free in the project directory | None — report to user |

### Warning Checks

Log the issue but do not block dispatch. Proceed with warnings visible in the dashboard.

| Check | What to detect |
| :--- | :--- |
| Uncommitted changes | `git status` shows modified or untracked files that may conflict with agent work |
| Multiple runtime versions | More than one virtual environment or runtime version detected |
| Stale lock files | `.lock` files older than 7 days are present in the project root |

## Check Procedure

The team manager dispatches a **verifier** agent to run the preflight checks. The agent:

1. Reads `CLAUDE.md` and project config files to discover the runtime path, package manager, and project structure
2. Runs each check as a separate Bash tool call — never chaining with `&&`, `;`, or `||`
3. Returns a structured checklist with `[PASS]`, `[FAIL]`, or `[WARN]` per check
4. Attempts auto-fix for standard checks that support it, then re-checks once

The team manager creates this as an **internal task** (`metadata._internal: true`) so it doesn't appear in user-facing progress counts.

### Agent Brief Template

When dispatching the preflight verifier, the team manager includes:
- The check tables from this file (critical, standard, warning)
- Any project-specific hints from `CLAUDE.md` (e.g., venv path, package manager)
- The plan summary (so the agent knows which config files the plan references)

### Expected Output

The agent returns a checklist that the team manager displays before the first task dispatch:

```
### Preflight Checks
- [PASS] Language runtime found (Python 3.11 via .venv/)
- [PASS] Git repository detected
- [PASS] Config file exists: config/settings.yaml
- [WARN] Uncommitted changes detected (3 files)
- [FAIL] Missing dependency: requests
```

The team manager stores the preflight result (`pass` / `blocked` / `pass-with-warnings`) in run metadata so it appears in the Phase 4 completion summary.

## Failure Behavior

| Outcome | Action |
| :--- | :--- |
| Any CRITICAL check fails | Stop immediately. Report the failed check(s) to the user with a clear description. Do not dispatch any tasks. Wait for the user to resolve. |
| Any STANDARD check fails | The preflight agent attempts the auto-fix listed in the table above. Re-runs the check once. If it still fails, the team manager stops and reports — do not dispatch. |
| Auto-fix succeeds | The agent re-runs only the failed check, marks it `[PASS]`, notes "auto-fixed" in the checklist, and the team manager proceeds. |
| Only WARN checks triggered | Proceed with dispatch. Warnings remain visible in the dashboard throughout the run. |
| All checks pass | Proceed with dispatch. |

When blocking on a failed check, create a blocker task on the task board:

```
Task: Resolve preflight failure — <check name>
Status: blocked
Description: <what failed and why>
Resolution: User must fix environment before dispatch can resume.
```

This blocker must be manually resolved (marked `deleted` or `completed`) before the dispatch loop will continue.

## Skipping Preflight

- **`--skip-preflight` flag** — reserved for future use. Not yet implemented in SKILL.md. Do not honor this flag until it is added there.
- **Resume within the same session** — if a successful preflight (`pass` or `pass-with-warnings`) was completed earlier in the same session and no package installs, git operations, or file-system changes have occurred since, skip the full check and log: `[SKIP] Preflight — passed earlier this session`.
- **Non-code plans** — if every task in the plan is documentation-only (no code execution, no builds, no tests), run critical checks only and skip standard and warning checks.

## Integration Points

- Preflight runs after Phase 2 (Task Board Creation) and before Phase 3 Step 1 (first dispatch).
- The checklist is displayed in the dashboard under a **Preflight** section, between the task board and the first dispatch notification.
- A failed preflight creates a blocker task (see Failure Behavior above) that is visible on the task board.
- The preflight result is stored in `metadata.preflight` on the run's tasks and included in the Phase 4 completion summary.
