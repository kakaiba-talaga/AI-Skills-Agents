# ClickUp

Interact with ClickUp directly from the CLI via the REST API. Manage tasks, comments, checklists, attachments, time tracking, assignees, tags, subtasks, and navigate your workspace hierarchy -- all without leaving your editor.

## How it works

```
Resolve token --> Resolve workspace --> Execute API call --> Present result
```

The skill reads your API token and workspace config from `~/.claude/config/clickup/config.json` (never from environment variables), resolves the target task (supporting custom ID prefixes), calls the ClickUp API, and presents a summarized result. Supports batch operations across multiple tasks and filtered task listings.

## Quick start

```bash
# Get task details
/clickup Get task 10060.

# Create a task
/clickup Create a task called 'Fix login bug' in list 12345.

# Update task status
/clickup Set task 10060 status to 'in progress'.

# Assign someone
/clickup Assign John to task 10060.

# Set a due date
/clickup Set task 10060 due date to 2026-04-10.

# Search for tasks
/clickup Find tasks matching 'Caddy migration'.

# List filtered tasks
/clickup List 'in progress' tasks in list 12345.

# Show help
/clickup --help
```

## Permissions

The skill uses `curl` for API calls and `jq` for JSON parsing. Add these to your `settings.json` allow list to avoid prompts:

```
"Bash(curl *)",
"Bash(jq *)"
```

If `jq` is not installed, the skill offers to install it automatically. To allow that without prompting, also add `Bash(winget *)` (Windows), `Bash(brew *)` (macOS), or `Bash(apt-get *)` (Linux).

## First-time setup

On first use, the skill walks you through setup:

1. Asks for a token **name** and your **API token** (from ClickUp Settings > Apps)
2. Asks for your **workspace name** and **team ID**
3. Auto-detects or asks for your **custom ID prefix**
4. Saves config to `~/.claude/config/clickup/config.json`

Token values are never displayed or logged after setup.

```bash
# Add a new token
/clickup --add-token

# Add a workspace
/clickup --add-workspace

# Auto-detect custom ID prefix
/clickup --detect-prefix

# Set up project-specific config
/clickup --init-project
```

## Flags

### Task targeting

| Flag | Effect |
|---|---|
| `--task <id>` | Target a specific task by custom or native ID |
| `--tasks <id1,id2,...>` | Target multiple tasks for batch operations |
| `--search "<text>"` | Search tasks by title (partial, case-insensitive) |
| `--comment "<text>"` | Add a comment to the target task(s) |

### Filtering and output

| Flag | Effect |
|---|---|
| `--status "<status>"` | Filter task listing by status |
| `--assignee "<name>"` | Filter task listing by assignee |
| `--tag "<tag>"` | Filter task listing by tag |
| `--due-before "<date>"` | Filter tasks due before a date |
| `--due-after "<date>"` | Filter tasks due after a date |
| `--include-subtasks` | Include subtasks in task listings |
| `--format <type>` | Output format: `summary` (default), `table`, `json` |

### Token and workspace management

| Flag | Effect |
|---|---|
| `--add-token` | Add a new API token interactively |
| `--list-tokens` | List stored tokens (names only, never values) |
| `--set-default-token <name>` | Set the default token |
| `--token <name>` | Use a specific token for this command |
| `--add-workspace` | Add a new workspace interactively |
| `--list-workspaces` | List configured workspaces |
| `--set-default-workspace <name>` | Set the default workspace |
| `--workspace <name>` | Use a specific workspace for this command |
| `--detect-prefix` | Auto-detect the custom ID prefix for a workspace |
| `--init-project` | Set up project-specific config (`.clickup/config.json`) |
| `--help` | Show the quick reference (no API calls) |

## What you can do

### Tasks

```bash
# Get task details
/clickup Get task 10060.

# Create a task in a specific list
/clickup Create a task called 'Fix login bug' in list 12345.

# Create with priority (1=Urgent, 2=High, 3=Normal, 4=Low)
/clickup Create a high-priority task called 'Security patch' in list 12345.

# Update task status
/clickup Set task 10060 status to 'in progress'.

# Delete a task
/clickup Delete task 10060.

# Search by title
/clickup Find tasks matching 'Caddy migration'.
```

### Assignees

```bash
# Assign a user to a task
/clickup Assign John to task 10060.

# Assign multiple users
/clickup Assign John and Jane to task 10060.

# Remove an assignee
/clickup Remove Jane from task 10060.

# Bulk assign across tasks
/clickup Assign John to tasks 10060,10061,10062.
```

User names are resolved to IDs automatically via the workspace member list.

### Due dates and scheduling

```bash
# Set a due date
/clickup Set task 10060 due date to 2026-04-10.

# Set a start date
/clickup Set task 10060 start date to 2026-04-05.

# Set a time estimate
/clickup Set task 10060 time estimate to 4h.

# Set both start and due
/clickup Set task 10060 start date to 2026-04-05 and due date to 2026-04-10.

# Clear a due date
/clickup Clear due date on task 10060.
```

Dates accept human-readable formats (e.g., `2026-04-10`, `tomorrow`, `next Friday`) and are converted to Unix epoch milliseconds for the API.

### Tags

```bash
# Add a tag
/clickup Add tag 'urgent' to task 10060.

# Remove a tag
/clickup Remove tag 'wontfix' from task 10060.

# Bulk tag multiple tasks
/clickup Add tag 'sprint-12' to tasks 10060,10061,10062.
```

Tag names are lowercased and URL-encoded automatically.

### Time tracking

```bash
# Log time on a task
/clickup Log 2h 30m on task 10060.

# Log with a note
/clickup Log 1h on task 10060: reviewed PR and fixed tests.

# Start a timer
/clickup Start timer on task 10060.

# Stop the running timer
/clickup Stop timer on task 10060.

# View time entries
/clickup Show time tracked on task 10060.
```

Durations accept human-readable formats (`2h`, `30m`, `1h 15m`) and are converted to milliseconds.

### Subtasks

```bash
# Create a subtask
/clickup Create a subtask under task 10060 called 'Write tests'.

# Create with priority
/clickup Create a high-priority subtask under task 10060 called 'Security review'.

# List subtasks
/clickup List subtasks of task 10060.
```

Subtasks are created using the `parent` field on the standard task creation endpoint. Custom IDs are resolved to native IDs automatically.

### Batch operations

Operate on multiple tasks at once using comma-separated IDs:

```bash
# Bulk status update
/clickup Set tasks 10060,10061,10062 status to 'done'.

# Bulk comment
/clickup Post comment on tasks 10060,10061: sprint complete.

# Bulk assign
/clickup Assign John to tasks 10060,10061,10062.

# Bulk tag
/clickup Add tag 'sprint-12' to tasks 10060,10061,10062.
```

Batch operations execute sequentially with automatic retry on rate limits. Each task reports success or failure individually.

### Checklists

```bash
# Add a checklist to a task
/clickup Add a checklist called 'Deploy steps' to task 10060.

# Add an item to a checklist
/clickup Add item 'Run tests' to checklist on task 10060.

# Mark an item as resolved
/clickup Mark checklist item 'Run tests' as resolved.

# Delete a checklist
/clickup Remove the 'Deploy steps' checklist from task 10060.
```

### Comments

```bash
# View comments on a task
/clickup Show comments on task 10060.

# Add a comment
/clickup Post a comment on task 10060: deployment complete.

# Update a comment
/clickup Update comment 456: revised timeline.

# Delete a comment
/clickup Delete comment 456.
```

### Attachments

```bash
# Upload a file to a task (max 1 GB)
/clickup Upload screenshot.png to task 10060.
```

### Filtered task listing

Query tasks with filters instead of getting everything:

```bash
# By status
/clickup List 'in progress' tasks in list 12345.

# By assignee
/clickup List tasks assigned to John in list 12345.

# By tag
/clickup List tasks tagged 'urgent' in list 12345.

# By due date
/clickup List tasks due before 2026-04-10 in list 12345.

# Combined filters
/clickup List 'in progress' tasks assigned to John due this week in list 12345.

# Include subtasks
/clickup List tasks in list 12345 including subtasks.

# As a table
/clickup List tasks in list 12345 --format table.

# As raw JSON
/clickup List tasks in list 12345 --format json.
```

### Workspace discovery

Navigate the workspace hierarchy:

```bash
# List your workspaces
/clickup List my workspaces.

# List spaces in a workspace
/clickup List spaces in my workspace.

# List folders in a space
/clickup List folders in space 12345.

# List projects (lists) in a folder
/clickup List projects in folder 12345.

# List tasks in a project (list)
/clickup List tasks in list 12345.
```

## Output formats

| Format | What you get | Best for |
|---|---|---|
| `summary` (default) | Human-readable summary with key fields | Quick checks, single tasks |
| `table` | Markdown table: ID, Title, Status, Assignee(s), Due Date, Tags | Task listings, overviews |
| `json` | Raw API JSON response | Scripting, debugging |

```bash
# Default summary
/clickup Get task 10060.

# Table format for listings
/clickup List tasks in list 12345 --format table.

# Raw JSON
/clickup Get task 10060 --format json.
```

## ClickUp terminology

| ClickUp term | Also called | What it is |
|---|---|---|
| **Workspace** | Organization | Top-level account |
| **Space** | Team area | Grouping within a workspace |
| **Folder** | Project group | Grouping within a space |
| **List** | Project | Container for tasks |
| **Task** | Work item | Individual piece of work |

In the API, "Workspace" is called "team" -- the skill handles this mapping automatically.

## Config structure

### Global config

Stored at `~/.claude/config/clickup/config.json`. Contains tokens and workspace definitions.

```json
{
  "default_token": "tok_1",
  "default_workspace": "ws_1",
  "tokens": {
    "tok_1": { "name": "Devinium", "token": "pk_..." }
  },
  "workspaces": {
    "ws_1": { "name": "Devinium", "team_id": "9003069448", "custom_id_prefix": "ID-" }
  }
}
```

### Project config (optional)

Stored at `<project-root>/.clickup/config.json`. Binds a project to a workspace without storing tokens.

```json
{
  "workspace_name": "Devinium",
  "custom_id_prefix": "ID-"
}
```

**Resolution priority:** explicit `--workspace`/`--token` flags > project config > global defaults.

### Migration

If you're coming from Cursor, the skill auto-detects the old config at `~/.cursor/skills/clickup/.config.json` and offers to migrate it.

## Custom ID prefixes

ClickUp supports custom task ID prefixes (e.g., `ID-10060` instead of `abc123xyz`). The skill handles this automatically:

- If a workspace has a `custom_id_prefix`, it's prepended to task IDs in API calls
- Use `--detect-prefix` to auto-detect the prefix from your workspace
- Override per-project in `.clickup/config.json`

## Error handling

| Error | Meaning | What happens |
|---|---|---|
| **401** | Token invalid | Reports which token (by name) failed |
| **404** | Entity not found | Asks to verify ID and custom ID prefix |
| **429** | Rate limited (100 req/min) | Exponential backoff: 1s, 2s, 4s, up to 3 retries. Uses `Retry-After` header if present. |
| **GBUSED_005** | Storage limit exceeded | Reports attachment upload failure |
| **OAUTH_027** | Team ID incorrect or no access | Asks to verify team ID and token permissions |
| **Network error** | Connection failed | Retries once after 2s, then reports failure |

For batch operations, rate limits pause the batch, retry the failed task, then continue. Each task reports individually.

## Examples

### Setup and configuration

```bash
# First-time setup
/clickup --add-token
/clickup --add-workspace

# Project binding
/clickup --init-project

# Auto-detect prefix
/clickup --detect-prefix

# List and switch
/clickup --list-tokens
/clickup --list-workspaces
/clickup --set-default-token Personal
/clickup --set-default-workspace Devinium
```

### Daily task management

```bash
# Check your tasks
/clickup List tasks assigned to me in list 12345.

# Start working on something
/clickup Set task 10060 status to 'in progress'.
/clickup Start timer on task 10060.

# Add a progress update
/clickup Post a comment on task 10060: finished API integration, starting tests.

# Stop timer and log time
/clickup Stop timer on task 10060.

# Mark done
/clickup Set task 10060 status to 'done'.
```

### Sprint management

```bash
# Tag all sprint tasks
/clickup Add tag 'sprint-12' to tasks 10060,10061,10062,10063.

# List what's in progress
/clickup List 'in progress' tasks tagged 'sprint-12' in list 12345 --format table.

# Bulk close completed items
/clickup Set tasks 10060,10061 status to 'done'.

# Check what's overdue
/clickup List tasks due before 2026-04-03 in list 12345 --format table.
```

### Creating structured work

```bash
# Create a task with subtasks
/clickup Create a task called 'Deploy v2.1' in list 12345.
/clickup Create a subtask under task 10061 called 'Run tests'.
/clickup Create a subtask under task 10061 called 'Tag release'.
/clickup Create a subtask under task 10061 called 'Deploy to staging'.

# Add a checklist
/clickup Add a checklist called 'Verification' to task 10061.
/clickup Add item 'Smoke test passed' to checklist on task 10061.
/clickup Add item 'Monitoring confirmed' to checklist on task 10061.
```

### Time tracking

```bash
# Log time after a session
/clickup Log 2h 30m on task 10060: implemented auth flow.

# Start/stop timer workflow
/clickup Start timer on task 10060.
# ... do work ...
/clickup Stop timer on task 10060.

# Review time spent
/clickup Show time tracked on task 10060.
```

### Filtered views

```bash
# What's assigned to me and in progress
/clickup List 'in progress' tasks assigned to me in list 12345.

# Upcoming deadlines
/clickup List tasks due before 2026-04-10 in list 12345 --format table.

# Everything tagged urgent
/clickup List tasks tagged 'urgent' in list 12345 --format table.

# All tasks including subtasks, as raw JSON
/clickup List tasks in list 12345 --include-subtasks --format json.

# Open tasks assigned to a specific person
/clickup List 'to do' tasks assigned to Jane in list 12345.
```

### Using with different workspaces

```bash
# One-off command with a different workspace
/clickup --workspace Personal Get task 5001.

# Use a specific token
/clickup --token Work List tasks in list 12345.

# Combine both
/clickup --workspace Devinium --token Work Get task 10060.
```
