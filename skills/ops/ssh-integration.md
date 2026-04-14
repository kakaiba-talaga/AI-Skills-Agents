<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# SSH Integration — Team Manager Reference

This file covers the three things the team manager needs when an SSH task appears on the task board: preflight checks before dispatch, a brief template for the ssh-executor agent, and the handoff document format for SSH operations.

---

## SSH Preflight Checklist

Run these checks (via the verifier agent) before dispatching the ssh-executor. If any critical check fails, do NOT dispatch — report the failure to the user with remediation steps.

### Check 1 — Host exists in SSH config

```bash
grep -i "^Host " ~/.ssh/config
```

Verify the target alias is listed. If the task requires multiple hosts, check each one. If the alias is absent, remediation: ask the user to add an entry to `~/.ssh/config` before proceeding.

**Critical:** yes — missing host alias means the executor has no address to connect to.

### Check 2 — Connectivity test

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 HOST "echo ok"
```

Run for each target host, substituting the SSH config alias for `HOST`. Exit code 0 = pass. Non-zero exit code = connectivity failure. Common causes: host unreachable, firewall block, wrong alias.

**Critical:** yes — a connectivity failure must be resolved before dispatch.

### Check 3 — SSH key loaded

```bash
ssh-add -l
```

Best-effort diagnostic. If `ssh-add -l` fails (exit code 1 or 2) but Check 2 (connectivity test) passes, the connection works via `IdentityFile` directive in SSH config — proceed without blocking.

Exit code 0 = at least one key is loaded, proceed. Exit code 1 = agent is running but no keys are loaded (remediation: `ssh-add ~/.ssh/<keyfile>`). Exit code 2 = agent is not running (remediation: `eval "$(ssh-agent -s)"` then `ssh-add`). Report whichever condition applies to the user. Note: with `BatchMode=yes`, a missing or unloaded key produces an immediate `Permission denied` error — not a passphrase prompt.

If both Check 2 and Check 3 fail, auth will fail. If Check 2 passes, auth works regardless of ssh-agent state.

**Critical:** no — advisory only. Check 2 is the definitive auth gate.

### Check 4 — Source files exist (file transfer tasks only)

Verify the local file or directory to be transferred exists before dispatching. Use the Read or Glob tool to confirm the path is present. If absent, report to the user — do not dispatch.

**Critical:** yes (for file transfer tasks) — not applicable to command-only tasks.

### Check 5 — Remote directory exists (file transfer tasks, optional)

```bash
ssh -o BatchMode=yes HOST "test -d /remote/path"
```

Verify the target directory exists on the remote server. Exit code 0 = directory present. Non-zero = directory absent. If absent, include a `mkdir -p /remote/path` command as the first step in the executor brief, or ask the user whether to create it.

**Critical:** no — downgrade to a warning. The executor can create the directory, but the team manager should be explicit about it in the brief.

---

## Brief Template for SSH Tasks

Use this template when briefing the ssh-executor. Fill in every field — do not leave placeholders. If a field does not apply (e.g., no rollback is possible), state that explicitly rather than omitting the field.

```markdown
## Task
[Subject from the task board]

## Target
- **Host:** [SSH config alias — the name from ~/.ssh/config, not an IP or hostname]
- **User:** [from SSH config, or note "default from config"]
- **Working directory:** [remote path where commands should execute, e.g., /opt/app]

## Commands
[Ordered list of commands to execute remotely. Each command on its own line.]
1. `command-one`
2. `command-two`
3. `command-three`

## Expected Output
[What success looks like for each command — exit codes, output patterns, state changes]

## Rollback
[Commands to reverse each change, in reverse order. If no rollback is possible, state that.]
1. `rollback-for-command-three`
2. `rollback-for-command-two`
3. `rollback-for-command-one`

## Sudo Authorization
[yes/no — whether the brief authorizes sudo usage. If yes, specify which commands may use sudo.]

## Timeout Budget
- **Total:** [max time for the entire task, e.g., 5 minutes]
- **Per-command:** [max time per command if different from default 60s]

## Constraints
- No compound Bash commands — never use `&&`, `;`, or `||`. Make separate Bash tool calls. (Exception: tar-over-ssh pipeline is allowed as a single logical operation.)
- No `cd` prefix — the working directory is already the project root.
- Do not use the Agent tool — you are a worker, not a manager.
- Do not modify local files — report back if local changes are needed.
- All SSH commands must include: `-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new`
- [Additional task-specific constraints]
```

---

## Handoff Document Format for SSH Operations

When the ssh-executor completes a task and feeds into a downstream task (e.g., verifier), write a handoff document that extends the standard handoff template with SSH-specific fields. Store it in the run's handoff subdirectory following the naming convention defined in `handoffs.md`.

```markdown
## SSH Handoff — Task #[N]

### Standard Fields
- **Run ID:** [run_id from task metadata]
- **Plan document:** [path to plan doc, if one exists]
- **Task #:** [task number]
- **Timestamp:** [ISO-8601]
- **Agent:** ssh-executor
- **Status:** completed

### What was done
[Summary of the completed work — which commands ran, what remote state changed]

### Key decisions
[Any non-obvious choices the agent made and why — e.g., skipped a command due to precondition failure, used a different path than specified]

### SSH-Specific Fields
- **Target host:** [SSH config alias]
- **Commands executed:**
  1. `command` → exit code [N], [pass/fail]
  2. `command` → exit code [N], [pass/fail]
- **Remote state changes:**
  - [what was modified on the remote server — files created, services restarted, configs changed]
- **Rollback commands:**
  - [commands to reverse each change, in reverse order]
  - [include even if task succeeded — downstream agents may need to rollback]
- **Remote artifacts:**
  - [paths on the remote server that were created or modified]
- **Verification hints:**
  - [what the downstream verifier should check — endpoints, log entries, file contents]

### Open items
[Anything the agent flagged but did not address — edge cases, partial failures, uncertainties]

### For the next agent
[Specific guidance for the downstream task — what to focus on, what remote state to inspect]
```

This format ensures that if the verifier needs to check remote state, or if a rollback is needed, all information is in the handoff file — no need to re-derive it from the task description.
