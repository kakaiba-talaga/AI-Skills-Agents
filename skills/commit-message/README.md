# Commit Message

Generates git commit messages following Conventional Commits conventions. Analyzes your staged or unstaged changes, determines the type and scope, and produces a ready-to-use message.

## How it works

```
Gather changes --> Analyze & categorize --> Generate message --> Present for review
```

1. Reads `git status`, `git diff --staged`, `git diff`, and recent commit history
2. Identifies the commit type (`fix`, `feat`, `refactor`, etc.) and scope from the changes
3. Picks up issue/ticket numbers from branch names or context
4. Generates a subject line + body bullets and presents them for you to copy

## Quick start

```bash
# Generate from staged changes (default)
/commit-message

# Explicitly target staged changes
/commit-message staged

# Override the scope
/commit-message --scope api

# Include issue numbers
/commit-message --issue 123

# Multiple issues
/commit-message --issue 42 --issue 87

# Combine flags
/commit-message staged --scope auth --issue 156
```

## Flags

| Flag | Effect |
|---|---|
| `staged` | Analyze only staged changes (`git diff --staged`) |
| `--scope <value>` | Override auto-detected scope (e.g., `--scope api`) |
| `--issue <number>` | Include issue number with `#` prefix. Repeatable for multiple issues. |

When no arguments are given, staged changes are analyzed first. If nothing is staged, falls back to unstaged changes and notes this.

## Commit types

The skill auto-detects the appropriate type from your changes:

| Type | When used |
|---|---|
| `feat` | New feature or capability added |
| `fix` | Bug fix |
| `refactor` | Code restructuring without behavior change |
| `docs` | Documentation changes only |
| `style` | Formatting, whitespace, semicolons -- no logic change |
| `test` | Adding or updating tests |
| `chore` | Maintenance, config, dependencies, tooling |
| `build` | Build system or external dependency changes |
| `ci` | CI/CD pipeline changes |
| `perf` | Performance improvement |

## Message format

### Subject line

```
type(scope): #issue Short imperative description.
```

- **Imperative mood**: fix, add, update, remove, refactor (not "fixed", "adds", "updating")
- **Under 72 characters** when possible
- **Ends with a period**
- **Scope** auto-detected from the primary area of change (or overridden with `--scope`)
- **Issue numbers** prefixed with `#` when available

### Body bullets

```
- Past-tense explanation of what was done and why.
- Another change with context on the reasoning.
```

- **Past tense** -- describes completed work ("Added validation" not "Add validation")
- **Focus on why and what changed**, not just what
- **Code references in backticks**: function names, variables, files, CLI flags, commands
- **Proper grammar and sentence structure**
- Each bullet starts with `- ` and ends with `.`

## Output

The generated message is presented in a fenced code block for easy review and copy:

```
fix(auth): #156 Fix token refresh race condition.

- Added mutex lock around the token refresh flow in `auth_client.py` to prevent
  concurrent requests from triggering duplicate refreshes.
- Updated `refresh_token()` to check token validity before attempting refresh,
  avoiding unnecessary network calls.
```

Every message is prefixed with the **`Commit`** badge.

## Issue detection

Issue numbers are sourced from (in priority order):

1. Explicit `--issue` flags
2. Branch name patterns (e.g., `feature/123-add-login`, `fix/PROJ-456`)
3. Recent conversation context

When detected, issues appear in the subject line with `#` prefix: `feat(auth): #123 Add login flow.`

## Scope detection

The scope is auto-detected from the primary area of change:

- If most changes are in `src/api/`, scope is `api`
- If changes span `tests/` only, scope is `test`
- If changes are in `docs/`, scope is `docs`
- For single-file changes, scope derives from the file's directory
- Override with `--scope` when auto-detection doesn't fit

## Examples

### Basic usage

```bash
# Generate from staged changes
/commit-message

# Generate from staged changes (explicit)
/commit-message staged
```

### With scope override

```bash
# Force scope to "api"
/commit-message --scope api

# Force scope to "cli"
/commit-message --scope cli

# Force scope to "db"
/commit-message staged --scope db
```

### With issue references

```bash
# Single issue
/commit-message --issue 42

# Multiple issues
/commit-message --issue 42 --issue 87

# Issue + scope
/commit-message --scope auth --issue 156

# Issue + staged
/commit-message staged --issue 99
```

### Full combinations

```bash
# Staged changes, custom scope, with issue
/commit-message staged --scope api --issue 123

# Multiple issues with scope override
/commit-message --scope auth --issue 42 --issue 87

# Staged, scoped, multi-issue
/commit-message staged --scope payments --issue 200 --issue 201
```

### Example outputs by type

**Feature:**
```
feat(auth): #123 Add OAuth2 login flow.

- Implemented `OAuth2Client` class in `src/auth/oauth.py` with support for
  authorization code and refresh token grants.
- Added `/auth/callback` endpoint to handle provider redirects.
```

**Bug fix:**
```
fix(api): #456 Fix null pointer on empty response body.

- Added null check in `parse_response()` before accessing `.data` field.
- Returned empty list instead of crashing when API returns 204 No Content.
```

**Refactor:**
```
refactor(models): Extract validation logic into shared module.

- Moved duplicate validation from `User` and `Organization` models into
  `src/models/validators.py`.
- Replaced inline regex patterns with named validator functions.
```

**Chore:**
```
chore(deps): Update dependencies to latest patch versions.

- Bumped `express` from 4.18.2 to 4.18.3 (security patch).
- Updated `typescript` from 5.3.2 to 5.3.3.
- Regenerated `package-lock.json`.
```
