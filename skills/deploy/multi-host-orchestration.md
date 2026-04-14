<!-- Referenced by ~/.claude/skills/deploy/SKILL.md. Keep in sync. -->
# Multi-Host Orchestration — Deploy Skill Reference

## Host Inventory

The host list comes from user input (comma-separated hosts in `/deploy <what> to <h1,h2,h3>`) or a config structure. Hosts are SSH config aliases — the same aliases the ssh-executor validates against `~/.ssh/config`.

Example deploy config host definition:

```json
{
  "hosts": ["prod-web-01", "prod-web-02", "prod-web-03"],
  "pattern": "rolling",
  "on_failure": "halt-on-failure"
}
```

The deploy skill reads this list at dispatch time. It does not resolve hostnames or IPs — that is the ssh-executor's job via SSH config.

---

## Sequential Dispatch (Rolling)

Rolling deployments use sequential dispatch. The deploy skill dispatches one ssh-executor, waits for its health check to pass, then dispatches the next.

**Gate rule:** The next dispatch call does NOT happen until the current response arrives with `health_check.status: "pass"`. A completed command set without a passing health check is NOT sufficient to proceed to the next host.

---

## Parallel Dispatch

Parallel dispatch is appropriate when:

- Hosts are independent (no shared state that a deployment step modifies)
- The deployment pattern does not require a gate between hosts (e.g., blue-green inactive host)
- Only one inactive host is being targeted at a time in a blue-green setup

**Hard rule:** Never dispatch two ssh-executors targeting the same host in parallel. The ssh-executor agent enforces this at its level, but the deploy skill must not create the condition in the first place.

---

## Failure Propagation

### `halt-on-failure` (default)

When any host's ssh-executor returns `status: failed` or a health check failure:

1. Stop dispatching to remaining hosts.
2. Record which hosts succeeded (deployed new version, health check passed).
3. Record which host failed and at what step.
4. Initiate rollback on the failed host.
5. Leave successfully-deployed hosts on new version — do not roll them back unless the user asks.
6. Report the partial deployment state: succeeded hosts, failed host, rollback result.

### `continue-on-failure`

When any host's ssh-executor returns a failure:

1. Log the failure with the host alias and `failed_at` command id.
2. Continue dispatching to the remaining hosts.
3. After all hosts complete (success or failure), report the full result: per-host status, which hosts need attention.
4. Do not rollback automatically. The user reviews the report and decides which hosts to rollback.

---

## Canary Pattern

Canary is a specialization of rolling. Deploy to one canary host first, run an extended verification window, then proceed to remaining hosts only if the canary stays healthy.

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

**Step sequence:**

1. Dispatch ssh-executor for `canary_host`. Wait for health check to pass.
2. Run extended canary verification: dispatch a monitoring ssh-executor that polls the health check endpoint repeatedly over `canary_health_check_duration_seconds` (default 300s).
   - If the canary fails at any point during this window → rollback the canary host, abort the deployment. No remaining hosts are deployed.
3. If the canary stays healthy through the full window → dispatch ssh-executors for `remaining_hosts` using the rolling pattern (sequential, gated).
4. Report the full result.

**When to use canary:** When you want to validate a new version under real traffic for a period of time before committing to a full rollout. Requires a load balancer that distributes traffic to all hosts so the canary receives real requests during the verification window.

---

## Coordinated Multi-Host Rollback

When a rolling deployment fails at host N after hosts 1 through N-1 succeeded:

### Default (`halt-on-failure`)

Only the failed host (N) is rolled back automatically. Hosts 1 through N-1 remain on the new version. After rollback of N, the deploy skill reports the partial deployment state and prompts the user:

- Proceed with remaining hosts
- Rollback all hosts
- Leave as-is

### Full rollback (user-requested)

If the user requests rollback of all hosts:

1. Dispatch ssh-executor instances to hosts 1 through N-1 in **reverse order**, using the rollback commands from their original deployment responses.
2. Each host's rollback is independent — a failure on one host's rollback does not block the others.
3. Report the rollback result for each host individually.

### Canary rollback

If the canary host fails during the extended monitoring window, rollback only the canary host. Do not proceed to the remaining hosts.

---

## Progress Reporting — Per-Host Status Table

Render a status table after each host completes and at final summary. Use this format:

```
| Host        | Status    | Health | Duration | Notes                          |
|-------------|-----------|--------|----------|--------------------------------|
| prod-web-01 | deployed  | pass   | 21s      | canary — monitoring complete   |
| prod-web-02 | deployed  | pass   | 19s      |                                |
| prod-web-03 | deploying | —      | 8s       | in progress                    |
| prod-web-04 | pending   | —      | —        | waiting for prod-web-03        |
```

**Status values:**

| Value      | Meaning                                                     |
|------------|-------------------------------------------------------------|
| `pending`  | Not yet dispatched — waiting for an earlier host to gate    |
| `deploying`| ssh-executor dispatched, response not yet received          |
| `deployed` | Commands complete, health check passed                      |
| `failed`   | ssh-executor returned failure or health check failed        |
| `rolled-back` | Rollback commands completed on this host               |
| `skipped`  | Not dispatched due to `halt-on-failure` stopping the run    |

Include the Notes column for anything non-obvious: canary monitoring state, rollback trigger, failure step, skip reason.
