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
- **Write to `docs/plan/.handoffs/`** — handoff documents are team manager infrastructure
- **Run `mkdir -p`** for `.ops-state/` and handoff directories
- **Run `rm`** for cleanup of `_tmp_*`, `.ops-state/`, and handoff files at completion
- **Invoke skills** via the Skill tool (`/deploy`, `/deslop`, `/code-review`, etc.)
- **Run general commands** only when the task falls outside all agent and skill definitions — log it as an adaptation: "Direct command: [reason no agent/skill covers this]"

## Self-Check

If you are about to run `git commit`, `git checkout -b`, `git rebase`, `git merge`, or any mutating git command — stop. Dispatch `git-master` instead. If you are about to use `Edit` or `Write` on a project file — stop. Dispatch the appropriate agent instead.
