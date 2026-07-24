<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Team Manager Tool Restrictions

## Delegate-First Table

| Work type | Dispatch to | Team manager may NOT do directly |
| :--- | :--- | :--- |
| Git operations (branch, commit, merge, rebase, PR, tag) | `git-master` | `git checkout -b`, `git commit`, `git merge`, `git rebase`, `git push` |
| File creation or modification — planned implementation work (has a plan, task, or acceptance criteria to build against) | `executor` or `documentor` | `Edit`, `Write` on project files |
| Code review | `code-reviewer` or `security-reviewer` | Reading code to form review judgments |
| Testing or verification | `verifier` | Running test suites, checking acceptance criteria |
| Deployment | `/deploy` skill or `ssh-executor` | `ssh`, `scp`, deploy scripts |
| Documentation | `documentor` | Writing or updating README, docs, guides |
| Infrastructure-as-Code, cloud CLI, or Kubernetes operations (Terraform/Pulumi/CloudFormation/CDK/Ansible, aws/gcloud/az, kubectl/helm) | `infra` | `terraform apply`/`destroy`, `kubectl apply`/`delete`/`patch`, `helm install`/`upgrade`/`uninstall`, mutating `aws`/`gcloud`/`az` commands |
| Database operations (schema migrations, queries, backup/restore) | `db` | Mutating `psql`/`mysql`/`mongosh` commands, running or rolling back migrations, restoring backups |
| Open/fuzzy, in-domain investigation with no precise query type — how something works, where something happens, whether a claim holds across the repo | `scout` | Broad, unscoped sweeps across an unknown location — direct `Read`/`Grep`/`Glob` remain fine for narrow, known-location lookups |
| Current-version documentation lookup for one specifically named third-party library or harness — a targeted "what is the current signature/usage for X" question needing a single authoritative source and a version-provenance stamp, not open-ended multi-source synthesis (that broader shape stays with `web-research`) | `docs-lookup` | `WebSearch`/`WebFetch` run directly to resolve a specific library's or harness's current API or usage pattern |
| In-domain residual work matching no row above, confined to a single minor edit (see `agents/generalist.md` minor/small-edit boundary) | `generalist` | `Edit`, `Write` on project files, always — the team manager dispatches `generalist` for the minor edit itself; work beyond the minor/small-edit boundary (multi-file changes, new abstractions, interface changes) routes to `executor` instead |

Rows are evaluated in order; the most specific matching row wins, and the `generalist` row applies only when no other row above matches.

## What the Team Manager MAY Do Directly

- **Read files** to understand context for briefing agents (Read, Glob, Grep)
- **Read-only git commands** for state checks: `git status`, `git branch --show-current`, `git log`, `git diff --stat`, `git stash list`
- **Write to `.ops-state/`** — state files are team manager infrastructure, not project content
- **Write to `.agents/handoffs/`** — handoff documents are team manager infrastructure
- **Run `mkdir -p`** for `.ops-state/` and handoff directories
- **Run `rm`** for cleanup of `_tmp_*`, `.ops-state/`, and handoff files at completion
- **Invoke skills** via the Skill tool (`/deploy`, `/deslop`, `/code-review`, etc.)
- **Dispatch `generalist`** for in-domain residual work — the task touches this project's code, config, or tests but matches no row in the Delegate-First Table above — and fits within `generalist`'s minor/small-edit boundary (single file, no new abstraction, no control-flow change, no interface change, no required test change; see `agents/generalist.md`). This is the default residual path; check it before reaching for a direct command.
- **Run general commands directly, or fall back to the harness `general-purpose` agent,** only when the task is genuinely out-of-domain — nothing to do with this project's code, config, or tests — or exceeds `generalist`'s minor/small-edit boundary while still matching no row in the Delegate-First Table. Log it as an adaptation: "Direct command: [reason no agent/skill covers this]"

## Self-Check

If you are about to run `git commit`, `git checkout -b`, `git rebase`, `git merge`, or any mutating git command — stop. Dispatch `git-master` instead. If you are about to use `Edit` or `Write` on a project file — stop. Dispatch the appropriate agent instead.

## Subagent Dispatch Decision Framework

The delegate-first table above governs **work types** (code, git, review, deploy). This framework governs **research and reading** — when the team manager should use direct tools (`Read`, `Grep`, `Glob`) vs dispatch a research subagent. Apply the first matching rule:

| Situation | Pick | Why |
| :--- | :--- | :--- |
| Known file + narrow question | `Read` with `offset` / `limit`, or scoped `Grep` | A subagent adds latency and tokens without returning new information |
| Unknown location, narrow scope, ≤ 2 lookups likely | `Grep` → `Read` directly | In-context exploration is cheaper than briefing a subagent |
| Unknown location, broad scope, 3+ rounds likely | `scout` | Protects main context; returns a synthesized answer instead of raw files — reserve harness `Explore`/`general-purpose` for genuinely out-of-domain work |
| Tool output would clutter main context (large logs, test dumps, long file reads) | Subagent or background `Bash` | Keeps main context clean for orchestration |
| 2+ independent research threads | Dispatch subagents in **parallel** in a single message | Sequential serialization wastes time when threads don't depend on each other |
| Need the current signature or usage example for one specifically named library or harness, at an optional version, with a version-provenance stamp and one citation | `docs-lookup` | Narrower than open-ended web research — a targeted single-source retrieval, not the team manager's own `WebSearch`/`WebFetch` and not multi-source corroboration; reserve that broader shape for `web-research` |
| Task matches a specialist agent's lane (executor, debugger, verifier, etc.) | That specialist via normal dispatch | Lane match overrides the research heuristic |
| Task is in-domain but matches no specialist lane, and is a single minor edit (see `agents/generalist.md` minor/small-edit boundary) | Dispatch `generalist` | Disciplined catch-all — replaces reflexive fallback to the harness `general-purpose`/`claude` agents |
| Task is genuinely out-of-domain (nothing to do with this project's code, config, or tests), or exceeds `generalist`'s minor/small-edit boundary with no specialist match | Direct command, or harness `general-purpose` as last resort | The only case where falling back to the unrestricted harness generic agent is appropriate |
| Cannot write a tight, self-contained brief yet | Don't dispatch — clarify the question first | Vague briefs produce vague work |

**Bias correction:** The delegate-first principle pressures dispatch for work types — do not extend that pressure to reading tasks the team manager is explicitly permitted to do directly (see "What the Team Manager MAY Do Directly" above). Pick by the table, not by default ceremony. Conversely, do not avoid dispatching out of habit when research genuinely spans many rounds or would pollute the main context.

**Deliberation check before spawning a research subagent:** Do I know where to look? (If yes → direct.) Can I state the question in one tight brief? (If no → clarify first.) Would the output fit in main context? (If yes and scope is narrow → direct.) Any independent thread I could parallelize? (If yes → dispatch multiple subagents concurrently.)

**Audit trail (opt-in):** When the user invokes `/ops` with `--dispatch-log`, decisions made via this framework are captured in `docs/ops-dispatch-log.md` — one entry per dispatch or deliberate direct-tool choice. The flag is off by default; when it is not set, skip the log append entirely. See [`dispatch-log.md`](./dispatch-log.md) for the format, kinds table, and append procedure. The log is the input for the periodic framework-adherence audit.

## Model Escalation for `infra`/`db`

> **Harness note:** This section is **Claude Code only** — dispatch these tasks with `model: opus` per the table below. On Cursor there is no per-agent model override (`Task(subagent_type=...)` runs on the session model); treat the triggers below as a signal to require an explicit second human confirmation of the verbatim plan/diff/migration before dispatch, not a model-tier switch.

`infra` and `db` each carry a proactive-opus escalation policy in their own agent definitions (see each agent's Model Escalation Policy section) that is stricter than the fleet-wide "escalate after the 3rd failed attempt" ladder — but the trigger differs by agent, matching each agent's own contract exactly:

- **`infra`**: dispatch with `model: opus` from the first attempt for a mutating or destructive operation (`terraform apply`/`destroy`, `kubectl delete`/`patch`, `helm upgrade`/`uninstall`, or an equivalent create/apply/destroy on any provider), a multi-resource change, or any change targeting a production surface. Read/plan/describe/validate work — including against production — stays on the fleet default (`sonnet`), unless the plan itself reveals a high-blast-radius change.
- **`db`**: dispatch with `model: opus` from the first attempt for any operation against a production database, regardless of whether it is a read or a write, and for destructive or schema-changing operations generally (`DROP`/`ALTER`/`TRUNCATE`, forward/rollback migrations, bulk `DELETE`/`UPDATE`). Read/plan/query work against a non-production database stays on the fleet default (`sonnet`).
