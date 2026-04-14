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
| Subagent spawning | `Agent` tool (custom model + tools + agent .md) | `Task` tool (`subagent_type` enum, `model` limited to `"fast"`) |
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
| `TaskCreate`/`TaskUpdate`/`TaskList` | No shared task board for multi-agent coordination. | **Mitigated** | Ops uses a JSON state file (`.ops-state/<run-id>-board.json`) as the real task board with `TodoWrite` as the display layer. Full metadata, dependencies, and timing preserved. |
| `Agent` tool with custom `model`/`tools` | Cannot spawn agents with a specific model or restrict their tool access. | **Mitigated** | Ops and deploy use `Task(subagent_type=...)` for dispatch. Deploy script injects `## Tool Constraints` markdown into agent bodies for tool-restricted agents. Model selection is not possible — documented as accepted limitation. |
| `Skill` tool | Cannot programmatically invoke another skill from within a skill. | **Mitigated** | Read-and-dispatch pattern: read the target skill's `SKILL.md` from `~/.cursor/skills/<name>/SKILL.md`, then follow inline or pass to `Task(subagent_type="generalPurpose")`. |
| `EnterWorktree`/`ExitWorktree` | No git worktree isolation for parallel agents. | **Mitigated** | `Task(subagent_type="best-of-n-runner")` provides isolated worktrees per agent. |
| Model enforcement per agent | Cursor runs all agents on the session model. The `model` field is stripped during transform. | **Accepted** | No workaround. All subagents run on session model or `model="fast"`. Cost implications only. |
| Tool surface restriction per agent | All tools are available to all agents in Cursor. | **Partially mitigated** | Deploy script injects `## Tool Constraints` section into agents whose Claude Code frontmatter restricted tools (critic, ssh-executor, interviewer, verifier). Advisory only — not enforced. |

### Summary by component

- **ops**: Functional with Cursor-native `SKILL.cursor.md`. Uses state file + TodoWrite for task board, `Task` tool for agent dispatch, read-and-dispatch for skill invocation. Limitations: no model escalation, no tool enforcement.
- **deploy**: Functional with Cursor-native `SKILL.cursor.md`. Uses `Task(subagent_type="ssh-executor")` for dispatch. All deployment patterns, rollback, and reporting work. Limitation: no model or tool enforcement on dispatched ssh-executor.
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

Currently, two skills have Cursor-native versions: `skills/ops/SKILL.cursor.md` and `skills/deploy/SKILL.cursor.md`.

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

## Naming

Agent and skill names can safely match built-in Cursor `subagent_type` values (e.g., `debugger`, `code-reviewer`, `shell`). These operate in separate namespaces — a custom agent named `debugger` does not conflict with `Task(subagent_type="debugger")`.

Verified against Cursor's built-in `create-subagent` skill and the existing `shell` skill, which coexists with `subagent_type="shell"`.

## Verified Findings (2026-04-14)

- **Cursor supports custom agents** at `~/.cursor/agents/` (or `.cursor/agents/` per-project). Format: `name` + `description` frontmatter, markdown body as system prompt.
- **Skills can instruct the agent to use the Task tool.** The deployed code-review skill already dispatches `Task(subagent_type="generalPurpose")` for parallel review.
- **Cursor skill format constraints:** `name` max 64 chars (lowercase/hyphens), `description` max 1024 chars. SKILL.md body under 500 lines recommended.
