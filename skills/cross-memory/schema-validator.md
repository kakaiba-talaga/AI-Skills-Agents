<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Schema validator

Every memory written through this skill is validated against the canonical frontmatter schema before any disk write occurs. Invalid files are rejected with a human-readable error message; the write is aborted and no file is created or modified.

## Required fields

| Field | Type | Allowed values | Description |
| :--- | :--- | :--- | :--- |
| `name` | string | (free text) | Human-readable title; should match the file's slug |
| `description` | string | (free text) | One-line summary of the memory's content |
| `type` | enum | see [Type enum](#type-enum) below | Origin-based classification of the memory |
| `scope` | enum pattern | see [Scope enum](#scope-enum) below | Defines visibility and storage location |
| `tags` | array of strings | any strings; may be empty | Flat, case-insensitive tags; required but may be `[]` |
| `created_at` | ISO-8601 UTC timestamp | e.g., `2026-05-08T14:32:01Z` | Set on first write; immutable thereafter |
| `updated_at` | ISO-8601 UTC timestamp | e.g., `2026-05-08T14:32:01Z` | Refreshed on every supersede |

## Optional fields

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

## Default rules

- **`tags`**: defaults to `[]` (empty array) when the field is omitted from user input. The validator still **requires** the field to be present in the written frontmatter — a missing `tags` key after normalization is a rejection.
- **`category`**: absent by default. The validator does **not** insert `category: other` on write. Absence is the canonical "uncategorized" signal. At read time, missing `category` is treated as `category: other` by all filtering logic.

## Enum values

### Type enum

Valid values for the `type` field:

| Value | Meaning |
| :--- | :--- |
| `feedback` | Feedback, corrections, or instructions the user has given |
| `project` | Project-specific facts, conventions, or status |
| `preference` | User preferences about tools, style, or workflow |
| `fact` | Objective facts or reference data to be remembered |
| `rule` | Explicit rules the agent must follow |

### Scope enum

The `scope` field must match one of three exact patterns:

| Pattern | Example | Notes |
| :--- | :--- | :--- |
| `user-global` | `user-global` | Applies across all projects and harnesses |
| `project:<slug>` | `project:D--Repositories-Personal-Git-AI-Skills-Agents` | Slug is the harness-derived directory name; the `<slug>` portion is required |
| `harness:<name>` | `harness:claude-code` | Harness-specific scope; the `<name>` portion is required |

A bare `project` or `harness` without a colon-and-slug suffix is invalid.

### Category enum

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

## Reject behavior — literal error strings

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
