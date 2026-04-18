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
| [security-reviewer](security-reviewer.md) | opus | Dedicated security auditor that analyzes implemented code for vulnerabilities, producing severity-rated findings with remediation guidance. Verdicts: SECURE / SECURE WITH FINDINGS / INSECURE. |
| [code-reviewer](code-reviewer.md) | sonnet | Two-stage code review (spec compliance then quality) for pipeline and targeted module reviews. Severity-rated findings with verdicts. For standalone diff reviews, see `code-reviewer-diff` or use the `/code-review` slash command. |
| [code-reviewer-diff](code-reviewer-diff.md) | sonnet | Standalone diff review variant. Full diff-gathering protocol, exclusion filters, cross-file impact analysis, language-specific checks. Used when `/code-review` skill is unavailable. |
| [documentor](documentor.md) | sonnet | Writes new documentation for implemented features, creates guides, documents architectural decisions, and updates project scoping after milestones. Writes in clear, natural language tailored to the audience. Delegates to `/doc-sync` for accuracy checks, or runs its own audit when the skill is unavailable. |
| [debugger](debugger.md) | opus | Runtime bug investigation — hypothesis-driven root cause analysis, circuit breaker, similar pattern scan, regression verification. For build errors, see `debugger-build`. Available at any pipeline stage. |
| [debugger-build](debugger-build.md) | opus | Focused variant for build/compilation errors — import errors, type errors, dependency issues, config errors. Systematic fix with progress tracking. Use instead of `debugger` when the error type is known to be a build issue. |
| [git-master](git-master.md) | sonnet | Utility agent for git operations — branching, commits, PRs, merges, conflict resolution, releases, repo hygiene, and work-in-progress pause/resume. Generates commit messages standalone when `/commit-message` is unavailable. Available at any pipeline stage. |
| [ssh-executor](ssh-executor.md) | sonnet | Executes commands on remote servers via SSH. Handles remote command execution, file transfer (scp), remote verification, and service management. Uses SSH config for host resolution and key-based auth only. |

### Model assignments

Agents that require deep reasoning, nuanced judgment, or complex analysis use **opus**: planner, project-scoper, critic, debugger, debugger-build, interviewer, architect, security-reviewer. Agents that follow structured instructions, execute plans, or perform well-scoped checks use **sonnet**: executor, git-master, ssh-executor, verifier, code-reviewer, code-reviewer-diff, documentor.

### Overriding the default model

The model in each agent's frontmatter is the default. It can be overridden in two ways:

1. **At spawn time** — pass a `model` parameter when invoking the Agent tool. This takes precedence over the frontmatter. The `/ops` can do this per-task if needed.
2. **Per project** — create a project-level `.claude/agents/<agent-name>.md` with a different `model` field. Project-level agents override global agents of the same name.

For example, to run the executor on opus for a particularly complex implementation, the ops would spawn it with `model: "opus"`. Or to use haiku for documentation tasks in a cost-sensitive project, drop a `documentor.md` in that project's `.claude/agents/` with `model: haiku`.

### Programmatic dispatch (ops skill)

When the ops skill dispatches agents programmatically via the `Agent` tool, the `subagent_type` parameter only accepts a limited built-in enum (`general-purpose`, `Explore`, `Plan`, `debugger-build`, `git-master`, `claude-code-guide`, `statusline-setup`). `debugger-build`, `git-master`, `code-reviewer`, and `code-reviewer-diff` from this taxonomy have matching entries (Claude Code built-ins; the enum may expand); all other agents dispatch as `general-purpose`.

Custom agent files at `~/.claude/agents/` are loaded when a user invokes an agent by name in conversation, but they do **not** extend the `subagent_type` enum for programmatic dispatch. The ops skill works around this by reading the agent definition file, injecting its instructions into the prompt, and labeling the dispatch via the `description` field (e.g., `"executor(Implement auth middleware)"`). See `docs/portability-guide.md` § Agent Dispatch Mechanism for the full procedure.

In Cursor, this is not an issue — Cursor's `Task` tool `subagent_type` enum includes all 15 agent types natively.

## Usage

Agents are invoked automatically by Claude Code when a task matches their description. You can also request them explicitly by name or by describing the task.

### Architect

- _"Use the architect to explore design options for the new caching layer"_
- _"Have the architect evaluate trade-offs between a queue-based vs event-driven approach"_
- _"Design the component boundaries for the notification system"_
- _"Produce an ADD for the authentication migration"_

### Planner

- _"Use the planner to break down this feature"_
- _"Plan the implementation for adding WebSocket support to the worker"_
- _"Break down Milestone 4 into stages and tasks"_
- _"I have these requirements — plan how to implement them"_

### Project Scoper

- _"Have the project scoper estimate this work"_
- _"Scope out the effort for adding a new detection model"_
- _"Analyze these requirements for gaps before we estimate"_
- _"Produce a scoping document for the planner's output"_

### Critic

- _"Have the critic review this plan before we start"_
- _"Review the scoping document for feasibility issues"_
- _"Is this plan ready for implementation? Have the critic check"_

### Executor

- _"Start implementing the validated plan"_
- _"Execute task 3.2 from the plan"_
- _"Implement the next task in the plan"_
- _"Continue implementing — pick up where we left off"_

### SSH Executor

- _"Deploy the build artifact to staging via SSH"_
- _"Verify the remote health endpoint returns 200"_
- _"Transfer the config file to the production server"_
- _"Restart the API service on the staging server"_
- _"Tail the last 100 lines of the app log on production"_

### Verifier

- _"Verify the executor's implementation against the acceptance criteria"_
- _"Check if all acceptance criteria for Milestone 3 are met"_
- _"Assess test coverage for the new detection module"_
- _"Run integration checks on the changes"_

### Security Reviewer

- _"Have the security reviewer audit the auth middleware changes"_
- _"Run a security review on the API endpoint implementations"_
- _"Check the payment processing code for vulnerabilities"_
- _"Security audit the user input handling in the new form"_

### Code Reviewer

- _"Have the code reviewer check this module for security issues"_
- _"Review the data pipeline for performance bottlenecks"_
- _"Do a release readiness review on the staged changes"_
- _"Review `src/parser.py` for correctness"_

### Documentor

- _"Document the new feature and update project scoping"_
- _"Write a developer guide for the processing pipeline"_
- _"Update the project scoping doc — Milestone 3 is complete"_
- _"Create API documentation for the new endpoints"_
- _"Document the architectural decisions from this milestone"_

### Debugger

- _"Debug why the parser is returning empty results for large inputs"_
- _"This test started failing after the last commit — have the debugger investigate"_
- _"The verifier reported a failure on AC3. Debug it."_
- _"There's a RuntimeError in the transform stage — find the root cause"_

### Debugger (Build)

- _"The build is broken — 12 import errors after the refactor. Have the debugger-build fix them."_
- _"ModuleNotFoundError when running pytest — debug-build it"_
- _"Fix the type errors in the converter package"_
- _"Dependency errors after upgrading — have debugger-build resolve them"_

### Git Master

- _"Pause my current work, I need to switch to a hotfix"_
- _"Resume where I left off"_
- _"Create a PR for this branch"_
- _"Split these changes into atomic commits"_
- _"Create a feature branch for the new verification framework"_
- _"Resolve the merge conflicts on this branch"_
- _"Tag this as v0.3.0 and generate a changelog"_

### Ops (skill)

For automated pipeline orchestration, use the `/ops` skill instead of manually invoking agents. It creates a shared task board, dispatches agents in parallel where safe, tracks progress, and handles failures. See [`~/.claude/skills/ops/README.md`](../skills/ops/README.md) for full documentation.

- _"/ops Add WebSocket support to the worker"_
- _"/ops execute"_ (plan already in conversation)
- _"/ops --autonomous Implement Milestone 4"_
- _"/ops status"_
- _"/ops resume"_

### Running the full pipeline

You can run the entire pipeline end-to-end by starting with the planner (or use `/ops` to automate it):

- _"Here are the specs for a new feature. Run the full pipeline — plan it, scope it, review, implement, verify, and document."_
- _"Take this feature request through the full pipeline"_

### Partial pipeline runs

You don't have to run the full pipeline. Start at any stage, stop at any stage, or skip stages entirely:

**Start at planner, stop early:**

- _"Here's a spec. Have the planner break it down and the project scoper estimate it. Stop there — I'll review before we go further."_
- _"Run this through planner → scoper → critic only. No implementation yet."_
- _"Plan and scope this feature, but don't implement anything."_

**Skip stages:**

- _"I already have a plan. Skip the planner and go straight to the project scoper."_
- _"Here's a scoping document. Have the critic review it directly."_
- _"The code is already written. Just run the verifier and code reviewer."_

**Single agent invocation:**

- _"Just have the critic review this plan — nothing else."_
- _"Run the verifier on what the executor just built. Don't proceed to code review yet."_
- _"Pass this document to the planner and tell me how it would break down the work."_

### Handoff behavior

By default, every agent prompts the user before handing off to the next stage. You always have the opportunity to:

- **Proceed** — approve the handoff and let the next agent start.
- **Stop** — pause the pipeline and review the current output.
- **Redirect** — skip the next stage, go back to a previous stage, or invoke a utility agent (e.g., git-master) before continuing.
- **Adjust** — give feedback on the current agent's output before it hands off.

This means the pipeline is collaborative, not automated. You stay in control at every transition.

**Autonomous mode:** You can opt in to silent advancement by explicitly requesting it. Agents will hand off without prompting, stopping only when a decision requires user input (e.g., critic issues ACCEPT WITH RESERVATIONS, verifier issues VERIFIED WITH GAPS, or any agent encounters a blocker).

- _"Run planner → scoper → critic autonomously. Only stop if the critic rejects."_
- _"Implement, verify, and review — don't ask me between stages."_
- _"Run the full pipeline autonomously. Stop at decision points only."_

Autonomous mode is per-request, not a persistent setting. The next run defaults back to prompting at each handoff unless you request autonomous mode again.

## Workflow

### Planning and Scoping Pipeline

All agents work as a pipeline with explicit handoffs between each stage:

1. **Interviewer** _(optional)_ — when specs are ambiguous, conducts a structured Socratic Q&A with the user to crystallize requirements before planning. Produces a requirements document. Skipped when specs are already clear.
2. **Architect** _(optional)_ — when the spec involves significant design decisions (new subsystems, technology choices, competing strategies, component boundary changes), explores alternatives and produces an Architecture Decision Document (ADD). The planner uses the ADD as structural input. Skipped when the implementation approach is clear.
3. **Planner** — breaks down specifications into a structured plan (what, how, in what order). Classifies scope, identifies dependencies, flags risks. Does not estimate hours.
4. **Project Scoper** — receives the plan, runs requirements analysis (gap detection, guardrails, scope risks, edge cases), then produces the formal scoping document with estimates, timelines, and traceability.
5. **Critic** — reviews the combined plan and scoping document for flawed assumptions, gaps, ambiguities, and feasibility issues. Issues a verdict before implementation begins.
6. **Executor** — implements code changes precisely as specified. Works through tasks in order, verifies against acceptance criteria, flags blockers.
7. **Verifier** — validates that acceptance criteria are met, assesses test coverage, writes missing tests, and runs integration checks.
8. **Security Reviewer** _(optional)_ — dedicated security audit of implemented code. Dispatched when changes involve security-sensitive patterns (auth, input handling, data access, cryptography, network calls). Produces severity-rated vulnerability findings with remediation guidance. Does not fix issues — hands off to the executor for remediation.
9. **Deslop** _(automatic)_ — runs `/deslop --conservative` on modified files to clean AI-generated structural bloat. Enabled by default; skipped with `--no-deslop`. Skipped silently if the skill is unavailable.
10. **Code Reviewer** — reviews the cleaned changes before commit. Delegates to `/code-review` for git diff reviews when available, or handles them directly with its built-in fallback.
11. **Documentor** — writes new documentation for implemented features, documents decisions, updates project scoping, then runs `/doc-sync` for a final consistency check (or its built-in audit fallback if the skill is unavailable).

```text
[Interviewer] → [Architect] → Planner → Project Scoper → Critic → Executor → Verifier → [Security Reviewer] → [Deslop] → Code Reviewer → Documentor → Done
```

_Brackets indicate optional/automatic stages. Interviewer runs only when specs are ambiguous. Security Reviewer runs when changes involve security-sensitive patterns. Deslop runs automatically unless disabled._

_The `ssh-executor` can be inserted between executor and verifier for deployment workflows: `executor → ssh-executor → verifier`. It can also operate standalone for remote verification tasks._

### Writing tone

The planner, project-scoper, and documentor all produce human-readable output. They follow a shared writing tone: plain language first, technical terms with context, conversational (not robotic), short sentences, active voice. Each agent's definition has a **Writing tone** section with specific guidance for its output type. The `/doc-sync` skill preserves the existing tone of docs it updates rather than imposing its own.

### Utility Agents

These agents operate independently of the pipeline and can be invoked at any stage:

**Debugger:**

- Hypothesis-driven investigation of bugs, errors, and unexpected behavior
- Root cause analysis with structured diagnosis (symptom collection → reproduction → hypothesis elimination → fix)
- For build/compilation errors (import, type, dependency, config errors), see the **debugger-build** variant
- 3-failure circuit breaker — escalates after 3 failed hypotheses instead of looping
- Similar pattern scan — greps for the same bug pattern elsewhere in the codebase after fixing
- Minimal, targeted fixes with regression verification and regression test creation
- Explicit scope boundaries — does not refactor, redesign, or optimize; hands off to the appropriate agent

**Git Master:**

- Branch creation, naming, cleanup
- Commit orchestration (supplements `/commit-message`, or generates messages standalone via built-in fallback)
- PR lifecycle, merge, conflict resolution
- Release tagging and changelogs
- **Pause/resume** — checkpoint WIP via stash or WIP commit, restore later

**Code Reviewer:**

- Two-stage review (spec compliance then quality) with severity-rated findings
- Supplements the `/code-review` slash command. For standalone diff reviews, see the **code-reviewer-diff** variant.
- Targeted reviews for specific concerns (e.g., thread safety, performance, security)
- Can be invoked outside the pipeline for ad-hoc reviews on any code

**Documentor:**

- Write documentation for existing features that were never documented
- Create guides, API references, or setup docs on demand
- Update the project scoping document outside the pipeline (e.g., marking a milestone complete)
- Document architectural decisions after a discussion
- Delegates to `/doc-sync` for accuracy checks, or runs built-in audit fallback when the skill is unavailable

**SSH Executor:**

- Remote command execution via SSH (`ssh -o BatchMode=yes`)
- File transfer via SCP (single files) or tar-over-ssh (directories, rsync unavailable on Windows)
- Remote health checks, endpoint verification, log inspection
- Service management (systemctl, docker) via SSH
- ProxyJump/bastion host support via standard SSH config

### Utility Agent Handoffs

Utility agents can hand off to pipeline agents or other utility agents depending on their outcome. Unlike the linear pipeline, these handoffs are conditional — they depend on what the agent found.

**Debugger:**

| Outcome | Hands off to |
| :--- | :--- |
| Fix applied and verified | **git-master** (commit fix + test separately), then **verifier** (re-run verification if bug surfaced during verification) |
| Root cause requires design change | **planner** (scope the change) or **executor** (if small and well-defined) |
| Cannot reproduce | Back to **user** for additional context or reproduction steps |
| Root cause in a dependency | No handoff — documents upstream issue and workaround |

**Code Reviewer** (when invoked outside the pipeline):

| Outcome | Hands off to |
| :--- | :--- |
| APPROVE / COMMENT | **git-master** (split and commit if needed), then **documentor** |
| REQUEST CHANGES | **executor** (address findings), then **verifier** (re-verify), then back to code reviewer |

**Documentor** (when invoked outside the pipeline):

| Outcome | Hands off to |
| :--- | :--- |
| Documentation complete | `/doc-sync` (final consistency check), or built-in audit fallback |
| Reveals implementation gap | **executor** (fix the gap) |

**Git Master:**

No outbound handoffs. Git-master is a pure utility — it is invoked by other agents (or the user) and returns control to the caller when done.

**SSH Executor:**

| Outcome | Hands off to |
| :--- | :--- |
| Deployment complete, needs verification | **verifier** (validate remote state) |
| Remote config changed, needs review | **code-reviewer** (review config changes) |
| Deployment complete, needs recording | **git-master** (tag deployment, update changelog) |
| Connection or permission failure | Back to **user** with diagnostic details |

### Parallelization

Agents cannot spawn subagents themselves (Claude Code limitation). The main session orchestrates parallelization by spawning multiple instances of the same agent when workload thresholds are met. Each agent defines its own scaling guidance:

| Agent | Threshold | Split dimension |
| :--- | :--- | :--- |
| Planner | 3+ subsystems | Parallel Explore agents for codebase research. |
| Architect | 3+ subsystems | Parallel Explore agents for domain research. |
| Project Scoper | 3+ milestones | Gap analysis and estimation per milestone. |
| Critic | 3+ milestones | Review per milestone, single-pass verdict. |
| Executor | 5+ independent tasks | Task groups by module (no shared files). |
| SSH Executor | 2+ SSH tasks to different hosts | By target host (never same host). |
| Verifier | 10+ criteria or 3+ modules | Verification per module or criteria group. |
| Code Reviewer | 5+ files | File groups of 3–5, single-pass spec compliance. |
| Security Reviewer | 3+ modules | Parallel instances per module (same pattern as code-reviewer). |
| Documentor | 3+ independent docs | One doc per instance, single-pass map update. |
| Debugger | 2+ independent bugs | One bug per instance (shared root cause → same instance). |
| Debugger (Build) | 5+ errors | Error groups by type (import, type, config). |
| Git Master | 3+ branches need same op | One operation per branch (never same branch). |

See each agent's **Scaling** section for full details on merge strategies and constraints.

### Permissions Reference

Below is the complete set of permissions needed for agents, skills, and the `/ops` to run without prompts. Add these to `~/.claude/settings.json` (global) or `.claude/settings.json` (per project).

If you experience an unexpected permission prompt, find the relevant entry below and add it to your settings.

#### Core tools

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Edit` | executor, verifier, documentor, debugger, git-master, project-scoper | Edit existing files |
| `Write` | executor, verifier, documentor, debugger, git-master, project-scoper | Create new files |
| `Read` | all agents | Read files |
| `Glob` | all agents | Find files by pattern |
| `Grep` | all agents | Search file contents |
| `Agent` | ops | Spawn sub-agents |
| `WebSearch` | planner, project-scoper | Search the web for context |
| `WebFetch` | planner, project-scoper | Fetch web page content |
| `NotebookEdit` | executor | Edit Jupyter notebooks |
| `TodoWrite` | any agent | Legacy todo list |
| `Skill` | ops | Invoke skills (`/ralph-loop`, `/doc-sync`, `/code-review`, etc.) |

#### State file tools (ops)

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Write` | ops | Create/update `.ops-state/<run-id>-board.json` state file |
| `Read` | ops | Read state file for resume, status, and dispatch |

#### Plan and worktree tools

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `EnterPlanMode` | planner | Enter structured plan mode |
| `ExitPlanMode` | planner | Exit plan mode after writing plan |
| `EnterWorktree` | ops (`--worktree`) | Create isolated git worktree for parallel agents |
| `ExitWorktree` | ops (`--worktree`) | Clean up worktree after agent finishes |

#### Scheduling tools

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `CronCreate` | `/schedule` skill, timed tasks | Create recurring or one-shot scheduled jobs |
| `CronDelete` | `/schedule` skill | Remove scheduled jobs |
| `CronList` | `/schedule` skill | List active scheduled jobs |

#### Bash — Git

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(git *)` | git-master, all agents | Git operations |
| `Bash(gh *)` | git-master | GitHub CLI (PRs, issues, checks) |

#### Bash — Python

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(python *)` | executor, verifier, debugger | Run Python scripts |
| `Bash(python3 *)` | executor, verifier, debugger | Run Python 3 scripts |
| `Bash(pip *)` | executor | Install packages |
| `Bash(pip3 *)` | executor | Install packages (pip3) |
| `Bash(pytest *)` | verifier, debugger | Run tests |
| `Bash(.venv/*)` | any agent | Run venv binaries directly |
| `Bash(uv *)` | executor | Fast Python package manager |
| `Bash(poetry *)` | executor | Python dependency management |
| `Bash(ruff *)` | `/linter` skill, code-reviewer | Python linter/formatter |
| `Bash(black *)` | `/linter` skill | Python formatter |
| `Bash(mypy *)` | verifier | Python type checker |

#### Bash — Node.js / TypeScript

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(node *)` | executor, verifier | Run Node.js scripts |
| `Bash(npm *)` | executor | Node package manager |
| `Bash(eslint *)` | `/linter` skill | JavaScript/TypeScript linter |
| `Bash(prettier *)` | `/linter` skill | Code formatter |
| `Bash(tsc *)` | verifier | TypeScript compiler/checker |

#### Bash — Docker

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(docker *)` | executor, debugger | Container operations |
| `Bash(docker-compose *)` | executor | Multi-container orchestration |

#### Bash — SSH / Remote

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(ssh *)` | ssh-executor | Remote command execution via SSH |
| `Bash(scp *)` | ssh-executor | File transfer to/from remote hosts |

#### Bash — Shells

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(bash *)` | any agent | Run bash scripts |
| `Bash(powershell *)` | any agent (Windows) | Run PowerShell scripts |
| `Bash(pwsh *)` | any agent (Windows) | Run PowerShell Core scripts |
| `Bash(cmd *)` | any agent (Windows) | Run cmd commands |
| `Bash(cmd.exe *)` | any agent (Windows) | Run cmd.exe commands |

#### Bash — File operations

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(ls *)` | any agent | List directory contents |
| `Bash(cd *)` | any agent | Change directory |
| `Bash(mkdir *)` | executor, documentor | Create directories |
| `Bash(cp *)` | executor, git-master | Copy files |
| `Bash(mv *)` | executor, git-master | Move/rename files |
| `Bash(rm *)` | executor | Remove files |
| `Bash(touch *)` | executor | Create empty files |
| `Bash(chmod *)` | executor | Change file permissions |
| `Bash(find *)` | any agent | Find files |

#### Bash — Text processing

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(cat *)` | any agent | Concatenate/display files |
| `Bash(head *)` | any agent | Show first lines |
| `Bash(tail *)` | any agent | Show last lines |
| `Bash(wc *)` | any agent | Word/line count |
| `Bash(diff *)` | code-reviewer, verifier | Compare files |
| `Bash(sort *)` | any agent | Sort lines |
| `Bash(grep *)` | any agent | Search text (fallback) |
| `Bash(rg *)` | any agent | Ripgrep search (fallback) |
| `Bash(sed *)` | any agent | Stream editing (fallback) |
| `Bash(awk *)` | any agent | Text processing (fallback) |
| `Bash(tee *)` | any agent | Write to file and stdout |
| `Bash(xargs *)` | any agent | Build commands from input |

#### Bash — Utilities

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(echo *)` | any agent | Print text |
| `Bash(which *)` | debugger | Find command location |
| `Bash(type *)` | debugger | Check command type |
| `Bash(env *)` | debugger | Show/set environment |
| `Bash(printenv *)` | debugger | Print environment variables |
| `Bash(source *)` | any agent | Source shell scripts |
| `Bash(date *)` | any agent | Date/time operations |
| `Bash(sleep *)` | any agent | Pause execution |
| `Bash(realpath *)` | any agent | Resolve file paths |
| `Bash(dirname *)` | any agent | Extract directory from path |
| `Bash(basename *)` | any agent | Extract filename from path |
| `Bash(curl *)` | any agent | HTTP requests |

#### Bash — Archives

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(tar *)` | executor | Create/extract tar archives |
| `Bash(zip *)` | executor | Create zip archives |
| `Bash(unzip *)` | executor | Extract zip archives |

#### Path-scoped permissions

| Permission | Purpose |
| :--- | :--- |
| `Edit(.claude/**)` | Edit project-level agent/command/settings files |
| `Write(.claude/**)` | Create project-level agent/command/settings files |

For user-level config access, also add (adjust the path to your home directory):

```
Read(//c/Users/<username>/.claude/**)
Edit(//c/Users/<username>/.claude/**)
Write(//c/Users/<username>/.claude/**)
```

#### Prompt before allowing (risky)

These are intentionally **not auto-allowed**. If an agent needs one of these, the user will be prompted. Opt in per project only if you trust the build scripts.

| Permission | Risk | When it comes up |
| :--- | :--- | :--- |
| `RemoteTrigger` | Spins up remote agents on claude.ai that consume API credits unattended. | Scheduling remote agent triggers or using the `/schedule` skill. |
| `Bash(npx *)` | Executes arbitrary npm packages — could run untrusted code. | Running Node.js tooling not installed globally (e.g., `npx prettier`, `npx jest`). |
| `Bash(make *)` | Runs arbitrary Makefile targets — a Makefile can do anything. | Building projects, running test suites via `make test`, compiling native extensions. |
| `Bash(cmake *)` | Runs arbitrary CMake commands. | Configuring and building C/C++ projects. |
| `Bash(ssh *)` | Connects to remote hosts and executes commands — network operation with security implications. | Deploying code, verifying remote services, managing remote processes via the ssh-executor agent. |
| `Bash(scp *)` | Transfers files to/from remote hosts — network operation. | Deploying artifacts, uploading configs to remote servers via the ssh-executor agent. |

To opt in per project, add to `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "RemoteTrigger",
      "Bash(npx *)",
      "Bash(make *)",
      "Bash(cmake *)",
      "Bash(ssh *)",
      "Bash(scp *)"
    ]
  }
}
```

#### Recommended deny list

These destructive operations should be denied globally to prevent accidental damage:

```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push *)",
      "Bash(git reset --hard*)",
      "Bash(git clean *)",
      "Bash(git branch -D *)",
      "Bash(ssh * rm -rf *)"
    ]
  }
}
```
