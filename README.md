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

- `/agents` — 28 agents that can be used standalone or dispatched by skills. Each has YAML frontmatter (`name`, `model`, `description`, `tools`) and a markdown body.
- `/skills` — 13 multi-file skills. Each skill is a directory with a `SKILL.md` entry point and companion files (helper docs, templates, etc.).
- `/hooks` — Event hooks (e.g., post-compaction context re-injection, PostToolUse security pattern warnings).
- `/docs` — Assessment and portability guide.
- `/tooling` — Deploy script and manifest for syncing to global directories.
- `settings.json` — Claude Code settings (permissions, preferences). Deployed to `~/.claude/` via the deploy script.
- `CLAUDE-root.md` — User-global Claude Code instructions (skill badges, conventions). Deployed as `~/.claude/CLAUDE.md`. Repo `CLAUDE.md` is project-only and is not deployed.

## Deployment

The deploy script syncs repo files to the correct global directories for each tool.

**Prerequisites:** `deploy.ps1` requires PowerShell 7+ (`pwsh`) on every platform. Windows PowerShell 5.1 is not supported.

By default, the script prompts for confirmation before writing files. Use `-Force` to skip the prompt, or `-DryRun` to preview without writing.

```powershell
# Deploy everything (prompts for confirmation)
.\tooling\deploy.ps1

# Deploy to Claude Code, skip confirmation
.\tooling\deploy.ps1 -Target claude -Force

# Deploy only skills to Cursor
.\tooling\deploy.ps1 -Target cursor -Category skills

# Deploy only Claude Code settings + global CLAUDE.md
.\tooling\deploy.ps1 -Target claude -Category settings

# Deploy to WSL only
.\tooling\deploy.ps1 -Target wsl -Force

# Preview what would change (writes nothing)
.\tooling\deploy.ps1 -DryRun

# Show which deployed files differ from the repo
.\tooling\deploy.ps1 -Diff
```

On Linux and macOS, install PowerShell 7+ and invoke the same script directly — `pwsh tooling/deploy.ps1 -DryRun`. The `wsl` target is Windows-only and has no meaning elsewhere.

For Cursor targets, the script automatically transforms files:

- Strips `model` and `tools` from agent frontmatter
- Injects `## Tool Constraints` into agents whose Claude Code frontmatter restricted tools
- Derives `name` + `description` frontmatter for skills
- Uses `SKILL.cursor.md` as the source when it exists (for Cursor-native skill versions)
- Remaps tool names (`Bash`→`Shell`, `Edit`→`StrReplace`, `Agent`→`Task`)
- Replaces `~/.claude/` paths with `~/.cursor/`

See `docs/portability-guide.md` for the full format differences and tool gap analysis.

### Pruning orphans

The deploy script is additive by default: it creates and updates files at the target, but never removes anything. Over time this accumulates stale agents and skills — files that were renamed or deleted from the repo but remain in `~/.claude/` or `~/.cursor/`. The `--prune` / `-Prune` flag adds an opt-in delete pass that enumerates those orphans and removes them after confirmation.

```powershell
# Preview orphans across all targets — delete nothing
.\tooling\deploy.ps1 -Prune -DryRun

# Deploy + prune in one pass (prompts for confirmation twice: once for upsert, once for prune)
.\tooling\deploy.ps1 -Prune

# Prune only, skip upsert, no confirmation prompt — useful after renaming or deleting files in the repo
.\tooling\deploy.ps1 -PruneOnly -Force
```

Before deleting, the script prints the full orphan list and prompts: `Delete N orphan file(s)? [y/N]`. Pass `-Force` to skip the prompt, or `-DryRun` to preview without deleting anything. When both flags are present, dry-run wins — no deletion occurs regardless of `-Force`.

`-PruneOnly` skips the upsert pass entirely, making it the right choice after renaming or deleting files in the repo when you only want to clean up the targets, not re-deploy.

## Compatibility

| Component | Claude Code | Cursor | Notes |
| :--- | :---: | :---: | :--- |
| **Agents** | | | |
| architect | Yes | Yes | |
| change-analyzer | Yes | Yes | |
| code-intel | Yes | Yes | Dispatched by `/ops` Phase 2.5b for structural queries |
| code-reviewer | Yes | Yes | |
| code-reviewer-diff | Yes | Yes | |
| corpus-search | Yes | Yes | Dispatched by `/ops` Phase 2.5c for free-text evidence search |
| critic | Yes | Yes | |
| cross-memory | Yes | Yes | |
| db | Yes | Yes | Database operations (migrations, queries, backup/restore); dispatched by `/ops` or standalone |
| debugger | Yes | Yes | |
| debugger-build | Yes | Yes | |
| docs-lookup | Yes | Yes | Fetches current library/harness documentation from the open web with a version-provenance stamp and one citation; dispatched by `/ops` Phase 2.5d (advisory) or standalone |
| documentor | Yes | Yes | |
| executor | Yes | Yes | |
| generalist | Yes | Yes | In-domain catch-all for cross-lane residual work no specialist owns; dispatched by `/ops` or standalone |
| git-master | Yes | Yes | |
| infra | Yes | Yes | Provider-agnostic IaC / cloud / Kubernetes operations; dispatched by `/ops` or standalone |
| interviewer | Yes | Yes | |
| planner | Yes | Yes | Auto-transformed by deploy script |
| preflight | Yes | Yes | |
| project-scoper | Yes | Yes | |
| rollback | Yes | Yes | |
| scout | Yes | Yes | Read-only investigator for open/fuzzy repo questions; dispatched by `/ops` or standalone |
| security-reviewer | Yes | Yes | |
| ssh-executor | Yes | Yes | |
| verifier | Yes | Yes | |
| web-research | Yes | Yes | External/web research, multi-source fact-checking, and synthesis into cited reports; dispatched standalone or by `/ops` |
| work-verifier | Yes | Yes | |
| **Skills** | | | |
| clickup | Yes | Yes | |
| code-review | Yes | Yes | |
| commit-message | Yes | Yes | |
| cross-memory | Yes | Yes | |
| deploy | Yes | Yes | Cursor-native version uses `Task(subagent_type="ssh-executor")` for dispatch. No model/tool enforcement on subagent. |
| deslop | Yes | Yes | |
| doc-sync | Yes | Yes | |
| kickoff | Yes | No | Scaffolds planning infrastructure; dispatches interviewer, architect, planner, critic, and project-scoper agents. No Cursor-native version. |
| linter | Yes | Yes | |
| ops | Yes | Yes | Cursor-native version uses state file + TodoWrite for task board, `Task` tool for dispatch. No model escalation. |
| ralph-loop | Yes | Yes | |
| timing-calibrator | Yes | Yes | |
| using-ai-skills-agents | Yes | Yes | Usage/onboarding guide for this repo's agents and skills; single-file, instructional (no badge) |

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

## Access & Working Agreement

This is a private, single-maintainer repository. Two operating norms keep that trust model intact:

- **Least-privilege collaborator access** — grant the minimum role needed for the task at hand (read/triage over admin), and prefer time-boxed or reviewed grants over standing elevated access.
- **MFA on the source-of-truth account** — the GitHub account holding this repository must have multi-factor authentication enabled; it is the account of record for every deployed agent and skill copy (see `CLAUDE.md` § *Source of Truth & Deployment*).

Internal operating hygiene for a private repo, not a public governance policy.
