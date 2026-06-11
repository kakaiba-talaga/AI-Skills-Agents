# Ops

> This skill is invoked as `/ops`.

A coordination skill that manages a team of specialized agents working on a shared task list. Instead of manually invoking agents one at a time, the team manager plans the work, creates a task board, dispatches agents (hands each a self-contained task brief, in parallel where safe), tracks progress, and handles failures.

## What is this?

`/ops` is a coordination skill that runs a full AI agent pipeline for you. Give it a goal — a spec, a bug report, a plan — and it breaks the work into tasks, assigns each to the right specialist agent (executor, verifier, code-reviewer, etc.), and drives the pipeline to completion while tracking progress and handling failures. It is the right tool when work spans multiple stages or agents (e.g., implement → verify → review → document). For a single, self-contained command ("rename this variable", "run the linter"), invoke the agent directly instead of routing through `/ops`.

## Is `/ops` agentic AI?

The short answer is: the *file* is not, but the *running system* is — and it qualifies as one of the more advanced forms.

**The artifact vs. runtime distinction.** `SKILL.md` and its companion files are inert Markdown — prompt scaffolding with no weights, no inference, no autonomy. Sitting on disk, the skill is no more "AI" than a screenplay is a performance. "Agentic AI" is a property of the *running system*: the LLM loaded with the skill's instructions, the dispatched agents exercising their tools, and the on-disk state file tying it all together across sessions. The skill is the choreography; the model executing it is the dancer.

**How `/ops` maps onto the standard criteria for agency.** The term "agentic AI" is often used loosely, but it has a reasonably stable set of dimensions in the research and engineering literature. `/ops` satisfies all of them:

| Agentic criterion | How `/ops` delivers it |
| :--- | :--- |
| **Goal-directedness** | Takes a spec, decomposes it into a task board, and drives the pipeline to completion without being re-instructed at each step. |
| **Autonomy** | `--autonomous` mode runs the full pipeline end-to-end — plan → implement → verify → review → document — stopping only at genuine blockers, not routine stage transitions. |
| **Tool use / world-effecting action** | Dispatched agents edit files, run commands, write commits, and push branches. The team manager itself coordinates via state-file reads and writes. |
| **Planning & decomposition** | Builds a dependency graph of tasks, assigns each to a specialist agent, and sequences or parallelizes them based on the graph. |
| **Persistent memory and state** | Every run writes a mandatory state file at `.ops-state/<run-id>-board.json`. Cross-run patterns (which modules need a more capable model, where parallel dispatch causes conflicts) are recorded as project memory and recalled on future runs. |
| **Feedback loops and self-correction** | Verification failures trigger a fix cycle (executor → verifier, up to 3 loops). Agent failures trigger debugger diagnosis, then model escalation (sonnet → opus), before reaching user escalation. |
| **Multi-agent delegation** | The defining feature: `/ops` never implements, verifies, or reviews anything itself. All work is delegated to specialist agents via fully self-contained briefs. |

**What kind of agentic system it is.** In the taxonomy of agentic architectures, `/ops` is an **orchestrator-worker** (manager-worker) system — a *meta-agent* that coordinates specialist subagents rather than acting as a single tool-using agent. This is distinct from a standalone agent that happens to call tools, and from a decentralized swarm where agents coordinate peer-to-peer. The README's own description — "the person in front of a task board, moving tickets and briefing team members — never picking up a wrench" — is the orchestrator pattern stated in plain language.

**Bounded autonomy as a design choice.** `/ops` deliberately fuses deterministic rails with genuine runtime agency. The non-negotiables (state file on disk, self-contained briefs, lane boundaries that prevent review agents from editing files) are not restrictions on agency — they are what make the autonomy *trustworthy enough to run unattended*. The rails enforce correctness; the agency decides *which* agent to dispatch, *when* to parallelize, *how* to adapt when a task fails, and *whether* to escalate mid-run scope changes to the user or handle them automatically. That is the line separating "agentic" from mere "automation": runtime decisions made on observed state, rather than following a predetermined script.

**The verdict.** The specification file is not AI. In execution it instantiates a higher-order agentic system — a meta-agent orchestrator — with persistent state, feedback loops, multi-agent delegation, and self-correction. Those are the properties that place it firmly in the "agentic" category, well past the simpler "tool-using" baseline.

## Words this skill uses

| Term | Plain meaning |
| :--- | :--- |
| **team manager** | The `/ops` skill itself — it coordinates agents but never implements or reviews anything directly. |
| **agent** | A specialist that performs one type of work (e.g., executor writes code, verifier checks it). |
| **dispatch** | Hand a self-contained task brief to an agent and wait for the result. |
| **pipeline** | The ordered sequence of stages a task moves through: plan → implement → verify → review → document. |
| **stage** | One phase in the pipeline (e.g., "verification stage", "code-review stage"). |
| **task board** | The list of tasks, their statuses, dependencies, and agent assignments for a run — tracked in the on-disk state file (the authoritative record). |
| **handoff** | A structured summary passed from one agent to the next so each agent starts with full context. |
| **state file** | The JSON file on disk (`.ops-state/<run-id>-board.json`) that preserves task-board state across sessions. |
| **idempotent** | Safe to run more than once — repeating the operation produces the same result without side effects. |
| **heuristic** | A rule-of-thumb estimate, not a measurement — used when precise data is unavailable. |
| **provenance** | Origin — which run or agent created a file or entry. |
| **predicate** | A condition that must be true for something to trigger (e.g., a security-review predicate fires only on security-related diffs). |

## Quick Start

```
/ops Here are the specs for the new feature: [paste spec]
/ops execute                  # plan already in conversation
/ops status                   # check task board
/ops resume                   # pick up where you left off
/ops save                     # manual checkpoint: save state and context
/ops ralph "hit 80% coverage" # wrap in ralph loop for iterative goals
```

## How It Works

1. **Intake** — Receives a spec, requirement, or existing plan. If a ClickUp task ID is referenced, pulls task details via the `/clickup` skill (falls back to manual API if the skill is unavailable).
2. **Plan Validation** — Scores plan complexity and automatically chooses whether to dispatch project-scoper (gap analysis, estimates) and/or critic (feasibility review, verdict) before execution. Three tiers: skip (trivial), scope only (medium), scope + critique (complex/architectural).
3. **Task Board** — Breaks work into tasks with dependencies, assigns each to a specialist agent.
4. **Dispatch Loop** — Spawns agents (in parallel where safe), tracks results, handles failures.
5. **Verify → Fix Loop** — Verification failures trigger fix cycles that loop back until clean (max 3 loops).
6. **Completion** — Final integration verification, summary, and next steps.

At any point during or after a run, `/ops save` writes a manual checkpoint: the current task-board state and a snapshot of user-typed conversation context to disk. User-typed text fields are redacted unconditionally before write, so no sensitive content leaks into the saved file.

The team manager never implements, verifies, reviews, or documents itself. It only coordinates.

## Supported Agents

The team manager auto-detects which agent to assign based on task content:

| Agent | Assigned when task involves |
| :--- | :--- |
| architect | Design exploration, architecture decision documents, trade-off evaluation |
| change-analyzer | Classifying diffs and recommending pipeline stage skips |
| code-reviewer | Reviewing code quality, auditing |
| critic | Reviewing plans, quality gates |
| debugger | Investigating bugs, diagnosing errors, unexpected behavior, test failures |
| debugger-build | Build errors, import errors, type errors, dependency/compilation/config errors |
| documentor | Writing or updating documentation |
| executor | Implementing, creating, modifying code |
| git-master | Git operations, branching, PRs |
| interviewer | Clarifying ambiguous requirements via structured follow-up questions |
| planner | Breaking down work, designing |
| preflight | Environment readiness checks (runtime, dependencies, git, disk space) |
| project-scoper | Estimating effort, analyzing requirements |
| research | External/web research, online fact-checking, synthesizing cited reports from outside sources |
| rollback | Rolling back agent-produced changes after failures |
| security-reviewer | Security audits, vulnerability scanning, OWASP checks, auth review |
| ssh-executor | Deploying to remote servers, SSH commands, file transfer, remote verification |
| verifier | Validating acceptance criteria, testing |
| work-verifier | Verifying whether interrupted agent work was completed |

## Autonomy Modes

| Mode | Flag | Behavior |
| :--- | :--- | :--- |
| Interactive | _(default)_ | Checkpoints after each pipeline stage. User confirms before proceeding. |
| Autonomous | `--autonomous` | Runs end-to-end. Stops on escalation/blockers and brainstorm design-approval checkpoints. |
| Supervised | `--supervised` | Checkpoints after every single task. Maximum control. |

## Options

| Flag | Description |
| :--- | :--- |
| `--autonomous` | No checkpoints between stages |
| `--supervised` | Checkpoint after every task |
| `--parallel N` | Max concurrent agents (default: 3) |
| `--agents <list>` | Comma-separated agent types to use |
| `--dry-run` | Show task board without dispatching |
| `--worktree` | Spawn parallel agents in isolated git worktrees |
| `--no-branch` | Skip working branch creation, work on current branch |
| `--no-deslop` | Skip the deslop cleanup stage after verification |
| `--cost` | Enable cost estimate reporting in Phase 4 and the completion dashboard (off by default) |
| `--budget=<N>` | Optional run-level dispatch-count ceiling the orchestrator consults at cost-affecting choice points (off by default). Advisory and escalation-only: a tight budget can defer or escalate a spending choice but never silently drops work and never skips a verification or correctness check. |
| `--brainstorm` | Run interviewer + architect and require design approval before planner |
| `--tdd` | Executor follows RED-GREEN-REFACTOR discipline; verifier adds a TDD-discipline check |
| `--skip-baseline` | With `--worktree`, skip the baseline test-suite check (only the `.gitignore` enforcement runs) |
| `--dispatch-log` | Append each dispatch to `docs/ops-dispatch-log.md` (opt-in audit trail; off by default) |
| `--security-review=off\|always` | By default, the security review runs only when the change looks security-related; `off` disables it; `always` runs it on every stage. |
| `--code-intel[=off]` | Phase 2.5b: fire `code-intel` on every code-modifying task (`--code-intel`) or disable it (`=off`) |
| `--corpus-search[=off]` | Phase 2.5c: fire `corpus-search` on every eligible task or disable it (`=off`) |
| `--memory-inject=off\|auto\|always` | Control `## Project Knowledge` injection into agent briefs (default `auto`) |
| `--no-adaptation-memory` | Skip the Phase 4 capture that writes this run's adaptations to the durable cross-run ledger (capture is on by default, threshold-gated) |
| `ralph` | Wrap workflow in a `/ralph-loop` for iterative metric-driven goals |

## Key Features

### Cursor state file sync

On **Cursor**, `/ops` uses `.ops-state/<run-id>-board.json` as the source of truth and `TodoWrite` only as an IDE display layer. After board creation, the team manager must **Write → Read verify → TodoWrite** on every status change — updating `TodoWrite` alone breaks `resume`, timing, and handoffs. See `phase-dispatch.md` § **Cursor: state file sync (mandatory)**.

### Branch Isolation

By default, the team manager creates a working branch before any agents modify code. This protects the base branch and makes the team's work easy to review, revert, or PR. The branch follows the project's naming convention (detected from git log) — e.g., `feature/<task>`, `fix/<task>`, or `team/<task>`.

- On `main`/`master`: always creates a working branch.
- On a feature branch that matches the task: works on the current branch — no sub-branch created. Logs the decision as an adaptation.
- On an unrelated feature branch: warns the user and asks whether to work here, create a sub-branch, or switch to main first.
- Exploratory or continuation work: skips branch creation if the current branch already contains related commits for the same initiative.
- Uncommitted changes: stashed or WIP-committed before branching.
- After completion: reports the branch name and suggests PR or merge.
- Use `--no-branch` to skip and work directly on the current branch.

Branch isolation is compatible with `--worktree` (worktree branches fork from the working branch), ralph-loop (snapshot tags are branch-independent), and git-master pause/resume (WIP state stays on the working branch).

### Plan Document Persistence

For non-trivial tasks (>2 implementation tasks or multi-stage work), the team manager writes the plan to `docs/plan/<descriptive-name>-plan.md` before creating the task board. This plan document survives session loss and serves as the source of truth on `resume`. For trivial tasks, the plan stays in conversation only. Use the `plan` command to force a plan document even for small tasks.

### Handoff Documents

Structured context summaries passed between pipeline stages, **saved to disk** at `.agents/handoffs/<run_id>/`. Each agent starts fresh, so handoff documents preserve what was done, key decisions, files changed, and guidance for the next agent.

Handoff files are scoped per run — each run gets its own subdirectory (e.g., `caching-layer-2026-04-09/`). This prevents interference when multiple sessions use the team manager concurrently on the same project. On successful completion, the run's handoff directory is cleaned up. On pause/cancel, it's kept for `resume`.

### Verify → Fix Loop

Verification isn't one-shot — it loops. When the verifier finds issues, the executor gets dispatched to fix them, then the verifier re-checks. Max 3 loops before escalation. Same pattern for code review request-changes cycles.

### Git Worktree Isolation

With `--worktree`, parallel agents each get their own copy of the repo. Eliminates file conflicts entirely. After agents complete, the git-master merges branches.

### Internal Tasks

The manager creates bookkeeping tasks (merging branches, final verification, compiling summaries) marked as internal. These are filtered from the user-facing progress bar but visible in a collapsed dashboard section.

### Agent Constraints

Spawned agents are workers, not managers. They cannot spawn sub-agents, make scope decisions, or invoke orchestration commands. The team manager enforces these rules in every brief.

The team manager does not end its turn on a nested-skill return — nested-skill invocations (deslop, clickup, etc.) are mid-loop events, not terminal events. The team manager writes a `pending_nested_skill` marker to the state file before invoking, and clears it after return.

> **Note:** When `/ops` is wrapped with `/ralph-loop` (`/ops ralph`), nested-skill invocations inside the ralph-loop wrapper (e.g., ralph-loop's Cleanup stage → `/deslop`) are governed by ralph-loop's own prompt, which does not currently have an equivalent non-negotiable. A follow-up fix to `skills/ralph-loop/` is needed for full coverage. See Appendix A of the fix plan.

### Agent Dispatch

Both Claude Code and Cursor support direct `subagent_type` dispatch for all agent types:

- **Cursor** — `Task(subagent_type="executor", prompt=<brief>)`.
- **Claude Code** — `Agent(subagent_type="executor", description="<task subject>", model="<from frontmatter>", prompt=<self-read template + brief>)`. All agents with definition files at `~/.claude/agents/` are auto-registered as `subagent_type` values. The self-read prompt template instructs the agent to read its own definition for full workflow context.

See `docs/portability-guide.md` § Agent Dispatch Mechanism for the full procedure.

### Adaptability

The team manager adapts strategy at runtime instead of rigidly following the initial plan. All adaptations are logged and visible in the dashboard.

- **Mid-run plan adjustment** — when agents discover missing tasks, wrong sequencing, or tasks that need splitting, the team manager updates the board in-place. Small scope changes are handled automatically; large ones escalate to the user.
- **Model escalation** — if an agent fails twice on sonnet, the 3rd attempt runs on opus before escalating to the user. Extends the failure handling from 3 strikes to 4 (sonnet → sonnet+context → opus → user).
- **Strategy adaptation** — switches between sequential and parallel dispatch based on throughput and file conflicts. Escalates to worktree isolation if parallel agents keep conflicting.
- **Cross-run learning** — records patterns from completed runs (which modules need opus, where parallel dispatch causes conflicts, which agent types fit which task patterns) as project memory. Recalled patterns inform future runs as soft defaults. Patterns are stored at `~/.claude/projects/<project>/memory/feedback_team_patterns.md` — created automatically after the first run that produces learnings worth recording.
- **Reflection beat** — at each pipeline stage transition, the team manager records a short self-critique of whether the remaining plan still holds; it can propose additions or re-sequencing, but escalates any scope reduction to the user rather than acting.
- **Dynamic re-planning** — when a finished stage materially invalidates two or more remaining tasks (making them impossible, redundant, or falsely-assumed), the team manager dispatches the planner on the unfinished task graph, routes the revision through the critic REVISE loop, and rewrites the remaining board only on a critic-accepted result that drops no scope; scope-dropping revisions and non-convergence escalate to the user.
- **Health-monitoring that acts** — beyond displaying `⚠️ SLOW` / `🔴 OVERRUN` / `👻 ORPHAN?` flags, the orchestrator dispatches the read-only `work-verifier` on a sustained `OVERRUN` to diagnose the agent's work-state; only on a confirmed orphan (orphan-shaped work-state plus no live agent signal) does it re-dispatch once via the existing retry-then-escalate rule — a slow-but-alive agent is never re-dispatched.
- **Adaptation memory** — at Phase 4 completion (before the per-run board is deleted), the team manager appends a rollup record to a durable, per-project adaptation ledger at `~/.claude/projects/<project>/memory/`. The ledger captures per-type adaptation counts, file-conflict pairs, plan-validation tier, and whether a critic REVISE occurred. It holds a rolling 10-run window, is gitignored, and is never cleaned up at Phase 4 — it is the corpus future runs draw on. Capture is threshold-gated: runs that produce no actionable adaptation write nothing. Use `--no-adaptation-memory` to skip the capture for a run. Applied-prior events (`type: prior-applied`) are reserved for the ledger's gated read-half — once it ships, a prior that changes a run-start default logs there and renders in the dashboard's Adaptations section.

### Timing and Estimation

Every task is timed and estimated. The dashboard always shows estimated vs actual:

- **Per-task** — estimated time (from scoping doc or team-manager heuristic — a rule-of-thumb estimate, not a measurement) alongside actual duration.
- **Per-stage totals** — estimated vs actual grouped by pipeline stage.
- **Total wall time** — estimated total vs actual elapsed.
- **Variance** — percentage over/under estimate. Tasks exceeding 2x their estimate are flagged.
- **Longest task** — flagged at completion for future optimization.
- **Estimation accuracy** — overall ratio fed into cross-run learning to improve future estimates.

Estimates come from the project-scoper's hour estimates when a scoping doc exists. Otherwise, the team-manager produces rough estimates based on task complexity (trivial: 1-5 min, scoped: 5-15 min, complex: 15-45 min). Heuristic estimates are flagged in the dashboard.

Edge cases are handled:

- **Retries** — each attempt tracked separately; variance compares against the successful attempt, not total retry time.
- **Parallel execution** — reports both agent time (total work) and wall time (user wait). Estimates compare against agent time.
- **Internal tasks** — excluded from estimates and variance (they're unestimated bookkeeping).
- **Session loss** — stale timers are detected on resume; durations that include downtime are excluded from variance.
- **Model escalation** — attempt-level model tracking; timing and adaptation reported independently.
- **Idle time** — checkpoint pauses (user think time) tracked separately; completion shows active vs total wall time.

## Pipeline Integration

The team manager understands the full agent pipeline:

```
[interviewer] → [architect] → planner → project-scoper → critic → executor → verifier → [security-reviewer] → [deslop] → code-reviewer → documentor
```

_Brackets indicate optional/automatic stages. Architect runs when the spec involves significant design decisions. By default, the security reviewer runs only when the task carries a security content signal **or** the diff touches security-sensitive paths (auto-detected post-executor by `change-analyzer`); `--security-review=off` disables it entirely; `--security-review=always` runs it on every stage. A trivial-route run the gate classified at low confidence is auto-promoted to the full pipeline when its post-executor diff contradicts the trivial assumption, keeping its run-id and state file and continuing forward through verify, review, and document._

For deployment workflows, the `ssh-executor` can be inserted between executor and verifier:

```
executor → ssh-executor → verifier  (build locally, deploy remotely, verify)
ssh-executor → verifier              (standalone remote task, then verify)
```

- **Interviewer** — dispatched before the planner when specs are ambiguous. Conducts structured follow-up questions to pin down requirements. Skipped when specs are clear.
- **Deslop** — runs `/deslop --conservative` on files modified by executors, cleaning AI-generated structural bloat before code review. Runs by default — use `--no-deslop` to skip. Silently skipped if the skill is not installed.

With the verify-fix loop:

```
executor → verifier → [FAIL] → executor (fix) → verifier → [PASS] → deslop → code-reviewer → documentor
```

If deslop makes changes, a quick re-verify runs. If that fails, deslop changes are reverted and code review proceeds with the original code.

Independent implementation tasks run in parallel, then converge for verification.

## Examples

### Starting a project from a spec

```
/ops We need to add a REST API for user management. It should support
CRUD operations, JWT auth, rate limiting, and input validation. Use FastAPI
with SQLAlchemy. Write tests for all endpoints.
```

The manager dispatches the **planner** to break this down, builds a task board (e.g., 12 tasks across 4 stages), then walks through: executor → verifier → deslop → code-reviewer → documentor, checking in at each stage transition.

### Planning only (dry run)

```
/ops --dry-run Add a caching layer to the data pipeline
```

Creates the task board and shows it — tasks, agent assignments, dependencies, pipeline stages — without dispatching anything. Review the plan, adjust, then run `/ops execute` to start.

### Execute a plan already in conversation

```
User: [pastes or discusses a plan with Claude]
User: /ops execute
```

Skips the planner. Reads the plan from conversation context, builds the task board, and starts dispatching immediately.

### Fully autonomous, hands-off execution

```
/ops --autonomous Implement Milestone 4 from the project scoping doc
```

Runs the full pipeline end-to-end without pausing. The manager only stops if an agent fails 3 times or hits a blocker that needs human input. Shows a final summary when done.

### Supervised mode for high-risk changes

```
/ops --supervised Refactor the authentication module to use OAuth2
```

Checks in after **every single task**. Shows the agent's output, asks you to approve before moving on. Slowest mode, but you see and approve every change.

### Parallel execution with worktrees

```
/ops --autonomous --worktree --parallel 4 Implement the 6 new API endpoints
```

Spawns up to 4 executor agents simultaneously, each in an isolated git worktree. No file conflicts. After all agents finish, the git-master merges the branches.

### Iterative goal with ralph loop

```
/ops ralph "improve test coverage to 80%"
```

Wraps the team workflow in a ralph loop. Each iteration: plan what's missing → implement tests → verify coverage. The loop continues until 80% is hit or you intervene.

### Bug fix workflow

```
/ops Users are reporting 500 errors on the /upload endpoint when
files exceed 10MB. Fix it, add a test, and update the API docs.
```

The manager creates 3 tasks: debugger investigates → executor fixes → verifier confirms → documentor updates API docs. Chains them with dependencies.

### Documentation sprint

```
/ops --parallel 3 Write developer documentation for the auth module,
the data pipeline, and the deployment process
```

All 3 are independent documentation tasks. Dispatches 3 documentor agents in parallel. No pipeline chain needed — just parallel work and a summary.

### Multi-milestone execution

```
/ops --autonomous Execute Milestones 3 and 4 from the scoping doc.
Skip code review for Milestone 3 (it was already reviewed).
```

Builds a task board spanning two milestones. Milestone 3 skips the code-reviewer stage. Milestone 4 runs the full pipeline. Independent tasks across milestones run in parallel.

### Mid-run interactions

**Check status while work is in progress:**

```
/ops status
```

**Add a task you forgot:**

```
Also add input validation for the email field in the signup endpoint
```

**Skip a stage:**

```
Skip documentation for now, we'll do that later
```

**Promote a task:**

```
Do task #7 next, it's blocking the frontend team
```

**Stop everything:**

```
Stop, I need to rethink the approach
```

**Resume later (even in a new conversation):**

```
/ops resume
```

### Combining with other skills

**Plan first, then hand off to ops:**

```
User: Use the planner to break down adding WebSocket support
[planner produces structured plan]
User: /ops execute
```

**Ops then doc-sync:**

```
User: /ops --autonomous Implement the new detection module
[team-manager completes, documentor finishes]
User: /doc-sync
```

**Review before committing:**

```
User: /ops Implement the refactoring plan. Stop before documentation.
[team-manager runs executor → verifier → code-reviewer, pauses]
User: /code-review staged
[user reviews the combined diff]
User: /ops resume
[documentor runs]
```

## Interruption Handling

You can interact with the team manager at any point between agent dispatches:

| Command | What happens |
| :--- | :--- |
| "stop" / "cancel" | Stops dispatching, lets active agents finish, preserves state file for later resume |
| "skip [stage/task]" | Deletes the tasks, updates dependencies, resumes |
| "do #N next" | Promotes task priority, dispatches immediately if unblocked |
| "add [task]" | Creates a new task, wires dependencies, slots into the dispatch loop |
| "drop #N" | Removes task, clears downstream blockers |
| "reprioritize" | Pauses, shows board, waits for instructions |
| "pause" | Stops dispatching but keeps all task state |
| "resume" | Recovers from state file, verifies in-progress tasks, continues |

**Conversation recovery:** Three things survive session loss: the **state file** (`.ops-state/<run-id>-board.json`), the **plan document** on disk (`docs/plan/`), and the **handoff files** on disk (`.agents/handoffs/<run_id>/`). Together they provide complete state recovery. `/ops resume` reads all three to rebuild the dispatch state — no reliance on conversation history.

## Failure Handling

- **1st attempt fails**: Re-dispatches with error context appended, narrowed scope.
- **2nd attempt fails**: Dispatches the **debugger** to diagnose (or **debugger-build** for build/import/type errors), then re-briefs the original agent with a corrected approach.
- **3rd attempt fails**: Escalates model (sonnet → opus) with full error history. Skipped if already on opus, or if the failure is a blocker or scope issue.
- **4th attempt fails**: Escalates to the user with all attempts, errors, and diagnosis.
- **Blocker**: Creates a blocker task, pauses the affected chain, continues other chains.
- **Scope issue**: Re-plans in-place if small; escalates to user if large.

## Troubleshooting / Common mistakes

**`/ops execute` says it cannot find a plan.**
`execute` reads the plan from the current conversation context. If you are in a new session or have used `/clear`, there is no plan in context. Paste or re-describe the plan before running `/ops execute`, or use `/ops resume` if you saved state from an earlier run.

**A new branch appeared on `main` — I didn't ask for that.**
By design, `/ops` creates a working branch before any agents modify code when you are on `main` or `master`. This protects your base branch. If you want to work directly on the current branch, pass `--no-branch`.

**`/ops resume` says no state file was found.**
`resume` relies on a state file at `.ops-state/<run-id>-board.json`. State is only written when a run has progressed past the task-board creation step, or when `/ops save` was called explicitly. If the previous session ended before that point, there is nothing to resume — start a new run instead.

**Where is the state file?**
`.ops-state/` in your project root. Each run gets its own file named after the run ID (e.g., `.ops-state/caching-layer-2026-04-09-board.json`). The state file, the plan document under `docs/plan/`, and handoff files under `.agents/handoffs/` together hold everything needed for a full session recovery.

**An agent is looping and the task never completes.**
The team manager retries a failing task up to 4 times (sonnet × 2 → debugger diagnosis → opus → user escalation). If you see the same task cycling, type `stop` to halt dispatching, then inspect what the last agent returned. You can then `skip` the task, adjust the plan, and resume.

**`/ops` is running when I just wanted a quick command.**
`/ops` is intended for multi-stage, multi-agent workflows. For single commands ("run the tests", "format this file"), invoke the agent or skill directly without wrapping in `/ops`.

## Reusability

This skill is project-agnostic. It coordinates whatever agents are available globally (`~/.claude/agents/`) or in the current project's `.claude/agents/` directory. To share agents with a specific project, copy the relevant files from `~/.claude/agents/` into that project's `.claude/agents/`.

---

## For skill maintainers

> The sections below describe the internal file layout and companion-loading architecture of `/ops`. If you are using the skill rather than maintaining or extending it, you can stop reading here.

### Companion Files

The skill uses companion files for conditional sections, loaded on demand via Read instead of being inlined in SKILL.md. This keeps the core file lean — sections are only loaded when the relevant workflow branch is reached.

**Phase companions (B1 hub):** After the Triage Gate classifies the invocation, pipeline work loads phase-scoped modules instead of keeping the full workflow inline in `SKILL.md`:

| File | Content | Loaded when |
| :--- | :--- | :--- |
| `phase-intake.md` | Phase 1 intake, trivial dispatch (**LB1**), save subcommand, brainstorm gate, plan persistence, Phase 1a/1.5/2 task board | Triage routes to `pipeline`, `trivial`, or `save` |
| `phase-preflights.md` | Phase 2.5b/2.5c advisory preflights — code-intel and corpus-search — with the shared preflight blocks (budget-governor guard, yield-record, refusal-handling, dispatch-log entry) | Phase 2.5 entry |
| `phase-dispatch.md` | Phase 2.5 validation, Phase 3 dispatch loop (**LB2**, memory injection, agent dispatch); **Cursor:** § state file sync (Write → verify → TodoWrite) | Task board ready; through dispatch |
| `phase-completion.md` | Phase 4 completion ceremony, status dashboard, cleanup | All tasks done; `status` route |

The hub file (`SKILL.md`) retains Triage Gate, Non-negotiables, and the phase pointer index. See the **Companion index** table in `SKILL.md` for MUST vs See on branch-only companions.

**Pointer tiers:** Always-hot companions use **`You MUST Read`**; branch-only or opt-in companions use **`See`**. Canonical rules and templates live in [`pointer-format.md`](pointer-format.md) (MUST vs See, fallback sentences, downgrade criteria).

| File | Content | Loaded when |
| :--- | :--- | :--- |
| `help-card.md` | Quick-reference card for commands, flags, and mid-run actions | `help` command |
| `plan-validation.md` | Spec clarity evaluation, plan complexity scoring, critic verdict handling, scoper/critic output descriptions, execute-skip detection, adaptation rules | Phase 1a Plan Validation (Tier 2/3 runs) |
| `state-schema.md` | State file JSON structure, field definitions, directory conventions | Phase 2 state file creation |
| `dispatch-policy.md` | Foreground/background dispatch decision criteria, thresholds, batch rules | Phase 3 dispatch decisions (tasks 8+ min) |
| `tool-restrictions.md` | Delegate-first table, permitted direct actions, self-check rules, subagent dispatch decision framework | Team manager tool use decisions |
| `dispatch-log.md` | Dispatch decision log spec — opt-in via `--dispatch-log` flag; file location, retention, entry format, kinds, append procedure, audit usage | Appending entries to `docs/ops-dispatch-log.md` when `--dispatch-log` is set |
| `handoffs.md` | Full handoff template, run identity rules, naming examples, accumulation rules, cleanup lifecycle | Writing or reading handoff documents |
| `integrations.md` | Deslop and Ralph Loop integration procedures | Verify→review stage transition; `ralph` flag |
| `timing-edge-cases.md` | 7 timing edge case rules (retry time, parallel execution, internal tasks, resume timing, model escalation, calibration, idle time) | Phase 4 completion and Status Dashboard display |
| `cost-tracking.md` | Token estimation heuristics, model pricing, cost dashboard format, per-task and per-model rollup templates | Phase 4 completion (cost estimate and dashboard) |
| `tdd-discipline.md` | RED-GREEN-REFACTOR discipline rules loaded by executor and verifier | `--tdd` flag set |
| `interruption-recovery.md` | Detailed procedures for cancel, reprioritize, inject tasks, remove tasks, session recovery, foreground/background dispatch explainer | User interrupts, `resume` command, dispatch context |
| `subcommand-save.md` | Full save flow, schema, ritual values, redaction integration, resume interaction | `save` subcommand |
| `completion-options.md` | Four-option completion menu (merge / PR / keep / discard), per-option workflow, destructive-option confirmation gate, worktree cleanup by provenance | Phase 4 completion (present decision menu and capture user choice) |
| `pointer-format.md` | Standard format for pointer lines, usage notes for extraction agents | Meta-reference for maintaining pointer consistency |

These companion files live at `~/.claude/skills/ops/` alongside `SKILL.md`. The skill entry point is `~/.claude/skills/ops/SKILL.md`.

Eight procedures previously in companion files have been extracted into standalone agents and a skill:

| Extracted to | Replaces | Used for |
| :--- | :--- | :--- |
| `~/.claude/agents/preflight.md` | `preflight-validation.md` | Phase 2.5 environment readiness checks |
| `~/.claude/agents/work-verifier.md` | `resume-dedup.md` | Resume dedup verification |
| `~/.claude/agents/rollback.md` | `rollback-strategy.md` | Failure rollback |
| `~/.claude/agents/change-analyzer.md` | `conditional-stage-skip.md` | Per-stage skip analysis |
| `~/.claude/skills/timing-calibrator/SKILL.md` | `estimation-feedback.md` | Timing calibration and cross-run learning |
| `~/.claude/agents/git-master.md` (enriched) | `branch-isolation.md` | Branch workflow decisions and worktree isolation |
| `~/.claude/agents/work-verifier.md` (enriched) | `agent-health-monitoring.md` | Orphan detection and timeout budgets |
| `~/.claude/agents/ssh-executor.md` (enriched) | `ssh-integration.md` | SSH preflight checks and handoff format |
