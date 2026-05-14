<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Adapter selection

The active adapter is determined once per subcommand invocation, before any mirror operation is dispatched. The selection follows a five-step precedence chain — first match wins. Steps are evaluated in order; as soon as one step resolves to a valid harness name, evaluation stops and that harness is used.

## Step 1 — CLI flag

Syntax: `--harness <name>` where `<name>` is one of `claude-code`, `cursor`, or `generic`.

The flag is parsed at the top of every subcommand invocation, before any other precedence step is evaluated. An invalid `<name>` (any value not in the registered set `{claude-code, cursor, generic}`) fails fast with a structured error and does not fall through to the next step:

```
error: unknown harness 'foo'. Valid values: claude-code, cursor, generic
```

When valid, this flag wins unconditionally. No warning is emitted, no other signal is consulted. The user is overriding detection — the skill respects that intent without comment.

## Step 2 — Config field

File: `~/.cross-memory/config.yaml`. Field: `current_harness:` with value `claude-code`, `cursor`, or `generic`.

When the field is absent from the config, or when the config file itself does not exist, this step produces no result and evaluation falls through to Step 3.

When the field is present but its value is not in the registered set, the skill logs a structured warning and treats the field as absent — precedence falls through to Step 3 rather than failing fast:

```
warning: config field 'current_harness' has unrecognized value '<value>'; ignoring and falling through to env-var check
```

This "warn and continue" behavior is deliberate: config corruption (a typo, a manually edited file) should not break the skill. The persistent config is more authoritative than an env var — it represents a deliberate per-machine choice — which is why it is evaluated before Step 3.

## Step 3 — Environment variable

Variable: `CROSS_MEMORY_HARNESS`. Value: `claude-code`, `cursor`, or `generic`.

When the variable is unset or empty, this step produces no result and evaluation falls through to Step 4.

When the variable is set but its value is not in the registered set, the skill logs a structured warning and treats the variable as absent — precedence falls through to Step 4:

```
warning: env var CROSS_MEMORY_HARNESS has unrecognized value '<value>'; ignoring and falling through to adapter probe
```

Env vars rank below the config field because they are session-scoped and easier to typo in shell aliases or CI job definitions. A persistent config entry is a more deliberate signal of the user's intent for a given machine.

## Step 4 — Adapter manifest probe

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

## Step 5 — Generic fallback

If Steps 1–4 all fail to select a harness, the generic adapter is used. The generic adapter requires no detection signals of its own and is always available. It is the documented behavior for environments where neither Claude Code nor Cursor is installed — sandboxed CI runners, minimal containers, or bare terminal sessions. See `adapter-generic.md § 1` for the full list of situations where the generic adapter is the right choice.

## Selection logging and observability

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

## Edge cases and pitfalls

**CLI flag overrides everything, including a config that disagrees.** No warning is emitted. When the user passes `--harness generic` on a machine where `~/.cross-memory/config.yaml` has `current_harness: claude-code`, the generic adapter is used for that invocation and the config is silently ignored. This is the intended behavior — explicit CLI intent beats persistent configuration.

**Adapter-specific env vars are not precedence signals.** Variables like `CLAUDE_CODE_VERSION` or `CURSOR_SESSION_ID` participate in adapter probe logic (Step 4) as detection signals within their respective adapter's detection function. They are not read by the precedence chain itself. Only `CROSS_MEMORY_HARNESS` is the Step 3 precedence signal.

**Detection function timeout at session bootstrap.** Because adapter detection runs before any subcommand logic, a hung detection function would block the entire invocation. The 250 ms timeout is enforced per-adapter. If both the Claude Code and Cursor adapters time out (each counted separately), the total overhead before reaching the generic fallback is at most 500 ms. This worst case is uncommon but worth knowing about when cross-memory is used in latency-sensitive automation.

**Config corruption falls through, not fails fast.** An invalid `current_harness` value in the config is treated as absent (warn and continue), not as a hard error. This means a corrupted config silently degrades to env-var or probe detection rather than breaking the skill. The structured warning gives the user enough information to fix the config; the skill stays usable.

## Cross-references

- **Dispatch points that consume this selection** — `subcommand-save.md § Mirror hook — standard save` and `subcommand-forget.md § Step 5 — Mirror-remove hook`.
- **Per-adapter detection signals** — `adapter-claude-code.md § 1`, `adapter-cursor.md § 1`, `adapter-generic.md § 1`.
- **Config field `current_harness`** — `## Config` above.
