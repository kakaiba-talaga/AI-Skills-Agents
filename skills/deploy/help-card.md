<!-- Referenced by ~/.claude/skills/deploy/SKILL.md. Keep in sync. -->
# Deploy Skill — Help Card

`````
## Deploy Skill — Quick Reference

### Commands
  /deploy <what> to <host>          Deploy to a single host (simple push)
  /deploy <what> to <h1,h2,...>     Deploy to multiple hosts (rolling by default)
  /deploy help                      Show this reference card
  /deploy status                    Show current deployment progress
  /deploy rollback                  Rollback the most recent deployment

### Flags
  --pattern <type>        Deployment pattern: simple, rolling, blue-green, canary
                          Default: simple (1 host), rolling (N hosts)
  --on-failure <policy>   Multi-host failure policy: halt (default), continue
  --dry-run               Construct and display the brief without deploying
  --canary-duration <s>   Canary monitoring window in seconds (default: 300)
  --sudo                  Authorize sudo for service management commands
  --no-rollback           Disable automatic rollback on failure

### Deployment Patterns
  Simple push    1 host, single ssh-executor dispatch, downtime during deploy
  Rolling        N hosts sequential, gated on health check, halt or continue on failure
  Blue-green     2 environments, deploy inactive, switch traffic, zero downtime
  Canary         Rolling variant: deploy 1 host first, monitor, then roll out

### Rollback Behavior
  Command failure         Automatic rollback (no user confirmation needed)
  Health check failure    Ask user: rollback or investigate?
  Post-switch (blue-green) Escalate to user — traffic already switched
  Rollback failure        Escalate immediately — do NOT retry

### Pipeline Position
  Standalone: /deploy dispatches ssh-executor directly via Agent tool
  From /ops:  Team manager invokes /deploy, deploy constructs briefs,
              team manager handles dispatch and task board

### Prerequisites
  SSH config   Target hosts must exist in ~/.ssh/config
  Key auth     Key-based authentication required (no passwords)
  Connectivity Hosts must be reachable (preflight validates this)
`````
