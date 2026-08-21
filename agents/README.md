# Claude Code Agents

Custom subagents for Claude Code, installed globally at `~/.claude/agents/`. Each agent has a specific role and is automatically available in every project. Per-project overrides can be placed in `.claude/agents/` within the project directory.

All agents support `help` — invoke any agent with the task `help` to see its quick reference card (capabilities, verdicts, pipeline position, handoffs).

## Available Agents

| Agent | Model | Description |
| :--- | :---: | :--- |
| [architect](architect.md) | opus | Explores design alternatives and produces Architecture Decision Documents (ADDs) that define component boundaries, evaluate trade-offs, and establish the structural foundation before planning begins. Writes the ADD to `docs/plan/*-design.md` (brainstorm gate) or `docs/plan/*-architecture.md` (default path) (`Write` creates a new ADD, `Edit` revises an existing one). |
| [change-analyzer](change-analyzer.md) | sonnet | Analyzes a git diff to classify changes and recommend which pipeline stages (verify, deslop, review, security-review) to run or skip. Returns per-stage recommendations with justification. Also recommends the security-review stage when the diff touches security-sensitive paths, providing the single classification signal the team manager uses to auto-schedule `security-reviewer`. |
| [code-intel](code-intel.md) | opus | Indexes the project into a SQLite-backed symbol graph and answers structural queries (callers, dependencies, impact, implementations, execution flow) for other agents and orchestrators. Prevents silent breakage by replacing structural guessing with citable lookups. |
| [code-reviewer](code-reviewer.md) | sonnet | Two-stage code review (spec compliance then quality) for pipeline and targeted module reviews. Severity-rated findings with verdicts. For standalone diff reviews, see `code-reviewer-diff` or use the `/code-review` slash command. |
| [code-reviewer-diff](code-reviewer-diff.md) | sonnet | Standalone diff review variant. Full diff-gathering protocol, exclusion filters, cross-file impact analysis, language-specific checks. Used when `/code-review` skill is unavailable. |
| [corpus-search](corpus-search.md) | opus | Terminal-native multi-hop corpus search for free-text evidence, file location, claim verification, and reference tracing — every finding cites path:line. Dispatched by `/ops` Phase 2.5c and standalone for investigative tasks. |
| [critic](critic.md) | opus | Final quality gate. Reviews plans and scoping documents for flawed assumptions, gaps, ambiguities, and feasibility issues. Verdicts: ACCEPT / ACCEPT WITH RESERVATIONS / REVISE / REJECT. |
| [cross-memory](cross-memory.md) | opus | Handles three intents: synthesize curated context blocks from the cross-memory store (User preferences / Project context / Harness rules / Notes); audit the store for staleness, duplicates, contradictions, and redaction misses; distill durable memories from project artifacts (git history, plan docs, handoffs, optional transcripts). Dispatched by `/ops`, `/kickoff`, and peer agents for `synthesize`; by `/cross-memory audit` for `audit`; by `/cross-memory reflect` for `distill`. |
| [db](db.md) | sonnet | Performs database operations — schema migrations, queries, and backup/restore — enforcing backup-before-mutate and a write gate on mutating commands whose primary control is the agent's own STOP-before-mutate discipline, not the permission layer (which reinforces it only on Claude Code). Composes with `ssh-executor` for databases reachable only through a bastion or tunnel. Escalates to opus proactively for destructive, schema-changing, or production operations rather than waiting for repeated failures. |
| [debugger](debugger.md) | opus | Runtime bug investigation — hypothesis-driven root cause analysis, circuit breaker, similar pattern scan, regression verification. For build errors, see `debugger-build`. Available at any pipeline stage. |
| [debugger-build](debugger-build.md) | opus | Focused variant for build/compilation errors — import errors, type errors, dependency issues, config errors. Systematic fix with progress tracking. Use instead of `debugger` when the error type is known to be a build issue. |
| [docs-lookup](docs-lookup.md) | opus | Fetches current third-party library and harness documentation from the open web and returns a code-ready snippet with a version-provenance stamp and one authoritative citation. Fetch-only and inline; a best-effort approximation of a documentation index, not a replacement for one. Dispatched by `/ops` Phase 2.5d or standalone. |
| [documentor](documentor.md) | sonnet | Writes new documentation for implemented features, creates guides, documents architectural decisions, and updates project scoping after milestones. Writes in clear, natural language tailored to the audience. Delegates to `/doc-sync` for accuracy checks, or runs its own audit when the skill is unavailable. |
| [executor](executor.md) | sonnet | Implements code changes precisely as specified in validated plans. Works through tasks in order, verifies against acceptance criteria, and flags blockers. |
| [generalist](generalist.md) | sonnet | Disciplined in-domain catch-all for cross-lane residual work that no existing specialist owns — defers to the correct specialist first, then to the executor for anything beyond a minor, single-file edit. Replaces reflexive use of the harness `general-purpose`/`claude` agents for in-domain work. No web tools; web-dependent work routes to `web-research`. |
| [git-master](git-master.md) | sonnet | Utility agent for git operations — branching, commits, PRs, merges, conflict resolution, releases, repo hygiene, and work-in-progress pause/resume. Generates commit messages standalone when `/commit-message` is unavailable. Available at any pipeline stage. |
| [infra](infra.md) | sonnet | Provider-agnostic infrastructure agent for Infrastructure-as-Code, cloud CLIs, and Kubernetes — validates, plans, and converges Terraform/Pulumi/CloudFormation/CDK/Ansible stacks, `aws`/`gcloud`/`az` resources, and `kubectl`/`helm` manifests. Applies or destroys only behind a human-approved verbatim plan, gated primarily by the agent's own STOP-before-mutate discipline, not the permission layer (which reinforces it only on Claude Code). Composes with `ssh-executor` for host-level access within a provisioned stack; escalates to opus proactively for mutating or production-targeting operations. |
| [interviewer](interviewer.md) | opus | Conducts structured Socratic interviews to crystallize ambiguous requirements. Identifies ambiguity dimensions, scores them 0.0–1.0, asks one targeted question at a time, and produces a requirements document. Dispatched before the planner when specs are vague. |
| [planner](planner.md) | opus | Breaks specifications and requirements into structured implementation plans (Milestones > Stages > Tasks > Subtasks). Identifies dependencies, sequencing, and risks. Writes the plan document to `docs/plan/*-plan.md` (`Write` creates a new plan doc, `Edit` revises an existing one). Writes in clear, natural language. Does not estimate hours. |
| [preflight](preflight.md) | sonnet | Validates project environment readiness — runtime, dependencies, git, config files, disk space. Returns a structured pass/fail/warn checklist. Runs before any agent dispatch. |
| [project-scoper](project-scoper.md) | opus | Analyzes requirements, identifies gaps and ambiguities, scopes projects with effort estimates, deliverables, dependencies, and produces formal scoping documents with timelines. Writes in clear, natural language. Also revises scoping documents based on review or critic findings. |
| [rollback](rollback.md) | sonnet | Rolls back agent-produced changes at the appropriate scope — single task, task chain, full run, or worktree. Stashes before reverting, checks for file overlap, and respects guardrails. |
| [scout](scout.md) | sonnet | Read-only investigator for open, fuzzy questions about this repository — how something works, where something happens, whether a claim holds across the codebase. Sweeps adaptively with read-only tools, follows leads across rounds, and synthesizes a narrative answer inline with `path:line` citations. Writes nothing. Dispatched by `/ops` or standalone. |
| [security-reviewer](security-reviewer.md) | opus | Dedicated security auditor that analyzes implemented code for vulnerabilities, producing severity-rated findings with remediation guidance. Verdicts: SECURE / SECURE WITH FINDINGS / INSECURE. Auto-fired when the task carries a security content signal or `change-analyzer` returns `security-review: run` on the post-executor diff. |
| [ssh-executor](ssh-executor.md) | sonnet | Executes commands on remote servers via SSH. Handles remote command execution, file transfer (scp), remote verification, and service management. Uses SSH config for host resolution and key-based auth only. |
| [verifier](verifier.md) | sonnet | Validates that implementation meets acceptance criteria, assesses test coverage, writes missing tests, and runs integration checks before code review. |
| [web-research](web-research.md) | opus | Performs external/web research, multi-source fact-checking, and synthesis into cited reports. Read-only on code; writes only to `docs/web-research/` report artifacts. Dispatched standalone or by `/ops` when a task requires evidence from the open web. |
| [work-verifier](work-verifier.md) | sonnet | Verifies whether interrupted or prior agent work was actually completed by checking file existence, git diff, handoff files, and content quality. Returns per-deliverable verdicts for resume decisions. |

### Model assignments

Agents that require deep reasoning, nuanced judgment, or complex analysis use **opus**: architect, code-intel, corpus-search, critic, cross-memory, debugger, debugger-build, docs-lookup, interviewer, planner, project-scoper, security-reviewer, web-research. Agents that follow structured instructions, execute plans, or perform well-scoped checks use **sonnet**: change-analyzer, code-reviewer, code-reviewer-diff, db, documentor, executor, generalist, git-master, infra, preflight, rollback, scout, ssh-executor, verifier, work-verifier. No agent defaults to **fable**; it is reachable only as a guarded last-resort escalation rung (`opus → fable`) behind an explicit confirmation gate — see the ops model-escalation behavior.

`infra` and `db` additionally carry a per-agent proactive-opus escalation policy — triggered by mutating, destructive, multi-resource, or production-targeting operations, before the fleet's standard 3rd-failed-attempt ladder — that is distinct from every other sonnet agent listed above. See each agent's own Model Escalation Policy section (`agents/infra.md`, `agents/db.md`) for the exact trigger.

### Overriding the default model

The model in each agent's frontmatter is the default. It can be overridden in two ways:

1. **At spawn time** — pass a `model` parameter when invoking the Agent tool. This takes precedence over the frontmatter. The `/ops` can do this per-task if needed.
2. **Per project** — create a project-level `.claude/agents/<agent-name>.md` with a different `model` field. Project-level agents override global agents of the same name.

For example, to run the executor on opus for a particularly complex implementation, the ops would spawn it with `model: "opus"`. Or to use haiku for documentation tasks in a cost-sensitive project, drop a `documentor.md` in that project's `.claude/agents/` with `model: haiku`.

### Programmatic dispatch (ops skill)

All agent definition files at `~/.claude/agents/` are auto-registered as `subagent_type` values for the `Agent` tool. The ops skill dispatches directly: `Agent(subagent_type="<agent_type>", description="<task subject>", model="<from frontmatter>", prompt=<self-read template + brief>)`. The self-read prompt template instructs the agent to read its own definition file as its first action, providing full workflow context.

Cursor's `Task` tool also includes all agent types as `subagent_type` values natively.

## Shared snippets (`agents/_shared/`)

Module contract, version, and consumer list: [`_shared/README.md`](_shared/README.md).

Pipeline agents share brief-format boilerplate in [`_shared/brief-format-snippet.md`](_shared/brief-format-snippet.md) instead of duplicating it in every contract. Each agent's `## Brief Format` subsection keeps agent-specific overrides only and points at the snippet with a **`See`** line (for example, `See ~/.claude/agents/_shared/brief-format-snippet.md`). Agents that compose or validate briefs still use **`You MUST Read`** on `~/.claude/skills/ops/brief-contract.md` for the canonical contract.

## Usage

Agents are invoked automatically by Claude Code when a task matches their description. You can also request them explicitly by name or by describing the task.

### Architect

- _"Use the architect to explore design options for the new caching layer"_
- _"Have the architect evaluate trade-offs between a queue-based vs event-driven approach"_
- _"Design the component boundaries for the notification system"_
- _"Produce an ADD for the authentication migration"_

### Change Analyzer

- _"Classify my staged changes — do I need a full review?"_
- _"Analyze the diff and tell me which pipeline stages to skip"_
- _"Is this change trivial enough to skip verification?"_

### Code Intel

- _"Index the project so the executor can check impact before editing `process_payment`"_
- _"Who calls `validate_token`? Give me the full caller chain."_
- _"Run an impact analysis on `UserRepository.save` before we refactor it"_
- _"Trace the execution flow from `handle_request` down three levels"_
- _"Find all concrete implementations of the `StorageBackend` interface"_

### Code Reviewer

- _"Have the code reviewer check this module for security issues"_
- _"Review the data pipeline for performance bottlenecks"_
- _"Do a release readiness review on the staged changes"_
- _"Review `src/parser.py` for correctness"_

### Corpus Search

- _"Search the repo for evidence that Phase 2.5c is advisory — grep for 'advisory' in skills/ops"_
- _"Locate where the verification-gate ritual is documented"_
- _"Verify that README.md contains the phrase 'reusable AI agents'"_

### Critic

- _"Have the critic review this plan before we start"_
- _"Review the scoping document for feasibility issues"_
- _"Is this plan ready for implementation? Have the critic check"_

### Cross-Memory

- _"Dispatch cross-memory with intent: synthesize, query: 'Python testing preferences and security rules' before writing pytest fixtures for the auth module."_
- _"/cross-memory audit → dispatches the cross-memory agent for a chat-only structured report on staleness, duplicates, contradictions, and redaction misses."_
- _"When /ops needs background context for a planning agent, it dispatches cross-memory with intent: synthesize and current_project_slug from the run state."_

### Db

- _"Back up the staging database, then apply the pending migration"_
- _"Write a forward and rollback migration to add an `email_verified` column to `users`"_
- _"Run a read-only query counting orders with status `pending` older than 30 days"_
- _"Restore the `orders` table from yesterday's backup after confirming the write gate"_

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

### Docs Lookup

- _"What's the current constructor signature for `httpx.Client` on the version this project is pinned to?"_
- _"Look up how to configure retry/backoff with `tenacity` and give me a code-ready snippet with a citation."_
- _"Fetch the current `aws_s3_bucket` resource syntax for the Terraform provider version this repo uses."_

Best-effort, not a pre-indexed documentation service — every lookup pays a live search-and-fetch, and coverage depends on whether a web search surfaces the authoritative page for the resolved version.

On Claude Code, a caller may prefer the harness-native `claude-code-guide` agent over `docs-lookup` for questions about the Claude Code SDK or API itself — it's purpose-built for that documentation specifically.

### Documentor

- _"Document the new feature and update project scoping"_
- _"Write a developer guide for the processing pipeline"_
- _"Update the project scoping doc — Milestone 3 is complete"_
- _"Create API documentation for the new endpoints"_
- _"Document the architectural decisions from this milestone"_

### Executor

- _"Start implementing the validated plan"_
- _"Execute task 3.2 from the plan"_
- _"Implement the next task in the plan"_
- _"Continue implementing — pick up where we left off"_

### Generalist

- _"Fix this typo in the log message — one file, one line"_
- _"Update the one config value in `settings.yaml` that's out of date"_
- _"This comment is stale and contradicts the code below it — fix the wording"_

### Git Master

- _"Pause my current work, I need to switch to a hotfix"_
- _"Resume where I left off"_
- _"Create a PR for this branch"_
- _"Split these changes into atomic commits"_
- _"Create a feature branch for the new verification framework"_
- _"Resolve the merge conflicts on this branch"_
- _"Tag this as v0.3.0 and generate a changelog"_

### Infra

- _"Validate and plan the Terraform changes to the staging VPC module — show me the plan, don't apply anything"_
- _"Diff the Helm chart against the live release in the `payments` namespace"_
- _"Converge the Kubernetes manifests in `k8s/staging/` — validate, diff, then apply once I approve"_
- _"Run `aws ec2 describe-instances` for the `prod` account and summarize idle instances"_

### Interviewer

- _"Use the interviewer to clarify this ambiguous spec before we plan"_
- _"My requirements are vague — have the interviewer ask me questions to crystallize them"_
- _"Resolve the open questions in this feature request before planning"_

### Planner

- _"Use the planner to break down this feature"_
- _"Plan the implementation for adding WebSocket support to the worker"_
- _"Break down Milestone 4 into stages and tasks"_
- _"I have these requirements — plan how to implement them"_

### Preflight

- _"Run a preflight check before I start working"_
- _"Check if the environment is ready for agent work"_
- _"Validate that dependencies are installed and the runtime works"_

### Project Scoper

- _"Have the project scoper estimate this work"_
- _"Scope out the effort for adding a new detection model"_
- _"Analyze these requirements for gaps before we estimate"_
- _"Produce a scoping document for the planner's output"_

### Rollback

- _"Undo the last executor's changes — they didn't pass verification"_
- _"Roll back everything from this run — the approach is wrong"_
- _"Revert the changes to src/auth/ from the failed task"_

### Scout

- _"How does the retry logic actually work across the executor and debugger — trace it end to end"_
- _"Where in the repo does anything reference the old phase-dispatch split — is it still current?"_
- _"Is it true that every agent shares the same Bash constraints? Check across the fleet and report back"_
- _"Do a quick recon sweep of how sessions get resumed after a pause — I don't have a precise question yet"_

### Security Reviewer

- _"Have the security reviewer audit the auth middleware changes"_
- _"Run a security review on the API endpoint implementations"_
- _"Check the payment processing code for vulnerabilities"_
- _"Security audit the user input handling in the new form"_

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

### Web Research

- _"Research current best practices for X from the web and synthesize a cited report"_
- _"Fact-check this claim against external/online sources and tell me the confidence per source"_
- _"Gather evidence from the open web on Y — read-only, cite every source with access date"_

### Work Verifier

- _"Check if the previous agent's work was actually completed"_
- _"Verify the interrupted task — did the executor finish before the session died?"_
- _"Assess the state of in-progress tasks before resuming"_

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

**Change Analyzer:**

- Diff classification by type: code, config, docs, tests
- Per-stage skip/run recommendations for verify, deslop, review, security-review
- NEVER-skip rules take precedence over skip conditions

**Code Intel:**

- Indexes the project's source tree into a SQLite symbol graph at `.code-intel/index.sqlite`
- Six query types via recursive CTEs: `find_definition`, `find_callers`, `find_dependencies`, `impact_analysis`, `find_implementations`, `execution_flow`
- **Primary consumers:** executor (pre-edit impact analysis), code-reviewer (diff-scope verification), debugger (call-chain tracing), ad-hoc humans (exploratory queries)
- **Brief format:** JSON-fenced block for orchestrators (required fields: `query_type`, `symbol`); labeled-prose (`Query:`, `Symbol:`, `Scope:`, `Depth:`) for humans; malformed input refused immediately with the usage card
- **Output format:** JSON response for orchestrator dispatches (summary + path); full inline rendered report for standalone human queries
- Read-only on source code — writes only to `.code-intel/**`, `docs/code-intel/**`, and `_tmp_*`
- **Adaptive (v2):** open extension discovery (unknown types still get file nodes, never silently dropped), `git ls-files`/`.gitignore`-aware ignores + vendored/generated heuristics, incremental re-index on HEAD change, capability-detected tree-sitter (deferred), and a corpus-search query-time companion; 7,500-file cap

**Code Reviewer:**

- Two-stage review (spec compliance then quality) with severity-rated findings
- Supplements the `/code-review` slash command. For standalone diff reviews, see the **code-reviewer-diff** variant.
- Targeted reviews for specific concerns (e.g., thread safety, performance, security)
- Can be invoked outside the pipeline for ad-hoc reviews on any code

**Corpus Search:**

- Multi-hop textual evidence search via terminal-native tools (`rg`, `Glob`, `Read`) — no vector retrieval or embeddings
- Four query types: `evidence_search`, `locate`, `verify_claim`, `trace_reference`
- **Primary consumers:** executor (investigative preflight), debugger (string/pattern bugs, "where mentioned" investigations), documentor (cite evidence when writing docs)
- **Brief format:** JSON-fenced block for orchestrators (required fields: `query_type`, `query`); labeled-prose (`Query:`, `Query-Type:`, `Scope:`, `Output:`, `Max-Hops:`, `Max-Results:`) for humans; malformed input refused immediately with the usage card
- **Output format:** JSON response for orchestrator dispatches (summary + path); full inline rendered report for standalone human queries
- Read-only on source code — writes only to `.corpus-search/**`, `docs/corpus-search/**`, and `_tmp_*`

**Db:**

- Performs schema migrations, queries, and backup/restore, always backing up before a mutating operation
- Every migration ships as a forward/rollback pair, transaction-wrapped where the engine supports it
- Write gate whose primary control is the agent's own STOP-before-mutate discipline, portable across harnesses; on Claude Code, the permission layer additionally reinforces it since mutating `psql`/`mysql`/`mongosh` commands and migrations are not auto-allowed and always prompt
- Never allow-lists a mutating command pattern
- Composes with `ssh-executor` for databases reachable only through a bastion or tunnel — db decides the command and clears its write gate, ssh-executor runs it on the host with network access
- Escalates to opus proactively (before the standard 3rd-attempt ladder) for destructive, schema-changing, or production-database operations

**Debugger:**

- Hypothesis-driven investigation of bugs, errors, and unexpected behavior
- Root cause analysis with structured diagnosis (symptom collection → reproduction → hypothesis elimination → fix)
- For build/compilation errors (import, type, dependency, config errors), see the **debugger-build** variant
- 3-failure circuit breaker — escalates after 3 failed hypotheses instead of looping
- Similar pattern scan — greps for the same bug pattern elsewhere in the codebase after fixing
- Minimal, targeted fixes with regression verification and regression test creation
- Explicit scope boundaries — does not refactor, redesign, or optimize; hands off to the appropriate agent

**Docs Lookup:**

- Fetch-only agent (opus) that retrieves current third-party library documentation from the open web on demand, and secondarily harness (Claude Code/Cursor) documentation
- Resolves a version from the brief, then a lockfile, then a manifest, before searching and fetching
- Returns one code-ready snippet, a version-provenance stamp (resolved vs. fetched version, match status), and one authoritative citation per dispatch
- Best-effort approximation of a documentation index, not a replacement for one — every lookup pays a live-fetch latency; no maintained crawl or ranking model behind it
- Dispatched as the `/ops` Phase 2.5d advisory preflight, or standalone by name for a targeted "what's the current API for X" question
- No file write, ever — holds no `Write`/`Edit`/`Bash` tools; every deliverable is inline in the response

**Documentor:**

- Write documentation for existing features that were never documented
- Create guides, API references, or setup docs on demand
- Update the project scoping document outside the pipeline (e.g., marking a milestone complete)
- Document architectural decisions after a discussion
- Delegates to `/doc-sync` for accuracy checks, or runs built-in audit fallback when the skill is unavailable

**Generalist:**

- Disciplined in-domain catch-all for cross-lane residual work no specialist owns — gates every dispatch against a defer-to-specialist table before touching a file
- Minor/small-edit boundary: performs an edit only if it touches one file, adds no new abstraction, doesn't change control flow or a public interface, needs no test change, and fits a 1–5 minute effort ceiling
- No web tools — any web-dependent task routes to `web-research`
- Replaces reflexive use of the harness `general-purpose`/`claude` agents for genuinely in-domain work
- A correct deferral is a successful outcome, not a failure to act

**Git Master:**

- Branch creation, naming, cleanup
- Commit orchestration (supplements `/commit-message`, or generates messages standalone via built-in fallback)
- PR lifecycle, merge, conflict resolution
- Release tagging and changelogs
- **Pause/resume** — checkpoint WIP via stash or WIP commit, restore later

**Infra:**

- Provider-agnostic agent for Infrastructure-as-Code (Terraform, Pulumi, CloudFormation, CDK, Ansible), cloud CLIs (`aws`, `gcloud`, `az`), and Kubernetes (`kubectl`, `helm`) — one agent, not split per cloud
- Operating spine: validate → plan/diff → human-gated apply → verify convergence (no-drift)
- Destructive-operation gate whose primary control is the agent's own STOP-before-mutate discipline, portable across harnesses; on Claude Code, the permission layer additionally reinforces it since mutating commands are not auto-allowed and always prompt
- Never allow-lists a mutating command pattern, even for a fully autonomous run
- Composes with `ssh-executor` — infra owns the cloud/cluster-API domain, ssh-executor owns host-level transport
- Escalates to opus proactively (before the standard 3rd-attempt ladder) for mutating, multi-resource, or production-targeting operations

**Preflight:**

- Environment readiness validation (runtime, dependencies, git, config, disk space)
- Three-tier check system: critical (blocks), standard (auto-fix then block), warning (log only)
- Standalone invocable — does not require an ops run

**Rollback:**

- Scope-level rollback: single task, task chain, full run, worktree
- Always stashes before reverting — nothing is permanently lost
- File overlap detection with successful tasks before auto-reverting

**Scout:**

- Read-only reconnaissance for open, fuzzy, repo-internal questions — how something works, where something happens, whether a claim holds across the repo
- Defer-to-specialist gate checked before any sweeping starts: fixed/reproducible query → `corpus-search`; structural symbol-graph query → `code-intel`; web-dependent question → `web-research`; reproducible bug → `debugger`; any edit → `generalist`/`executor`
- Sweeps adaptively across as many rounds as the question needs, then synthesizes a narrative answer inline — `path:line` citations, confirmed (direct `Read`) vs. inferred always labeled
- Soft, self-governed budget — no hard numeric round cap; reports unexplored branches at a natural stopping point rather than fabricating certainty
- Writes nothing — no `Write` tool, no write-side `Bash`; a clean deferral is a successful outcome, not a failure

**SSH Executor:**

- Remote command execution via SSH (`ssh -o BatchMode=yes`)
- File transfer via SCP (single files) or tar-over-ssh (directories, rsync unavailable on Windows)
- Remote health checks, endpoint verification, log inspection
- Service management (systemctl, docker) via SSH
- ProxyJump/bastion host support via standard SSH config

**Web Research:**

- External/web research, multi-source fact-checking, and synthesis into cited reports
- Read-only on code; writes only `docs/web-research/<slug>.md` report artifacts (untracked by default)
- Structural anti-exfiltration trust boundary: only fetches URLs surfaced by a prior `WebSearch` or supplied in the brief; never writes secrets into a report

**Work Verifier:**

- 4-check verification protocol: file existence, git diff, handoff file, content validation
- Per-deliverable verdicts: completed, partial, not-started, broken
- Re-dispatch context generation for partially completed work

### Utility Agent Handoffs

Utility agents can hand off to pipeline agents or other utility agents depending on their outcome. Unlike the linear pipeline, these handoffs are conditional — they depend on what the agent found.

**Change Analyzer:**

No outbound handoffs. Change-analyzer returns per-stage recommendations — the caller decides whether to run or skip each stage.

**Code Intel:**

No outbound handoffs. Code-intel returns citable query results (callers, impact, execution flow) to the caller — the executor, debugger, code-reviewer, or `/ops` orchestrator decides what to do with the data.

**Code Reviewer** (when invoked outside the pipeline):

| Outcome | Hands off to |
| :--- | :--- |
| APPROVE / COMMENT | **git-master** (split and commit if needed), then **documentor** |
| REQUEST CHANGES | **executor** (address findings), then **verifier** (re-verify), then back to code reviewer |

**Corpus Search:**

No outbound handoffs. Corpus-search returns citable evidence (path:line snippets, verdicts, reference chains) to the caller — the executor, debugger, documentor, or `/ops` orchestrator decides what to do with the data.

**Db:**

| Outcome | Hands off to |
| :--- | :--- |
| Migration or operation complete, needs schema/data validation | **verifier** |
| Migration files changed | **code-reviewer** (review), **git-master** (commit) |
| Database only reachable through a bastion or tunnel | **ssh-executor** — domain vs. transport: db formulates the command and clears its write gate locally, ssh-executor runs it on the host with network access |
| Backup failed or the write gate was denied | Hard stop — report what was declined, don't retry the same command |
| Schema-design ambiguity surfaces | **architect** or **planner** (data-model decision) |

**Debugger:**

| Outcome | Hands off to |
| :--- | :--- |
| Fix applied and verified | **git-master** (commit fix + test separately), then **verifier** (re-run verification if bug surfaced during verification) |
| Root cause requires design change | **planner** (scope the change) or **executor** (if small and well-defined) |
| Cannot reproduce | Back to **user** for additional context or reproduction steps |
| Root cause in a dependency | No handoff — documents upstream issue and workaround |

**Docs Lookup:**

No outbound handoffs. Docs-lookup returns a citable result (code-ready snippet, version-provenance block, one citation) to the caller — the executor, documentor, or `/ops` orchestrator decides what to do with it.

**Documentor** (when invoked outside the pipeline):

| Outcome | Hands off to |
| :--- | :--- |
| Documentation complete | `/doc-sync` (final consistency check), or built-in audit fallback |
| Reveals implementation gap | **executor** (fix the gap) |

**Generalist:**

| Outcome | Hands off to |
| :--- | :--- |
| Minor edit complete | No downstream stage required, unless the edit touched behavior worth a second look — then **verifier** |
| Edit is part of a larger uncommitted change set | **git-master** (commit handling) |
| Task matches a specialist's lane (gate match) | The matching specialist per the defer-to-specialist gate |
| Scope grew mid-edit past the minor/small-edit boundary | **executor**, with the specific boundary predicate that now applies |
| Genuinely out-of-domain work | Back to the caller — harness `general-purpose` is appropriate only here |

**Git Master:**

No outbound handoffs. Git-master is a pure utility — it is invoked by other agents (or the user) and returns control to the caller when done.

**Infra:**

| Outcome | Hands off to |
| :--- | :--- |
| Operation complete, needs acceptance-criteria validation | **verifier** (confirm convergence, no-drift state) |
| Task needs host-level verification within a provisioned stack | **ssh-executor** — domain vs. transport: infra owns the cloud/cluster API, ssh-executor owns the SSH connection |
| IaC source or manifests changed | **git-master** (commit), **code-reviewer** (non-trivial changes) |
| Plan/diff shows an unexpected destroy or replace | STOP — surface the verbatim plan and ask before proceeding |
| Human declines the gate | Report what was declined; wait for a revised plan, don't retry the same apply |

**Preflight:**

No outbound handoffs. Preflight returns a structured checklist — the caller (ops or user) decides whether to proceed, fix, or stop.

**Rollback:**

| Outcome | Hands off to |
| :--- | :--- |
| Rollback complete, clean state | Caller re-dispatches the failed task |
| File overlap detected | Back to **user** for manual decision |

**Scout:**

| Outcome | Hands off to |
| :--- | :--- |
| Sweep complete, findings returned | **Caller** (inline synthesis with citations; no downstream stage required) |
| Sweep crystallizes into a precise, verifiable claim | **corpus-search** (recommended, not performed) |
| Sweep surfaces a structural symbol-graph question | **code-intel** (recommended, not performed) |
| Sweep surfaces a reproducible bug | **debugger** (recommended, not performed) |
| Sweep surfaces something that needs to change | **generalist** (minor) / **executor** (larger) (recommended, not performed) |
| Gate match before any sweeping began | The matching specialist, or back to the caller — a clean deferral is a success |

**SSH Executor:**

| Outcome | Hands off to |
| :--- | :--- |
| Deployment complete, needs verification | **verifier** (validate remote state) |
| Remote config changed, needs review | **code-reviewer** (review config changes) |
| Deployment complete, needs recording | **git-master** (tag deployment, update changelog) |
| Connection or permission failure | Back to **user** with diagnostic details |

**Web Research:**

| Outcome | Hands off to |
| :--- | :--- |
| Report complete | **user**, **planner**, or **documentor** consume the cited findings |
| No reliable sources found | Back to **user** with an explicit "cannot answer reliably" notice — does not fabricate |

**Work Verifier:**

No outbound handoffs. Work-verifier returns per-deliverable verdicts — the caller uses them to decide: mark complete, re-dispatch with context, or rollback.

### Parallelization

Agents cannot spawn subagents themselves (Claude Code limitation). The main session orchestrates parallelization by spawning multiple instances of the same agent when workload thresholds are met. Each agent defines its own scaling guidance:

| Agent | Threshold | Split dimension |
| :--- | :--- | :--- |
| Architect | 3+ subsystems | Parallel scout agents for domain research. |
| Code Reviewer | 5+ files | File groups of 3–5, single-pass spec compliance. |
| Critic | 3+ milestones | Review per milestone, single-pass verdict. |
| Db | 2+ independent database targets | By database/schema; never the same target. |
| Debugger | 2+ independent bugs | One bug per instance (shared root cause → same instance). |
| Debugger (Build) | 5+ errors | Error groups by type (import, type, config). |
| Documentor | 3+ independent docs | One doc per instance, single-pass map update. |
| Executor | 5+ independent tasks | Task groups by module (no shared files). |
| Generalist | 3+ independent single-file minor edits | One instance per edit (no shared files). |
| Git Master | 3+ branches need same op | One operation per branch (never same branch). |
| Infra | 2+ independent stacks/clusters/accounts | By provider + environment; never the same stack/state file. |
| Planner | 3+ subsystems | Parallel scout agents for codebase research. |
| Project Scoper | 3+ milestones | Gap analysis and estimation per milestone. |
| Scout | 3+ independent investigation areas | Split by area (same pattern as architect/debugger); never split an interdependent trail. |
| Security Reviewer | 3+ modules | Parallel instances per module (same pattern as code-reviewer). |
| SSH Executor | 2+ SSH tasks to different hosts | By target host (never same host). |
| Verifier | 10+ criteria or 3+ modules | Verification per module or criteria group. |

See each agent's **Scaling** section for full details on merge strategies and constraints.

## Permissions Reference

Below is the complete set of permissions needed for agents, skills, and the `/ops` to run without prompts. Add these to `~/.claude/settings.json` (global) or `.claude/settings.json` (per project).

If you experience an unexpected permission prompt, find the relevant entry below and add it to your settings.

### Core tools

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Edit` | architect, db, debugger, debugger-build, documentor, executor, generalist, git-master, infra, planner, project-scoper, verifier | Edit existing files — every grant is scoped to the holder's own file-class allowlist (e.g., planner to `docs/plan/*-plan.md`, verifier to test files only); see each agent's own `File-class allowlist` section for exact globs |
| `Write` | architect, code-intel, corpus-search, cross-memory, db, debugger, debugger-build, documentor, executor, generalist, git-master, infra, interviewer, planner, project-scoper, verifier, web-research | Create new files — scoped to the holder's own file-class or write allowlist for 16 of 17 (e.g., planner to `docs/plan/*-plan.md`, web-research to `docs/web-research/**`; see each agent's own allowlist section for exact globs); interviewer has no allowlist and writes its `*-requirements.md` deliverable to the brief-specified path, or the project root if none is given |
| `Read` | all agents | Read files |
| `Glob` | all agents | Find files by pattern |
| `Grep` | all agents | Search file contents |
| `Agent` | ops | Spawn sub-agents |
| `WebSearch` | docs-lookup, planner, project-scoper, web-research | Search the web for context |
| `WebFetch` | docs-lookup, planner, project-scoper, web-research | Fetch web page content |
| `TodoWrite` | any agent | Legacy todo list |
| `Skill` | ops | Invoke skills (`/ralph-loop`, `/doc-sync`, `/code-review`, etc.) |

### State file tools (ops)

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Write`, `Edit` | ops | Create `.ops-state/<run-id>-board.json` state file (`Write`) and mutate it (`Edit`) |
| `Read` | ops | Read state file for resume, status, and dispatch |

### Worktree tools

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `EnterWorktree` | ops (`--worktree`) | Create isolated git worktree for parallel agents |
| `ExitWorktree` | ops (`--worktree`) | Clean up worktree after agent finishes |

### Scheduling tools

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `CronCreate` | `/schedule` skill, timed tasks | Create recurring or one-shot scheduled jobs |
| `CronDelete` | `/schedule` skill | Remove scheduled jobs |
| `CronList` | `/schedule` skill | List active scheduled jobs |

### Bash — Git

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(git *)` | git-master, all agents | Git operations |
| `Bash(gh *)` | git-master | GitHub CLI (PRs, issues, checks) |

### Bash — Python

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

### Bash — Node.js / TypeScript

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(node *)` | executor, verifier | Run Node.js scripts |
| `Bash(npm *)` | executor | Node package manager |
| `Bash(eslint *)` | `/linter` skill | JavaScript/TypeScript linter |
| `Bash(prettier *)` | `/linter` skill | Code formatter |
| `Bash(tsc *)` | verifier | TypeScript compiler/checker |

### Bash — Docker

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(docker *)` | executor, debugger | Container operations |
| `Bash(docker-compose *)` | executor | Multi-container orchestration |

### Bash — SSH / Remote

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(ssh *)` | ssh-executor | Remote command execution via SSH |
| `Bash(scp *)` | ssh-executor | File transfer to/from remote hosts |

### Bash — Shells

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(bash *)` | any agent | Run bash scripts |
| `Bash(powershell *)` | any agent (Windows) | Run PowerShell scripts |
| `Bash(pwsh *)` | any agent (Windows) | Run PowerShell Core scripts |
| `Bash(cmd *)` | any agent (Windows) | Run cmd commands |
| `Bash(cmd.exe *)` | any agent (Windows) | Run cmd.exe commands |

### Bash — File operations

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

### Bash — Text processing

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

### Bash — Utilities

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

### Bash — Archives

| Permission | Used by | Purpose |
| :--- | :--- | :--- |
| `Bash(tar *)` | executor | Create/extract tar archives |
| `Bash(zip *)` | executor | Create zip archives |
| `Bash(unzip *)` | executor | Extract zip archives |

### Path-scoped permissions

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

### Prompt before allowing (risky)

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

### Destructive-operation gates (`infra` / `db`) — do not allow-list

| Permission pattern | Used by | Why it stays gated |
| :--- | :--- | :--- |
| Mutating IaC/cloud/k8s commands (`terraform apply`/`destroy`, `pulumi up`/`destroy`, `cdk deploy`/`destroy`, `ansible-playbook` against live inventory, `kubectl apply`/`delete`/`patch`, `helm install`/`upgrade`/`uninstall`, mutating `aws`/`gcloud`/`az` calls) | infra | The prompt this triggers IS the destructive-operation gate (`agents/infra.md` § Destructive-operation gate) — approving it silently or allow-listing it removes the human-approved-verbatim-plan control the agent depends on |
| Mutating database commands (`psql`/`mysql`/`mongosh` write queries, forward/rollback migrations, restores) | db | The prompt this triggers IS the write gate (`agents/db.md` § Write Gate) — allow-listing it removes the backup-before-mutate/human-approval control the agent depends on |

**Never add either pattern to the opt-in JSON block above, a project's `.claude/settings.json`, or a "trusted project" allow-list** — not even for `--autonomous` `/ops` runs. Autonomous mode pauses at the prompt instead of bypassing it, by design. Read/describe/plan equivalents from the same CLIs (`terraform plan`, `kubectl get`/`describe`, `SELECT`/`EXPLAIN` queries) are not auto-allowed either — they also prompt — but are safe to approve since they don't mutate state.

### Recommended deny list

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
