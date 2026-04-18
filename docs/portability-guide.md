# Portability Guide

This document describes the format differences between Claude Code and Cursor, what can be automated, and what limitations exist. It serves as the spec that the deploy script's transform logic implements.

## Format Differences

| Aspect | Claude Code | Cursor |
|--------|------------|--------|
| Agent format | YAML: `name`, `model`, `description`, `tools` | YAML: `name`, `description` only (no `model`/`tools`) |
| Agent location | `~/.claude/agents/` | `~/.cursor/agents/` |
| Skill entry point | `SKILL.md`; may have no frontmatter; can use `$ARGUMENTS` | `SKILL.md` with required `name` + `description` frontmatter |
| Skill location | `~/.claude/skills/` | `~/.cursor/skills/` |
| Tool names | `Bash`, `Edit`, `Write`, `Agent`, `Skill` | `Shell`, `StrReplace`, `Write`, `Task`, no `Skill` equivalent |
| Subagent spawning | `Agent` tool (`subagent_type` has limited built-in enum; custom agents loaded via read-and-inject pattern) | `Task` tool (`subagent_type` enum covers all 15 agent types natively plus utility types; `model` limited to `"fast"`) |
| Invocation | `/skill-name args` with `$ARGUMENTS` | Description-matched by IDE; no slash commands |
| Config/state paths | `~/.claude/config/`, `.claude/state/` | `~/.cursor/config/`, `.cursor/state/` |
| Size limits | No formal limit | SKILL.md under 500 lines; use companion files |

## Transform Rules

The deploy script (`tooling/deploy.ps1` / `tooling/deploy.sh`) automates all transforms when deploying to Cursor. See the deploy script for the implementation. The rules are:

### Agents

1. Strip `model` and `tools` from YAML frontmatter; keep `name` and `description`
2. Replace tool names in the markdown body (`Bash` → `Shell`, `Edit` → `StrReplace`, `Agent` → `Task`)
3. Replace `~/.claude/` paths with `~/.cursor/`

### Skills

1. Derive `name` from the skill's directory name (e.g., `skills/clickup/` → `clickup`)
2. Derive `description` using this precedence:
   - If YAML frontmatter exists with a `description` field, use it
   - Otherwise, extract the first non-empty line of the file, stripping any trailing ` Arguments: $ARGUMENTS` suffix
3. Inject `name` + `description` as YAML frontmatter in the output
4. Strip `model` and `tools` from frontmatter if present
5. Replace tool names and paths (same as agents)
6. Only `SKILL.md` is transformed; companion files receive tool name and path replacements but no frontmatter changes
7. **`SKILL.cursor.md` override:** If a `SKILL.cursor.md` exists alongside `SKILL.md`, the deploy script uses it as the Cursor version directly — no further transforms are applied. The file is deployed as `SKILL.md` at the target. `SKILL.cursor.md` is never deployed as a separate artifact.

`$ARGUMENTS` references are left in place. Cursor invokes skills by intent matching, not slash commands, so the variable simply won't be populated. The surrounding workflow instructions still function.

**Prune mode and `SKILL.cursor.md`:** The `--prune` / `-Prune` flag's orphan calculation is filename-based, so the `SKILL.cursor.md` override does not affect it. The deploy script always writes the file as `SKILL.md` at the target — whether its content came from a straight transform of `SKILL.md` or from a `SKILL.cursor.md` override. Prune therefore computes the expected set using the deployed filename (`SKILL.md`) and correctly identifies it as a tracked file, not an orphan. Conversely, a file literally named `SKILL.cursor.md` found at a Cursor target is always an orphan — it is never in the expected set, because the deploy script never writes a file by that name to any target. Prune will flag and remove it.

## Tool Name Mapping

| Claude Code | Cursor | Notes |
|------------|--------|-------|
| `Bash` | `Shell` | Same capabilities, different name |
| `Edit` | `StrReplace` | Cursor uses exact string replacement instead of line-based edits |
| `Write` | `Write` | Same in both |
| `Read` | `Read` | Same in both |
| `Glob` | `Glob` | Same in both |
| `Grep` | `Grep` | Same in both |
| `Agent` | `Task` | Cursor's `Task` tool uses a `subagent_type` enum instead of custom agent specs |
| `Skill` | — | No direct equivalent; workaround via read-and-dispatch pattern (see below) |

## Features with No Cursor Equivalent

These Claude Code features have no direct counterpart in Cursor. The mechanical transform cannot address these gaps. For ops and deploy, Cursor-native `SKILL.cursor.md` versions provide functional workarounds (see Cursor-Native Adaptations below).

| Feature | Impact | Severity | Mitigation |
|---------|--------|----------|------------|
| `TaskCreate`/`TaskUpdate`/`TaskList` | No shared task board for multi-agent coordination. | **Mitigated** | Both Claude Code and Cursor versions of ops now use a JSON state file (`.ops-state/<run-id>-board.json`) as the task board. Cursor adds `TodoWrite` as a display layer on top. Full metadata, dependencies, and timing preserved. |
| `Agent` tool with custom `model`/`tools` | Cannot spawn agents with a specific model or restrict their tool access. | **Mitigated** | Ops and deploy use `Task(subagent_type=...)` for dispatch. Deploy script injects `## Tool Constraints` markdown into agent bodies for tool-restricted agents. Model selection is not possible — documented as accepted limitation. |
| `Skill` tool | Cannot programmatically invoke another skill from within a skill. | **Mitigated** | Read-and-dispatch pattern: read the target skill's `SKILL.md` from `~/.cursor/skills/<name>/SKILL.md`, then follow inline or pass to `Task(subagent_type="generalPurpose")`. |
| Agent `subagent_type` coverage | Cursor's `Task` tool `subagent_type` enum includes all 15 agent types natively (executor, verifier, planner, architect, security-reviewer, etc.) plus utility types (generalPurpose, explore, shell, etc.). Claude Code's `Agent` tool `subagent_type` only includes `debugger-build`, `git-master`, `code-reviewer`, and `code-reviewer-diff` from the ops taxonomy (Claude Code built-ins; the enum may expand) — all others dispatch as `general-purpose` and display as "Agent." | **Mitigated** | See Agent Dispatch Mechanism section below. |
| `EnterWorktree`/`ExitWorktree` | No git worktree isolation for parallel agents. | **Mitigated** | `Task(subagent_type="best-of-n-runner")` provides isolated worktrees per agent. |
| Model enforcement per agent | Cursor runs all agents on the session model. The `model` field is stripped during transform. | **Accepted** | No workaround. All subagents run on session model or `model="fast"`. Cost implications only. |
| Tool surface restriction per agent | All tools are available to all agents in Cursor. | **Partially mitigated** | Deploy script injects `## Tool Constraints` section into agents whose Claude Code frontmatter restricted tools (critic, ssh-executor, interviewer, verifier). Advisory only — not enforced. |

### Summary by component

- **ops**: Functional with Cursor-native `SKILL.cursor.md`. Both versions use `.ops-state/<run-id>-board.json` state file for the task board; Cursor adds TodoWrite as display layer. `SKILL.cursor.md` still needed for `Task` tool dispatch, read-and-dispatch skill invocation, and TodoWrite integration. Limitations: no model escalation, no tool enforcement.
- **deploy**: Functional with Cursor-native `SKILL.cursor.md`. Cursor uses `Task(subagent_type="ssh-executor")` for dispatch; Claude Code uses the read-and-inject pattern (see Agent Dispatch Mechanism) since `ssh-executor` is not a built-in `subagent_type`. All deployment patterns, rollback, and reporting work. Limitation: no model or tool enforcement on dispatched ssh-executor.
- **All agents**: Functional. Tool-restricted agents receive injected `## Tool Constraints` markdown section (advisory). No model enforcement.
- **All other skills**: Fully functional after mechanical transform. No missing features.

## Cursor-Native Adaptations

### `SKILL.cursor.md` Convention

When mechanical transformation of `SKILL.md` produces a non-functional result (e.g., the skill depends on `Agent` tool, task board tools, or `Skill` tool), maintain a Cursor-native companion file:

```text
skills/<name>/
  SKILL.md            # Claude Code version
  SKILL.cursor.md     # Cursor-native version (used for Cursor deployments)
  README.md           # Shared
  *.md                # Companion files (shared, transformed by deploy script)
```

The deploy script detects `SKILL.cursor.md` and uses it instead of transforming `SKILL.md`. The file is deployed as `SKILL.md` at the target — `SKILL.cursor.md` never appears at the destination.

**When to create a `SKILL.cursor.md`:**

- **Needs one** — skill uses `Agent` tool with custom model/tools, `TaskCreate`/`TaskUpdate`/`TaskList`, `Skill` tool, `EnterWorktree`/`ExitWorktree`, or relies on model enforcement
- **Does NOT need one** — skill only uses standard tools (Bash, Edit, Write, Read, Glob, Grep) and file paths. The mechanical transform handles these.

Currently, three skills have Cursor-native versions: `skills/ops/SKILL.cursor.md`, `skills/deploy/SKILL.cursor.md`, and `skills/ralph-loop/SKILL.cursor.md`.

- **ops** — multi-patch transform (YAML frontmatter + Bash→Shell + `~/.claude/`→`~/.cursor/` + dispatch adaptations). Transform: `tooling/transform-cursor-ops.{sh,ps1}`.
- **ralph-loop** — 4-patch transform (YAML frontmatter + Bash→Shell + `~/.claude/`→`~/.cursor/` + `/deslop` flag note). No Agent/TodoWrite/Skill dependencies. Transform: `tooling/transform-cursor-ralph-loop.{sh,ps1}`.

Both transform pairs run in **drift-check mode by default**: they compare the transform output against the checked-in `SKILL.cursor.md` and either report "in sync" (exit 0), prompt interactively on drift, or exit 3 in non-interactive contexts (CI-friendly). Pass `-f` / `--force` to bypass the check and regenerate unconditionally.

### Agent Tool-Restriction Hardening

When deploying agents to Cursor, the deploy script compares each agent's `tools` list from Claude Code frontmatter against the full tool set. If any tools are excluded, a `## Tool Constraints` section is injected at the end of the agent body:

```markdown
## Tool Constraints

The following tools are NOT available to this agent. Do not use them:
- StrReplace (file editing)
- Write (file creation)
```

This is advisory — Cursor cannot enforce tool restrictions. The injected section informs the agent about its intended limitations.

Agents affected: critic, ssh-executor, interviewer, verifier. Agents with all tools allowed (executor, planner, project-scoper, etc.) receive no injected constraints.

### Read-and-Dispatch Pattern

Cursor has no `Skill` tool for programmatic skill invocation. The ops skill works around this by reading the target skill file and dispatching it:

1. Read `~/.cursor/skills/<name>/SKILL.md`
2. Pass the content + arguments to `Task(subagent_type="generalPurpose", prompt=<skill content + args>)`

This provides functional equivalence for skill invocation within orchestration workflows.

## Agent Dispatch Mechanism

The two platforms differ significantly in how agents are dispatched programmatically. This affects labeling, model selection, and agent definition loading.

### Cursor — native `subagent_type` enum

Cursor's `Task` tool includes all 15 agent types as built-in `subagent_type` values, plus utility types: `generalPurpose`, `explore`, `shell`, `browser-use`, `best-of-n-runner`, `architect`, `code-reviewer-diff`, `code-reviewer`, `critic`, `debugger-build`, `debugger`, `documentor`, `executor`, `git-master`, `interviewer`, `planner`, `project-scoper`, `security-reviewer`, `ssh-executor`, `verifier`.

The ops skill dispatches directly: `Task(subagent_type="executor", prompt=<brief>)`. The agent type appears as the label in dispatch notifications. No additional setup is needed.

### Claude Code — limited `subagent_type` enum with read-and-inject workaround

Claude Code's `Agent` tool `subagent_type` enum only includes: `general-purpose`, `Explore`, `Plan`, `debugger-build`, `git-master`, `code-reviewer`, `code-reviewer-diff`, `claude-code-guide`, `statusline-setup`. Only `debugger-build`, `git-master`, `code-reviewer`, and `code-reviewer-diff` from the ops agent taxonomy have matching entries (Claude Code built-ins; the enum may expand). All other agent types (executor, verifier, planner, critic, etc.) dispatch as `general-purpose` and display as "Agent" in the UI.

**Custom agent files at `~/.claude/agents/` do NOT extend the `subagent_type` enum.** Those files are loaded when the user directly invokes an agent by name in conversation, but they are not available for programmatic dispatch via the Agent tool's `subagent_type` parameter.

**Workaround (implemented in ops `SKILL.md`):**

1. **Read** the agent definition from `~/.claude/agents/<agent_type>.md`. Extract the `model` from YAML frontmatter and the full instruction body.
2. **Set `description`** to `"<agent_type>(<task subject>)"` so the role is visible in dispatch notifications (e.g., `"executor(Implement auth middleware)"`).
3. **Set `model`** from the agent's frontmatter (e.g., `"sonnet"`, `"opus"`).
4. **Set `subagent_type`** only when the agent type matches a built-in value (Claude Code: `debugger-build`, `git-master`, `code-reviewer`, `code-reviewer-diff`). Omit for all others.
5. **Concatenate** the agent definition body + task brief into the `prompt` parameter.

This preserves the agent's specialized behavior and model assignment while making the role visible in the UI, despite the platform's limited enum.

### Impact on `SKILL.cursor.md` vs `SKILL.md`

This dispatch mechanism difference is a primary reason the ops skill requires a `SKILL.cursor.md` companion. The Cursor version uses `Task(subagent_type="<agent_type>")` directly. The Claude Code version implements the read-and-inject pattern described above. The dispatch logic cannot be mechanically transformed between the two.

## Naming

Agent and skill names can safely match built-in Cursor `subagent_type` values (e.g., `debugger`, `code-reviewer`, `shell`). These operate in separate namespaces — a custom agent named `debugger` does not conflict with `Task(subagent_type="debugger")`.

Verified against Cursor's built-in `create-subagent` skill and the existing `shell` skill, which coexists with `subagent_type="shell"`.

## Verified Findings (2026-04-14)

- **Cursor supports custom agents** at `~/.cursor/agents/` (or `.cursor/agents/` per-project). Format: `name` + `description` frontmatter, markdown body as system prompt.
- **Skills can instruct the agent to use the Task tool.** The deployed code-review skill already dispatches `Task(subagent_type="generalPurpose")` for parallel review.
- **Cursor skill format constraints:** `name` max 64 chars (lowercase/hyphens), `description` max 1024 chars. SKILL.md body under 500 lines recommended.
