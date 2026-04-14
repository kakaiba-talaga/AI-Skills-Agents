<!-- Referenced by ~/.claude/skills/deploy/SKILL.md. Keep in sync. -->
# Rollback Procedures — Deploy Skill Reference

Rollback is the deploy skill's response to a failed deployment. The decision to
rollback and the mechanism for doing it follow this defined protocol.

---

## 1. Automatic Rollback Triggers

Initiate rollback **automatically — no user confirmation required** when:

- `ssh-executor` returns `status: "failed"` with a `failed_at` command id.

This means a deployment step exited non-zero. The server is in a
partially-modified state and must be restored. The deploy skill immediately
constructs and dispatches a rollback `ssh-executor` brief.

---

## 2. User-Confirmed Rollback Triggers

Ask the user before rolling back in exactly two cases:

1. **Health check failure after all commands succeeded.**
   All deployment commands exited 0, but the service did not pass the health
   check. The server may be in a valid but degraded state. The user may want to
   investigate before reversing changes.

2. **Post-switch failure in a blue-green deployment.**
   The traffic switch has already executed. Rolling back means switching traffic
   back — this has service-availability implications and is a user decision.

---

## 3. Rollback Scope Calculation

Read `rollback_available` from the `ssh-executor` response. This map contains
rollback commands **only for steps that completed successfully before the
failure.**

Example: if steps 1, 2, and 3 completed and step 4 failed:
- `rollback_available` has entries for steps 1, 2, and 3.
- Step 4's rollback entry is absent — the step failed, so nothing was applied.
- Step 5's rollback entry is absent — the step was never reached.

Execute rollbacks in **reverse order** of the original `commands` list:
- rollback-3, rollback-2, rollback-1 (not 1, 2, 3).

---

## 4. Constructing the Rollback Brief

Build a new `ssh-executor` brief with the following fields:

| Field | Value |
| :--- | :--- |
| `target_host` | Same as the failed deployment |
| `commands` | Rollback commands from `rollback_available`, in reverse order. Each command gets a new id prefixed with `rollback_` — e.g., `rollback_backup_current`. |
| `rollback_commands` | Empty map — rollbacks do not have their own rollbacks |
| `health_check` | Same health check from the original deployment brief |
| `timeout` | Same timeout budget as the original deployment |
| `sudo_authorization` | Same as the original deployment (rollback commands may need the same sudo access) |

The rollback `ssh-executor` runs independently of the failed deployment. Its
response is a separate structured result that the deploy skill reports alongside
the original failure.

---

## 5. Pre-Hook Rollback

Pre-hooks often create side effects that outlive the deployment attempt:
enabling maintenance mode, draining connections, pausing cron jobs. If only the
main `commands` are rolled back, these side effects persist — the server stays
in maintenance mode even though the deployment was reversed.

### Rules

- Pre-hooks with side effects **MUST** have corresponding entries in
  `pre_hook_rollback` in the brief.
- On failure, the deploy skill reads **both** `rollback_available` (main command
  rollbacks) **and** `pre_hook_rollback_available` (pre-hook rollbacks) from the
  `ssh-executor` response.
- Pre-hooks that are read-only (e.g., connectivity checks, disk space
  assertions) do not need entries in `pre_hook_rollback` — only pre-hooks that
  change state on the remote host require reversal commands.

### Rollback Order (Critical)

A single rollback `ssh-executor` is dispatched containing both sets, in this
order:

1. **Main command rollbacks** from `rollback_available`, in reverse order of
   the original `commands` list.
2. **Pre-hook rollbacks** from `pre_hook_rollback_available`, in reverse order
   of the original `pre_hooks` list.

Rationale: deployment changes must be undone **before** taking the server out
of maintenance mode. Reversing the order — disabling maintenance first, then
restoring the old artifact — would briefly expose a broken deployment to live
traffic.

### Pre-Hook Failure (Before Main Commands)

If a pre-hook itself fails before any main commands ran, `rollback_available`
is empty. The deploy skill checks `pre_hook_rollback_available` for any
pre-hooks that completed before the failure, and reverses only those.

Example: if `enable_maintenance` succeeds but `drain_connections` fails, the
rollback disables maintenance mode only — it does not attempt to un-drain
connections that were never drained.

---

## 6. State Capture Before Rollback

Before dispatching the rollback `ssh-executor`, dispatch a **brief read-only
ssh-executor** to capture the current remote state:

- Check service status
- Read the current artifact version
- List the deployment directory

This snapshot is attached to the failure report and is available for diagnosis
if the rollback itself fails.

**State capture is best-effort.** If the state-capture `ssh-executor` fails to
connect, proceed to rollback anyway and note that state capture was unavailable.
Do not block rollback waiting for state capture to succeed.

---

## 7. Connection-Drop Recovery (SSH Exit Code 255)

When `ssh-executor` reports exit code 255 (SSH connection dropped), the command
**may have partially or fully executed on the remote.** Do NOT assume it failed.

### Recovery Steps

1. **Dispatch a state-check ssh-executor** — connect to the same host and
   verify current state: is the service running, was the file deployed, what is
   the backup status?

2. **Interpret the state:**
   - Command completed → mark as success, continue the deployment.
   - Command did not complete → treat as failure, enter the rollback flow.
   - State is ambiguous → escalate to the user immediately. Do not guess.

3. **Do NOT blindly retry.** Re-running a non-idempotent command after a
   connection drop can cause double-execution — double restart, double write,
   double database migration, etc. Verify state first, act based on evidence.

---

## 8. Rollback Failure Escalation

If the rollback `ssh-executor` returns `status: "failed"`:

- **Escalate to the user immediately.**
- Report all of the following:
  - What the original deployment did before failing (steps completed, what changed)
  - What the rollback attempted (which rollback commands were dispatched)
  - Which rollback step failed and why (the `failed_at` id and exit output)
  - Current known remote state (from `remote_state_changes` in both the
    original failure response and the rollback failure response)

**Do NOT retry rollback automatically.** Retrying a failed rollback risks making
the remote state worse. The user must take manual action to restore the server.

---

## 9. Destructive Command Policy

Rollback commands are subject to the same restrictions as deployment commands:

- Avoid `rm -rf` with globs — use `rm -r` with specific, timestamped paths
  (e.g., `rm -r /var/app/releases/20240112-143022`).
- The `ssh-executor` will escalate any rollback command matching the destructive
  command blocklist: `rm -rf`, `dd`, `mkfs`, `fdisk`, `parted`, `wipefs`,
  `shred`.
- If a necessary rollback command would match the blocklist, escalate to the
  user before dispatching — do not attempt to work around the blocklist.

---

## Quick Reference: Decision Tree

```
ssh-executor response received
│
├── status: "failed" with failed_at id
│   ├── Capture remote state (best-effort, read-only ssh-executor)
│   ├── Build rollback brief (reverse order: main commands, then pre-hooks)
│   └── Dispatch rollback ssh-executor (automatic, no user confirmation)
│       ├── rollback succeeds → report failure + rollback summary to user
│       └── rollback fails → ESCALATE immediately, no retry
│
├── status: "succeeded" but health check failed
│   └── ASK USER before rolling back
│
├── blue-green post-switch failure
│   └── ASK USER before switching traffic back
│
└── exit code 255 (SSH drop)
    ├── Dispatch state-check ssh-executor
    ├── Command completed → continue
    ├── Command not completed → enter rollback flow
    └── State ambiguous → ESCALATE to user
```
