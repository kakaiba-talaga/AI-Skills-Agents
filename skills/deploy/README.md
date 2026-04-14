# Deploy Skill

Orchestrate deployments to remote servers from within Claude. The skill constructs structured briefs, dispatches the `ssh-executor` agent to run remote commands, interprets the results, and manages rollback when something goes wrong. It is a prompt skill — not executable code — so it runs inside a Claude session via `/deploy`.

## Quick start

```
/deploy webapp to staging                                # Simple push to one host
/deploy api-service to web-01,web-02                    # Rolling deploy to multiple hosts
/deploy app to blue,green --pattern blue-green          # Zero-downtime blue-green
/deploy api to canary,web-02,web-03 --pattern canary    # Canary then rollout
/deploy --dry-run webapp to production                  # Preview the brief without deploying
```

Additional commands:

```
/deploy help        Show the quick-reference help card
/deploy status      Show progress for an in-flight deployment
/deploy rollback    Initiate rollback of the most recent deployment
```

## Deployment patterns

| Pattern | Description |
|---|---|
| **Simple push** | Deploys to one host with a single ssh-executor dispatch. Expect brief downtime during the service restart. |
| **Rolling** | Deploys to N hosts sequentially. Each host's health check must pass before the next host is deployed. |
| **Blue-green** | Deploys to the inactive environment first, then switches traffic. The active environment is untouched until the switch, giving zero-downtime deployment. |
| **Canary** | Deploys to one host first and monitors it for a configurable window (default 300 s). If it stays healthy, the remaining hosts receive the deployment via rolling. |

Pattern is auto-selected: `simple` for one host, `rolling` for two or more. Override with `--pattern`.

## Prerequisites

**SSH config** — every target host must have a named entry in `~/.ssh/config`. The skill uses SSH config aliases, never raw IPs or hostnames.

Example entry:

```
Host staging
    HostName 10.0.1.42
    User deploy
    IdentityFile ~/.ssh/deploy_key
```

**Key-based authentication** — the skill passes `-o BatchMode=yes` to all SSH connections, which rejects password prompts. Password auth will always fail.

**Bash permissions** — the ssh-executor agent needs `Bash(ssh *)` and `Bash(scp *)` entries in your `settings.json` allow list. Without these, every remote command will prompt for approval.

## Flags

| Flag | Default | Description |
|---|---|---|
| `--pattern <type>` | auto | `simple`, `rolling`, `blue-green`, or `canary` |
| `--on-failure <policy>` | `halt` | `halt` stops at the first failure; `continue` logs it and proceeds |
| `--dry-run` | off | Construct and display the brief without dispatching ssh-executor |
| `--canary-duration <s>` | `300` | Canary monitoring window in seconds |
| `--sudo` | off | Authorize sudo for service management commands in the brief |
| `--no-rollback` | off | Disable automatic rollback on failure |

## Rollback behavior

The skill distinguishes between failure types and responds accordingly:

| Failure type | Response |
|---|---|
| Command failure | Automatic rollback — no user confirmation required |
| Health check failure after successful commands | Asks user: rollback or investigate? |
| Post-switch failure (blue-green) | Escalates to user — traffic already switched, automated rollback is not safe |
| Rollback failure | Escalates immediately — does not retry |

To manually roll back the most recent deployment: `/deploy rollback`

## Architecture

```
User → /deploy skill → constructs brief → ssh-executor agent → remote server
                     ← interprets response ←
```

The deploy skill never SSHs directly. It translates your deployment intent into a structured brief (target host, ordered commands, rollback commands, health check, timeouts), then dispatches the ssh-executor via the Agent tool. The ssh-executor handles all remote operations and returns a structured response. The deploy skill reads that response, decides what to do next, and reports to you.

Each brief targets exactly one host. Multi-host patterns (rolling, canary) produce one brief per host, dispatched sequentially and gated on health checks.

## Ops integration

The skill works standalone or as part of a larger `/ops` workflow:

- **Standalone** (`/deploy ...`) — the skill manages its own dispatch loop, rollback decisions, and reporting directly to you.
- **From `/ops`** — the team manager invokes `/deploy` as a task. The deploy skill constructs briefs, dispatches ssh-executor, handles rollback, and reports results back to the team manager. The team manager owns the task board.

When ops invokes deploy, the **`Deploy`** badge appears on turns where the deploy skill is active. When it finishes and control returns to ops, the **`Team Manager`** badge resumes.

## File structure

| File | Purpose |
|---|---|
| `SKILL.md` | Main skill — argument parsing, workflow phases, constraints |
| `README.md` | This file — user-facing documentation |
| `help-card.md` | Quick reference displayed by `/deploy help` |
| `brief-construction.md` | Field-by-field brief construction guidance and examples |
| `deployment-patterns.md` | Full step sequences and dispatch rules for all four patterns |
| `response-interpretation.md` | Response field interpretation and decision trees |
| `rollback-procedures.md` | Rollback contract and connection-drop recovery |
| `multi-host-orchestration.md` | Host inventory, dispatch sequencing, failure propagation |
