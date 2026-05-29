# Claude Code Agents

Custom subagents for Claude Code, installed globally at `~/.claude/agents/`. Each agent has a specific role and is automatically available in every project. Per-project overrides can be placed in `.claude/agents/` within the project directory.

All agents support `help` — invoke any agent with the task `help` to see its quick reference card (capabilities, verdicts, pipeline position, handoffs).

## Available Agents

| Agent | Model | Description |
| :--- | :---: | :--- |
| [interviewer](interviewer.md) | opus | Conducts structured Socratic interviews to crystallize ambiguous requirements. Identifies ambiguity dimensions, scores them 0.0–1.0, asks one targeted question at a time, and produces a requirements document. Dispatched before the planner when specs are vague. |
| [architect](architect.md) | opus | Explores design alternatives and produces Architecture Decision Documents (ADDs) that define component boundaries, evaluate trade-offs, and establish the structural foundation before planning begins. |
| [planner](planner.md) | opus | Breaks specifications and requirements into structured implementation plans (Milestones > Stages > Tasks > Subtasks). Identifies dependencies, sequencing, and risks. Writes in clear, natural language. Does not estimate hours. |
| [project-scoper](project-scoper.md) | opus | Analyzes requirements, identifies gaps and ambiguities, scopes projects with effort estimates, deliverables, dependencies, and produces formal scoping documents with timelines. Writes in clear, natural language. Also revises architecture and planning documents based on review or critic findings. |
| [critic](critic.md) | opus | Final quality gate. Reviews plans and scoping documents for flawed assumptions, gaps, ambiguities, and feasibility issues. Verdicts: ACCEPT / ACCEPT WITH RESERVATIONS / REVISE / REJECT. |
| [executor](executor.md) | sonnet | Implements code changes precisely as specified in validated plans. Works through tasks in order, verifies against acceptance criteria, and flags blockers. |
| [verifier](verifier.md) | sonnet | Validates that implementation meets acceptance criteria, assesses test coverage, writes missing tests, and runs integration checks before code review. |
| [security-reviewer](security-reviewer.md) | opus | Dedicated security auditor that analyzes implemented code for vulnerabilities, producing severity-rated findings with remediation guidance. Verdicts: SECURE / SECURE WITH FINDINGS / INSECURE. Auto-fired when the task carries a security content signal or `change-analyzer` returns `security-review: run` on the post-executor diff. |
| [code-reviewer](code-reviewer.md) | sonnet | Two-stage code review (spec compliance then quality) for pipeline and targeted module reviews. Severity-rated findings with verdicts. For standalone diff reviews, see `code-reviewer-diff` or use the `/code-review` slash command. |
| [code-reviewer-diff](code-reviewer-diff.md) | sonnet | Standalone diff review variant. Full diff-gathering protocol, exclusion filters, cross-file impact analysis, language-specific checks. Used when `/code-review` skill is unavailable. |
| [code-intel](code-intel.md) | opus | Indexes the project into a SQLite-backed symbol graph and answers structural queries (callers, dependencies, impact, implementations, execution flow) for other agents and orchestrators. Prevents silent breakage by replacing structural guessing with citable lookups. |
| [corpus-search](corpus-search.md) | opus | Terminal-native multi-hop corpus search for free-text evidence, file location, claim verification, and reference tracing — every finding cites path:line. Dispatched by `/ops` Phase 2.5c and standalone for investigative tasks. |
| [cross-memory](cross-memory.md) | opus | Handles three intents: synthesize curated context blocks from the cross-memory store (User preferences / Project context / Harness rules / Notes); audit the store for staleness, duplicates, contradictions, and redaction misses; distill reflect-session entries into durable memory. Dispatched by `/ops`, `/kickoff`, and peer agents for `synthesize`; by `/cross-memory audit` for `audit`; by `/cross-memory reflect` for `distill`. |
| [documentor](documentor.md) | sonnet | Writes new documentation for implemented features, creates guides, documents architectural decisions, and updates project scoping after milestones. Writes in clear, natural language tailored to the audience. Delegates to `/doc-sync` for accuracy checks, or runs its own audit when the skill is unavailable. |
| [debugger](debugger.md) | opus | Runtime bug investigation — hypothesis-driven root cause analysis, circuit breaker, similar pattern scan, regression verification. For build errors, see `debugger-build`. Available at any pipeline stage. |
| [debugger-build](debugger-build.md) | opus | Focused variant for build/compilation errors — import errors, type errors, dependency issues, config errors. Systematic fix with progress tracking. Use instead of `debugger` when the error type is known to be a build issue. |
| [git-master](git-master.md) | sonnet | Utility agent for git operations — branching, commits, PRs, merges, conflict resolution, releases, repo hygiene, and work-in-progress pause/resume. Generates commit messages standalone when `/commit-message` is unavailable. Available at any pipeline stage. |
| [ssh-executor](ssh-executor.md) | sonnet | Executes commands on remote servers via SSH. Handles remote command execution, file transfer (scp), remote verification, and service management. Uses SSH config for host resolution and key-based auth only. |
| [preflight](preflight.md) | sonnet | Validates project environment readiness — runtime, dependencies, git, config files, disk space. Returns a structured pass/fail/warn checklist. Runs before any agent dispatch. |
| [work-verifier](work-verifier.md) | sonnet | Verifies whether interrupted or prior agent work was actually completed by checking file existence, git diff, handoff files, and content quality. Returns per-deliverable verdicts for resume decisions. |
| [rollback](rollback.md) | sonnet | Rolls back agent-produced changes at the appropriate scope — single task, task chain, full run, or worktree. Stashes before reverting, checks for file overlap, and respects guardrails. |
| [change-analyzer](change-analyzer.md) | sonnet | Analyzes a git diff to classify changes and recommend which pipeline stages (verify, deslop, review, security-review) to run or skip. Returns per-stage recommendations with justification. Also recommends the security-review stage when the diff touches security-sensitive paths, providing the single classification signal the team manager uses to auto-schedule `security-reviewer`. |

### Model assignments

Agents that require deep reasoning, nuanced judgment, or complex analysis use **opus**: planner, project-scoper, critic, debugger, debugger-build, interviewer, architect, security-reviewer, code-intel, corpus-search, cross-memory. Agents that follow structured instructions, execute plans, or perform well-scoped checks use **sonnet**: executor, git-master, ssh-executor, verifier, code-reviewer, code-reviewer-diff, documentor, preflight, work-verifier, rollback, change-analyzer.

### Overriding the default model

The model in each agent's frontmatter is the default. It can be overridden in two ways:

1. **At spawn time** — pass a `model` parameter when invoking the Agent tool. This takes precedence over the frontmatter. The `/ops` can do this per-task if needed.
2. **Per project** — create a project-level `.claude/agents/<agent-name>.md` with a different `model` field. Project-level agents override global agents of the same name.

For example, to run the executor on opus for a particularly complex implementation, the ops would spawn it with `model: "opus"`. Or to use haiku for documentation tasks in a cost-sensitive project, drop a `documentor.md` in that project's `.claude/agents/` with `model: haiku`.

### Programmatic dispatch (ops skill)

All agent definition files at `~/.claude/agents/` are auto-registered as `subagent_type` values for the `Agent` tool. The ops skill dispatches directly: `Agent(subagent_type="<agent_type>", description="<task subject>", model="<from frontmatter>", prompt=<self-read template + brief>)`. The self-read prompt template instructs the agent to read its own definition file as its first action, providing full workflow context. See `docs/portability-guide.md` § Agent Dispatch Mechanism for the full procedure.

Cursor's `Task` tool also includes all agent types as `subagent_type` values natively.

## Shared snippets (`agents/_shared/`)

Module contract, version, and consumer list: [`_shared/README.md`](_shared/README.md).

Pipeline agents share brief-format boilerplate in [`_shared/brief-format-snippet.md`](_shared/brief-format-snippet.md) instead of duplicating it in every contract. Each agent's `## Brief Format` subsection keeps agent-specific overrides only and points at the snippet with a **`See`** line (for example, `See ~/.claude/agents/_shared/brief-format-snippet.md`). Agents that compose or validate briefs still use **`You MUST Read`** on `~/.claude/skills/ops/brief-contract.md` for the canonical contract.

Deploy includes nested markdown: [`tooling/deploy-manifest.json`](../tooling/deploy-manifest.json) uses `"include": ["**/*.md"]` for agents (both Claude Code and Cursor targets), so `_shared/` ships to `~/.claude/agents/_shared/` and, on Cursor deploy, `~/.cursor/agents/_shared/` with path rewrite. `agents/README.md` stays repo-only (`exclude: ["README.md"]`). See [`skills/ops/pointer-format.md`](../skills/ops/pointer-format.md) for MUST vs See tiering.

## Extended documentation

Usage examples, handoff behavior, utility-agent details, parallelization thresholds, and the full permissions reference are in **[Agents guide](../docs/agents-guide.md)** (repo-only; not deployed).

| Topic | Section |
| :--- | :--- |
| Prompt examples per agent | [Usage](../docs/agents-guide.md#usage) |
| Handoffs and autonomous mode | [Handoff behavior](../docs/agents-guide.md#handoff-behavior) |
| Pipeline stages and utility agents | [Workflow](../docs/agents-guide.md#workflow) |
| Parallel dispatch thresholds | [Parallelization](../docs/agents-guide.md#parallelization) |
| `settings.json` allow/deny lists | [Permissions Reference](../docs/agents-guide.md#permissions-reference) |

## Workflow

Default pipeline (optional stages in brackets):

```text
[Interviewer] → [Architect] → Planner → Project Scoper → Critic → Executor → Verifier → [Security Reviewer] → [Deslop] → Code Reviewer → Documentor → Done
```

For stage-by-stage detail, utility-agent handoffs, and parallelization, see [Agents guide](../docs/agents-guide.md#workflow). For automated orchestration, use `/ops` — see [`skills/ops/README.md`](../skills/ops/README.md).

### Permissions

The complete allow/deny permission tables for agents and `/ops` live in [Agents guide — Permissions Reference](../docs/agents-guide.md#permissions-reference). The ops skill also summarizes risky tools that always prompt.
