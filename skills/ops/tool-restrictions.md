<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Team Manager Tool Restrictions

## Delegate-First Table

| Work type | Dispatch to | Team manager may NOT do directly |
| :--- | :--- | :--- |
| Git operations (branch, commit, merge, rebase, PR, tag) | `git-master` | `git checkout -b`, `git commit`, `git merge`, `git rebase`, `git push` |
| File creation or modification | `executor` or `documentor` | `Edit`, `Write` on project files |
| Code review | `code-reviewer` or `security-reviewer` | Reading code to form review judgments |
| Testing or verification | `verifier` | Running test suites, checking acceptance criteria |
| Deployment | `/deploy` skill or `ssh-executor` | `ssh`, `scp`, deploy scripts |
| Documentation | `documentor` | Writing or updating README, docs, guides |

## What the Team Manager MAY Do Directly

- **Read files** to understand context for briefing agents (Read, Glob, Grep)
- **Read-only git commands** for state checks: `git status`, `git branch --show-current`, `git log`, `git diff --stat`, `git stash list`
- **Write to `.ops-state/`** — state files are team manager infrastructure, not project content
- **Write to `.agents/handoffs/`** — handoff documents are team manager infrastructure
- **Run `mkdir -p`** for `.ops-state/` and handoff directories
- **Run `rm`** for cleanup of `_tmp_*`, `.ops-state/`, and handoff files at completion
- **Invoke skills** via the Skill tool (`/deploy`, `/deslop`, `/code-review`, etc.)
- **Run general commands** only when the task falls outside all agent and skill definitions — log it as an adaptation: "Direct command: [reason no agent/skill covers this]"

## Self-Check

If you are about to run `git commit`, `git checkout -b`, `git rebase`, `git merge`, or any mutating git command — stop. Dispatch `git-master` instead. If you are about to use `Edit` or `Write` on a project file — stop. Dispatch the appropriate agent instead.

## Subagent Dispatch Decision Framework

The delegate-first table above governs **work types** (code, git, review, deploy). This framework governs **research and reading** — when the team manager should use direct tools (`Read`, `Grep`, `Glob`) vs dispatch a research subagent. Apply the first matching rule:

| Situation | Pick | Why |
| :--- | :--- | :--- |
| Known file + narrow question | `Read` with `offset` / `limit`, or scoped `Grep` | A subagent adds latency and tokens without returning new information |
| Unknown location, narrow scope, ≤ 2 lookups likely | `Grep` → `Read` directly | In-context exploration is cheaper than briefing a subagent |
| Unknown location, broad scope, 3+ rounds likely | `Agent(subagent_type: Explore)` | Protects main context; returns a summary instead of raw files |
| Tool output would pollute main context (large logs, test dumps, long file reads) | Subagent or background `Bash` | Keeps main context clean for orchestration |
| 2+ independent research threads | Dispatch subagents in **parallel** in a single message | Sequential serialization wastes time when threads don't depend on each other |
| Task matches a specialist agent's lane (executor, debugger, verifier, etc.) | That specialist via normal dispatch | Lane match overrides the research heuristic |
| Cannot write a tight, self-contained brief yet | Don't dispatch — clarify the question first | Vague briefs produce vague work |

**Bias correction:** The delegate-first principle pressures dispatch for work types — do not extend that pressure to reading tasks the team manager is explicitly permitted to do directly (see "What the Team Manager MAY Do Directly" above). Pick by the table, not by default ceremony. Conversely, do not avoid dispatching out of habit when research genuinely spans many rounds or would pollute the main context.

**Deliberation check before spawning a research subagent:** Do I know where to look? (If yes → direct.) Can I state the question in one tight brief? (If no → clarify first.) Would the output fit in main context? (If yes and scope is narrow → direct.) Any independent thread I could parallelize? (If yes → dispatch multiple subagents concurrently.)

**Audit trail (opt-in):** When the user invokes `/ops` with `--dispatch-log`, decisions made via this framework are captured in `docs/ops-dispatch-log.md` — one entry per dispatch or deliberate direct-tool choice. The flag is off by default; when it is not set, skip the log append entirely. See [`dispatch-log.md`](./dispatch-log.md) for the format, kinds table, and append procedure. The log is the input for the periodic framework-adherence audit.
