<!-- Referenced by ~/.claude/skills/deploy/SKILL.md. Keep in sync. -->
# Deployment Patterns — Deploy Skill Reference

---

## Pattern Selection Logic

The deploy skill selects a pattern based on host count unless an explicit `--pattern` override is provided.

| Hosts | Default pattern | Override with |
|---|---|---|
| 1 host | Simple push | `--pattern rolling` (no-op), `--pattern blue-green` (needs 2 envs) |
| 2 hosts | Rolling | `--pattern blue-green` (if they are active/inactive environments) |
| N hosts | Rolling | `--pattern canary` (deploys 1 first, monitors, then rolls out) |

---

## Simple Push (1 host)

**When to use:** Single-host deployments, development environments, services without redundancy requirements, or any scenario where downtime during deployment is acceptable.

**Step sequence:**

1. Dispatch 1 ssh-executor with the full brief (artifact transfer → pre-hooks → commands → health check → post-hooks).
2. Receive response. Check `status`.
3. If `status` is `success` → deployment complete.
4. If `status` is `failed` → initiate rollback (see rollback-procedures.md).
5. If health check failed but commands succeeded → ask the user whether to rollback or leave the deployment in place for investigation.

**Dispatch count:** 1 ssh-executor.

**Failure behavior:** On any command failure, the ssh-executor stops immediately and returns `status: failed`. The deploy skill reads `rollback_available` from the response and decides whether to rollback automatically (command failure) or ask the user (health check failure).

**Rollback:** Dispatch a new ssh-executor with the rollback commands from `rollback_available`, executed in reverse order of the original `commands` list.

---

## Rolling (N hosts, sequential)

**When to use:** Multi-host deployments where you want to detect problems early and limit the blast radius. Suitable for stateless services behind a load balancer where gradual rollout reduces risk.

**Step sequence:**

1. Read the host list from the deploy config. Establish the ordered sequence.
2. For each host in order:
   a. Dispatch 1 ssh-executor brief for that host (same structure as simple push).
   b. Wait for the response.
   c. Check the health check result in the response.
   d. If health check passes → proceed to next host.
   e. If health check fails → apply the failure policy (see below).
3. After all hosts deploy successfully, report completion with per-host results.

**Dispatch count:** N sequential ssh-executor dispatches (one per host).

**Gate:** The next host dispatch ONLY happens after the current host's ssh-executor response shows `health_check.status: pass`. A completed set of `commands` without a passing health check is NOT sufficient to proceed.

**Failure behavior:** Controlled by the `on_failure` option in the deploy config.

- `halt-on-failure` (default): Stop the rolling deployment. Do not proceed to remaining hosts. Initiate rollback on the failed host. Report which hosts deployed successfully and which failed.
- `continue-on-failure`: Log the failure, continue to remaining hosts. Report all failures at the end. Does not rollback the failed host automatically — requires explicit user action.

**Rollback:** Rollback applies only to the host that failed. Hosts that already deployed successfully are left in the new state. The deploy skill reports the partial deployment state clearly so the user can decide whether to rollback the successfully-deployed hosts manually.

---

## Blue-Green (2 environments)

**When to use:** Zero-downtime deployments where you maintain two identical environments (blue and green) and route traffic to only one at a time. The inactive environment receives the new deployment; traffic switches only after verification.

**Prerequisites in deploy config:**
- `active_host` — the environment currently serving traffic
- `inactive_host` — the environment to deploy to first
- `traffic_switch_command` — executes the load balancer or DNS change

**Step sequence:**

1. Dispatch ssh-executor #1: Deploy to `inactive_host`. Brief includes artifact transfer, commands, and health check. No pre-hooks that affect the live environment.
2. Receive response from ssh-executor #1.
   - If `status` is `failed` or health check did not pass → ABORT. Do NOT switch traffic. The inactive environment stays dirty; report what failed.
3. If ssh-executor #1 succeeds and health check passes → execute the traffic switch. The traffic switch is external to the ssh-executor (it may be a local command, an API call, or a separate system). The deploy skill owns this step directly.
4. Dispatch ssh-executor #2: Verify `active_host` (the environment that just received traffic — previously `inactive_host`). Brief contains only the health check command, no deployment commands.
5. Receive response from ssh-executor #2.
   - If health check passes → deployment complete.
   - If health check fails → ESCALATE to user immediately (see failure behavior below).

**Dispatch count:** 2 ssh-executor dispatches (deploy to inactive + verify active). The traffic switch happens between them, outside of any ssh-executor.

**Failure before traffic switch:** Abort. Do not switch traffic. The active environment is unaffected. The inactive environment contains the failed deployment and should be cleaned up manually.

**Failure after traffic switch:** Escalate to the user immediately. Do NOT attempt automatic rollback. Traffic is already on the new environment and the health check is failing. Reverting the switch is a manual operation with service impact — the user must make this decision.

**Rollback:** If failure occurs before the traffic switch, rollback is not needed (the active environment never changed). If failure occurs after the switch, there is no automated rollback — this must be a user-confirmed manual operation.

---

## Canary (rolling variant)

**When to use:** When you want to validate a new version under real traffic for a period of time before committing to a full rollout. Requires a load balancer that distributes traffic to all hosts so the canary receives real requests during the verification window.

**Config:**

```json
{
  "canary_host": "prod-web-01",
  "remaining_hosts": ["prod-web-02", "prod-web-03"],
  "pattern": "canary",
  "canary_health_check_duration_seconds": 300,
  "on_failure": "halt-on-failure"
}
```

`canary_health_check_duration_seconds` defaults to `300` if not specified.

**Step sequence:**

1. Dispatch ssh-executor for `canary_host`. Wait for health check to pass.
2. Run extended canary monitoring: dispatch a monitoring ssh-executor that polls the health check endpoint repeatedly over `canary_health_check_duration_seconds`.
   - If the canary fails at any point during this window → rollback the canary, abort the deployment. No remaining hosts are deployed.
3. If the canary stays healthy through the full monitoring window → dispatch ssh-executors for `remaining_hosts` using the rolling pattern (sequential, gated on health check pass per host).
4. Report the full result.

**Dispatch count:** 1 (canary) + 1 (monitoring) + N sequential (remaining hosts).

**Failure behavior:** Same as rolling with `halt-on-failure`. A canary failure aborts everything. No remaining hosts are deployed.

**Canary rollback:** If the canary host fails during the extended monitoring window, rollback only the canary. Do not proceed to the remaining hosts.

---

## Cross-Pattern Notes

### Partial deployment state (rolling and canary)

When a rolling deployment fails at host N after hosts 1 through N-1 succeeded:

- **Default (`halt-on-failure`):** Only the failed host (N) is rolled back automatically. Hosts 1 through N-1 remain on the new version. The deploy skill reports the partial state and asks the user: proceed with remaining hosts, rollback all hosts, or leave as-is.
- **Full rollback (user-requested):** Dispatch ssh-executor instances to hosts 1 through N-1 in reverse order using the rollback commands from their original deployment responses. Each host's rollback is independent — a failure on one does not block others. Report the rollback result for each host individually.

### Traffic switch ownership (blue-green)

The deploy skill owns the traffic switch step directly. It is not delegated to an ssh-executor. The mechanism may be a local CLI command, an API call, or any external system — the key rule is that it executes between ssh-executor #1 and ssh-executor #2 and is always the deploy skill's responsibility.
