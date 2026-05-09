Harness-portable memory layer with subcommands for init / save / recall / list / forget / search / audit / doctor. Memories live in ~/.cross-memory/ and mirror to harness-native locations where applicable. Arguments: $ARGUMENTS

Parse the arguments as follows:

- The first token after `/cross-memory` is the **subcommand**. Accepted values: `init`, `save`, `recall`, `list`, `forget`, `search`, `audit`, `doctor`. Any other first token is an error: emit `unknown subcommand: '<token>'. Valid subcommands: init, save, recall, list, forget, search, audit, doctor.` and stop.
- `help` — emit the structured usage block below, then stop. No hint is appended (regardless of canonical-store or sentinel-block state).
- Remaining tokens are parsed per the subcommand's `### Command syntax` section below.

Default behavior when no subcommand is given: run the bare-invocation sequence described below.

### Structured usage block

Used by both `help` and bare invocation:

```
usage: /cross-memory <subcommand> [flags]

Subcommands:
  init     Bootstrap ~/.cross-memory/ and the harness sentinel block
  save     Persist a memory (parse → redact → confirm → write)
  recall   Retrieve memories by topic
  list     Enumerate memories with one-line summaries
  forget   Archive a memory (no hard delete)
  search   Grep-style full-text search over memory bodies
  audit    Scan for staleness, duplicates, contradictions, redaction misses
  doctor   Read-only structural and integration health check

Run /cross-memory <subcommand> --help for per-subcommand details.
```

### Bare-invocation sequence

When invoked with no subcommand, the skill:

1. **Runs the probe (read-only, synchronous).** Determine the active harness via the precedence chain in `## Adapter selection`. Then:
   - Check whether `~/.cross-memory/` exists (directory-existence check).
   - On Claude-Code-class harnesses (where `update_sentinel_block` is real at v1): additionally read the harness-native `MEMORY.md` once to count sentinel markers and inspect the bytes between them.
   - On Cursor-class and generic harnesses (where `update_sentinel_block` is a documented no-op at v1): skip the sentinel-block read. The sentinel-block predicate is suppressed for these harnesses so the hint does not fire on every invocation after a successful init.
   - The probe makes no writes, no network calls, and no state changes.

2. **Emits the structured usage block** (same block as `help`).

3. **Conditionally appends the first-run hint** after the usage block, in the same response:
   - **Under Claude-Code-class harnesses:** emit the hint if `~/.cross-memory/` is absent **or** if the active harness's sentinel block is missing or empty.
     - Hint text: `Tip: run /cross-memory init to bootstrap this project.`
   - **Under Cursor-class and generic harnesses:** emit the hint only if `~/.cross-memory/` is absent (sentinel-block predicate suppressed).
     - Hint text: `Tip: run /cross-memory init to bootstrap (Cursor injection surface deferred to post-v1).`
   - If neither condition applies (canonical store exists and — where applicable — the sentinel block is populated), the hint is suppressed.

4. **Stops.** The skill never auto-runs init from bare invocation. State changes always require an explicit subcommand.

**Probe scope:** the probe inspects only the **current** harness's sentinel block, not other harnesses' blocks. The harness is determined once at the start of step 1 and honored throughout.

## Schema validator

Every memory written through this skill is validated against the canonical frontmatter schema before any disk write occurs. Invalid files are rejected with a human-readable error message; the write is aborted and no file is created or modified.

### Required fields

| Field | Type | Allowed values | Description |
| :--- | :--- | :--- | :--- |
| `name` | string | (free text) | Human-readable title; should match the file's slug |
| `description` | string | (free text) | One-line summary of the memory's content |
| `type` | enum | see [Type enum](#type-enum) below | Origin-based classification of the memory |
| `scope` | enum pattern | see [Scope enum](#scope-enum) below | Defines visibility and storage location |
| `tags` | array of strings | any strings; may be empty | Flat, case-insensitive tags; required but may be `[]` |
| `created_at` | ISO-8601 UTC timestamp | e.g., `2026-05-08T14:32:01Z` | Set on first write; immutable thereafter |
| `updated_at` | ISO-8601 UTC timestamp | e.g., `2026-05-08T14:32:01Z` | Refreshed on every supersede |

### Optional fields

| Field | Type | Allowed values | Description |
| :--- | :--- | :--- | :--- |
| `category` | enum | see [Category enum](#category-enum) below | Semantic classification (orthogonal to `type`) |
| `originSessionId` | string | (any session ID string) | Session ID at time of original capture |
| `redacted` | boolean | `true` \| `false` | Set to `true` if any auto-redaction rule fired on the body |
| `harness` | enum | `claude-code` \| `cursor` \| `generic` | Harness in which the memory was first saved |
| `superseded_by` | string | (filename) | Filename of the replacement; **present only on archived copies** |
| `verified_at` | ISO-8601 UTC timestamp | e.g., `2026-05-08T14:32:01Z` | Timestamp of last user-confirmed-still-accurate check |
| `mirrored_from` | string | (canonical filename) | Set by adapters on mirror copies only; **never present on canonical files** |
| `redaction_overridden_at` | ISO-8601 UTC timestamp | e.g., `2026-05-08T14:32:01Z` | Set when `--no-redact` was used to bypass auto-redaction |

### Default rules

- **`tags`**: defaults to `[]` (empty array) when the field is omitted from user input. The validator still **requires** the field to be present in the written frontmatter — a missing `tags` key after normalization is a rejection.
- **`category`**: absent by default. The validator does **not** insert `category: other` on write. Absence is the canonical "uncategorized" signal. At read time, missing `category` is treated as `category: other` by all filtering logic.

### Enum values

#### Type enum

Valid values for the `type` field:

| Value | Meaning |
| :--- | :--- |
| `feedback` | Feedback, corrections, or instructions the user has given |
| `project` | Project-specific facts, conventions, or status |
| `preference` | User preferences about tools, style, or workflow |
| `fact` | Objective facts or reference data to be remembered |
| `rule` | Explicit rules the agent must follow |

#### Scope enum

The `scope` field must match one of three exact patterns:

| Pattern | Example | Notes |
| :--- | :--- | :--- |
| `user-global` | `user-global` | Applies across all projects and harnesses |
| `project:<slug>` | `project:D--Repositories-Personal-Git-AI-Skills-Agents` | Slug is the harness-derived directory name; the `<slug>` portion is required |
| `harness:<name>` | `harness:claude-code` | Harness-specific scope; the `<name>` portion is required |

A bare `project` or `harness` without a colon-and-slug suffix is invalid.

#### Category enum

Valid values for the optional `category` field:

| Value | Meaning |
| :--- | :--- |
| `project-config` | Build commands, environment setup, project-level config |
| `architecture` | Design decisions, structural constraints |
| `error-solution` | Specific errors and their resolutions |
| `preference` | User preferences (semantic overlap with `type: preference` is intentional) |
| `learned-pattern` | Patterns the agent has discovered about this user or project |
| `conversation` | Conversation-derived context or agreed conclusions |
| `other` | Uncategorized; also the implicit default at read time |

### Reject behavior — literal error strings

When validation fails, the skill emits a rejection message to the chat and aborts the write. The strings below are the exact messages the validator emits for each documented failure path.

**Missing `tags` field (required array field absent after normalization):**

```
validation error: required field 'tags' missing (must be an array, may be empty)
```

**Invalid `type` value (not in the type enum):**

```
validation error: 'type' must be one of {feedback, project, preference, fact, rule}; got 'foo'
```

**Invalid `category` value (not in the category enum):**

```
validation error: 'category' must be one of {project-config, architecture, error-solution, preference, learned-pattern, conversation, other}; got 'error-soln'
```

**Invalid `scope` value (bare `project` without slug suffix):**

```
validation error: 'scope' must match user-global, project:<slug>, or harness:<name>; got 'project'
```

**Missing required field other than `tags` (e.g., `type` absent entirely):**

```
validation error: required field 'type' missing
```

---

## Config

### Config file location

Path: `~/.cross-memory/config.yaml`

Format: YAML, single document, top-level keys per the field table below.

### Fields

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `current_harness` | string | (auto-detected) | Active harness identifier: `claude-code`, `cursor`, or `generic`. Falls back to harness detection (CLI flag → config field → env var → manifest probe → generic) if absent. |
| `staleness_threshold_days` | integer | 90 | Memories with `verified_at` older than this many days are flagged stale by `recall`, the always-on tier injection block, and `audit`. |
| `max_inject_chars` | integer | 2048 | Maximum bytes for the `[CROSS-MEMORY]` injection block. When the block exceeds this budget, the formatter drops sub-sections in priority order; see the Injection block section's Size budget enforcement for the full drop protocol. |

### Lazy-provisioning sequence

When `~/.cross-memory/` is absent on first save / recall / etc., the skill provisions it before proceeding:

1. **Check** for `~/.cross-memory/` existence. If present, skip provisioning.
2. **Create the directory tree** with these six subdirectories (relative to `~/.cross-memory/`):
   - `user-global/`
   - `projects/`
   - `harnesses/claude-code/`
   - `harnesses/cursor/`
   - `harnesses/generic/`
   - `archive/`
3. **Write the default `config.yaml`** with the three fields above set to their defaults.
4. **Initialize per-scope `MEMORY.md` files** as empty index files for `user-global/`, `harnesses/claude-code/`, `harnesses/cursor/`, `harnesses/generic/`. Project-scope `MEMORY.md` files are created lazily per-project on first save (since the project slug isn't known until a save targets it).
5. **Proceed** with the original operation (save / recall / etc.).

**The deploy pipeline (`tooling/deploy.{ps1,sh}`) does NOT provision `~/.cross-memory/`.** Provisioning is runtime, triggered by the first skill invocation. This keeps deploy idempotent and store creation user-driven.

### Cross-references

When `current_harness` is absent from the config, harness detection falls back to the full precedence chain: CLI flag → config field → env var → manifest probe → generic fallback.

---

## Adapter selection

The active adapter is determined once per subcommand invocation, before any mirror operation is dispatched. The selection follows a five-step precedence chain — first match wins. Steps are evaluated in order; as soon as one step resolves to a valid harness name, evaluation stops and that harness is used.

### Step 1 — CLI flag

Syntax: `--harness <name>` where `<name>` is one of `claude-code`, `cursor`, or `generic`.

The flag is parsed at the top of every subcommand invocation, before any other precedence step is evaluated. An invalid `<name>` (any value not in the registered set `{claude-code, cursor, generic}`) fails fast with a structured error and does not fall through to the next step:

```
error: unknown harness 'foo'. Valid values: claude-code, cursor, generic
```

When valid, this flag wins unconditionally. No warning is emitted, no other signal is consulted. The user is overriding detection — the skill respects that intent without comment.

### Step 2 — Config field

File: `~/.cross-memory/config.yaml`. Field: `current_harness:` with value `claude-code`, `cursor`, or `generic`.

When the field is absent from the config, or when the config file itself does not exist, this step produces no result and evaluation falls through to Step 3.

When the field is present but its value is not in the registered set, the skill logs a structured warning and treats the field as absent — precedence falls through to Step 3 rather than failing fast:

```
warning: config field 'current_harness' has unrecognized value '<value>'; ignoring and falling through to env-var check
```

This "warn and continue" behavior is deliberate: config corruption (a typo, a manually edited file) should not break the skill. The persistent config is more authoritative than an env var — it represents a deliberate per-machine choice — which is why it is evaluated before Step 3.

### Step 3 — Environment variable

Variable: `CROSS_MEMORY_HARNESS`. Value: `claude-code`, `cursor`, or `generic`.

When the variable is unset or empty, this step produces no result and evaluation falls through to Step 4.

When the variable is set but its value is not in the registered set, the skill logs a structured warning and treats the variable as absent — precedence falls through to Step 4:

```
warning: env var CROSS_MEMORY_HARNESS has unrecognized value '<value>'; ignoring and falling through to adapter probe
```

Env vars rank below the config field because they are session-scoped and easier to typo in shell aliases or CI job definitions. A persistent config entry is a more deliberate signal of the user's intent for a given machine.

### Step 4 — Adapter manifest probe

When Steps 1–3 produce no result, the skill probes registered adapters in a fixed order to ask each one whether its detection signals match the current environment.

**Probe order:** `claude-code` first, then `cursor`. The generic adapter is **not** in the probe set — it is the Step 5 fallback and is never probed.

For each adapter in that order, the skill calls the adapter's detection function, which returns one of three outcomes:

| Outcome | Meaning | Probe continues? |
| :--- | :--- | :--- |
| `active` | The adapter's own signals match the current environment | No — this adapter is selected immediately |
| `inactive` | The adapter's signals are absent | Yes — continue to the next adapter |
| `error` | The detection function raised an exception | Yes — log a warning, treat as `inactive`, continue |

When an `error` outcome occurs, the structured warning names the adapter and the exception:

```
warning: adapter 'claude-code' detection raised an error: <exception message>. Treating as inactive; continuing probe.
```

**First-claim-wins rule.** When the Claude Code adapter returns `active`, the probe stops immediately. The Cursor adapter is never consulted — whether or not Cursor's signals would also match is irrelevant. There is no "both adapters claimed active, ask the user" state. The probe order is deterministic, and determinism is the guarantee: a user who installs both Claude Code and Cursor gets a predictable result every time, not an interactive prompt.

**Probe order rationale.** Claude Code is the primary target harness; Cursor is the secondary supported harness. Claude Code is probed first because its detection signals are more specific (the `CLAUDE_CODE_*` env-var family is less likely to be present in a non-Claude-Code environment than a generic directory probe) and because the relative usage weight favors Claude Code. The alphabetical coincidence is just that — the ordering is by priority, not by alphabet.

**Detection signals per adapter.** Each adapter's detection function checks its own set of signals. For the details of what each adapter treats as evidence of its environment being active, see the individual adapter files:

- `adapter-claude-code.md § 1` — `CLAUDE_CODE_*` env-var family (prefix test) and `~/.claude/` directory probe
- `adapter-cursor.md § 1` — `CURSOR_*` env-var family (prefix test) and `~/.cursor/` directory probe
- `adapter-generic.md § 1` — never probed; activates only as Step 5 fallback

**Detection timeout.** If an adapter's detection function takes longer than **250 ms**, the skill treats the outcome as `error` (logged as a timeout warning) and continues probing. Detection runs at session-bootstrap time, before any subcommand logic executes; a slow detection function would stall every invocation, so the timeout is enforced strictly regardless of the adapter's implementation.

**Cross-platform path probing.** The Claude Code adapter's marker-directory probe checks for `~/.claude/`. On Windows, `~` resolves to the user profile directory (e.g., `C:\Users\<username>`), so the probe looks for `C:\Users\<username>\.claude\`. Standard path expansion handles this correctly on all platforms — the same probe logic works on macOS, Linux, and Windows without platform-specific branches.

### Step 5 — Generic fallback

If Steps 1–4 all fail to select a harness, the generic adapter is used. The generic adapter requires no detection signals of its own and is always available. It is the documented behavior for environments where neither Claude Code nor Cursor is installed — sandboxed CI runners, minimal containers, or bare terminal sessions. See `adapter-generic.md § 1` for the full list of situations where the generic adapter is the right choice.

### Selection logging and observability

After selection, the skill records two pieces of information: the chosen harness name and the precedence step that selected it. This pair travels with the invocation's internal state and surfaces in two places:

- **Verbose output** — when `--verbose` is passed to any subcommand, the selection step is printed on the first output line of that invocation:

  ```
  harness: claude-code (selected via: adapter probe)
  harness: cursor (selected via: env var)
  harness: generic (selected via: generic fallback)
  ```

- **`audit` subcommand** — the selection record appears in the environment block of the audit report, so the user can see which harness was active and how it was detected during the audit run.

The step label used in both surfaces follows this vocabulary:

| Precedence step | Label in output |
| :--- | :--- |
| CLI flag | `cli flag` |
| Config field | `config field` |
| Environment variable | `env var` |
| Adapter probe | `adapter probe` |
| Generic fallback | `generic fallback` |

### Edge cases and pitfalls

**CLI flag overrides everything, including a config that disagrees.** No warning is emitted. When the user passes `--harness generic` on a machine where `~/.cross-memory/config.yaml` has `current_harness: claude-code`, the generic adapter is used for that invocation and the config is silently ignored. This is the intended behavior — explicit CLI intent beats persistent configuration.

**Adapter-specific env vars are not precedence signals.** Variables like `CLAUDE_CODE_VERSION` or `CURSOR_SESSION_ID` participate in adapter probe logic (Step 4) as detection signals within their respective adapter's detection function. They are not read by the precedence chain itself. Only `CROSS_MEMORY_HARNESS` is the Step 3 precedence signal.

**Detection function timeout at session bootstrap.** Because adapter detection runs before any subcommand logic, a hung detection function would block the entire invocation. The 250 ms timeout is enforced per-adapter. If both the Claude Code and Cursor adapters time out (each counted separately), the total overhead before reaching the generic fallback is at most 500 ms. This worst case is uncommon but worth knowing about when cross-memory is used in latency-sensitive automation.

**Config corruption falls through, not fails fast.** An invalid `current_harness` value in the config is treated as absent (warn and continue), not as a hard error. This means a corrupted config silently degrades to env-var or probe detection rather than breaking the skill. The structured warning gives the user enough information to fix the config; the skill stays usable.

### Cross-references

- **Dispatch points that consume this selection** — `## Subcommand: save → Mirror hook — standard save` and `## Subcommand: forget → Step 5 — Mirror-remove hook`.
- **Per-adapter detection signals** — `adapter-claude-code.md § 1`, `adapter-cursor.md § 1`, `adapter-generic.md § 1`.
- **Config field `current_harness`** — `## Config` above.

---

## Shared flag parsing

The following flags are accepted by `init` and `doctor` (and may appear on other subcommands where noted). They are defined once here; per-subcommand `### Command syntax` sections reference this section rather than redefining semantics.

### `--harness <claude-code|cursor|generic>`

Overrides adapter selection for the duration of the invocation. Semantics and precedence are identical to the `## Adapter selection` five-step chain: when this flag is present and valid, it wins unconditionally as Step 1 of that chain. An unrecognized value fails fast:

```
error: unknown harness 'foo'. Valid values: claude-code, cursor, generic
```

The full precedence chain (CLI flag → config field → env var → manifest probe → generic fallback) is documented in `## Adapter selection`. This flag is Step 1 of that chain — no new precedence logic is introduced here.

### `--scope <user-global|project:<slug>|harness:<name>>`

Restricts the subcommand's operation to a single scope. The accepted patterns are the same as the `scope` frontmatter field:

| Pattern | Example |
| :--- | :--- |
| `user-global` | `user-global` |
| `project:<slug>` | `project:D--Repositories-Personal-Git-AI-Skills-Agents` |
| `harness:<name>` | `harness:claude-code` |

A bare `project` or `harness` without a colon-and-slug suffix is invalid. When `--scope` is omitted, scope defaults to the subcommand's own default (documented per subcommand in `### Command syntax`).

### `--json`

Requests machine-readable output. When present, the subcommand emits its result as a JSON document to stdout instead of the default human-readable prose. The exact JSON shape is defined per subcommand in its own `### Command syntax` section. The flag is parsed at invocation time, before any subcommand logic executes; an unknown value after `--json` is not an error (the flag is boolean — it takes no argument).

### `--verbose`

Requests additional diagnostic output. When present, the harness selection step is printed on the first output line of the invocation, per `## Adapter selection → Selection logging and observability`. Subcommands may emit additional per-step detail when `--verbose` is set; this is documented per subcommand. The flag is boolean — it takes no argument.

### Cross-references

- **`--harness` precedence chain**: `## Adapter selection` above.
- **`--scope` field semantics**: `## Schema validator → Scope enum` above.
- **`--verbose` harness logging**: `## Adapter selection → Selection logging and observability` above.
- **Per-subcommand JSON shapes**: `## Subcommand: init` and `## Subcommand: doctor` below.

---

## Subcommand: init

Bootstrap `~/.cross-memory/` and register the active harness sentinel block. Init is additive only — it never deletes, overwrites, or repairs existing files.

### Command syntax

```
/cross-memory init \
  [--harness <claude-code|cursor|generic>] \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--json] \
  [--verbose]
```

No positional arguments. The flags `--harness`, `--scope`, `--json`, and `--verbose` are defined in `## Shared flag parsing` above. There is no `--repair`, `--force`, or `--reset` flag — any modification to existing files is out of scope for init.

### Step 1 — Provisioning

Invoke the lazy-provisioning sequence documented in `## Config → Lazy-provisioning sequence`. Init calls that sequence eagerly on every invocation; the same sequence that normally fires lazily on first save is executed up front.

If `~/.cross-memory/` already exists, the provisioning sequence exits at its check step (step 1 of that sequence: "If present, skip provisioning") and step 1 of init is a no-op. No directories are created, no config file is written, and no index files are touched.

Init does **not** duplicate the directory-creation or config-write logic — it delegates entirely to the documented lazy-provisioning path. The authoritative directory tree and default field values are maintained in `## Config → Lazy-provisioning sequence`; init adds no new provisioning logic of its own.

**Verbose trace (when `--verbose` is set):**

```
[init] step 1: ~/.cross-memory/ already exists; provisioning skipped
[init] step 1: ~/.cross-memory/ absent; running lazy-provisioning sequence
```

### Step 2 — Adapter detection

Run the five-step precedence chain in `## Adapter selection` (CLI flag → config field → env var → manifest probe → generic fallback) to determine the active harness. Record both the chosen harness name and the precedence step that won; both are included in the step 5 summary line (documented in a later task) and in the `harness_selection_step` field of the `--json` output.

This step makes no writes. It calls the same selection logic invoked at the start of every other subcommand.

**Verbose trace (when `--verbose` is set):**

```
[init] step 2: harness=claude-code (selected via: adapter probe)
```

The step-label vocabulary (`cli flag`, `config field`, `env var`, `adapter probe`, `generic fallback`) matches the table in `## Adapter selection → Selection logging and observability`.

### Step 3 — Reachability probe

Run two check primitives from `## Check-name vocabulary` in read-only mode:

- **`adapter-detection`** — re-runs the adapter selection chain and confirms the harness resolves consistently. Any divergence between this result and step 2's result is a structured warning.
- **`sentinel-marker-count`** — reads the active project's harness-native `MEMORY.md` (if reachable) and verifies exactly one begin-marker and one end-marker are present.

The probe target is harness-specific:

| Harness | Reachability target | slug derivation |
| :--- | :--- | :--- |
| `claude-code` | `~/.claude/projects/<slug>/memory/` | slug derived from the current project's canonical path; same derivation as the save and recall paths |
| `cursor` | `~/.cursor/projects/<slug>/memory/` | same slug-derivation logic applied to the Cursor project path |
| `generic` | *(no target)* | step 3 is a no-op for the generic harness |

For the `claude-code` and `cursor` harnesses, the probe verifies two things in order:

1. The `memory/` directory at the harness path is reachable (directory-existence check).
2. The active project's `MEMORY.md` within that directory is reachable (file-existence check).

**Failure isolation.** A failed reachability check produces a structured warning and continues. The canonical store provisioned in step 1 is not rolled back. The warning is recorded in the invocation's warning list, which step 5 will include in the summary output. The summary line will report `harness target: unreachable` so the user knows the sentinel block in step 4 will be skipped (that skip behavior is documented in the step 4 task). Check identifiers match the vocabulary in `## Check-name vocabulary` — do not invent new names.

**Verbose trace (when `--verbose` is set):**

```
[init] step 3: harness target ~/.claude/projects/<slug>/memory/ reachable
[init] step 3: harness target unreachable; warning recorded, continuing
[init] step 3: generic harness; reachability probe skipped
```

### Step 4 — Always-on filter + sentinel write

**Sequencing rule.** The five init steps are sequential, but a warning at step 3 does not abort the sequence. The always-on filter runs regardless of step 3's outcome. The sentinel-block write is skipped only when the adapter has nothing to write to (unreachable harness target or cursor no-op). The step 5 summary still prints in all cases.

**What step 4 does:**

1. Invoke the always-on tier filter (see `## Always-on tier`) to produce the ordered entry list for the current session. The filter is harness-agnostic — it reads the three canonical scope index files and applies the four entry-selection rules regardless of which adapter is active.
2. Pass the filter's output list to the injection-block formatter (see `## Injection block`) to produce the `[CROSS-MEMORY]` content bytes. The formatter renders the `User Profile:`, `Project Knowledge:`, and `Relevant Memories:` sub-sections, applies the `max_inject_chars` size budget, and returns the bytes that will be placed between the sentinel markers. It does not emit the markers themselves.
3. Dispatch `active_adapter.update_sentinel_block(content)` with those bytes. The call shape is identical to the dispatch used in the save and forget flows (see `## Subcommand: save → Mirror hook — standard save` and `adapter-claude-code.md § 6`).

After the write, init runs `sentinel-region-content-parses` (from `## Check-name vocabulary` Group C) as a self-check to confirm the bytes just written parse as a valid `[CROSS-MEMORY]` injection block. If this check reports `fail`, init fails fast and emits a structured violation report before step 5.

**Per-harness behavior:**

| Harness | Sentinel write | Self-check result |
| :--- | :--- | :--- |
| `claude-code` | `update_sentinel_block(content)` writes the populated `[CROSS-MEMORY]` block into the harness-native `MEMORY.md` sentinel region at `~/.claude/projects/<slug>/memory/MEMORY.md` | `sentinel-region-content-parses` returns `pass` or `fail` |
| `cursor` | `update_sentinel_block` is a documented no-op at v1 (`adapter-cursor.md § 6`). The always-on filter still runs and the summary still prints, but no sentinel-block bytes are written. The summary line reports `sentinel=skipped (cursor adapter no-op at v1)`. | `sentinel-region-content-parses` returns `not-applicable` (see `## Check-name vocabulary` Group C — `not-applicable` means the check does not apply on this harness surface rather than pass or fail) |
| `generic` | Same no-op as cursor — no sentinel surface exists | `sentinel-region-content-parses` returns `not-applicable` |

**Failure-isolation rule.** When step 3 recorded a reachability warning (harness target unreachable), step 4 skips the `update_sentinel_block` dispatch entirely and does not run the `sentinel-region-content-parses` self-check. The always-on filter and injection-block formatter still run — their output is retained for the step 5 summary's `always-on entries` count. The canonical store provisioned in step 1 is not affected. The step 5 summary reports `sentinel=skipped (harness target unreachable)`.

**Implementation note.** On a fresh `~/.cross-memory/` with no user-global memories, the always-on filter produces an empty entry list. The injection-block formatter returns empty bytes (no sub-sections, no header content). Init writes those empty bytes between the sentinel markers — the markers themselves are still written. Step 5 reports `0 always-on entries`. This is a successful empty write, not a failure. The `sentinel-region-content-parses` self-check treats an empty-but-structurally-valid block as `pass`.

**Verbose trace (when `--verbose` is set):**

```
[init] step 4: always-on filter: 3 entries selected
[init] step 4: injection-block formatter: 412 bytes
[init] step 4: sentinel block written (claude-code)
[init] step 4: self-check sentinel-region-content-parses: pass
[init] step 4: always-on filter: 0 entries selected
[init] step 4: injection-block formatter: 0 bytes (empty block)
[init] step 4: sentinel block written (claude-code, 0 bytes between markers)
[init] step 4: self-check sentinel-region-content-parses: pass
[init] step 4: sentinel write skipped (cursor adapter no-op at v1)
[init] step 4: self-check sentinel-region-content-parses: not-applicable
[init] step 4: sentinel write skipped (harness target unreachable)
```

### Step 5 — Summary output (human / JSON / verbose)

Step 5 emits the invocation result. It makes no writes; it only reads the state accumulated by steps 1–4 and formats it. The summary always prints, regardless of whether earlier steps produced warnings or skips.

#### Human-readable summary

The summary line shape is:

```
cross-memory initialized: harness=<name>, store=<state>, sentinel=<state> (<bytes>), <count> always-on entries
```

**State values:**

- `store` is one of:
  - `provisioned` — step 1 created `~/.cross-memory/` and wrote a fresh config.
  - `already-present` — step 1 found the directory already existed; nothing was created.

- `sentinel` is one of:
  - `updated (<N> bytes)` — step 4 wrote `N` bytes between the sentinel markers. `N` may be zero (see empty-write note below).
  - `already-current (no change)` — step 4 computed the same bytes as the markers already contained; no write was performed.
  - `skipped (<reason>)` — step 4 did not write. The reason string is one of:
    - `cursor adapter no-op at v1`
    - `harness target unreachable`
    - `not-applicable` (generic harness)

**Concrete examples:**

```
cross-memory initialized: harness=claude-code, store=provisioned, sentinel=updated (1843 bytes), 12 always-on entries
cross-memory initialized: harness=claude-code, store=already-present, sentinel=already-current (no change), 12 always-on entries
cross-memory initialized: harness=cursor, store=provisioned, sentinel=skipped (cursor adapter no-op at v1), 5 always-on entries
cross-memory initialized: harness=generic, store=already-present, sentinel=skipped (not-applicable), 0 always-on entries
```

**Empty-write disambiguation.** A successful init on a fresh `~/.cross-memory/` with no user-global memories produces:

```
cross-memory initialized: harness=claude-code, store=provisioned, sentinel=updated (0 bytes), 0 always-on entries
```

This is a **successful pass**. The sentinel markers were written; the region between them is intentionally empty because the always-on filter returned no entries. This is not a failure or warning condition.

#### JSON output (`--json`)

When `--json` is passed, step 5 prints a JSON object instead of the human summary line. The schema version is `1`. Keys appear in this order:

```json
{
  "schema_version": 1,
  "timestamp_utc": "2026-05-09T14:23:01Z",
  "harness": "claude-code",
  "harness_selection_step": "cli-flag",
  "active_project_slug": "ai-skills-agents",
  "store": {
    "provisioned": true,
    "path": "/home/user/.cross-memory"
  },
  "sentinel": {
    "updated": true,
    "bytes": 1843,
    "path": "/home/user/.claude/projects/ai-skills-agents/memory/MEMORY.md"
  },
  "always_on_entries": 12,
  "warnings": []
}
```

**`harness_selection_step` enum.** This field reports which step in the five-step precedence chain selected the harness. Allowed values, in precedence order:

| Value | Meaning |
| :--- | :--- |
| `cli-flag` | `--harness` flag was present on the command line |
| `config-field` | `harness` field in `~/.cross-memory/config.yaml` was set |
| `env-var` | `CROSS_MEMORY_HARNESS` environment variable was set |
| `manifest-probe` | harness was auto-detected via adapter manifest probe (step 4 of the selection chain) |
| `generic-fallback` | no prior step matched; generic adapter selected |

A user who sees `harness=generic` unexpectedly can read `harness_selection_step` to understand which detection step was the furthest the chain reached, without needing to re-run with `--verbose`.

**`warnings` array.** Each element is a structured warning object capturing a non-fatal issue from steps 3 or 4:

```json
{ "step": 3, "code": "harness-target-unreachable", "message": "~/.claude/projects/<slug>/memory/ not found" }
```

Shape: `{ step: 3 | 4, code: <string>, message: <string> }`. The `code` field uses the same identifier vocabulary as `## Check-name vocabulary`. An empty `warnings` array means all steps completed without non-fatal issues.

**Empty-write in JSON.** When the always-on filter returns zero entries and step 4 writes empty bytes, the JSON reflects this as a successful pass:

```json
{
  "sentinel": { "updated": true, "bytes": 0, "path": "..." },
  "always_on_entries": 0
}
```

`sentinel.updated: true` and `sentinel.bytes: 0` together signal a successful empty write. This is not an error; `warnings` will be empty.

**Cross-tool key note.** The fields `harness`, `harness_selection_step`, and `timestamp_utc` use the same field names and value shapes as the doctor JSON schema. Additions or renames to these three keys must be applied consistently to both subcommands.

#### Verbose mode (`--verbose`)

When `--verbose` is set, step 5 prints each step's trace on its own line, then the summary line. The full trace for a successful init looks like:

```
[init] step 1: ~/.cross-memory/ already exists; provisioning skipped
[init] step 2: harness=claude-code (selected via: cli flag)
[init] step 3: harness target reachable; sentinel markers found
[init] step 4: filter computed 12 always-on entries; sentinel block updated (1843 bytes)
[init] step 5: cross-memory initialized: harness=claude-code, store=already-present, sentinel=updated (1843 bytes), 12 always-on entries
```

The trace for a fresh install with an empty store:

```
[init] step 1: ~/.cross-memory/ absent; running lazy-provisioning sequence
[init] step 2: harness=claude-code (selected via: adapter probe)
[init] step 3: harness target reachable; sentinel markers found
[init] step 4: filter computed 0 always-on entries; sentinel block updated (0 bytes)
[init] step 5: cross-memory initialized: harness=claude-code, store=provisioned, sentinel=updated (0 bytes), 0 always-on entries
```

The step-5 trace line is identical to the human summary line, prefixed with `[init] step 5:`. When `--json` and `--verbose` are both set, the step traces still print as plain text and the final output line is the JSON object.

### Idempotency contract

Init is safe to run repeatedly with no state changes between runs. The per-step behavior is:

1. **Step 1** is a no-op if `~/.cross-memory/` already exists. The provisioning sequence exits at its own guard, no files are created or overwritten, and `store` reports `already-present` in the summary.
2. **Steps 2 and 3** are read-only. They call the adapter-selection chain and the reachability probe respectively, neither of which writes anything.
3. **Step 4** produces byte-identical sentinel-block content across runs when no canonical-store changes have occurred between them. The always-on filter draws from the same canonical memories on each run; if the filter output is unchanged, the computed bytes are unchanged, and step 4 skips the write entirely. `sentinel` reports `already-current (no change)` in the summary.
4. **Step 5** prints to chat. It has no on-disk effect. The `timestamp_utc` field emitted in the `--json` output (see `### Step 5 — Summary output (human / JSON / verbose)`) is run-scoped — it changes on every invocation. It lives only in the chat-only JSON object and does not appear inside the sentinel-bounded region; the byte-identical sentinel-content guarantee is therefore unaffected by the timestamp.

The human summary distinguishes the two idempotent-path states explicitly — `store=already-present` and `sentinel=already-current (no change)` — so a user running init defensively (e.g., after pulling a new harness config) can confirm at a glance that nothing changed unexpectedly. See `### Step 5 — Summary output (human / JSON / verbose)` for the full state vocabulary.

### What init does NOT do

- **No codebase-fact distillation.** Init makes zero LLM calls. The `--discover` flag (which would trigger an LLM-driven pass to extract project facts from the codebase) is deferred to a future release.
- **No agent dispatch.** Init runs entirely in the skill body. The cross-memory agent's lane allowlist is not touched by v1.1; init's writes are skill-side only.
- **No save.** Init does not create or modify any canonical memory file under `~/.cross-memory/`. The always-on filter reads from canonical memories but never writes to them.
- **No `--repair` or `--force`.** Bad-state diagnosis and repair are doctor's lane. Init is additive only — it provisions what is absent and leaves everything else untouched.
- **No telemetry.** Same posture as v1: no usage data, no network calls, no analytics.
- **No deploy.** Init is not invoked by `tooling/deploy.{ps1,sh}` and does not invoke them.
- **No project-scope provisioning.** The project-scope `MEMORY.md` for the active project is still created lazily on first save, exactly as today. Init does not create or write project-scope memory files.

### Reuse of doctor's check primitives

Init does not import or call doctor's checks at runtime. The shared contract is a documentation contract: any check identifier that appears in both subcommands means the **same finding** regardless of which subcommand surfaces it. The identifiers are defined in `## Check-name vocabulary`; each entry below cites the group it belongs to.

**Three reuse points:**

1. **After step 1 (provisioning).** Once the canonical store has been provisioned (or confirmed already-present), init optionally runs two Group A checks in read-only mode to confirm the freshly-provisioned store is in the expected state:
   - `canonical-archive-not-indexed` — asserts `~/.cross-memory/archive/MEMORY.md` does not exist.
   - `canonical-memory-md-consistency` — verifies each scope's `MEMORY.md` index matches the on-disk file set.
   Both are read-only probes. A failure here surfaces as a structured warning in the step 5 summary; init does not abort.

2. **Step 3 (reachability probe).** Init runs two checks from `## Check-name vocabulary` against the harness-native file:
   - `adapter-detection` (Group E) — re-runs the adapter selection chain and confirms the harness resolves consistently against the step 2 result.
   - `sentinel-marker-count` (Group C) — reads the active project's harness-native `MEMORY.md` and verifies exactly one begin-marker and one end-marker are present.
   Both are read-only. See `### Step 3 — Reachability probe` for failure-isolation and verbose-trace details.

3. **After step 4 (sentinel write).** Before printing the step 5 summary, init runs `sentinel-region-content-parses` (Group C) as a self-check against the file it just wrote, to confirm the bytes parse as a valid `[CROSS-MEMORY]` injection block. If this check reports `fail`, init fails fast and emits a structured violation report rather than proceeding to step 5. See `### Step 4 — Always-on filter + sentinel write` for the full behavior table.

**Consistency guarantee.** A sentinel-marker corruption that init reports during its step 3 probe is the same finding doctor would surface under `--check sentinel-marker-count`: both subcommands use the same check identifier from `## Check-name vocabulary`, and the identifier is the contract.

**Per-harness applicability of the step 4 self-check.** The Group C checks `sentinel-region-bytes-fingerprint` and `sentinel-region-content-parses` return `not-applicable` under the Cursor harness at v1, because `update_sentinel_block` is a documented no-op there (see `## Check-name vocabulary` Group C). Init's step 4 self-check therefore returns `not-applicable` under Cursor — and init still **succeeds**, with the skip noted in the summary line per the state vocabulary in `### Step 5 — Summary output (human / JSON / verbose)`.

### Cross-references

- **Lazy-provisioning sequence** (step 1 delegate): `## Config → Lazy-provisioning sequence` above.
- **Adapter selection chain** (step 2): `## Adapter selection` above.
- **Reachability check primitives** (step 3): `## Check-name vocabulary` (`adapter-detection` in Group E; `sentinel-marker-count` in Group C).
- **Always-on tier filter** (step 4): `## Always-on tier` above.
- **Injection-block formatter** (step 4): `## Injection block` above.
- **Sentinel write operation and call shape** (step 4): `adapter-claude-code.md § 6`; Cursor no-op: `adapter-cursor.md § 6`.
- **Step 4 self-check** (`sentinel-region-content-parses` per-harness applicability): `## Check-name vocabulary` Group C above.
- **Shared flags** (`--harness`, `--scope`, `--json`, `--verbose`): `## Shared flag parsing` above.
- **Selection logging vocabulary**: `## Adapter selection → Selection logging and observability` above.

---

## Subcommand: doctor

Read-only structural and integration health check. Doctor inspects the canonical store, sentinel blocks, redaction surface, mirror consistency, and adapter-detection state. It never writes, repairs, or auto-corrects.

### Command syntax

```
/cross-memory doctor \
  [--pre-deploy | --post-deploy] \
  [--check <name>] \
  [--harness <claude-code|cursor|generic>] \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--json] \
  [--verbose]
```

No positional arguments. The flags `--harness`, `--scope`, `--json`, and `--verbose` are defined in `## Shared flag parsing` above — their semantics are not redefined here.

### Mutual-exclusion rules

The three mode flags interact with the following constraints:

- `--pre-deploy` and `--post-deploy` are **mutually exclusive** with each other. Passing both is an error:

  ```
  error: --pre-deploy and --post-deploy are mutually exclusive
  ```

- `--check <name>` is **mutually exclusive** with both `--pre-deploy` and `--post-deploy`. Combining `--check` with either mode flag is an error:

  ```
  error: --check cannot be combined with --pre-deploy or --post-deploy
  ```

  `--check` is **repeatable**: multiple `--check name1 --check name2` arguments on a single invocation are valid and select the union of the named checks.

- An unrecognized check name passed to `--check` fails fast:

  ```
  error: unknown check name 'foo'. See ## Check-name vocabulary for valid names.
  ```

### Mode selection and default check sets

Doctor operates in one of four modes depending on which flags are present. Each mode selects a distinct set of checks to run.

#### Default mode (no flags)

When neither `--pre-deploy`, `--post-deploy`, nor `--check` is present, doctor runs a balanced read-only sweep covering the four groups most likely to surface regressions without requiring harness-side writes or cross-harness coordination.

**Default check groups:**

| Group | Checks run |
| :--- | :--- |
| Group A — `canonical-integrity` | All five checks |
| Group B — `mirror-consistency` | All three checks (read-only; no adapter writes) |
| Group C — `sentinel-markers` | All three checks (per-harness applicability applies) |
| Group D — `redaction-surface` | All three checks |
| Group E — `deploy-target-prep` and `cross-harness-validation` | `adapter-detection` only |

**Excluded from default:** `deploy-manifest-coverage`, `stale-shipped-artifacts`, `cross-harness-roundtrip`, `sc-behavioral-walk`. These are either CI-context-specific (deploy-manifest coverage, stale artifacts) or require a second harness to be active (cross-harness round-trip, SC behavioral walk).

**Wall-clock budget.** The default mode must complete in under **5 seconds** on a healthy 100-memory store. New check additions to any default-mode group must be measured against this budget before being included in the default set.

Check identifiers used above are defined in `## Check-name vocabulary`. Cross-reference each by group when adding new default-mode checks.

#### Pre-deploy mode (`--pre-deploy`)

Selects the six-check shorthand for validating the local repository state before a deploy run. All six checks are read-only. This mode is appropriate as a pre-flight step in CI or before running `tooling/deploy.{ps1,sh}`.

| Check name | Group |
| :--- | :--- |
| `canonical-frontmatter-parse` | Group A — `canonical-integrity` |
| `canonical-memory-md-consistency` | Group A — `canonical-integrity` |
| `sentinel-marker-count` | Group C — `sentinel-markers` |
| `redaction-denylist-parses` | Group D — `redaction-surface` |
| `deploy-manifest-coverage` | Group E — `deploy-target-prep` |
| `stale-shipped-artifacts` | Group E — `deploy-target-prep` |

Full check definitions, finding shapes, and PASS/WARN/FAIL criteria are documented in `### Check definitions (full table)` below.

#### Post-deploy mode (`--post-deploy`)

Selects the five-check shorthand for validating a deployed state. Designed to run after `tooling/deploy.{ps1,sh}` completes, using the second harness as the invoking context.

| Check name | Group | Notes |
| :--- | :--- | :--- |
| `mirror-canonical-source-exists` | Group B — `mirror-consistency` | |
| `mirror-detect-collisions` | Group B — `mirror-consistency` | |
| `sentinel-region-content-parses` | Group C — `sentinel-markers` | Per-harness applicability applies |
| `adapter-detection` | Group E — `cross-harness-validation` | |
| `sc-behavioral-walk` | Group E — `cross-harness-validation` | `cross-harness-roundtrip` is invoked from the second harness as part of the SC-2 walk |

`cross-harness-roundtrip` is not listed as a standalone entry in `--post-deploy` because it is driven by `sc-behavioral-walk`'s SC-2 sub-walk from the second harness. See `## Check-name vocabulary` Group E for the `sc-behavioral-walk` per-harness applicability matrix.

**Single-harness invocation note.** When `--post-deploy` is invoked with only one harness (e.g., `--post-deploy --harness claude-code` without a corresponding second-harness invocation), `cross-harness-roundtrip` and the SC-2 sub-finding inside `sc-behavioral-walk` return `not-applicable` with `reason: "cross-harness round-trip requires a second harness; not invoked under single-harness post-deploy"`. Both are excluded from overall-verdict aggregation in this case.

Full check definitions, finding shapes, and PASS/WARN/FAIL criteria are documented in `### Check definitions (full table)` below.

#### Post-deploy walk (Claude Code)

The following six-step procedure constitutes the operator-facing validation walk for a single-harness Claude Code post-deploy invocation. Execute the steps in order; each step is a prerequisite for the next.

1. **Provision a healthy canonical store.** Confirm that `~/.cross-memory/` exists and contains at least one project-scope memory (type `project`, scope `project:<slug>`). If the store is absent, run `/cross-memory init` first.

2. **Invoke the post-deploy check.** Run:

   ```
   /cross-memory doctor --post-deploy --harness claude-code
   ```

3. **Assert mirror checks pass.** Verify that `mirror-canonical-source-exists` and `mirror-sidecar-frontmatter-agreement` both return `pass`. A failure here indicates the sidecar manifest or the canonical source path is inconsistent — resolve the inconsistency before proceeding.

4. **Assert sentinel check passes.** Verify that `sentinel-region-content-parses` returns `pass`. A `fail` here means the bytes between the sentinel markers are malformed; re-run `/cross-memory init` to rewrite the sentinel block, then re-invoke the post-deploy check.

5. **Assert the SC behavioral sub-findings.** Verify that the following six `sc-behavioral-walk` sub-findings all return `pass` under `--harness claude-code`: SC-1, SC-3, SC-4, SC-5, SC-15, SC-16. SC-2 returns `not-applicable` in a single-harness invocation — see the single-harness note above — and is excluded from aggregation here.

6. **Assert overall verdict.** Confirm the overall verdict is `pass`. Any `warn` or `fail` finding must be resolved before the deployment is considered healthy.

#### Post-deploy walk (Cursor)

The following six-step procedure constitutes the operator-facing validation walk for a Cursor post-deploy invocation. Execute the steps in order; each step is a prerequisite for the next. Step 0 of the cross-harness gate (a save performed in Claude Code) must have completed before this walk begins.

1. **Confirm the canonical store is healthy.** The Step 0 Claude Code save should have landed a canonical file at `~/.cross-memory/`. Confirm the file exists and is accessible from the Cursor harness session before continuing.

2. **Invoke the post-deploy check.** Run:

   ```
   /cross-memory doctor --post-deploy --harness cursor
   ```

3. **Assert mirror and adapter checks pass.** Verify that `mirror-canonical-source-exists`, `mirror-detect-collisions`, and `adapter-detection` all return `pass`. A failure in `mirror-canonical-source-exists` or `mirror-detect-collisions` indicates a sidecar or canonical source inconsistency; a failure in `adapter-detection` indicates the harness selection chain did not resolve to `cursor` — resolve each before proceeding.

4. **Assert sentinel checks return `not-applicable`.** Verify that `sentinel-marker-count` and `sentinel-region-content-parses` both return `not-applicable`. Cursor's `update_sentinel_block` is a documented v1 no-op (`adapter-cursor.md § 6`), so no sentinel markers are written and no region exists to inspect. A `fail` here would indicate an unexpected marker in the Cursor-side `MEMORY.md` — see `## Check-name vocabulary` Group C for the `not-applicable` criteria.

5. **Assert the cross-harness round-trip passes.** Verify that `cross-harness-roundtrip` returns `pass` with the canonical path of the test memory landed by the Step 0 Claude Code save. This constitutes a behavioral walk of SC-2: a memory saved in harness A (Claude Code) is locatable via `recall` in harness B (Cursor).

6. **Assert the SC behavioral sub-findings.** Verify that the `sc-behavioral-walk` findings are: SC-2, SC-3, SC-4, SC-5 return `pass`; SC-1, SC-15, and SC-16 return `not-applicable` with `reason: "cursor injection surface (update_sentinel_block) is a documented v1 no-op"`. The overall `sc-behavioral-walk` verdict is `pass` because `not-applicable` is treated as `pass` under the `not-applicable = pass` aggregation rule (see `### Output formats and exit codes`). Confirm the overall doctor verdict is `pass`.

**Cursor slash-command parity note.** Cursor slash-command parity (whether `/cross-memory <subcommand>` parses correctly in Cursor's composer) is verified at deploy time as part of the cross-harness gate. If `/cross-memory <subcommand>` does not parse in Cursor's composer, a `tooling/transform-cursor-cross-memory.{ps1,sh}` transform is required; that transform is a deferred contingent path and is not part of the v1.1 deliverable.

### Targeted check mode (`--check <name>`)

When one or more `--check <name>` flags are present (and neither `--pre-deploy` nor `--post-deploy` is set), doctor runs exactly the named checks — no implicit additions. Multiple checks can be passed in a single invocation:

```
/cross-memory doctor --check canonical-frontmatter-parse --check sentinel-marker-count
```

`--check <name>` accepts either an **individual check identifier** from `## Check-name vocabulary` (e.g., `--check sentinel-marker-count`) or a **Group identifier** (e.g., `--check sentinel-markers`), which resolves to the full set of checks in that group. The five valid Group identifiers are:

- `canonical-integrity` — all five Group A checks
- `mirror-consistency` — all three Group B checks
- `sentinel-markers` — all three Group C checks
- `redaction-surface` — all three Group D checks
- `deploy-target-prep` — both Group E pre-deploy checks

The cross-harness-validation Group is post-deploy-only and its checks (`cross-harness-roundtrip`, `adapter-detection`, `sc-behavioral-walk`) do not run under targeted mode; passing `cross-harness-validation` as a `--check` argument is rejected at parse time.

An unrecognized `--check` argument — one that matches neither an individual check identifier nor a valid Group identifier — is rejected at parse time:

```
error: unknown check name 'foo'. See ## Check-name vocabulary for valid names.
```

When a named check's per-harness applicability determines it does not apply to the active harness (for example, `sentinel-region-content-parses` under `--harness cursor` at v1), the check returns `not-applicable` rather than `pass` or `fail`. Output formats and exit-code semantics for `not-applicable` are documented in `### Output formats and exit codes` below.

### Group A — canonical-integrity (5 checks)

These checks verify the internal consistency of the canonical store at `~/.cross-memory/`. All five are read-only and apply under every harness.

| Check name | Description | Finding shape | PASS | WARN | FAIL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `canonical-frontmatter-parse` | Parses every `.md` file in the canonical store against the schema validator. Catches malformed YAML, missing required fields, and invalid enum values before they can corrupt downstream reads. | `{ file: string, error: string }` | All files parse without error | — | Any file's frontmatter is malformed or is missing a required field. Finding includes the offending file path and the parser error message. |
| `canonical-slug-derivation` | For every project-scope file, derives the expected slug from the file's parent directory name and compares it to the `name` field in frontmatter. A mismatch means the file was likely moved or renamed without updating its frontmatter. | `{ file: string, expected_slug: string, actual_slug: string }` | All derivations match | — | Any derivation does not match. Finding includes the file path, the slug derived from the directory name (expected), and the slug recorded in frontmatter (actual). |
| `canonical-memory-md-consistency` | For each scope directory (`user-global/`, `project/<slug>/`, `harness/<name>/`), compares the file list in `MEMORY.md` against the `.md` files on disk. Detects orphans (entry in `MEMORY.md` with no corresponding file on disk) and missing entries (file on disk absent from `MEMORY.md`). | `{ scope: string, orphans: string[], missing: string[] }` | No orphans and no missing entries in any scope | — | Any orphan or missing entry exists. Finding lists the scope path, orphan entries, and missing entries. |
| `canonical-no-duplicate-slugs` | Within each scope directory, asserts that no two files share the same slug (derived from the `name` frontmatter field). Duplicate slugs create ambiguous recall results and can cause one file to shadow another. | `{ scope: string, slug: string, files: string[] }` | All slugs are unique within each scope | — | Any two files in the same scope share a slug. Finding lists the duplicate slug and the full paths of both files. |
| `canonical-archive-not-indexed` | Asserts that `~/.cross-memory/archive/MEMORY.md` does not exist. Per the invariant in `indexing.md` § 3, the archive directory is intentionally not indexed — archived memories are historical state accessed by direct directory traversal, not by an index. A `MEMORY.md` in the archive would be written only by an out-of-spec tool and must be flagged. | `{ archive_path: string }` | `~/.cross-memory/archive/MEMORY.md` is absent | — | `~/.cross-memory/archive/MEMORY.md` exists. Finding includes the archive path that was found. |

### Group B — mirror-consistency (3 checks)

These checks verify the consistency of adapter-managed mirror copies against the canonical store. All three are read-only. Group B reuses each adapter's existing read-only `detect_collisions` contract — no new adapter operations are introduced by doctor at v1.1.

| Check name | Description | Finding shape | PASS | WARN | FAIL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `mirror-sidecar-frontmatter-agreement` | For every mirror file recorded in the adapter sidecar, verifies that the mirror file's `mirrored_from` frontmatter field matches the canonical source path recorded in the sidecar entry. A mismatch indicates the mirror was written with a stale or incorrect source reference. | `{ mirror_path: string, sidecar_canonical: string, frontmatter_mirrored_from: string }` | Every mirror file's `mirrored_from` field agrees with the sidecar's recorded canonical source path | — | Any mirror file's `mirrored_from` field is absent or does not match the sidecar entry. Finding lists the mirror path, the canonical source from the sidecar, and the value found in frontmatter. |
| `mirror-canonical-source-exists` | For every sidecar entry, verifies that the recorded `canonical_source` path exists on disk. A missing source means the canonical file was deleted or moved outside the canonical store without updating the sidecar. | `{ sidecar_entry: string, canonical_source: string }` | Every sidecar entry's canonical source file exists on disk | — | Any canonical source path referenced in the sidecar is absent from disk. Finding lists the broken sidecar entry and the canonical path that was not found. |
| `mirror-detect-collisions` | Calls each active adapter's read-only `detect_collisions` contract and reports the three-state classification for every mirror file: `native` (file exists only as a mirror, no user edits), `stale-mirror` (mirror is older than the canonical source), or `user-edited` (mirror has been modified independently since it was written). Doctor reports the classification and **takes no action** — no overwriting, no quarantining, no merging. | `{ mirror_path: string, classification: "native" \| "stale-mirror" \| "user-edited" }` | No collisions found, or all collisions are classified as `native` | One or more collisions classified as `stale-mirror` or `user-edited`. These states are informational — doctor does not take corrective action. Finding lists each collision with its classification. | — |

### Group C — sentinel-markers (3 checks)

These checks verify the integrity of the sentinel-bounded `[CROSS-MEMORY]` injection region in the harness-native `MEMORY.md`. Per-harness applicability is load-bearing for this group.

**Harness applicability summary.** The Claude Code adapter's `update_sentinel_block` writes and maintains the sentinel region. The Cursor adapter's `update_sentinel_block` is a documented no-op at v1 (`adapter-cursor.md § 6`). The generic adapter's `update_sentinel_block` is equally a no-op (`adapter-generic.md § 6`). Therefore:

- Under `--harness claude-code` — all three checks run normally.
- Under `--harness cursor` at v1 — all three checks return `not-applicable` because no sentinel region exists to inspect.
- Under `--harness generic` at v1 — all three checks return `not-applicable` for the same reason.

| Check name | Description | Finding shape | PASS | WARN | FAIL | `not-applicable` (cursor / generic at v1) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `sentinel-marker-count` | Reads the active project's harness-native `MEMORY.md` and counts begin-marker and end-marker occurrences. Exactly one of each is required; zero or more than one indicates a structural corruption that will cause the injection block to be misread or skipped. | `{ harness: string, file_path: string, begin_count: number, end_count: number }` — `file_path` is the harness-native `MEMORY.md` whose markers were inspected | Exactly one begin marker and exactly one end marker are present | — | Any count other than exactly one of each. Finding includes the harness name, the inspected file path, and the actual counts found. | `reason: "cursor adapter update_sentinel_block is a v1 no-op; sentinel markers are not written"`. Generic: same reason, citing `adapter-generic.md § 6`. |
| `sentinel-region-bytes-fingerprint` | At v1.1, operates as an intra-run check only. Computes a SHA-256 fingerprint of the bytes **outside** the sentinel region (i.e., the user-managed content above the begin marker and below the end marker) at run start, then again at run end, and compares the two. A mismatch indicates that the skill modified bytes it should not have touched — only the bytes between the markers are ever written by the skill. | `{ harness: string, start_fingerprint: string, end_fingerprint: string }` (fingerprints truncated to first 16 hex characters in human output) | Start and end fingerprints are identical | — | Fingerprints differ. Finding includes the harness name and both truncated fingerprints. | `reason: "cursor adapter update_sentinel_block is a v1 no-op; no sentinel region exists to fingerprint around"`. Generic: same reason. |
| `sentinel-region-content-parses` | Reads the bytes between the sentinel markers and asserts they parse as a valid `[CROSS-MEMORY]` injection block. An empty region (zero bytes) is also a valid state and returns PASS. A region whose content is malformed — for example, truncated mid-entry or containing bytes from a non-cross-memory write — returns FAIL. | `{ harness: string, parser_error: string \| null }` | Content between the markers parses as a valid injection block (or the region is empty) | — | Content does not parse. Finding includes the harness name and the parser error message. | `reason: "cursor adapter update_sentinel_block is a v1 no-op; no sentinel region to parse"`. Generic: same reason. |

#### Group C and init's step-4 self-check

The Group C checks double as init's step-4 self-check primitives. After init writes the sentinel block under `--harness claude-code`, it immediately runs `sentinel-marker-count` and `sentinel-region-content-parses` as read-only self-checks against the file it just wrote. If either check would report `fail`, init fails fast and emits a structured violation report rather than proceeding to the step 5 summary. Under `--harness cursor` or `--harness generic`, init's step 4 reports `sentinel=skipped` and these two self-checks return `not-applicable` rather than running — so init always succeeds on those harnesses regardless of Group C state. See `## Subcommand: init → Reuse of doctor's check primitives` for the full step-4 behavior table.

### Group D — redaction-surface (3 checks)

These checks verify that the redaction layer is healthy and that no sensitive content has slipped through into the canonical store. All three are read-only. They apply under every harness.

| Check name | Description | Finding shape | PASS | WARN | FAIL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `redaction-denylist-parses` | Verifies that `redaction.md` is present at the deployed path and that the denylist table parses as expected. This is a boolean structural check — it does not scan any memory content; it only confirms the denylist itself is intact and loadable before any scan-dependent check runs. Finding always includes the path checked; if parsing fails, the parser error is included. | `{ path: string, parser_error: string \| null }` | `redaction.md` is present and the denylist table parses without error | — | `redaction.md` is absent from the deployed path, or the denylist table is present but cannot be parsed. Finding includes the path checked and the parser error if any. |
| `redaction-sampling-scan` | Samples N memories per scope (default 10, capped at 30) and scans each memory body against the Pass-B regex set from `redaction.md`. Sampling is non-deterministic; the finding records the sample size and seed (or the full sample list) for reproducibility. Each suspicious match is emitted as a separate finding entry — the match is never reported verbatim; only a redacted excerpt is included. Doctor does not modify any memory regardless of findings. | `{ file: string, scope: string, regex_name: string, redacted_excerpt: string }` per match; `{ sample_size: number, seed: string \| null, sample_list: string[] }` for the run summary | No regex matches across all sampled memories | One or more matches found across the sample. Each match is an independent finding with the file path, scope name, regex name, and a redacted excerpt. This is informational — operators must inspect and resolve matches manually using `forget` or `save --no-redact` with the corrected body. | — |
| `redaction-overridden-flag-audit` | Surfaces every memory whose frontmatter contains `redaction_overridden_at`. Override timestamps indicate a deliberate operator decision to bypass the redaction gate; this check makes those decisions visible in the doctor report so they can be reviewed periodically. Doctor does not remove or modify any override. | `{ file: string, scope: string, override_timestamp: string, override_reason: string \| null }` per overridden memory | No memories with `redaction_overridden_at` set in frontmatter | One or more memories with `redaction_overridden_at` set. Each override is a separate finding with the file path, scope, override timestamp, and override reason if present in frontmatter. This is informational — operators may have legitimate reasons to override. | — |

### Group E pre-deploy — deploy-target-prep (2 checks)

These checks are intended to run before deploying a new version of the cross-memory skill. They verify that the deployment manifest and installed artifacts are consistent with the repo. Both are read-only.

| Check name | Description | Finding shape | PASS | WARN | FAIL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `deploy-manifest-coverage` | Globs the patterns defined in `tooling/deploy-manifest.json` and asserts that all eight cross-memory files are covered: six skill files (`SKILL.md`, `redaction.md`, `indexing.md`, `adapter-claude-code.md`, `adapter-cursor.md`, `adapter-generic.md`), the agent definition (`agents/cross-memory.md`), and the redaction reference. Also confirms that exclusion patterns in the manifest do not unintentionally drop any of the eight files. Finding lists which file(s) are missing from manifest coverage when the check fails. | `{ uncovered_files: string[] }` | All eight cross-memory files are covered by at least one manifest glob, and no exclusion pattern removes them. | — | One or more of the eight files is not covered by any manifest glob, or is covered but then removed by an exclusion pattern. Finding lists each uncovered or excluded-out file path. |
| `stale-shipped-artifacts` | Globs `~/.claude/skills/cross-memory/`, `~/.cursor/skills/cross-memory/`, and `~/.claude/agents/cross-memory.md` for files that have no source counterpart in the repo. This check assumes cross-harness directory reads are read-only and accessible from either harness session — it does not require switching harnesses to perform the glob. Doctor does not delete any stale artifact. Finding lists each stale path and the missing repo counterpart. | `{ stale_path: string, missing_repo_counterpart: string }` per stale file | No stale files found in any of the three target locations. | One or more stale files found (i.e., a file is present in a deploy target but has no matching source file in the repo). Each stale file is a separate finding. This is informational — doctor does not delete. | — |

### Group E post-deploy — cross-harness-validation (3 checks)

These checks validate that the deployed skill behaves correctly across harness boundaries. They are intended to run after a successful deploy and are the primary integration gate for the v1.1 acceptance criteria.

| Check name | Description | Finding shape | PASS | WARN | FAIL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `cross-harness-roundtrip` | Run from harness B after a save has been performed in harness A. Walks SC-2 behaviorally: issues a `recall` from harness B and confirms the memory saved under harness A can be located via the canonical store. Single PASS/FAIL per run. Finding always includes: harness A name, harness B name, the save target path probed, and the recall result. | `{ harness_a: string, harness_b: string, save_target_path: string, recall_result: "found" \| "not-found" }` | Recall in harness B successfully locates the memory saved in harness A. | — | Recall in harness B fails to locate the memory. Finding includes the path that was probed. |
| `adapter-detection` | Re-runs the five-step adapter selection chain (see `## Adapter selection`) and reports which step resolved the active harness. The five steps, in precedence order, are: `cli-flag` → `config-field` → `env-var` → `manifest-probe` → `generic-fallback`. The generic fallback is always defined, so the chain cannot silently fail to select a harness. Always emits a single finding with the winning step name and the resolved harness name. | `{ winning_step: "cli-flag" \| "config-field" \| "env-var" \| "manifest-probe" \| "generic-fallback", harness: string }` | A harness was resolved via any of the five steps. (The `generic-fallback` is a valid PASS — it means the harness was not explicitly configured, which is allowed.) | — | The adapter selection chain itself errors before any step can resolve (the generic fallback should prevent this; a FAIL here indicates a structural error in the chain logic). |
| `sc-behavioral-walk` | Walks the seven contract-only-verified scenarios (SC-1, SC-2, SC-3, SC-4, SC-5, SC-15, SC-16) as small in-place behavioral checks. Each scenario emits its own sub-finding with a verdict of `pass`, `fail`, `warn`, or `not-applicable`. The per-harness applicability matrix below determines whether each SC is walked, delegated to `cross-harness-roundtrip`, or returned as `not-applicable`. | Array of `{ sc: string, verdict: "pass" \| "fail" \| "warn" \| "not-applicable", reason: string \| null }` — one entry per SC | All walked SCs return `pass` (and any `not-applicable` SCs are treated as `pass` for aggregation). | Any walked SC returns `warn`. | Any walked SC returns `fail`. |

#### `sc-behavioral-walk` per-harness applicability matrix

| SC | What it verifies | Under `--harness claude-code` | Under `--harness cursor` |
| :--- | :--- | :--- | :--- |
| SC-1 | User-global preference surfaces in a different project | Walked behaviorally — confirms `[CROSS-MEMORY]` block in the harness-native file contains the user-global entry. | **`not-applicable`** — Cursor's `update_sentinel_block` is a documented v1 no-op (`adapter-cursor.md` § 6); the `[CROSS-MEMORY]` block this check inspects does not exist on the Cursor side. |
| SC-2 | Cross-harness round-trip | Delegates to `cross-harness-roundtrip` (post-deploy). Walked behaviorally. | Delegates to `cross-harness-roundtrip` (post-deploy). Walked behaviorally — exercises canonical-store + mirror surfaces that Cursor implements. |
| SC-3 | Auto-propose flow surfaces a memory candidate | Walked behaviorally. | Walked behaviorally. |
| SC-4 | Save / recall round-trip on canonical store | Walked behaviorally. | Walked behaviorally. |
| SC-5 | List / forget / search round-trip on canonical store | Walked behaviorally. | Walked behaviorally. |
| SC-15 | `<private>` redaction suppresses content from the always-on tier output | Walked behaviorally — confirms redacted content does not appear in the populated `[CROSS-MEMORY]` block. | **`not-applicable`** — the `[CROSS-MEMORY]` block is itself absent at v1; redaction itself remains contract-verified via Group D `redaction-sampling-scan`. |
| SC-16 | `[CROSS-MEMORY]` injection block format is correct | Walked behaviorally — `sentinel-region-content-parses` is the same primitive. | **`not-applicable`** — same reason as SC-1. |

Under `--harness claude-code` the walk emits **seven** sub-findings, one per SC, each with verdict `pass` / `fail` / `warn`. Under `--harness cursor` the walk emits **four behavioral** sub-findings (SC-2, SC-3, SC-4, SC-5) plus **three** `not-applicable` sub-findings (SC-1, SC-15, SC-16) each with `reason: "cursor injection surface (update_sentinel_block) is a documented v1 no-op"`. Doctor's overall-verdict aggregation treats `not-applicable` as `pass`, so an otherwise-healthy Cursor walk still returns overall `pass`. Cross-reference `### Output formats and exit codes` below for the formal aggregation rule.

### Adapter detection delegation

The `adapter-detection` check contains **no precedence logic of its own**. It delegates entirely to the five-step chain defined in `## Adapter selection`. Any future change to harness selection logic — adding a step, reordering existing steps, changing timeout behavior — must be made in `## Adapter selection` only. Init and doctor both call that chain; neither duplicates it.

The check emits a single finding with two fields: `harness` (the resolved harness name, one of `claude-code`, `cursor`, `generic`) and `harness_selection_step` (the enum value naming which step in the chain won). The allowed values for `harness_selection_step`, in precedence order, are: `cli-flag`, `config-field`, `env-var`, `manifest-probe`, `generic-fallback`.

This `harness` + `harness_selection_step` pair is surfaced in the following places. A user who sees an unexpected harness in any output can read `harness_selection_step` to understand which detection step was the furthest the chain reached, without needing to re-run with `--verbose`.

| Surface | Section | What it shows |
| :--- | :--- | :--- |
| Init human-readable summary | `## Subcommand: init → Step 5 — Summary output → Human-readable summary` | `harness=<name>` in the summary line |
| Init JSON output | `## Subcommand: init → Step 5 — Summary output → JSON output` | `harness` and `harness_selection_step` as top-level keys |
| Init verbose trace | `## Subcommand: init → Step 5 — Summary output → Verbose mode` | `harness=<name> (selected by <step>)` on the step-2 trace line |
| Doctor human report | `### Output formats and exit codes → Human-readable report` | `harness` listed in the per-check finding under `adapter-detection` |
| Doctor JSON output | `### Output formats and exit codes → JSON report` | `harness` and `harness_selection_step` as top-level keys |

### Output formats and exit codes

#### Human-readable report (default)

Doctor emits a structured markdown report to chat. The report contains one section per check group, a per-section verdict line, and a final overall verdict line.

Shape:

```
## cross-memory doctor

### canonical-integrity
<finding per check, one line each>
verdict: PASS

### sentinel-hygiene
<finding per check, one line each>
verdict: WARN  — <brief reason>

### adapter-wiring
verdict: NOT-APPLICABLE  — cursor injection surface is a documented v1 no-op

...

---
Overall: WARN
```

Per-section verdict is one of `PASS`, `WARN`, `FAIL`, `NOT-APPLICABLE` (upper-case in the human report). The overall verdict at the bottom is the worst per-section verdict under the aggregation rule below.

#### JSON report (`--json`)

When `--json` is passed, doctor prints a single JSON object instead of the markdown report. The schema version is `1`. Keys appear in this order:

```json
{
  "schema_version": 1,
  "timestamp_utc": "2026-05-09T14:23:01Z",
  "harness": "claude-code",
  "harness_selection_step": "cli-flag",
  "active_project_slug": "ai-skills-agents",
  "overall": "warn",
  "sections": [
    {
      "name": "canonical-integrity",
      "verdict": "pass",
      "findings": [
        { "check": "canonical-frontmatter-parse", "verdict": "pass" },
        { "check": "canonical-index-coherence", "verdict": "pass" }
      ]
    },
    {
      "name": "sentinel-hygiene",
      "verdict": "warn",
      "findings": [
        { "check": "sentinel-marker-count", "verdict": "warn", "detail": "marker count=3, expected 2" }
      ]
    },
    {
      "name": "adapter-wiring",
      "verdict": "not-applicable",
      "reason": "cursor injection surface (update_sentinel_block) is a documented v1 no-op",
      "findings": [
        { "check": "sentinel-region-content-parses", "verdict": "not-applicable" }
      ]
    }
  ]
}
```

**Top-level keys (in order):**

| Key | Type | Description |
| :--- | :--- | :--- |
| `schema_version` | integer | Always `1` at v1.1. |
| `timestamp_utc` | string | ISO-8601 UTC timestamp of the run. |
| `harness` | string | Active harness name (`claude-code`, `cursor`, `generic`). |
| `harness_selection_step` | string | Which step in the five-step precedence chain selected the harness (same enum as init — see `## Subcommand: init → Step 5 — Summary output`). |
| `active_project_slug` | string | Slug of the active project, or `null` if no project context. |
| `overall` | string | Overall verdict (one of the five values below). |
| `sections` | array | One object per check group. |

**`sections[]` object keys:**

| Key | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `name` | string | always | Check group identifier, e.g., `"canonical-integrity"`. |
| `verdict` | string | always | One of the five verdict values below. |
| `findings` | array | always | One finding object per check in the group. Finding shape is defined by each individual check. |
| `reason` | string | when `verdict == "not-applicable"` | Human-readable explanation of why this group does not apply to the active harness. Required — omitting it when verdict is `not-applicable` is a schema error. |

**Cross-tool key note.** The fields `harness`, `harness_selection_step`, and `timestamp_utc` use the same field names and value shapes as the init JSON schema (documented in `## Subcommand: init → Step 5 — Summary output`). Additions or renames to these three keys must be applied consistently to both subcommands.

#### Exit codes

Exit codes apply to the **overall** verdict and are only meaningful when `--json` is set. Under the human-readable report, the skill exits 0 regardless of verdict (chat output is the channel; non-zero exits would break the conversational surface).

| Overall verdict | Exit code | Meaning |
| :--- | :--- | :--- |
| `pass` | 0 | All checks passed (or were not-applicable). |
| `not-applicable` | 0 | Every section was not-applicable on this harness. Treated as success — this is correct behavior on this surface. |
| `warn` | 1 | At least one check surfaced a warning; nothing is broken but review is recommended. |
| `fail` | 2 | At least one check found a definite problem requiring action. |
| `error` | 3 | At least one check could not complete (e.g., unreadable file, unexpected exception). |

#### Verdict aggregation

**The `verdict` field is a string enum with five values:**

| Value | Meaning |
| :--- | :--- |
| `pass` | Check completed; no issues found. |
| `warn` | Check completed; non-critical issue found — review recommended. |
| `fail` | Check completed; definite problem found — action required. |
| `error` | Check could not complete due to an unexpected condition (e.g., unreadable file, parse exception). |
| `not-applicable` | Check does not apply to the active harness on this surface. This is not a problem. |

**Per-section verdict** is the worst of the per-check verdicts within that section, under the ordering:

```
not-applicable = pass  <  warn  <  fail  <  error
```

Concretely:

| Checks in section | Section verdict |
| :--- | :--- |
| `pass + not-applicable + pass` | `pass` |
| `not-applicable + warn` | `warn` |
| `not-applicable + fail` | `fail` |
| `not-applicable` (all checks not-applicable) | `not-applicable` |

A section composed entirely of inapplicable checks reports `not-applicable`. For **overall-verdict aggregation**, that section is treated as `pass` (i.e., `not-applicable` at the section level does not elevate the overall verdict above any worse section).

**Overall verdict** is the worst per-section verdict under the same ordering. A run where every section is either `pass` or `not-applicable` returns overall `pass` (exit code 0).

#### Read-only by default

Doctor is **read-only at v1.1**. There is no `--repair`, no `--fix`, and no auto-correction. The diagnostic-then-fix workflow is explicit: doctor reports findings; the user dispatches `audit`, `forget`, or `save` to address specific findings. This is a lane-policy constraint, not a missing feature — auto-repair would conflate diagnosis and mutation in a single command.

### Lane boundary

Doctor is **skill-only**. The cross-memory agent is not invoked by doctor, and doctor does not dispatch to any agent. Doctor runs entirely in the skill body and is **read-only** at v1.1 — there is no `--repair`, no `--fix`, and no auto-correction. The diagnostic-then-fix workflow stays explicit: doctor reports findings; the user dispatches `audit`, `forget`, or `save` to address specific findings.

### Cross-references

- **Check-name vocabulary** (stable identifier set): `## Check-name vocabulary` above.
- **Shared flag semantics** (`--harness`, `--scope`, `--json`, `--verbose`): `## Shared flag parsing` above.
- **Adapter selection chain** (consumed by `adapter-detection` check): `## Adapter selection` above.
- **Init's reuse of check primitives**: `## Subcommand: init → Reuse of doctor's check primitives` above.
- **SC behavioral walk per-harness matrix**: `## Check-name vocabulary` Group E (`sc-behavioral-walk` row).

---

## Mirror failure handling

Two dispatch points invoke adapter operations: the `save` subcommand calls `mirror_write` after the canonical write, and the `forget` subcommand calls `mirror_remove` after the canonical archive. Both share the same three governing principles:

1. **The canonical store is the source of truth.** Mirror operations always run _after_ the canonical operation succeeds. A mirror failure never rolls back the canonical write or archive — the canonical result stands regardless.
2. **Adapter-side failures surface as structured warnings, not errors.** When an adapter returns a violation or raises an unexpected exception, the skill emits a user-facing warning describing what failed and what the user can do to resolve it. The subcommand still returns success because the canonical operation succeeded.
3. **The `generic-fallback` no-op is the expected silent path.** When the generic adapter is active, it returns a structured "no mirror written / removed; harness=generic" result. The skill records this result and emits no warning — this is correct behavior, not a degraded state.

---

## Subcommand: save

Persist a new memory entry to the canonical store. Runs four sequential gates: parse → redact → confirm → write.

### Command syntax

```
/cross-memory save \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--type <feedback|project|preference|fact|rule>] \
  [--category <project-config|architecture|error-solution|preference|learned-pattern|conversation|other>] \
  [--tags <tag1,tag2,...>] \
  [--name <slug>] \
  [--no-redact] \
  -- <body>
```

### Default values

| Flag | Default | Notes |
| :--- | :--- | :--- |
| `--scope` | `user-global` | Broadest, safest default. Project memories require explicit `--scope project:<slug>`. |
| `--type` | `feedback` | Most common origin type. |
| `--category` | *(absent)* | Not defaulted to `other` — absence is the canonical "uncategorized" signal per Schema validator default rules. |
| `--tags` | `[]` | Empty array. |
| `--name` | *(derived)* | First 40 characters of the body, slugified: lowercase, non-alphanumeric characters replaced with `-`. |
| `--no-redact` | `false` | Redaction is on by default. |

### Gate 1 — Parse

Parse all command-line arguments. Validate each flag value against its enum (type enum and category enum are defined in `## Schema validator` above). On any invalid value, emit the exact validation error string documented in that section and abort — no file is created.

Compose the in-memory candidate object: a `frontmatter` dict containing all required fields and any provided optional fields, and a `body` string containing the literal `-- <body>` text.

### Gate 2 — Redact

Pass the `body` through the redaction pipeline per `~/.claude/skills/cross-memory/redaction.md`:

1. **Pass A** — `<private>` strip: replace every `<private>...</private>` span with `[REDACTED:private]`. This pass always runs regardless of `--no-redact`.
2. **Pass B** — regex denylist: scan the body for the eight pattern categories (api-key, password, bearer-token, jwt, aws-secret, env-block, private-key-header, user-tagged-secret). Replace each match with `[REDACTED:<category>]`.

**When `--no-redact` is NOT set** (default): apply the Pass B replacements. If any Pass A or Pass B pattern fired, set `redacted: true` in the frontmatter.

**When `--no-redact` IS set and Pass B matched ≥1 pattern**: enter the typed-phrase confirmation flow defined in `redaction.md` `### --no-redact behavior`:

```
warning: --no-redact is set; Pass B would have redacted the following patterns:
  - <category>: <preview of matched text>
  - ...
Type 'save unredacted' to persist the unredacted memory, or anything else to cancel:
```

- **On exact phrase `save unredacted`** (case-sensitive): preserve the unredacted body; stamp `redaction_overridden_at: <ISO-8601 UTC timestamp>` in the frontmatter; persist `redacted: false` (unless Pass A fired, in which case `redacted: true` regardless).
- **On anything else**: abort the save with no disk write.

**When `--no-redact` IS set and Pass B matched nothing**: accept silently; no typed confirmation required.

### Gate 3 — Confirm

Display the post-redaction candidate — rendered frontmatter followed by body — and request final confirmation.

**When redaction fired** (`redacted: true` — any Pass A or Pass B pattern matched and `--no-redact` is false): render the distinct WARN UX box:

```
┌─ Sensitive pattern detected ─────────────────────┐
│ The following categories were redacted:         │
│   - <category1>                                  │
│   - <category2>                                  │
│                                                  │
│ Body preview (post-redaction):                   │
│   <first 3 lines of redacted body>               │
│                                                  │
│ Save anyway? [y/N]                               │
└──────────────────────────────────────────────────┘
```

The default answer is **N** (no silent commits — even on explicit save, when redaction fired the user must explicitly type `y` or `Y` (case-insensitive) to confirm). Any response other than `y` or `Y` aborts with no disk write.

**When no redaction fired** (clean explicit save — `redacted: false` or the field is absent): display the standard post-redaction candidate (rendered frontmatter followed by body) and prompt for confirmation. The default answer is **Y** (no surprise; the user explicitly invoked save and no patterns were detected). Any response other than `y` or `Y` (case-insensitive) aborts with no disk write.

### Gate 4 — Write

Resolve the canonical path from `--scope`:

| Scope | Canonical path |
| :--- | :--- |
| `user-global` | `~/.cross-memory/user-global/<filename>` |
| `project:<slug>` | `~/.cross-memory/projects/<slug>/<filename>` |
| `harness:<name>` | `~/.cross-memory/harnesses/<name>/<filename>` |

Where `<filename>` is `<type>_<name>.md`. The `<name>` portion in canonical and mirror filenames is the slugified version of the user-supplied `--name` argument, with the same character-replacement rule used elsewhere for slugs.

For `project:<slug>` scope: if the per-project directory and its `MEMORY.md` are absent, lazy-provision them now (see `## Config` → Lazy-provisioning sequence above).

Stamp frontmatter fields:
- `created_at: <ISO-8601 UTC now>`
- `updated_at: <ISO-8601 UTC now>` (equal to `created_at` at create time)
- `originSessionId: <active harness session ID>` (if available from the active harness)

Write the file to the resolved canonical path. Update the scope's `MEMORY.md` index per the line format and re-sort rules in `~/.claude/skills/cross-memory/indexing.md`:

```
- [<name>](<filename>.md) — <description>
```

Echo the canonical path to the user.

### Supersede branch

Triggered when Gate 4 detects a filename collision: the resolved canonical path `<type>_<name>.md` already exists in the target scope directory. If no collision is found, Gate 4 proceeds with the standard write path. If a collision is found, execution enters this branch instead.

#### Step 1 — Collision detection

Before opening the canonical file path for writing, check whether a file with the filename `<type>_<name>.md` already exists in the resolved scope directory. If yes → supersede branch. If no → standard write (no change to Gate 4 behaviour).

#### Step 2 — Diff rendering

Read the body of the existing canonical file. Apply the full redaction pipeline (Pass A + Pass B, per `~/.claude/skills/cross-memory/redaction.md`) to **both** the existing body and the new candidate body. Re-redacting the existing body accounts for any pattern additions to the denylist since it was originally saved.

Render a unified diff (`diff -u` style) between the two redacted bodies, existing on top, new on bottom. Display the diff to the user in a box alongside the existing file's `created_at` and `updated_at` values:

```text
┌─────────────────────────────────────────────────────────────┐
│ This would replace an existing memory:                      │
│                                                             │
│ ~/.cross-memory/<scope-dir>/<filename>.md                   │
│ Created: <created_at>  Updated: <updated_at>                │
│                                                             │
│ Diff (existing → proposed):                                 │
│ ─────                                                       │
│ - <removed lines from existing redacted body>               │
│ + <added lines from new redacted body>                      │
│ ─────                                                       │
│                                                             │
│ Supersede existing memory? [y/N]                            │
└─────────────────────────────────────────────────────────────┘
```

#### Step 3 — Confirmation UX

The default answer is **N** (the user is overwriting durable state; the destructive default must be conservative). Any response other than `y` or `Y` (case-insensitive) → abort, no disk write, emit "Supersede cancelled." On `y` or `Y` → continue to Step 4.

#### Step 4 — Archive predecessor

Move the existing canonical file to:

```
~/.cross-memory/archive/<original-stem>-<YYYYMMDDTHHMMSSZ>.md
```

Where `<original-stem>` is the original filename without the `.md` extension, and the timestamp is UTC at the moment of archive write (format: `YYYYMMDDTHHMMSSZ`, e.g., `20260508T143201Z`).

In the archive copy, set `superseded_by: <new-canonical-filename>` in the frontmatter. This field is **only** present on archived copies — it must never appear on canonical files (per Schema validator rules above).

#### Step 5 — Write new canonical

Write the new memory to the original canonical path. Apply these frontmatter rules:

- **`created_at`**: preserve the predecessor's `created_at` value exactly. The superseding memory inherits the original creation timestamp — the memory is a continuation, not a fresh entry.
- **`updated_at`**: stamp to `<ISO-8601 UTC now>` (the supersede moment). This is the field that marks when the memory last changed.
- All other frontmatter fields come from the new memory's user-supplied arguments and redaction-derived flags (same as the standard write path).

#### Step 6 — Update MEMORY.md

Remove the predecessor's index line from the scope's `MEMORY.md`. Add the new memory's index line in its place. Re-sort all entries by `updated_at` descending per the rules in `~/.claude/skills/cross-memory/indexing.md`. The archive copy is **never** added to any `MEMORY.md`.

#### Step 7 — Mirror hook (supersede case)

After the canonical supersede completes successfully (Steps 4–6 done), the save flow determines the active adapter (via the precedence chain in `## Adapter selection` above) and dispatches three calls in order:

1. Call `active_adapter.mirror_remove(predecessor)` to remove the predecessor's harness-native mirror file and its sidecar manifest entry. The predecessor mirror removal runs first to prevent stale harness-native copies.
2. Call `active_adapter.mirror_write(successor)` to write the successor's mirror file and update the sidecar manifest. The direction is canonical → mirror; the canonical write has already committed before this call is made.
3. Invoke the always-on tier filter to produce the updated entry list, invoke the injection-block formatter on the filter's output to produce the updated content bytes, and call `active_adapter.update_sentinel_block(content)` to refresh the sentinel-bounded `MEMORY.md` region.

All three dispatches follow the same canonical-first failure-isolation rules as the standard-save mirror hook: a failure at any step is a structured warning, not an error, and the canonical supersede is not rolled back.

---

### Mirror hook — standard save

After Gate 4 completes successfully, the save flow determines the active adapter (via the precedence chain in `## Adapter selection` above) and dispatches:

```
active_adapter.mirror_write(memory)
```

Where `memory` is the metadata of the just-written canonical memory (its `type`, `name`, `scope`, and canonical file path). The direction is one-way: **canonical → mirror**. The mirror write always runs _after_ the canonical write — the canonical store is the source of truth and must be committed before any mirror is attempted.

#### Success path

The active adapter creates the harness-native mirror file, updates the sidecar manifest, and returns a structured result. The skill records the result and appends a brief write-confirmation to the user-facing output (e.g., "mirrored to `~/.claude/projects/<slug>/memory/<type>_<name>.md`").

#### Failure paths

**Structured violation from the adapter** — for example, the Claude Code adapter's pre-flight slug check fails (derived slug absent from `~/.claude/projects/`) or a sidecar/frontmatter disagreement is detected during a collision check. The canonical write is not rolled back. The skill emits a structured warning to the user:

```
mirror skipped: <short reason from adapter violation report>
The canonical memory was saved successfully. <Resolution hint from adapter.>
```

The save subcommand returns success.

**`generic-fallback` no-op** — the generic adapter returns its standard structured result (`harness: generic`, `mirror written: false`). The skill records this result and emits no warning — this is the expected silent path when no harness-native adapter is active (see `## Mirror failure handling` above).

**Unexpected exception** — if the adapter raises a truly unhandled error (not a structured violation), the skill catches it, emits a structured warning naming the exception, and returns success. The canonical write is preserved.

#### Sentinel block update (save)

After `active_adapter.mirror_write(memory)` succeeds, the save flow updates the harness-native `MEMORY.md` sentinel region:

1. Invoke the always-on tier filter to produce the updated entry list (the newly saved memory may now qualify for the always-on tier).
2. Invoke the injection-block formatter on the filter's output to produce the updated content bytes.
3. Call `active_adapter.update_sentinel_block(content)` to splice those bytes into the harness-native `MEMORY.md`.

This call follows the same canonical-first failure-isolation rules as `mirror_write`: a failure here is a structured warning, not an error. The canonical save still succeeds and `mirror_write` is not rolled back.

#### Ordering guarantee

The `mirror_write` dispatch is deliberately placed _after_ Gate 4 completes. A failure at this step must never prevent or undo the canonical write. The three governing principles are stated in `## Mirror failure handling` above.

### Cross-references

- **Argument validation** (enum values, reject error strings): `## Schema validator` section above.
- **Redaction pipeline** (Pass A, Pass B, `--no-redact` typed-phrase UX): `~/.claude/skills/cross-memory/redaction.md`.
- **MEMORY.md update format and re-sort rules**: `~/.claude/skills/cross-memory/indexing.md`.
- **Lazy provisioning of scope directories**: `## Config` → Lazy-provisioning sequence above.
- **Active adapter selection and precedence**: `## Adapter selection` above.
- **Mirror failure handling principles**: `## Mirror failure handling` above.
- **`mirror_write` operation contract** (target path, sidecar manifest, bootstrap, and violation report format): `adapter-claude-code.md § 3`, `adapter-cursor.md § 3`, `adapter-generic.md § 3`.

### Auto-propose flow

The auto-propose flow allows the skill to proactively suggest saving a memory when the user's message contains an explicit cue — without requiring the user to invoke `/cross-memory save` directly. This flow fires **only** on enumerated explicit cue patterns. It shares the same redaction pipeline as the explicit save flow.

#### Trigger surface

The assistant scans each user message for the following cue patterns (case-insensitive substring match):

```
remember that
save this preference
save this for later
don't forget
note that
from now on
make a note that
keep in mind that
```

Any user message containing one of these substrings triggers the auto-propose flow. No other detection strategy is used.

**No NLP heuristics.** The auto-propose flow fires **only** on the enumerated cue patterns above. The assistant's own judgment that a piece of content is "memorable" or "worth saving" does **NOT** trigger the flow. Heuristic LLM-based detection is explicitly excluded because it risks surprising the user with proposals on every interesting-sounding sentence and creates noise. Heuristic detection may be added in a later version once the explicit-trigger flow is validated.

#### Candidate drafting

When a cue fires, the assistant constructs a candidate memory from the user's message:

1. **Salient fact extraction** — strip the cue phrase itself and extract the substantive content the user intends to be remembered.
2. **`type` and `category` inference** — inferred from the cue pattern:
   - Cues indicating a preference (`"save this preference"`, `"from now on"`, `"keep in mind that"`) → `type: preference`, `category: preference`.
   - Cues indicating a rule or standing instruction (`"from now on"`) → `type: rule`.
   - Cues indicating a fact or note (`"remember that"`, `"note that"`, `"make a note that"`, `"don't forget"`, `"save this for later"`) → `type: fact`.
   - When a cue matches multiple categories, prefer the more specific inference.
3. **Name slug** — generated from the first 40 characters of the salient fact, slugified (lowercase; non-alphanumeric characters replaced with `-`).
4. **`scope` inference** — default `user-global`. If the cue or adjacent context references "this project", "for this repo", "in this codebase", or similar, infer `project:<slug>` using the active harness's project slug. If no slug is available, fall back to `user-global` and note the fallback to the user.

#### Redaction

Before presenting the candidate to the user, apply the full redaction pipeline per `~/.claude/skills/cross-memory/redaction.md` — identical to Gate 2 of the explicit save flow:

1. **Pass A** — `<private>` strip: replace every `<private>...</private>` span with `[REDACTED:private]`. Runs unconditionally.
2. **Pass B** — regex denylist: scan the body for the eight pattern categories. Replace each match with `[REDACTED:<category>]`.

If any Pass A or Pass B pattern fired, set `redacted: true` in the candidate frontmatter.

#### Confirmation UX

Display the post-redaction candidate to the user using the following box format:

```text
┌─────────────────────────────────────────────────────────────┐
│ I'd like to save this as a memory. Confirm?                 │
│                                                             │
│ Scope: <scope>    Type: <type>    Tags: <tags>              │
│ Name:  <name-slug>                                          │
│                                                             │
│ Body (redacted candidate):                                  │
│ ─────                                                       │
│ <redacted body>                                             │
│ ─────                                                       │
│                                                             │
│ Save this memory? [y/N]                                     │
└─────────────────────────────────────────────────────────────┘
```

The default answer is **N**. The auto-propose flow is a proactive suggestion, not the user's explicit command. Any response other than `y` or `Y` (case-insensitive) is treated as a decline.

#### On confirm (`y`)

Flow into **Gate 4 — Write** of the explicit save flow (see above). The path resolution, MEMORY.md update, and mirror hook proceed identically to a user-invoked `/cross-memory save`. No separate code path exists for the write step — auto-propose and explicit save converge at Gate 4.

#### On decline (anything not `y`)

Abort immediately. No file is written, no index entry is created, no mirror hook is called. No message is emitted other than silently dropping the proposal.

#### Cross-references

- **Redaction pipeline** (Pass A, Pass B): `~/.claude/skills/cross-memory/redaction.md`; mirrors Gate 2 of the explicit save flow.
- **Gate 4 — Write** (path resolution, MEMORY.md update, mirror hook): `### Gate 4 — Write` above.

---

## Subcommand: recall

Retrieve memories from the canonical store by topic. Uses case-insensitive substring matching across multiple fields; no ranking, no fuzzy match.

### Command syntax

```
/cross-memory recall <topic> \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--type <feedback|project|preference|fact|rule>] \
  [--category <project-config|architecture|error-solution|preference|learned-pattern|conversation|other>] \
  [--tag <tag>] \
  [--include-stale]
```

`<topic>` is a required positional argument. At least one character must be provided.

### Match strategy

For each memory file in `~/.cross-memory/` (excluding `archive/`), the skill tests whether `<topic>` appears (case-insensitive substring match) in any of the following fields:

| Field | Where to check |
| :--- | :--- |
| `name` | Frontmatter |
| `description` | Frontmatter |
| `tags` | Frontmatter array — topic is tested against each tag element |
| Body | Full body text after the closing `---` of the frontmatter block |

A memory is included in results if any one of the four fields matches. All four checks run on every candidate file; partial matches (substring anywhere in the field) qualify.

### Filter flags

Filter flags narrow the candidate set **before** the topic match is applied. A memory must pass all provided filters to be considered.

| Flag | Effect | Notes |
| :--- | :--- | :--- |
| `--scope <s>` | Retain only memories whose `scope` frontmatter field equals `<s>` exactly | Accepts the same values as `--scope` in `save`: `user-global`, `project:<slug>`, `harness:<name>` |
| `--type <t>` | Retain only memories whose `type` field equals `<t>` | Must be a valid type enum value; invalid values emit the same validation error string as the `save` gate |
| `--category <c>` | Retain only memories whose `category` field equals `<c>` | Must be a valid category enum value; memories with no `category` field are treated as `category: other` at filter time (per Schema validator default rules) |
| `--tag <tag>` | Retain only memories whose `tags` array contains `<tag>` (case-insensitive) | Can be repeated to require multiple tags; each `--tag` narrows further (AND semantics) |
| `--include-stale` | No-op at v1 — stale memories are always included in results | Flag is reserved for a future opt-out variant; parsing it is required (unknown-flag error must not fire), but its presence has no effect on the result set |

### Output ordering

Results are sorted by `updated_at` descending (most recently updated first). The sort is a string comparison against the ISO-8601 UTC timestamp in the frontmatter; because ISO-8601 timestamps sort lexicographically in UTC, no date parsing is required.

### Staleness banner

For each matched memory where `verified_at` is present and `(now - verified_at) > staleness_threshold_days` (default 90, configurable in `~/.cross-memory/config.yaml`), the rendered body is prefixed with a one-line banner:

```
(stale: last verified <N> days ago)
```

Where `<N>` is the integer number of days elapsed since `verified_at`. The banner is **inline** — prepended to the body text as part of the rendered output the user sees. It is not a separate frontmatter field and is not written to disk. Memories with no `verified_at` field are treated as not stale — no banner is applied.

### Body rendering

Two cosmetic transforms apply when rendering the body for display:

1. **`[REDACTED:private]` → `…`** — per `~/.claude/skills/cross-memory/redaction.md` (cosmetic ellipsis on recall render). The on-disk form remains `[REDACTED:private]`; only the displayed output uses `…`. This is a recall-time visual transform; the stored bytes are never modified.
2. **Other `[REDACTED:<category>]` placeholders** — rendered literally. The bracketed placeholder text is shown as-is; no substitution is applied.

### Path output

For each matching memory, the canonical file path is rendered on the line immediately before the body:

```
~/.cross-memory/<scope-dir>/<filename>
(stale: last verified <N> days ago)        ← only if staleness threshold exceeded
<rendered body>
```

The path line allows the user to locate and edit the file directly.

### Empty results

If no memories match the topic (after applying all filters), the skill outputs:

```
no memories matched topic '<topic>'
```

When one or more filter flags are also present, the message is extended:

```
no memories matched topic '<topic>' [with filters: --scope user-global --type fact]
```

The `[with filters: ...]` suffix lists only the flags the user provided, in the order they appeared on the command line.

### Cross-references

- **Enum values and validation error strings**: `## Schema validator` section above.
- **`staleness_threshold_days` config field**: `## Config` section above.
- **Cosmetic ellipsis rule (`[REDACTED:private]` → `…`)**: `~/.claude/skills/cross-memory/redaction.md`.
- **Match strategy (no indexing at v1)**: `recall` and `search` use `Glob` + `Grep` against the tree directly; no pre-built index.
- **`[CROSS-MEMORY]` injection block (always-on tier)**: the adapter renders the always-on memories as a sentinel-bounded block inside the harness-native `MEMORY.md`.

---

## Subcommand: list

Enumerate memories from the canonical store. Returns a filterable one-line summary per memory; no body rendering. Use case: "show me everything I have saved under this project" or "show me stale memories".

### Command syntax

```
/cross-memory list \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--type <feedback|project|preference|fact|rule>] \
  [--category <project-config|architecture|error-solution|preference|learned-pattern|conversation|other>] \
  [--tag <tag>] \
  [--stale-only]
```

No positional argument — `list` shows all memories that pass the applied filters. Substring matching is not performed; the full filtered set is returned.

### Filter flags

Filter flags narrow the candidate set. A memory must pass all provided filters to appear in the output. The flag set is the same as `recall` minus the positional `<topic>` argument.

| Flag | Effect | Notes |
| :--- | :--- | :--- |
| `--scope <s>` | Retain only memories whose `scope` frontmatter field equals `<s>` exactly | Accepts `user-global`, `project:<slug>`, `harness:<name>` |
| `--type <t>` | Retain only memories whose `type` field equals `<t>` | Must be a valid type enum value; invalid values emit the same validation error string as the `save` gate |
| `--category <c>` | Retain only memories whose `category` field equals `<c>` | Memories with no `category` field are treated as `category: other` at filter time (per Schema validator default rules) |
| `--tag <tag>` | Retain only memories whose `tags` array contains `<tag>` (case-insensitive) | Can be repeated; each `--tag` narrows further (AND semantics) |
| `--stale-only` | Retain only memories where `verified_at` is present and `(now - verified_at) > staleness_threshold_days` | Memories with no `verified_at` field are treated as not stale and are excluded from `--stale-only` results; threshold is from `~/.cross-memory/config.yaml` (default 90 days) |

### Output format

One line per matching memory, in the form:

```
<name> — <description> — <scope> — <tags> — <staleness>
```

Where `<staleness>` is either `stale: N days` (if the staleness threshold is exceeded) or `ok`. No body text, no frontmatter block is rendered — summary fields only.

### Output ordering

Results are sorted by `updated_at` descending (most recently updated first). Sort is a string comparison against the ISO-8601 UTC timestamp in the frontmatter; ISO-8601 timestamps sort lexicographically in UTC, so no date parsing is required.

### Archive excluded

The `~/.cross-memory/archive/` directory is never listed. Archived memories are soft-deleted predecessors that have been superseded; they are recoverable via the `audit` subcommand only, not via `list`.

### Empty results

If no memories match the applied filters, the skill outputs:

```
no memories matched [filters]
```

Where `[filters]` lists the flags the user provided. If no filter flags were provided, the message is simply `no memories matched`.

### Cross-references

- **Enum values and validation error strings**: `## Schema validator` section above.
- **`staleness_threshold_days` config field**: `## Config` section above.
- **Archive directory layout**: `## Config` → Lazy-provisioning sequence above.

---

## Subcommand: search

Grep-style full-text search across memory body content. Returns raw matched lines with their source path and line number; no body rendering, no frontmatter rendering, no synthesis. Distinct from `recall`, which is topic-targeted and may invoke synthesis.

### Command syntax

```
/cross-memory search <query> \
  [--scope <user-global|project:<slug>|harness:<name>>] \
  [--type <feedback|project|preference|fact|rule>]
```

`<query>` is a required positional argument. At least one character must be provided.

### Match style

For each memory file in scope, every line in the memory body that contains `<query>` as a case-insensitive substring is returned as a triple:

```
<canonical-path>:<line-number>: <matched-line-text>
```

Where:

- `<canonical-path>` is the full path to the memory file (e.g., `~/.cross-memory/user-global/preference_pytest-not-unittest.md`).
- `<line-number>` is the 1-based line number within that file.
- `<matched-line-text>` is the raw text of the matched line, exactly as stored on disk.

No frontmatter fields are searched — only the body content after the closing `---` of the frontmatter block. No body rendering or cosmetic transforms are applied; the output is the raw on-disk bytes of matched lines.

### Filter flags

`--scope` and `--type` narrow the candidate file set before the body scan. Only these two flags are supported — `--category` and `--tag` are not available for `search` because search is content-driven, not metadata-driven.

| Flag | Effect | Notes |
| :--- | :--- | :--- |
| `--scope <s>` | Scan only files whose `scope` frontmatter field equals `<s>` exactly | Accepts `user-global`, `project:<slug>`, `harness:<name>` |
| `--type <t>` | Scan only files whose `type` frontmatter field equals `<t>` | Must be a valid type enum value; invalid values emit the same validation error string as the `save` gate |

### Archive excluded

The `~/.cross-memory/archive/` directory is excluded from search by default. Archived memories are superseded predecessors that are no longer canonical; including them in search results would surface stale or contradicted content. If a search across archived memories is needed, use the `audit` subcommand, which can inspect the archive on demand.

### Empty results

If no lines match the query (after applying all filters), the skill outputs:

```
no matches for query '<query>'
```

When one or more filter flags are also present, the message is extended:

```
no matches for query '<query>' [in scope]
```

Where `[in scope]` describes the active filters (e.g., `in scope: user-global`).

### Cross-references

- **Enum values and validation error strings**: `## Schema validator` section above.
- **Archive directory layout**: `## Config` → Lazy-provisioning sequence above.
- **Indexing decision (no index at v1; Glob + Grep on demand)**: `search` scans file content directly using `Glob` + `Grep`; no pre-built index.

---

## Subcommand: forget

Archives the named memory and removes its index entry from the scope's `MEMORY.md`. The memory is not permanently deleted — it is moved to `~/.cross-memory/archive/` and remains recoverable. This is the only removal operation at v1; there is no "hard delete."

### Command syntax

```
/cross-memory forget <name> [--scope <s>]
```

`<name>` is a required positional argument — the memory's `name` slug (the value of the `name` frontmatter field, which is also the slug portion of the canonical filename). `--scope` defaults to `user-global`; accepted values are `user-global`, `project:<slug>`, and `harness:<name>`.

### Step 1 — Lookup

Resolve the canonical path:

```
~/.cross-memory/<scope-dir>/<type>_<name>.md
```

Where `<scope-dir>` follows the same scope-to-directory mapping used by `save` and `list`. Because the `<type>` prefix is part of the filename, the skill must enumerate all files in the scope directory whose stem ends with `_<name>` to find the match (there must be exactly one, because the name slug is unique within a scope per the Gate 4 collision rule).

If no matching file is found, output:

```
no memory named '<name>' in scope '<scope>'
```

and abort without further action.

### Step 2 — Confirmation

Display the memory's `name`, `type`, `category` (if set), and `scope`, then prompt:

```
Forget memory '<name>'? It will be archived but not auto-deleted. [y/N]
```

Default is `N`. Any input other than `y` or `Y` (case-insensitive) aborts without changes.

### Step 3 — Archive

On `y` or `Y` (case-insensitive), move the canonical file to:

```
~/.cross-memory/archive/<original-stem>-<YYYYMMDDTHHMMSSZ>.md
```

Where `<original-stem>` is the canonical filename without the `.md` extension, and the timestamp is UTC at the moment of the archive write (format: `YYYYMMDDTHHMMSSZ`, e.g., `20260508T143201Z`). This is the same archive mechanism used by the supersede branch of `save`.

**Do NOT set `superseded_by`** in the archive copy. The `superseded_by` field is exclusively for archived predecessors that were replaced by a new canonical memory. A forgotten memory has no successor — it is gone from the active store, not replaced. Adding `superseded_by` would misrepresent the reason for archival and would corrupt the supersede chain. The archive copy retains its original frontmatter without modification.

Echo the archive path to the user:

```
archived: ~/.cross-memory/archive/<original-stem>-<YYYYMMDDTHHMMSSZ>.md
```

### Step 4 — MEMORY.md update

Remove the memory's index line from the scope's `MEMORY.md`. The indexing module's line-removal rule applies: find the single line that references the canonical filename (by the `[name](path)` link pattern used when the memory was indexed) and delete it. Blank lines immediately surrounding the removed line are preserved; do not compact the file's vertical spacing. If no matching line is found (the memory was never indexed, or the index entry was already removed), skip this step silently — it is not an error.

For `project:<slug>` scope, the relevant `MEMORY.md` is the scope's own index file. The harness-native `MEMORY.md` (e.g., `~/.claude/projects/<slug>/memory/MEMORY.md`) is managed separately by the mirror-remove hook in Step 5.

### Step 5 — Mirror-remove hook

After the canonical archive in Step 3 succeeds, the forget flow determines the active adapter (via the precedence chain in `## Adapter selection` above) and dispatches:

```
active_adapter.mirror_remove(memory)
```

Where `memory` is the metadata of the archived memory (its `type`, `name`, `scope`, and the canonical path it occupied before archiving). The dispatch runs _after_ the canonical archive — the canonical operation is committed first and mirror removal follows unconditionally.

#### Success path

The active adapter deletes the harness-native mirror file (e.g., `~/.claude/projects/<slug>/memory/<type>_<name>.md`) and removes its entry from the sidecar manifest. A brief removal confirmation is appended to the user-facing output (e.g., "mirror removed from `~/.claude/projects/<slug>/memory/<type>_<name>.md`").

#### Failure paths

**Mirror file absent** — the adapter checks for the mirror file and finds it is not present (already removed by the user or a prior forget). This is not an error. The adapter records the absence and the skill continues without emitting a warning.

**Structured violation from the adapter** — for example, a sidecar/frontmatter disagreement is detected. The canonical archive is not rolled back. The skill emits a structured warning describing what failed and what the user can do to resolve it. The forget subcommand returns success.

**`generic-fallback` no-op** — the generic adapter returns its standard structured result (`harness: generic`, no mirror removed). The skill records this result and emits no warning — this is the expected silent path (see `## Mirror failure handling` above).

**Unexpected exception** — if the adapter raises a truly unhandled error, the skill catches it, emits a structured warning naming the exception, and returns success. The canonical archive is preserved.

#### Sentinel block update (forget)

After `active_adapter.mirror_remove(memory)` succeeds, the forget flow updates the harness-native `MEMORY.md` sentinel region:

1. Invoke the always-on tier filter to produce the updated entry list (the forgotten memory is now archived, so the always-on tier may shrink).
2. Invoke the injection-block formatter on the filter's output to produce the updated content bytes.
3. Call `active_adapter.update_sentinel_block(content)` to overwrite the sentinel region with the smaller content.

This call follows the same canonical-first failure-isolation rules as `mirror_remove`: a failure here is a structured warning, not an error. The canonical archive still succeeds and `mirror_remove` is not rolled back.

### Cross-references

- **Archive filename pattern and timestamp format**: `## Subcommand: save` → Supersede branch, Step 4 above.
- **`superseded_by` field rules (only on supersede, never on forget)**: `## Schema validator` and `## Subcommand: save` → Supersede branch, Step 4 above.
- **Scope-directory mapping**: `## Config` section above.
- **Indexing line-removal rule**: `## Subcommand: save` → Gate 4 (standard write path) above.
- **Active adapter selection and precedence**: `## Adapter selection` above.
- **Mirror failure handling principles**: `## Mirror failure handling` above.
- **`mirror_remove` operation contract** (removal steps, post-removal directory state, and absence handling): `adapter-claude-code.md § 4`, `adapter-cursor.md § 4`, `adapter-generic.md § 4`.

---

## Subcommand: audit

Scan the canonical cross-memory store for staleness, duplicates, contradictions, redaction misses, and missing-category curation; render a structured five-section report directly to chat; and offer per-finding actions (refresh, archive, forget, redact-now, categorize) gated by the standard write-path confirmation. No file is written to disk for the audit report.

### Command syntax

```
/cross-memory audit [--staleness-days <N>]
```

`--staleness-days <N>` overrides the `staleness_threshold_days` config field for the duration of this invocation. Any other value passed is validated as a positive integer; a non-integer or negative value aborts with a structured error.

### Default values

The staleness threshold defaults to the `staleness_threshold_days` config field (default `90`). When `--staleness-days <N>` is passed, that value supersedes the config field for this invocation only. See `## Config` for the field definition and the config file location.

### Step 1 — Build the brief

Compose the labeled-prose brief per the `## Brief Format` section in `agents/cross-memory.md`. The effective staleness threshold `<N>` is the CLI flag value if `--staleness-days` was passed, else the `staleness_threshold_days` config field value, else `90`.

```
## Task
Audit the cross-memory store for staleness, duplicates, contradictions, redaction misses, and missing-category curation.

## Scope
- ~/.cross-memory/** (read)
- ~/.claude/projects/<active-slug>/memory/MEMORY.md (read; for sentinel-block refresh)
- ~/.claude/projects/<active-slug>/memory/<type>_<slug>.md (read; for mirror collision detection)

## Acceptance Criteria
1. A structured report rendered to chat with the five sections: Stale memories, Duplicates, Contradictions, Redaction misses, Recommended actions.

## Constraints
[Shared Brief Constraints — see skills/ops/SKILL.md#shared-brief-constraints]
- intent: audit
- staleness_threshold_days: <N>
```

### Step 2 — Dispatch the cross-memory agent

Dispatch via the Agent tool with `subagent_type: cross-memory` and the brief built in Step 1. The agent is `model: opus` and reads its own definition at `agents/cross-memory.md` as its first action; the skill does not paste the agent body into the dispatch prompt. The agent inherits the per-agent self-read prompt template documented in `agents/cross-memory.md`.

### Step 3 — Render the agent's report

The agent's return value is a fenced markdown block matching the `## Output Contract — audit` shape in `agents/cross-memory.md`: five sections (Stale memories, Duplicates, Contradictions, Redaction misses, Recommended actions). The skill renders this block directly to chat.

No file is written to disk for the audit report. There is no `~/.cross-memory/audit-reports/` directory; the lazy-provisioning sequence in `## Config` does not create one. The environment block of the report names the active harness and the precedence step that selected it, consistent with the selection-logging behavior described in `## Adapter selection`.

### Step 4 — Per-finding actions

After rendering the report, the skill presents the available per-finding actions. The user picks an action by typing the action name followed by the memory identifier (e.g., `refresh feedback_strict_lane_boundaries`). The skill never auto-applies any action — every action goes through its respective confirmation gate before any change is made.

| Action | What it does | Confirmation gate |
| :--- | :--- | :--- |
| `refresh` | Sets the memory's `verified_at` frontmatter field to today's ISO-8601 UTC date | Standard write-path confirmation (mirror of save Gate 3-4): display the updated frontmatter, prompt `[y/N]`, require `y` or `Y` to proceed |
| `archive` | Moves the memory file to `~/.cross-memory/archive/<scope>/<original-stem>-<timestamp>.md` | Standard write-path confirmation: display the target archive path, prompt `[y/N]`, require `y` or `Y` to proceed |
| `forget` | Dispatches the full `/cross-memory forget <name>` flow | Standard forget-flow confirmation: `Forget memory '<name>'? It will be archived but not auto-deleted. [y/N]` — require `y` or `Y` (case-insensitive) |
| `redact-now` | Re-runs the redaction pipeline on the body and supersedes the memory with the redacted version | Standard save Gate 2-4 (redaction scan → confirm → write), treating the supersede branch as the write path |
| `categorize` | Sets the memory's `category` frontmatter field to a user-chosen value from the five-value enum | Standard save Gate 3-4: display the updated frontmatter with the chosen category, prompt `[y/N]`, require `y` or `Y` to proceed |

On any input other than a recognized action-plus-identifier, the skill re-displays the action menu. The session ends when the user issues an empty line or types `done`.

### Cross-references

- **Gate 3-4 write-path confirmation pattern**: `## Subcommand: save` above.
- **Full forget flow**: `## Subcommand: forget` above.
- **Agent brief format and output contract**: `agents/cross-memory.md` (`## Brief Format` and `## Output Contract — audit`).
- **`staleness_threshold_days` config field**: `## Config` above.
- **Harness selection and audit environment block**: `## Adapter selection` above (the audit report's environment block names the active harness and the step that selected it).

---

## Check-name vocabulary

The identifiers below are stable check names used by `--check <name>` in the `doctor` subcommand and referenced by the `init` subcommand's success-confirm step. Renaming any identifier is a breaking change. New checks are pure-add.

Each name belongs to one of five groups. Checks within a group run in declared order when the group is selected.

### Group A — canonical-integrity

| Check name | What it does |
| :--- | :--- |
| `canonical-frontmatter-parse` | Verifies every memory file's frontmatter parses against the schema validator. |
| `canonical-slug-derivation` | Verifies every project-scope file's slug derivation matches the file's directory name. |
| `canonical-memory-md-consistency` | Verifies each scope's `MEMORY.md` indexes match the on-disk file set — no orphans, no missing entries. |
| `canonical-no-duplicate-slugs` | Asserts no two files within the same scope directory share the same slug. |
| `canonical-archive-not-indexed` | Asserts `~/.cross-memory/archive/MEMORY.md` does not exist. |

### Group B — mirror-consistency

| Check name | What it does |
| :--- | :--- |
| `mirror-sidecar-frontmatter-agreement` | Verifies each sidecar-recorded mirror file has a `mirrored_from` frontmatter field pointing at the recorded canonical source. |
| `mirror-canonical-source-exists` | Verifies each sidecar entry's `canonical_source` path exists on disk. |
| `mirror-detect-collisions` | Reports the three-state classification (native / stale-mirror / user-edited) over each adapter's mirror directory without taking action. |

### Group C — sentinel-markers

| Check name | What it does |
| :--- | :--- |
| `sentinel-marker-count` | Verifies exactly one begin and one end sentinel marker are present in the active project's harness-native `MEMORY.md`. |
| `sentinel-region-bytes-fingerprint` | Computes a SHA-256 of the bytes outside the sentinel region at run start and compares against the same bytes at run end to detect unintended mutation. |
| `sentinel-region-content-parses` | Asserts the bytes between the sentinel markers parse as a valid `[CROSS-MEMORY]` injection block. |

### Group D — redaction-surface

| Check name | What it does |
| :--- | :--- |
| `redaction-denylist-parses` | Verifies `redaction.md` is present at the deployed path and the denylist table parses as expected. |
| `redaction-sampling-scan` | Samples N memories per scope (default 10, capped at 30) and scans their bodies with the Pass-B regex set. |
| `redaction-overridden-flag-audit` | Surfaces every memory with `redaction_overridden_at` set. |

### Group E — deploy-target-prep and cross-harness-validation

| Check name | What it does |
| :--- | :--- |
| `deploy-manifest-coverage` | Verifies `tooling/deploy-manifest.json` globs cover all cross-memory files and no files are unintentionally excluded. |
| `stale-shipped-artifacts` | Identifies artifacts in `~/.claude/skills/cross-memory/` and `~/.cursor/skills/cross-memory/` that have no source counterpart in the repo. |
| `cross-harness-roundtrip` | Run from harness B after a save in harness A; confirms recall can locate the canonical file across harnesses. |
| `adapter-detection` | Re-runs the adapter selection chain and reports which step won. |
| `sc-behavioral-walk` | Walks the cross-harness SCs as in-place behavioral checks; per-harness applicability is defined in `## Subcommand: doctor`. |

### Cross-references

- **Full check definitions** (findings shapes, per-harness applicability, exit-code meanings): `## Subcommand: doctor` below.
- **Init's use of check primitives**: `## Subcommand: init` below.
- **Adapter selection chain**: `## Adapter selection` above.

---

## Always-on tier

The always-on tier is a session-bootstrap filter that selects which memories surface automatically in the `[CROSS-MEMORY]` injection block at the start of every new session. It runs once per session, after the active harness adapter has been detected and the active project's slug has been determined. Its output is a filtered, deduplicated, staleness-decorated list of memory entries consumed by the injection-block formatter, which renders those entries as the `[CROSS-MEMORY]` block and writes them into the sentinel-bounded region of the harness-native `MEMORY.md`.

The filter is harness-agnostic: it consumes the adapter interface (the active harness and project slug already resolved by detection time) and does not need to know how the resulting block will be spliced into any particular harness's file layout.

### Trigger

The always-on tier filter is invoked once at session bootstrap, after:

1. The harness adapter has been detected (resolving the active harness identifier: `claude-code`, `cursor`, or `generic`).
2. The active project's slug has been determined from the current working directory, derived per the slug rule in `adapter-claude-code.md` § 2.

No subcommand invocation is required. The filter fires automatically as part of the adapter's session-start sequence.

### Inputs

| Input | Source | Notes |
| :--- | :--- | :--- |
| Active harness identifier | Harness detection (CLI flag → config field → env var → adapter probe → generic fallback) | One of `claude-code`, `cursor`, `generic` |
| Active project slug | Current working directory → slug-derivation rule | See `indexing.md` § 5 for the exact derivation; `adapter-claude-code.md` § 2 for the Claude Code implementation |
| `staleness_threshold_days` | `~/.cross-memory/config.yaml`, field `staleness_threshold_days` | Integer; default `90`; used for staleness banner computation |

### Inclusion rules

Four rules determine which memory entries are selected. Rules are applied in order; the results are merged into a single list before deduplication.

1. **User-global, type in {preference, rule, fact}.** Walk `~/.cross-memory/user-global/MEMORY.md`. Select entries whose `type` frontmatter field is one of `preference`, `rule`, or `fact`. These are the user's persistent identity — preferences, hard rules, and objective facts that apply across every project and every harness.

2. **Project:current-slug, type in {feedback, project, rule}.** Walk `~/.cross-memory/projects/<active-slug>/MEMORY.md`. Select entries whose `type` frontmatter field is one of `feedback`, `project`, or `rule`. Only the active project's scope is walked — other project scopes are not examined. If the active project slug is absent (the adapter could not determine the current project), this rule contributes zero entries and the filter continues.

3. **Harness:current-harness, type in {rule, feedback}.** Walk `~/.cross-memory/harnesses/<active-harness>/MEMORY.md`. Select entries whose `type` frontmatter field is one of `rule` or `feedback`. These are harness-specific standing rules that apply in every session under that harness.

4. **Tag = `always-on`, across all scopes.** Walk all three scope index files (`~/.cross-memory/user-global/MEMORY.md`, `~/.cross-memory/projects/<active-slug>/MEMORY.md`, and `~/.cross-memory/harnesses/<active-harness>/MEMORY.md`). Select entries whose `tags` array contains `always-on` (case-insensitive match), regardless of type. This is an explicit opt-in mechanism — the user can force any memory into the always-on tier by tagging it `always-on`.

### Deduplication

The deduplication key is the memory file's absolute canonical path (e.g., `~/.cross-memory/user-global/rule_no-commit-trailers.md`). If the same canonical path appears in the merged list more than once — for example, because a memory tagged `always-on` also matches a type-based inclusion rule — it is retained exactly once in the output.

When a canonical path appears via multiple routes, no precedence resolution is required: the underlying file is the same in all cases. The deduplication step simply removes duplicate path references and preserves one entry per canonical path. The entry's scope, type, description, tags, and staleness state all come from the canonical file — there is nothing to merge.

**The archive directory is never walked.** Memories in `~/.cross-memory/archive/` are excluded from all four rules. The archive scope has no `MEMORY.md` index file, so it is structurally unreachable by the filter. Memories move to the archive on `forget` or supersede; once archived they no longer appear in the always-on tier regardless of their type or tags.

### Staleness banner

For each entry in the filtered, deduplicated list, the filter checks whether the entry's `verified_at` frontmatter field indicates a stale memory:

- If `verified_at` is present and `(today_utc - verified_at) > staleness_threshold_days`, a staleness banner is appended inline to the entry's description field.
- The banner format is: `(stale: last verified <N> days ago)` where `<N>` is the integer number of days elapsed since `verified_at`.
- The banner lives at the end of the `description` string and travels with the bullet into the injection block. It is not a separate frontmatter field and is never written to disk — it is a rendering-time annotation applied only when building the output list.
- If `verified_at` is absent, the entry is treated as not stale. No banner is applied. Absence of `verified_at` is not an error.

**Example:** if `staleness_threshold_days` is `90` and a memory's `verified_at` was 113 days ago, the description `"Use pytest for all new Python tests"` becomes `"Use pytest for all new Python tests (stale: last verified 113 days ago)"` in the output entry.

### Output

The filter produces an ordered list of structured entries. Each entry is a tuple:

```
(scope, type, name, description_with_banner, tags)
```

Where:

- `scope` — the memory's `scope` frontmatter field (e.g., `user-global`, `project:D--Repositories-Personal-Git-AI-Skills-Agents`, `harness:claude-code`).
- `type` — the memory's `type` frontmatter field (one of the five type enum values from `## Schema validator`).
- `name` — the memory's `name` frontmatter field.
- `description_with_banner` — the memory's `description` frontmatter field with the staleness banner appended inline, or the bare `description` if no banner applies.
- `tags` — the memory's `tags` frontmatter array (flat list of strings; may be empty).

The list order is: user-global entries first (Rule 1), then project entries (Rule 2), then harness entries (Rule 3), then any additional entries that entered solely via the `always-on` tag (Rule 4) that did not already appear from Rules 1–3. Within each group, entries are ordered by `updated_at` descending (most recently updated first).

This list is consumed by the injection-block formatter, which formats the entries into the three sub-sections (`User Profile:`, `Project Knowledge:`, `Relevant Memories:`) and applies the size budget. The always-on filter does not own block layout — that is the injection-block formatter's responsibility (see Injection block section below).

### Edge cases

| Scenario | Behavior |
| :--- | :--- |
| A scope's `MEMORY.md` is missing | Treat as an empty list. The rule for that scope contributes zero entries. No error is raised; the filter continues with the remaining rules. |
| `verified_at` is absent from a memory's frontmatter | Treat as not stale. No staleness banner is applied. |
| The user-global scope is empty | Rule 1 contributes zero entries. The filter still runs and the remaining rules are evaluated normally. |
| The active project slug is unavailable | Rule 2 is skipped entirely. Its `MEMORY.md` path cannot be determined without a slug, so it contributes zero entries. |
| All three scope index files are empty or missing | The filter produces an empty list. The injection-block formatter receives an empty list and decides whether to render an empty block or skip the block entirely — the filter does not make that call. |
| A memory has `tag: always-on` AND matches a type-based rule | The memory appears in the merged list from two routes (the type rule and Rule 4). Deduplication retains it once. One entry, not two. |
| A memory's type matches a type rule but the memory is in the archive directory | Excluded. The filter walks only the three canonical scope index files. `~/.cross-memory/archive/` has no `MEMORY.md` and is never walked. |

### Cross-references

- **Slug derivation rule** (how the active project slug is computed from the current working directory): `adapter-claude-code.md` § 2.
- **Claude Code slug derivation and pre-flight confirmation**: `adapter-claude-code.md` § 2.
- **Scope index file layout** (which paths carry a `MEMORY.md` and the line format used): `~/.claude/skills/cross-memory/indexing.md` § 1–2.
- **`staleness_threshold_days` config field**: `## Config` section above.
- **Injection-block formatter** (consumes this filter's output list and produces the `[CROSS-MEMORY]` block bytes, including sub-section layout, size-budget enforcement, and sentinel-bounded write): see Injection block section below.
- **Adapter interfaces** (how the filter's output is handed off to the harness-specific sentinel write): `adapter-claude-code.md` § 6 (`update_sentinel_block`).

---

## Injection block

The injection-block formatter consumes the ordered entry list produced by the always-on tier filter and renders the bytes that the harness adapter splices between the `<!-- cross-memory:begin -->` and `<!-- cross-memory:end -->` sentinel markers in the harness-native `MEMORY.md`. The formatter is strictly a renderer: it takes entries in, produces bytes out, and makes no decisions about scope selection, staleness, or deduplication — all of that is the filter's job.

### Output contract

The formatter's output is **exactly** the bytes the adapter passes to `update_sentinel_block(content)`. The formatter does **not** emit the sentinel marker lines themselves — those are part of the file structure managed by the adapter. The output begins with the `[CROSS-MEMORY]` header line and ends with the last sub-section's last bullet line. There is no trailing blank line and no trailing marker in the formatter's output.

This means:

- The adapter writes `<!-- cross-memory:begin -->\n`, then the formatter's output, then `\n<!-- cross-memory:end -->` (the exact byte layout is the adapter's concern; the formatter is unaware of it).
- If the formatter produces zero bytes (see empty-list edge case below), the region between the markers is empty — the markers remain present but contain nothing.

### Block structure

A fully populated block looks like this:

```
[CROSS-MEMORY]

User Profile:
- <bullet 1>
- <bullet 2>

Project Knowledge:
- <bullet 1>
- <bullet 2>
```

Key layout rules:

- There is **one blank line** after the `[CROSS-MEMORY]` header line (before the first sub-section).
- There is **one blank line** between sub-sections.
- There is **no blank line** after the last bullet of the last sub-section — the formatter's output ends with that bullet line.
- Sub-section headers use the form `<Name>:` — a plain text label terminated with a colon, not a Markdown heading. This keeps the always-on injection block visually flat inside the harness's MEMORY.md.

At v1, the block contains **two active sub-sections**: `User Profile:` and `Project Knowledge:`. The `Relevant Memories:` sub-section is reserved in the design but not emitted at v1 (see Relevant Memories below).

### Sub-section sourcing rules

#### User Profile

The `User Profile:` sub-section is populated from two sources, combined in this order:

1. All filter Rule 1 entries — scope `user-global`, type in `{preference, rule, fact}`.
2. All filter Rule 3 entries (harness-scope) — scope `harness:<current-harness>`, type in `{rule, feedback}`.

The harness-scope entries (Rule 3) are folded into User Profile rather than given their own sub-section. This is a deliberate v1 simplification: harness-specific standing rules are user-level rules that happen to be harness-specific. A dedicated harness sub-section would be sparse in practice (most users have few harness-scoped memories) and would add visual noise without benefit. The fold collapses two structurally similar categories into a single coherent identity block.

Additionally, any `tag=always-on` entries from the `user-global` scope that entered via Rule 4 (and were not already selected by Rule 1) are appended at the end of the User Profile list. Plus any `tag=always-on` entries from the harness scope that entered via Rule 4 (and were not already selected by Rule 3) — these fold into User Profile alongside the harness-scope Rule 3 entries.

Within each source group, entries are ordered as delivered by the filter (most recently updated first within each group). Source groups appear in the order listed above — Rule 1 entries, then Rule 3 entries, then Rule 4 user-global additions, then Rule 4 harness-scope additions.

#### Project Knowledge

The `Project Knowledge:` sub-section is populated from:

1. All filter Rule 2 entries — scope `project:<current-slug>`, type in `{feedback, project, rule}`.
2. Any `tag=always-on` entries from the `project:<current-slug>` scope that entered via Rule 4 and were not already selected by Rule 2.

Entries are ordered as delivered by the filter (most recently updated first within each group).

If no active project slug was resolved (the adapter could not determine the current project), Rule 2 contributes zero entries and the sub-section is omitted from the output.

#### Relevant Memories — deferred at v1

The `Relevant Memories:` sub-section is **reserved** in the injection block design but is **not emitted at v1**. Its header line is not written, and no bullets are produced for it. The sub-section will be populated in a future release by a relevance-ranking step that scores memories against the current session context. At v1 the always-on tier surfaces every qualifying memory via type and tag rules rather than ranking — there is no ranking signal to drive a relevance sub-section.

This is not a gap or omission; it is an explicit deferral. The sub-section slot is documented here so the formatter spec is complete: when relevance ranking is introduced post-v1, the `Relevant Memories:` sub-section will be inserted after `Project Knowledge:` and will carry its own drop-priority position in the size budget.

### Bullet format

Each memory entry is rendered as a single Markdown list item:

```
- <description_with_banner>
```

The leading `- ` prefix is literal (hyphen, space). The `<description_with_banner>` field is the `description_with_banner` value from the filter output tuple — the memory's `description` frontmatter field with the staleness banner appended if applicable.

**120-character cap.** The rendered bullet (excluding the leading `- `) is capped at **120 characters**. If `description_with_banner` exceeds 120 characters, the description portion is truncated and a `…` (Unicode ellipsis, U+2026, single character) is appended such that the full `description_with_banner` in the rendered bullet is exactly 120 characters. The truncation preserves the staleness banner: if a staleness banner is present, the description is shortened to make room, not the banner.

**Truncation with staleness banner.** When a staleness banner is present, the cap is applied to the full `description_with_banner` string. If that string exceeds 120 characters, the description is shortened (from its right end) until `<shortened_description> + <banner>` fits within 120 characters, then `…` replaces the last character of the shortened description (keeping the total at exactly 120). The banner is never truncated.

**No metadata.** The bullet contains only the `description_with_banner` value. No memory `name`, `type`, `category`, `scope`, `verified_at`, or confidence score is rendered. No bullet IDs, no source attribution. The simplest possible line.

### Size budget enforcement

The formatter must fit its output within the byte budget configured by `max_inject_chars` (default: 2048 bytes). The budget is measured in UTF-8 encoded bytes of the formatter's full output string. When the output would exceed the budget, sub-sections are dropped in a defined priority order until the output fits.

#### Drop priority

Sub-sections drop in this order (last item drops first, first item drops last):

1. **`[CROSS-MEMORY]` header line** — **never dropped**. The header line always appears in the output. If even the bare header line (seven bytes: `[CROSS-MEMORY]`) does not fit within the budget, the formatter emits **zero bytes** rather than a partial header. A 2048-byte budget is unlikely to be smaller than the header, but the rule is documented for completeness.
2. **User Profile sub-section** — drops last. User Profile represents the most stable, identity-shaping context. It is the last sub-section to be sacrificed.
3. **Project Knowledge sub-section** — drops second-to-last. Project Knowledge is valuable but more volatile than user identity.

The `Relevant Memories:` sub-section is already deferred at v1 and does not participate in drop-priority at this time. When introduced post-v1, it will occupy the first-to-drop position.

Harness-scope entries (Rule 3), folded into User Profile, drop together with User Profile — they do not get independent drop-priority.

#### Sub-section atomicity

A sub-section either fits in full or is dropped entirely. Partial sub-sections are not emitted. The user-experience cost of a half-rendered sub-section (a header with only some of its bullets) is worse than its complete omission, because a partial block gives a misleading picture of the memory tier's content.

When computing whether a sub-section fits within the remaining budget, the formatter must account for **all bytes** the sub-section would contribute:

- The sub-section header line (e.g., `User Profile:\n`).
- The blank line preceding the sub-section header (one `\n`).
- Every bullet line (`- <description_with_banner>\n`).

If the total byte cost of the sub-section plus all previously committed bytes exceeds `max_inject_chars`, the sub-section is dropped in its entirety.

#### Within-sub-section bullet trimming

Before applying whole-sub-section drop, the formatter trims individual bullets bottom-to-top (lowest-priority bullet drops first). The filter's sort order establishes priority: within a sub-section, the last entry in the sorted list is the first to be trimmed. Bullets are dropped one at a time until either the sub-section fits within the remaining budget or no bullets remain (in which case the sub-section itself is dropped — an empty sub-section is not emitted).

The combination of bullet trimming and whole-sub-section drop means:
1. Try to fit the full sub-section. If it fits, emit it.
2. If it does not fit, drop bullets bottom-to-top until it does.
3. If trimming all bullets still doesn't bring the cost within budget (i.e., even the sub-section header alone overflows), drop the entire sub-section.

### Edge cases

| Scenario | Behavior |
| :--- | :--- |
| Filter returns an empty list | Emit only the `[CROSS-MEMORY]` header line (seven bytes plus a trailing newline). No sub-section headers, no bullets. This signals the always-on tier is active but has no qualifying entries for this session. Emitting the header alone rather than zero bytes allows the user to confirm the skill is wired up correctly — an empty block is a meaningful signal. |
| All sub-sections fit within budget | Emit the complete block with all sub-sections and all bullets. No truncation. |
| User Profile fits but Project Knowledge does not | Drop Project Knowledge. Emit the header line and the User Profile sub-section. (Drop priority: Project Knowledge drops before User Profile.) |
| Project Knowledge fits but User Profile does not | Drop User Profile. Emit the header line and the Project Knowledge sub-section only. This is unusual — User Profile is typically smaller and more stable — but the drop priority is applied mechanically regardless. |
| A single bullet's description exceeds 2048 bytes on its own | Apply the 120-character cap first. A 120-character bullet is 122 bytes (120 + `- ` prefix); well within the default 2048-byte budget. In practice, a single bullet will not exhaust the budget on its own under default config. If a user sets `max_inject_chars` to an unusually small value (e.g., 64 bytes), bullets that cannot coexist with even the sub-section header are dropped at the bullet-trimming step. |
| A staleness banner inflates a bullet past 120 characters | The 120-character cap is applied to `description_with_banner` as a whole. The description is shortened to make room for the banner. The banner text is never truncated — only the description is shortened. The truncated description ends with `…`, and the full rendered bullet is exactly 120 characters. |
| `max_inject_chars` is set below the header length (pathological config) | Emit zero bytes. The formatter does not emit a partial header under any circumstance. |

### Cross-references

- **Always-on tier filter** (produces the ordered entry list this formatter consumes): `## Always-on tier` section above.
- **`update_sentinel_block` operation** (how the formatter's output bytes are spliced between the sentinel markers in the harness-native `MEMORY.md`): `adapter-claude-code.md` § 6.
- **`max_inject_chars` config field** (controls the byte budget): `## Config` section above.

---

## Context Resilience

If the conversation thread is summarized, compacted, or interrupted mid-flow, recover by:

1. **Re-read this file** at `~/.claude/skills/cross-memory/SKILL.md` to restore the full subcommand specifications and gate semantics.
2. **If a save was in progress** (Gate 3 confirmation pending or Gate 4 write underway), do NOT assume the file was written. Re-examine `~/.cross-memory/<scope-dir>/` for partial files or stale staging artifacts. If the canonical file exists with the expected `name` slug, the save completed; if not, treat the prior invocation as aborted.
3. **If `MEMORY.md` appears out of sync** (an entry references a file that no longer exists, or a file is on disk but absent from the index), regenerate the affected scope's `MEMORY.md` from the files actually present per `~/.claude/skills/cross-memory/indexing.md` line format.
4. **Emit a recovery message** with the **`Cross-Memory`** badge naming what was recovered and what is still in flight.

## Constraints

- No compound Bash commands — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls instead — use parallel calls for independent commands.
- No `cd` prefix — the working directory is already the project root. Run commands directly instead of `cd "/path/to/project" && command`.
- Use relative paths from the project root — never use absolute paths in Bash commands. Only use absolute paths for resources genuinely outside the project (e.g., `~/.cross-memory/`, `~/.claude/`).
- Temporary files go in the **project root** (e.g., `_tmp_test.py`, `_tmp_payload.json`) — never in `/tmp/`, `%TEMP%`, or any path outside the project. Paths outside the project trigger sensitive-file prompts. Use the `_tmp_` prefix. Do not delete individually — clean up in batch at checkpoints with `rm _tmp_*`.
- **Never write to a memory file without passing the confirmation gate** — the Gate 3 confirmation (or auto-propose `[y/N]` prompt) must complete before any disk write occurs. There is no "silent save" path.
- **Never hard-delete** — the only removal operation is archive (move to `~/.cross-memory/archive/`). Permanent deletion is out of scope at v1.
- **Canonical → mirror direction only** — never read from a mirror copy as authoritative state. The canonical `~/.cross-memory/` store is the source of truth; adapters write *to* harness-native locations, not *from* them.

## Output Tagging

**`Cross-Memory`** appears on the **opening line** of each assistant turn only. Do **not** prefix every bullet or heading in the same turn.

The **first line** of each assistant turn for this command MUST begin with: **`Cross-Memory`**

Continuation lines within the same turn (sub-items, indented details, bullet lists, tables) do NOT repeat the badge. Only the opening line carries it.

Apply the badge on the opening line of turns that contain: save confirmations, recall results, list output, forget confirmations, search results, audit output, status/progress messages, validation errors, and auto-propose proposals.

**Format:** **`Cross-Memory`** (bold backtick-wrapped) as the **first element** on the **opening line** of the turn.
