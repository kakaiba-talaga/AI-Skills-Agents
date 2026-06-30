Interact with ClickUp via the REST API. Arguments: $ARGUMENTS

Parse the arguments as follows:

- If `--task <id>` is present, target that task ID.
- If `--tasks <id1,id2,...>` is present, target multiple task IDs for batch operations (comma-separated). Supported batch actions: status update, add comment, add/remove assignees, add/remove tags. Execute sequentially with automatic retry on rate limits. Report per-task success/failure.
- If `--search "<text>"` is present, search for tasks by title (partial, case-insensitive) in a list. Ask the user which list (project) to search if not obvious.
- If `--comment "<text>"` is present, add a comment with that text to the target task(s).
- If `--filter` is present with a task listing command, apply query parameter filters. Supported filters: `--status "<status>"`, `--assignee "<name or id>"`, `--tag "<tag>"`, `--due-before "<date>"`, `--due-after "<date>"`, `--include-subtasks`. Filters map to ClickUp API query params on `GET /list/{id}/task`. Multiple filters can be combined.
- If `--format <type>` is present, control output format: `summary` (default -- human-readable summary), `table` (tabular format for task lists), `json` (raw JSON from API). For task listings, `table` shows: ID, Title, Status, Assignee(s), Due Date, Tags.
- If `--token <name>` is present, use that named token instead of the default.
- If `--workspace <name>` is present, use that named workspace instead of the default.
- If `--add-token` is present, add a new API token interactively.
- If `--add-workspace` is present, add a new workspace interactively. If the user does not know the custom ID prefix, auto-detect it.
- If `--detect-prefix` is present, auto-detect and update the custom ID prefix for the default workspace (or the one specified by `--workspace`).
- If `--init-project` is present, set up a project-specific ClickUp config (`.clickup/config.json`) that binds the current project to a workspace. List available workspaces, ask which to associate, optionally override the prefix, write the file, and offer to add `.clickup/` to `.gitignore` — but only if `git check-ignore -q .clickup/` exits non-zero (genuinely unignored); if it exits `0`, the path is already ignored (possibly via a catch-all) and no offer or append should be made — but do inform the user that `.clickup/` is already covered by `.gitignore` so the interactive flow does not go silent.
- If `--list-tokens` is present, list all stored tokens (names and IDs only, never values).
- If `--list-workspaces` is present, list all configured workspaces.
- If `--set-default-token <name>` is present, set the default token.
- If `--set-default-workspace <name>` is present, set the default workspace.
- If `--help` is present, show the quick reference below. Do not execute any API calls.

```text
ClickUp Skill -- Quick Reference
=================================

TASK OPERATIONS
  Get task details          "Get ClickUp task 10060."
  Create a task             "Create a ClickUp task called 'Fix login bug' in list 12345."
  Create a subtask          "Create a subtask under task 10060 called 'Write tests'."
  Update a task             "Set ClickUp task 10060 status to 'in progress'."
  Delete a task             "Delete ClickUp task 10060."
  Search by title           "Find ClickUp tasks matching 'Caddy migration'."

BATCH OPERATIONS
  Bulk status update        "Set tasks 10060,10061,10062 status to 'done'."
  Bulk comment              "Post comment on tasks 10060,10061: sprint complete."

ASSIGNEES
  Assign user               "Assign John to ClickUp task 10060."
  Unassign user             "Remove Jane from ClickUp task 10060."
  Bulk assign               "Assign John to tasks 10060,10061,10062."

DUE DATES & SCHEDULING
  Set due date              "Set ClickUp task 10060 due date to 2026-04-10."
  Set start date            "Set ClickUp task 10060 start date to 2026-04-05."
  Set time estimate         "Set ClickUp task 10060 time estimate to 4h."
  Clear due date            "Clear due date on ClickUp task 10060."

TAGS
  Add tag                   "Add tag 'urgent' to ClickUp task 10060."
  Remove tag                "Remove tag 'wontfix' from ClickUp task 10060."
  Bulk tag                  "Add tag 'sprint-12' to tasks 10060,10061,10062."

TIME TRACKING
  Start timer               "Start timer on ClickUp task 10060."
  Stop timer                "Stop timer on ClickUp task 10060."
  Log time                  "Log 2h 30m on ClickUp task 10060."
  View time entries         "Show time tracked on ClickUp task 10060."

SUBTASKS
  Create subtask            "Create a subtask under task 10060 called 'Write tests'."
  List subtasks             "List subtasks of ClickUp task 10060."

CHECKLISTS
  Add checklist             "Add a checklist called 'Deploy steps' to ClickUp task 10060."
  Add checklist item        "Add item 'Run tests' to checklist on ClickUp task 10060."
  Mark item resolved        "Mark checklist item 'Run tests' as resolved."
  Delete checklist          "Remove the 'Deploy steps' checklist from ClickUp task 10060."

COMMENTS
  View comments             "Show comments on ClickUp task 10060."
  Add comment               "Post a comment on ClickUp task 10060: deployment complete."
  Update comment            "Update ClickUp comment 456: revised timeline."
  Delete comment            "Delete ClickUp comment 456."

ATTACHMENTS
  Upload file               "Upload screenshot.png to ClickUp task 10060."

FILTERED TASK LISTING
  By status                 "List 'in progress' tasks in ClickUp list 12345."
  By assignee               "List tasks assigned to John in list 12345."
  By tag                    "List tasks tagged 'urgent' in list 12345."
  By due date               "List tasks due before 2026-04-10 in list 12345."
  Combined                  "List 'in progress' tasks assigned to me due this week."
  With subtasks             "List tasks in list 12345 including subtasks."
  As table                  "List tasks in list 12345 --format table."

WORKSPACE DISCOVERY
  List workspaces           "List my ClickUp workspaces."
  List spaces               "List spaces in my ClickUp workspace."
  List folders              "List folders in ClickUp space 12345."
  List projects (lists)     "List projects in ClickUp folder 12345."
  List tasks in project     "List tasks in ClickUp list 12345."

TOKEN MANAGEMENT
  Add token                 "Add a new ClickUp token called 'Work'."
  List tokens               "List my ClickUp tokens."
  Switch default token      "Set my default ClickUp token to Personal."
  Remove token              "Remove the Work ClickUp token."

WORKSPACE MANAGEMENT
  Add workspace             "Add ClickUp workspace 'Devinium'."
  List workspaces           "List my configured ClickUp workspaces."
  Switch default workspace  "Set my default ClickUp workspace to Devinium."
  Detect prefix             "Detect the custom ID prefix for workspace Devinium."
  Update prefix             "Update the prefix for workspace Devinium to ID-."
  Remove workspace          "Remove the Devinium ClickUp workspace."

PROJECT SETUP
  Init project config       /clickup --init-project

OUTPUT FORMAT
  Summary (default)         Human-readable summary
  Table                     --format table (ID, Title, Status, Assignee, Due, Tags)
  JSON                      --format json (raw API response)

TERMINOLOGY
  Workspace = Organization    Space = Team area
  Folder    = Project group   List  = Project
  Task      = Work item

Type "ClickUp help" anytime to see this again.
```

- If no arguments are given, ask the user what they need.

## Workflow

1. **Check prerequisites**: Verify `curl` and `jq` are available. If `jq` is missing, ask the user whether to install automatically (`winget install jqlang.jq` on Windows, `brew install jq` on macOS, `sudo apt-get install -y jq` on Ubuntu) or manually. Skip on subsequent invocations once confirmed.

2. **Resolve the token** from `~/.claude/config/clickup/config.json` (**never** from environment variables — do not check `$CLICKUP_API_TOKEN` or `printenv`; the config file is the only token source):

   - **Migration**: If the global config does not exist but `~/.cursor/skills/clickup/.config.json` does (pre-v1.5 Cursor location), offer to copy it to `~/.claude/config/clickup/config.json`.
   - If the file does not exist (and no old config to migrate): first check for a **project config** at `<project-root>/.clickup/config.json`. If found, inform the user that this project expects workspace **{workspace_name}** and pre-fill the workspace name (and prefix if present). Then ask for a token **name** and **API token**, confirm the workspace **name**, and ask for the **team ID**. For the **custom ID prefix**, ask the user or auto-detect it. Write config to `~/.claude/config/clickup/config.json`, ensuring the workspace name matches the project config.
   - If `--token <name>` was provided, match by name (case-insensitive) or internal ID.
   - Otherwise, use the `default_token`.
   - **Token extraction must be a separate Bash call.** Read the token in its own Bash invocation (e.g., `jq -r '...' ~/.claude/config/clickup/config.json`), then store the value internally. In all subsequent `curl` calls, inline the literal token value in the `-H "Authorization: ..."` header. **Never** prefix a `curl` command with a variable assignment like `CLICKUP_TOKEN=$(...) curl ...` — this changes the first word of the command from `curl` to a variable assignment, which breaks `Bash(curl:*)` permission matching and causes the user to be prompted for every single API call.
   - **Never display or log token values.**
   - **Note on code examples below:** All examples use `$CLICKUP_TOKEN` as a placeholder for the literal token value. When emitting actual Bash calls, substitute the real token string directly — do **not** use `$CLICKUP_TOKEN` as a shell variable.

3. **Resolve the workspace**:

   - If `--workspace <name>` was provided, match by name or internal ID in the global config.
   - Otherwise, check for a **project config** at `<project-root>/.clickup/config.json`. If it exists and has a `workspace_name`, match that name against the global `workspaces` (case-insensitive). If it also has a `custom_id_prefix`, use it instead of the global workspace's prefix.
   - Otherwise, use `default_workspace` from the global config.
   - The resolved workspace provides `team_id` and `custom_id_prefix` for API calls.

4. **Handle management commands** if `--add-token`, `--add-workspace`, `--detect-prefix`, `--init-project`, `--list-tokens`, `--list-workspaces`, `--set-default-token`, or `--set-default-workspace` was provided.

5. **Resolve task**: If `--task <id>` was provided and the workspace has a non-empty `custom_id_prefix`, prepend it to form the full custom ID. If the prefix is empty, use the ID as-is with the standard endpoint.

   If `--search` was provided, fetch tasks from a list and filter by name:

   ```bash
   curl -s -H "Authorization: $CLICKUP_TOKEN" \
     "https://api.clickup.com/api/v2/list/{list_id}/task" \
     | jq '[.tasks[] | select(.name | test("SEARCH_TERM"; "i")) | {id, name, status: .status.status}]'
   ```

   ClickUp terminology: Workspace (organization) > Space (team area) > Folder (project group) > List (project) > Task (work item). API v2 calls "Workspace" a "team".

6. **Execute the API call**:

   Base URL: `https://api.clickup.com/api/v2`

   For custom task IDs (non-empty prefix), append `?custom_task_ids=true&team_id={team_id}`. If the prefix is empty, use standard endpoints.

   Headers: `-H "Authorization: $CLICKUP_TOKEN" -H "Content-Type: application/json; charset=utf-8"`

   **Encoding safety (Windows):** On Windows (Git Bash/MSYS2), passing non-ASCII characters (em dashes, curly quotes, etc.) directly in `curl -d '...'` shell arguments can corrupt multi-byte UTF-8 sequences. To avoid this:
   - For any payload containing non-ASCII text, write the JSON to a temp file first using the Write tool, then use `curl -d @/path/to/payload.json`. This bypasses shell encoding issues.
   - Alternatively, sanitize non-ASCII before sending: replace `—` with `--`, `'` `'` with `'`, `"` `"` with `"`, etc.
   - For simple ASCII-only payloads, inline `-d '{"name":"..."}` is fine.

   - **Get task**: `curl -s -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/task/{custom_task_id}?custom_task_ids=true&team_id={team_id}" | jq .`
   - **Add comment (plain text)**: `curl -s -X POST -H "Authorization: $CLICKUP_TOKEN" -H "Content-Type: application/json" -d '{"comment_text":"TEXT","notify_all":false}' "https://api.clickup.com/api/v2/task/{custom_task_id}/comment?custom_task_ids=true&team_id={team_id}" | jq .`
   - **Add comment (formatted)**: Use the `comment` array field (not `comment_text`) with ClickUp's block-based rich text format. Write the JSON payload to a temp file and use `curl -d @file`. Format reference:
     - **Bold**: `{"text": "bold", "attributes": {"bold": true}}`
     - **Italic**: `{"text": "italic", "attributes": {"italic": true}}`
     - **Inline code**: `{"text": "code", "attributes": {"code": true}}`
     - **Strikethrough**: `{"text": "struck", "attributes": {"strike": true}}`
     - **Bullet list**: item text followed by `{"text": "\n", "attributes": {"list": {"list": "bullet"}}}`
     - **Ordered list**: item text followed by `{"text": "\n", "attributes": {"list": {"list": "ordered"}}}`
     - **Code block**: code line followed by `{"text": "\n", "attributes": {"code-block": true}}`
     - **Plain newline**: `{"text": "\n"}`
     - **Headings**: Use bold text on its own line (no native heading support in comments)
     - URLs in text are auto-linked by ClickUp.
     Example: `{"comment": [{"text": "Title", "attributes": {"bold": true}}, {"text": "\n"}, {"text": "Item one"}, {"text": "\n", "attributes": {"list": {"list": "bullet"}}}], "notify_all": false}`
     **When to use formatted vs plain**: Always prefer formatted (`comment` array) when the source content has structure (lists, bold, code). Use plain `comment_text` only for simple one-line messages. When converting from markdown source, map: `**bold**` -> bold attribute, `*italic*` -> italic attribute, `` `code` `` -> code attribute, `- item` -> bullet list, `1. item` -> ordered list, fenced code blocks -> code-block attribute.
   - **Create task**: `curl -s -X POST -H "Authorization: $CLICKUP_TOKEN" -H "Content-Type: application/json" -d '{"name":"Name","priority":3,"status":"to do"}' "https://api.clickup.com/api/v2/list/{list_id}/task" | jq .` (priority: 1=Urgent, 2=High, 3=Normal, 4=Low)
   - **Update task**: `curl -s -X PUT -H "Authorization: $CLICKUP_TOKEN" -H "Content-Type: application/json" -d '{"status":"in progress"}' "https://api.clickup.com/api/v2/task/{custom_task_id}?custom_task_ids=true&team_id={team_id}" | jq .`
   - **Delete task**: `curl -s -X DELETE -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/task/{custom_task_id}?custom_task_ids=true&team_id={team_id}"`
   - **Create checklist**: `curl -s -X POST -H "Authorization: $CLICKUP_TOKEN" -H "Content-Type: application/json" -d '{"name":"Checklist name"}' "https://api.clickup.com/api/v2/task/{custom_task_id}/checklist?custom_task_ids=true&team_id={team_id}" | jq .`
   - **Create checklist item**: `curl -s -X POST -H "Authorization: $CLICKUP_TOKEN" -H "Content-Type: application/json" -d '{"name":"Item text"}' "https://api.clickup.com/api/v2/checklist/{checklist_id}/checklist_item" | jq .`
   - **Update checklist item** (resolve/rename): `curl -s -X PUT -H "Authorization: $CLICKUP_TOKEN" -H "Content-Type: application/json" -d '{"resolved":true}' "https://api.clickup.com/api/v2/checklist/{checklist_id}/checklist_item/{checklist_item_id}" | jq .`
   - **Delete checklist**: `curl -s -X DELETE -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/checklist/{checklist_id}"`
   - **Get comments**: `curl -s -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/task/{custom_task_id}/comment?custom_task_ids=true&team_id={team_id}" | jq .`
   - **Update comment**: `curl -s -X PUT -H "Authorization: $CLICKUP_TOKEN" -H "Content-Type: application/json" -d '{"comment_text":"Updated"}' "https://api.clickup.com/api/v2/comment/{comment_id}" | jq .`
   - **Delete comment**: `curl -s -X DELETE -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/comment/{comment_id}"`
   - **Upload attachment**: `curl -s -X POST -H "Authorization: $CLICKUP_TOKEN" -F "attachment=@/path/to/file.png" "https://api.clickup.com/api/v2/task/{custom_task_id}/attachment?custom_task_ids=true&team_id={team_id}" | jq .` (max 1 GB; omit Content-Type)
   - **Assign user**: `curl -s -X PUT ... -d '{"assignees":{"add":[USER_ID]}}' ".../task/{id}..."` — resolve user names to IDs via `GET /team/{team_id}/member`. Remove with `{"assignees":{"rem":[USER_ID]}}`.
   - **Set due date**: `curl -s -X PUT ... -d '{"due_date":EPOCH_MS,"due_date_time":true}' ".../task/{id}..."` — convert human dates (e.g., `2026-04-10`) to Unix epoch milliseconds. Clear with `{"due_date":null}`. Start date uses `start_date` field similarly.
   - **Set time estimate**: `curl -s -X PUT ... -d '{"time_estimate":MILLISECONDS}' ".../task/{id}..."` — convert human durations (e.g., `4h`, `2h 30m`) to milliseconds.
   - **Add tag**: `curl -s -X POST -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/task/{custom_task_id}/tag/{tag_name}?custom_task_ids=true&team_id={team_id}"` — tag names are URL-encoded, lowercase.
   - **Remove tag**: `curl -s -X DELETE -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/task/{custom_task_id}/tag/{tag_name}?custom_task_ids=true&team_id={team_id}"`
   - **Create subtask**: Same as create task but include `"parent":"{parent_task_id}"` in the body. The parent must be a native task ID (not custom ID); resolve custom IDs first via GET task.
   - **List subtasks**: GET the parent task and read its `subtasks` array, or use `GET /list/{list_id}/task?subtasks=true` to include subtasks in listing.
   - **Log time**: `curl -s -X POST -H "Authorization: $CLICKUP_TOKEN" -H "Content-Type: application/json" -d '{"duration":MILLISECONDS,"description":"optional note"}' "https://api.clickup.com/api/v2/task/{custom_task_id}/time?custom_task_ids=true&team_id={team_id}" | jq .` — convert human durations to milliseconds.
   - **Get time entries**: `curl -s -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/task/{custom_task_id}/time?custom_task_ids=true&team_id={team_id}" | jq .`
   - **Start timer**: `curl -s -X POST -H "Authorization: $CLICKUP_TOKEN" -H "Content-Type: application/json" -d '{"tid":"{task_id}"}' "https://api.clickup.com/api/v2/team/{team_id}/time_entries/start" | jq .`
   - **Stop timer**: `curl -s -X POST -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/team/{team_id}/time_entries/stop" | jq .`
   - **List tasks with filters**: `GET /list/{list_id}/task?statuses[]=STATUS&assignees[]=USER_ID&tags[]=TAG&due_date_gt=EPOCH&due_date_lt=EPOCH&subtasks=true&include_closed=true` — map `--filter` flags to these query params. Dates converted to epoch ms.
   - **Workspace discovery**: `GET /team`, `GET /team/{team_id}/space`, `GET /space/{space_id}/folder`, `GET /folder/{folder_id}/list`, `GET /list/{list_id}/task`

   **Batch operations**: When `--tasks` provides multiple IDs, iterate through each task ID and execute the operation sequentially. Apply rate-limit-aware pacing (see error handling). Report results per task: `Task {id}: OK` or `Task {id}: FAILED ({reason})`. If a 429 is hit mid-batch, pause and retry that task before continuing.

7. **Present the result** using the format specified by `--format`:
   - `summary` (default): human-readable summary with key fields highlighted.
   - `table`: for task listings, render as a markdown table with columns: ID, Title, Status, Assignee(s), Due Date, Tags. For single-task results, fall back to summary.
   - `json`: raw JSON from the API response, piped through `jq .` for formatting.

## Error handling

- **401**: Token invalid. Tell user which token (by name) failed.
- **404**: Entity not found. Verify ID and custom ID prefix with user.
- **429**: Rate limited (100 req/min). Use exponential backoff: wait 1s, then 2s, then 4s, up to 3 retries. If the response includes a `Retry-After` header or `X-RateLimit-Reset`, use that value instead. For batch operations, pause the batch on 429, retry the failed task, then continue. Report to the user: "Rate limited, retrying in Ns..."
- **GBUSED_005**: Workspace storage limit exceeded (attachments).
- **OAUTH_027**: Team ID incorrect or token lacks access. Verify both.
- **Network errors**: If `curl` fails with a connection error, retry once after 2s. If it fails again, report the error and stop.
- No compound Bash commands — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls instead — use parallel calls for independent commands.
- No `cd` prefix — the working directory is already the project root. Run commands directly instead of `cd "/path/to/project" && command`.
- Use relative paths from the project root — never use absolute paths in Bash commands. Use `.venv/3.11/Scripts/python.exe`, `data/output/`, etc. Only use absolute paths for resources genuinely outside the project (e.g., `~/.claude/`).
- Temporary files go in the **project root** (e.g., `_tmp_test.py`, `_tmp_payload.json`) — never in `/tmp/`, `%TEMP%`, or any path outside the project. Paths outside the project trigger sensitive-file prompts. Use the `_tmp_` prefix. Do not delete individually — clean up in batch at checkpoints with `rm _tmp_*`.

## Output tagging

**`ClickUp`** appears on the **opening line** of each assistant turn only. Do **not** prefix every bullet or heading in the same turn.

The **first line** of each assistant turn for this command MUST begin with: **`ClickUp`**

Continuation lines within the same turn (sub-items, indented details, bullet lists, tables) do NOT repeat the badge. Only the opening line carries it.

Apply the badge on the opening line of turns that contain: result summaries, status/progress messages, error messages, confirmations, and structured data presentations.

**Format:** **`ClickUp`** (bold backtick-wrapped) as the **first element** on the **opening line** of the turn.

## Config file format

**Global config** — `~/.claude/config/clickup/config.json` (tokens live only here):

```json
{
  "default_token": "tok_1",
  "default_workspace": "ws_1",
  "next_token_id": 2,
  "next_workspace_id": 2,
  "tokens": {
    "tok_1": { "name": "Devinium", "token": "pk_..." }
  },
  "workspaces": {
    "ws_1": { "name": "Devinium", "team_id": "9003069448", "custom_id_prefix": "ID-" }
  }
}
```

**Project config** (optional) — `<project-root>/.clickup/config.json` (never contains tokens):

```json
{
  "workspace_name": "Devinium",
  "custom_id_prefix": "ID-"
}
```

Resolution: explicit `--workspace`/`--token` > project config > global defaults.
