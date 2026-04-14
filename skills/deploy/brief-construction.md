<!-- Referenced by ~/.claude/skills/deploy/SKILL.md. Keep in sync. -->

# Brief Construction — Deploy Skill Reference

A brief is the complete set of instructions for one ssh-executor invocation targeting one host. This file provides field-by-field construction guidance for Phase 3 of the deploy skill workflow.

---

## Field Reference

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `target_host` | string | Yes | SSH config alias from `~/.ssh/config`. Never a raw IP or hostname. |
| `commands` | list of command objects | Yes | Ordered, sequential. Execution stops on first failure. |
| `rollback_commands` | map of id → string | Yes | One reversal command per entry in `commands`, keyed by command `id`. |
| `health_check` | object | Yes | Verification step run after all commands complete. |
| `timeout` | object | Yes | `total_seconds` caps the entire task. `per_command_seconds` caps each command. |
| `sudo_authorization` | list of strings | No | Command ids whose `run` may contain `sudo`. Omit if no sudo needed. |
| `pre_hooks` | list of command objects | No | Run before `commands`. Failure aborts before any main step runs. |
| `pre_hook_rollback` | map of id → string | No | Reversal commands for pre-hooks with side effects. |
| `post_hooks` | list of command objects | No | Run after commands and health check pass. Failure is reported but does NOT trigger rollback. |
| `artifact` | object | No | Local file or directory to transfer before pre-hooks and commands run. |

---

## Command Object Structure

```json
{
  "id": "stop_service",
  "description": "Stop the web application service",
  "run": "sudo systemctl stop webapp"
}
```

- `id`: Unique within the brief. Use lowercase with underscores. Be descriptive: `stop_service`, `backup_current`, `deploy_artifact`, `start_service`.
- `description`: Human-readable label shown in the execution report.
- `run`: The exact shell command to execute on the remote host.

---

## Rollback Command Mapping

Every command in `commands` MUST have a corresponding entry in `rollback_commands`, keyed by that command's `id`. The rollback command reverses that specific step.

Rules:
- Use specific paths — never globs. `rm -r /opt/app/backup-20260412143022` not `rm -rf /opt/app/backup-*`.
- `rm -rf` is a destructive command and is blocked unconditionally. Use `rm -r` with a specific path instead.
- Rollback commands are also checked against the destructive command blocklist: `rm -rf`, `dd`, `mkfs`, `fdisk`, `parted`, `wipefs`, `shred`.

---

## Health Check Selection

Choose the health check type that matches the service:

| Service type | `type` value | `command` pattern |
| :--- | :--- | :--- |
| Web service with `/health` endpoint | `http` | `curl -sf http://localhost:PORT/health` |
| Systemd service | `systemd` | `systemctl is-active SERVICE` |
| Background process | `process` | `pgrep -f PROCESS_NAME` |
| Custom verification | `custom` | Any command that exits 0 on success |

Default values for all health checks:

```json
{
  "expected_exit_code": 0,
  "retry_count": 3,
  "retry_interval_seconds": 5,
  "timeout_seconds": 30
}
```

---

## Timeout Budgeting

```json
{
  "total_seconds": 300,
  "per_command_seconds": 60
}
```

- Default `total_seconds`: 300 (5 minutes). Increase for deployments with large artifact transfers, database migrations, or services with slow startup.
- Default `per_command_seconds`: 60. The ssh-executor wraps each remote command with `timeout PER_COMMAND_SECONDS COMMAND`. Increase for individual long-running commands.
- If the total wall-clock time exceeds `total_seconds`, the ssh-executor stops, reports a timeout failure, and returns what it completed.

---

## Sudo Authorization

List specific command ids — not patterns, not prefixes:

```json
"sudo_authorization": ["stop_service", "start_service"]
```

- Only commands whose ids appear in this list may contain `sudo` in their `run` field.
- If a command id is not listed, the ssh-executor stops and escalates if it encounters `sudo` in that command's `run` value.
- Destructive commands are NEVER authorized regardless of this field: `rm -rf`, `dd`, `mkfs`, `fdisk`, `parted`, `wipefs`, `shred`.

---

## Pre-Hooks and Post-Hooks

**Common pre-hook patterns** (run before `commands`; failure aborts before any main step):
- Enable maintenance mode in a load balancer
- Drain in-flight connections (e.g., `sleep 5`)
- Pause cron jobs

**Common post-hook patterns** (run after commands and health check pass; failure is reported, not rolled back):
- Disable maintenance mode
- Warm the application cache
- Clean up uploaded artifacts from `/tmp` — always include this to prevent accumulation

**Pre-hook rollback rules:**
- Pre-hooks with side effects (maintenance mode, cron pause) MUST have entries in `pre_hook_rollback`.
- Read-only pre-hooks (connectivity checks, disk space assertions) do not need rollback entries.
- Post-hook failures do NOT trigger rollback — the deployment already succeeded.

---

## Artifact Transfer

```json
{
  "local_path": "dist/webapp-1.4.2.tar.gz",
  "remote_path": "/tmp/webapp-1.4.2.tar.gz",
  "transfer_method": "scp"
}
```

- `local_path`: Relative to the project root.
- `remote_path`: Absolute path on the remote host.
- `transfer_method`: Use `scp` for single files. Use `tar-ssh` for directories.
- Transfer happens before `pre_hooks` and `commands` run.

---

## Timestamp Coordination

When commands use dynamic timestamps for backup directories, pre-compute the timestamp ONCE before constructing the brief and substitute it into BOTH the command and its rollback command.

Why: if you use `$(date +%Y%m%d%H%M%S)` in the `run` field, the shell substitution runs at dispatch time on the remote host. The rollback command cannot know which timestamp was used — making the rollback target unpredictable.

Correct pattern:
1. Compute `DEPLOY_TS=20260412143022` at brief construction time.
2. Use the fixed value in the command: `cp -r /opt/app/current /opt/app/backup-20260412143022`
3. Use the same fixed value in the rollback: `cp -r /opt/app/backup-20260412143022 /opt/app/current`

---

## Idempotency

Commands SHOULD be idempotent. If an SSH connection drops after a command executes but before the exit code is received, the deploy skill may re-dispatch. Non-idempotent commands risk double-execution.

| Prefer | Over |
| :--- | :--- |
| `systemctl restart SERVICE` | `systemctl start SERVICE` |
| `mkdir -p /path` | `mkdir /path` |
| `cp -f source dest` | `cp source dest` |

---

## Concrete Example — Web App Deployment

```json
{
  "target_host": "prod-web-01",
  "commands": [
    {
      "id": "stop_service",
      "description": "Stop the web application service",
      "run": "sudo systemctl stop webapp"
    },
    {
      "id": "backup_current",
      "description": "Backup the current deployment directory",
      "run": "cp -r /opt/webapp/current /opt/webapp/backup-20260412143022"
    },
    {
      "id": "deploy_artifact",
      "description": "Extract the new artifact to the deployment directory",
      "run": "tar xzf /tmp/webapp-1.4.2.tar.gz -C /opt/webapp/current"
    },
    {
      "id": "start_service",
      "description": "Start the web application service",
      "run": "sudo systemctl start webapp"
    }
  ],
  "rollback_commands": {
    "stop_service": "sudo systemctl start webapp",
    "backup_current": "rm -r /opt/webapp/backup-20260412143022",
    "deploy_artifact": "rm -r /opt/webapp/current && cp -r /opt/webapp/backup-20260412143022 /opt/webapp/current",
    "start_service": "sudo systemctl stop webapp"
  },
  "health_check": {
    "type": "http",
    "command": "curl -sf http://localhost:8080/health",
    "expected_exit_code": 0,
    "retry_count": 3,
    "retry_interval_seconds": 5,
    "timeout_seconds": 30
  },
  "timeout": {
    "total_seconds": 300,
    "per_command_seconds": 60
  },
  "sudo_authorization": ["stop_service", "start_service"],
  "pre_hooks": [
    {
      "id": "enable_maintenance",
      "description": "Enable maintenance mode in the load balancer",
      "run": "curl -sf -X POST http://localhost:9090/maintenance/enable"
    },
    {
      "id": "drain_connections",
      "description": "Wait for in-flight requests to complete",
      "run": "sleep 5"
    }
  ],
  "pre_hook_rollback": {
    "enable_maintenance": "curl -sf -X POST http://localhost:9090/maintenance/disable",
    "drain_connections": "sudo systemctl reload nginx"
  },
  "post_hooks": [
    {
      "id": "disable_maintenance",
      "description": "Disable maintenance mode",
      "run": "curl -sf -X POST http://localhost:9090/maintenance/disable"
    },
    {
      "id": "warm_cache",
      "description": "Prime the application cache",
      "run": "curl -sf http://localhost:8080/warmup"
    },
    {
      "id": "cleanup_artifact",
      "description": "Remove the uploaded deployment artifact from /tmp",
      "run": "rm -f /tmp/webapp-1.4.2.tar.gz"
    }
  ],
  "artifact": {
    "local_path": "dist/webapp-1.4.2.tar.gz",
    "remote_path": "/tmp/webapp-1.4.2.tar.gz",
    "transfer_method": "scp"
  }
}
```

Notes on this example:
- `backup_current` uses the pre-computed timestamp `20260412143022`, not `$(date ...)`. The same fixed timestamp appears in its rollback command.
- `stop_service` and `start_service` are in `sudo_authorization` because their `run` fields contain `sudo`.
- `drain_connections` is a read-only sleep with no side effects, but `enable_maintenance` has a side effect, so it has an entry in `pre_hook_rollback`. `drain_connections` also has an entry because nginx state was changed.
- `cleanup_artifact` in post-hooks removes the `/tmp` artifact. This prevents accumulation across repeated deployments.
