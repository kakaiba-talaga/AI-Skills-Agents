# AI Skills and Agents

This project is a collection of AI skills and agents that can be used to build AI-powered applications. This is targeted at developers who are using AI to help them with their work.

## Goal

The goal is be able to use the same agents and skills across different AI development tools or agentic harnesses like Claude Code, Cursor, and others.

All specs are written for Claude Code. The deploy script automatically transforms them for Cursor at deploy time. For skills that depend on Claude Code-specific features (ops, deploy), Cursor-native `SKILL.cursor.md` companion files provide functional equivalents using Cursor primitives.

### Priority

Initially, these should work on Claude Code and Cursor. Other AI development tools or agentic harnesses should be supported later.

- [x] Claude Code
- [x] Cursor
- [ ] Other AI Development Tools or Agentic Harnesses

## Structure

The project is organized into the following directories:

- `/agents` — 15 agents that can be used standalone or dispatched by skills. Each has YAML frontmatter (`name`, `model`, `description`, `tools`) and a markdown body.
- `/skills` — 9 multi-file skills. Each skill is a directory with a `SKILL.md` entry point and companion files (helper docs, templates, etc.).
- `/docs` — Assessment and portability guide.
- `/tooling` — Deploy script and manifest for syncing to global directories.

## Deployment

The deploy script syncs repo files to the correct global directories for each tool.

By default, the script prompts for confirmation before writing files. Use `-Force` to skip the prompt, or `-DryRun` to preview without writing.

```powershell
# Deploy everything (prompts for confirmation)
.\tooling\deploy.ps1

# Deploy to Claude Code, skip confirmation
.\tooling\deploy.ps1 -Target claude -Force

# Deploy only skills to Cursor
.\tooling\deploy.ps1 -Target cursor -Category skills

# Deploy to WSL only
.\tooling\deploy.ps1 -Target wsl -Force

# Preview what would change (writes nothing)
.\tooling\deploy.ps1 -DryRun

# Show which deployed files differ from the repo
.\tooling\deploy.ps1 -Diff
```

On Linux/macOS (requires `jq`):

```bash
./tooling/deploy.sh                          # prompts for confirmation
./tooling/deploy.sh -t claude -f             # skip confirmation
./tooling/deploy.sh -t cursor -c skills
./tooling/deploy.sh -t wsl -f              # deploy to WSL only
./tooling/deploy.sh --dry-run
./tooling/deploy.sh --diff
```

For Cursor targets, the script automatically transforms files:

- Strips `model` and `tools` from agent frontmatter
- Injects `## Tool Constraints` into agents whose Claude Code frontmatter restricted tools
- Derives `name` + `description` frontmatter for skills
- Uses `SKILL.cursor.md` as the source when it exists (for Cursor-native skill versions)
- Remaps tool names (`Bash`→`Shell`, `Edit`→`StrReplace`, `Agent`→`Task`)
- Replaces `~/.claude/` paths with `~/.cursor/`

See `docs/portability-guide.md` for the full format differences and tool gap analysis.

## Compatibility

| Component | Claude Code | Cursor | Notes |
| :--- | :---: | :---: | :--- |
| **Agents** | | | |
| planner | Yes | Yes | Auto-transformed by deploy script |
| architect | Yes | Yes | |
| project-scoper | Yes | Yes | |
| critic | Yes | Yes | |
| executor | Yes | Yes | |
| ssh-executor | Yes | Yes | |
| verifier | Yes | Yes | |
| security-reviewer | Yes | Yes | |
| code-reviewer | Yes | Yes | |
| code-reviewer-diff | Yes | Yes | |
| documentor | Yes | Yes | |
| debugger | Yes | Yes | |
| debugger-build | Yes | Yes | |
| git-master | Yes | Yes | |
| interviewer | Yes | Yes | |
| **Skills** | | | |
| clickup | Yes | Yes | |
| code-review | Yes | Yes | |
| commit-message | Yes | Yes | |
| deslop | Yes | Yes | |
| doc-sync | Yes | Yes | |
| linter | Yes | Yes | |
| ops | Yes | Yes | Cursor-native version uses state file + TodoWrite for task board, `Task` tool for dispatch. No model escalation. |
| deploy | Yes | Yes | Cursor-native version uses `Task(subagent_type="ssh-executor")` for dispatch. No model/tool enforcement on subagent. |
| ralph-loop | Yes | Yes | |

## Global Directories

Listed here are the global directories for the AI development tools or agentic harnesses. The global directory structure may change over time.

### Claude Code

- `~/.claude/agents/`
- `~/.claude/skills/`

### Cursor

- `~/.cursor/agents/`
- `~/.cursor/skills/`

### Claude Code (WSL)

- `//wsl.localhost/Ubuntu-24.04/home/ubuntu/.claude/agents/`
- `//wsl.localhost/Ubuntu-24.04/home/ubuntu/.claude/skills/`
