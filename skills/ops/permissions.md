<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

## Permission Notes

The team manager and its agents require a broad set of permissions to run without prompts. See the **Permissions Reference** in [`~/.claude/agents/README.md`](../agents/README.md) for the complete list of required permissions, organized by category.

Some operations will **always prompt** even in autonomous mode because they carry risk:

| Command / Tool | Risk | When it comes up |
| :--- | :--- | :--- |
| `RemoteTrigger` | Spins up remote agents that consume API credits unattended. | Ralph integration with remote scheduling. |
| `Bash(npx *)` | Executes arbitrary npm packages. | Node.js agents running tooling not installed globally. |
| `Bash(make *)` / `Bash(cmake *)` | Runs arbitrary Makefile targets. | Build steps, `make test`, native compilation. |

If a dispatched agent needs one of these, the team manager should **warn the user before dispatch** rather than letting the agent hit the permission prompt mid-task. In autonomous mode, pause the affected task and continue other chains.

To opt in per project, add to `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": ["RemoteTrigger", "Bash(npx *)", "Bash(make *)", "Bash(cmake *)"]
  }
}
```
