<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Brief injector

## Purpose

The brief injector is a parameterized selector that reads `~/.cross-memory/**` at dispatch time and produces UTF-8 bytes suitable for rendering under a `## Project Knowledge` heading in a subagent brief. It is the bridge between the durable canonical store and the per-dispatch brief surface: where the always-on tier fires once at session bootstrap to populate the harness-native `MEMORY.md`, the brief injector fires once per qualifying dispatch to carry the relevant subset of standing rules into the agent's isolated context. The file is a thin composer — it calls `skills/cross-memory/always-on-tier.md` and `skills/cross-memory/injection-block.md` unchanged, adds an agent-type tag intersection step on top of the filter output, and strips the `[CROSS-MEMORY]` header line before returning the bytes. Empty bytes signal "skip injection."

---

## Function signature

```
brief_injector(
    agent_type:                    str,   # The dispatched agent type, e.g. "executor", "git-master", "ssh-executor"
    task_subject:                  str,   # One-line description of the task being dispatched
    stage:                         str,   # Pipeline stage identifier, e.g. "implement", "verify", "deploy"
    attempt:                       int,   # Dispatch attempt number; 1 for the first dispatch of a task
    prior_handoff:                 str | None,  # Full body of the upstream handoff file, or None if attempt == 1
    enable_agent_type_intersection: bool, # When True, apply agent-type tag intersection to filter by agent_type
    budget_chars:                  int,   # Maximum UTF-8 character budget for this dispatch; overrides config default
) -> bytes  # UTF-8 bytes ready to render under "## Project Knowledge"; empty bytes = skip injection
```

**Parameter notes:**

- `agent_type` drives the agent-type tag intersection when `enable_agent_type_intersection` is `True`. It is also the value tested against `exclude:<agent>` negative tags. The value is the agent's registered name as it appears in `agents/*.md`.
- `task_subject` and `stage` are passed to the always-on tier filter for future extensibility. At v1 neither is used as a filter input — all selection is type-based and tag-based.
- `attempt` is used only by the **orchestrator's predicate** to decide whether to call this function at all; the function itself does not change behavior based on `attempt`.
- `prior_handoff` is likewise a predicate input, not a selector input. The function ignores `prior_handoff` internally — it is listed here for completeness because the orchestrator resolves it before the call.
- `budget_chars` overrides the `max_brief_inject_chars` config field for this single call. The orchestrator passes the call-site budget; the function does not re-read the config for this field.

---

## Composition rules

The selector runs four steps in order:

**Step 1 — Always-on tier filter.** Call the filter defined in `skills/cross-memory/always-on-tier.md` with the active harness identifier and project slug already resolved. The filter walks the three canonical scope index files (`~/.cross-memory/user-global/MEMORY.md`, `~/.cross-memory/projects/<slug>/MEMORY.md`, `~/.cross-memory/harnesses/<harness>/MEMORY.md`), applies its four inclusion rules, deduplicates by canonical path, and appends staleness banners. This step is called **unchanged** — the brief injector does not modify the filter's logic or its output tuple list.

**Step 2 — Agent-type tag intersection (conditional).** When `enable_agent_type_intersection` is `True`, the selector applies the tag intersection step on the tuples returned by step 1:

- Retain every tuple whose `tags` array contains the dispatched `agent_type` as a positive tag (bare name match, case-insensitive).
- Retain every tuple whose `tags` array contains no agent-type tags at all (neither positive bare names nor `exclude:` prefix tags). The un-tagged-default rule applies: memories with no agent-type tag in `tags[]` are included by default.
- Drop every tuple whose `tags` array contains `exclude:<agent_type>` (the negative tag for the dispatched agent type) regardless of whether it also carries a positive agent-type tag. The `exclude:` prefix wins precedence when both apply.
- Tuples that pass the intersection step proceed to step 3.

When `enable_agent_type_intersection` is `False` (as when the orchestrator's override flag is set to `always`), skip this step entirely and pass all tuples from step 1 to step 3.

**Step 3 — Injection-block formatter.** Call the formatter defined in `skills/cross-memory/injection-block.md` with the filtered tuple list and the `budget_chars` value as the effective `max_inject_chars` ceiling. The formatter produces the `[CROSS-MEMORY]` block with `User Profile:` and `Project Knowledge:` sub-sections, applies the 120-character bullet cap, enforces the byte budget with its drop-priority cascade, and returns the block bytes.

**Step 4 — `[CROSS-MEMORY]` header strip.** Remove the first line of the formatter's output — the `[CROSS-MEMORY]` header line and the blank line that follows it. The sub-sections `User Profile:` and `Project Knowledge:` are kept intact. This strip is a **hard rule**: the `[CROSS-MEMORY]` label is the harness-native injection preamble and is not appropriate as a Markdown section heading inside a brief. The bytes returned to the orchestrator begin at the first sub-section header (e.g., `User Profile:\n`). If the formatter returned only the `[CROSS-MEMORY]` header line (because the filter produced an empty list), stripping it results in empty bytes — and empty bytes signal "skip injection."

---

## Tag vocabulary

The agent-type tag intersection step recognizes two tag forms in the `tags[]` array of each memory (the array schema is defined in `skills/cross-memory/schema-validator.md`):

**Positive tag — bare agent name.** A tag that exactly matches an agent's registered name, e.g. `executor`, `git-master`, `ssh-executor`, `verifier`, `documentor`. When a memory carries a positive tag for the dispatched `agent_type`, that memory is included in the intersection result. Positive tags express "this memory is relevant to this agent type."

**Negative tag — `exclude:` prefix.** A tag of the form `exclude:<agent_name>`, e.g. `exclude:executor`, `exclude:git-master`. When a memory carries a negative tag matching the dispatched `agent_type`, it is dropped from the intersection result for that dispatch. Negative tags express "do not surface this memory to this specific agent type." The `exclude:` prefix is intentionally narrow — it gates out one agent type at a time, not a category of agents.

**Precedence rule.** When a memory carries both a positive tag and a negative tag for the same `agent_type` (e.g., both `executor` and `exclude:executor`), the negative tag wins. The memory is dropped for that dispatch. This prevents tag-list errors from accidentally surfacing sensitive or irrelevant context.

**Un-tagged-default behavior.** A memory whose `tags[]` array contains **no agent-type tags at all** (no bare agent names, no `exclude:` prefixes — even if other non-agent tags are present) is included by default. The un-tagged-default rule preserves backward compatibility: existing memories saved before the agent-type tag vocabulary was introduced carry no agent-type tags, and they should continue to appear in injections for all agent types. Only an explicit `exclude:<agent>` filters them out for a specific agent type.

**Interaction with `enable_agent_type_intersection=False`.** When the orchestrator sets this parameter to `False` (e.g., because the override flag is set to `always`), the intersection step is skipped entirely. All memories returned by the always-on tier filter proceed to the formatter regardless of their agent-type tags. The `exclude:` prefix has no effect in this mode — the broader filter applies.

---

## Budget rule

The selector reads `max_brief_inject_chars` from `~/.cross-memory/config.yaml` as the default per-dispatch budget (default value: `4096`). This field is distinct from `max_inject_chars` (default `2048`), which governs the sentinel-block surface used by the harness-native `MEMORY.md` injection. The separation prevents a future tuning of either surface from accidentally affecting the other.

The `budget_chars` parameter passed to the function overrides the config value for the current call. The orchestrator is responsible for computing the appropriate call-site budget (e.g., reserving headroom for other optional sections in the brief) and passing it explicitly. If the config file is absent or `max_brief_inject_chars` is not present, the function falls back to the default value of `4096` without error.

The budget is enforced by the injection-block formatter (step 3) via its existing drop-priority cascade: `Project Knowledge:` drops before `User Profile:`; bullets trim bottom-to-top within a sub-section before the whole sub-section drops. The brief injector does not implement a separate budget enforcement step — it passes `budget_chars` through to the formatter.

---

## Selector timeout rule

The selector races its Glob + Read operations against a **soft 1-second deadline**. If the cumulative file-read time across the three canonical scope index files and their referenced memory files exceeds 1 second, the selector aborts, returns empty bytes, and emits a one-line WARN to the orchestrator. The dispatch proceeds with `## Project Knowledge` omitted — the timeout is non-fatal by design.

The 1-second value was calibrated against the healthy-baseline performance of this project's canonical store: a full Glob + Read across `~/.cross-memory/**` typically completes in **10–50 ms**, yielding a **20–100x safety margin**. This margin keeps the selector well below the ~3–5 second human-perceptual orchestration-latency threshold at which a user begins to wonder whether the run is stalled. Without a deadline, a degraded local filesystem or a network-mounted home directory could stall every gated dispatch by an unbounded amount.

The WARN format is one line: `[brief-injector] WARN: selector timeout after 1s — ## Project Knowledge omitted for this dispatch`.

---

## Sentinel marker emission rule

The selector returns raw UTF-8 bytes that the orchestrator renders under a `## Project Knowledge` heading in the brief. After rendering, the **orchestrator** — not the selector — appends the sentinel marker:

```
<!-- project-knowledge:carried -->
```

on its own line at the **bottom** of the `## Project Knowledge` section. This sentinel is the signal that a prior handoff carried the section. On retry (attempt > 1), the orchestrator's predicate searches the prior handoff body for an exact-byte match of the sentinel. If found, the predicate skips re-injection for that dispatch.

**Responsibility boundary.** The selector's job ends at returning bytes. The orchestrator owns both the rendering step (placing the bytes under the `## Project Knowledge` heading between `## Context` and `## Scope`) and the sentinel emission step (appending the marker at the bottom of the rendered section). This split ensures the sentinel always appears in the correct position regardless of which orchestrating skill calls the selector.

**Detection is exact-byte grep.** The predicate searches for the literal byte sequence `<!-- project-knowledge:carried -->` — no regex, no whitespace tolerance, no case folding. A handoff that carried the section will contain this exact sequence. A handoff that did not carry the section will not, even if it happens to contain the text `## Project Knowledge` elsewhere in its body (e.g., in a code example or a quoted brief).

---

## Self-citation hazard

When the selector's output bytes happen to contain the text `## Project Knowledge` — for example, because a stored memory's body quotes the brief grammar as a documentation example — a naïve substring scan of the rendered brief for that heading would produce a false positive on retry: the predicate would detect the heading and skip re-injection even though the section was never actually injected on the prior attempt.

The sentinel-marker approach eliminates this hazard entirely. The predicate searches for `<!-- project-knowledge:carried -->`, which is an HTML comment that cannot appear in normal Markdown rendered output or inside a code fence that quotes a brief structure. The quoted heading text inside a memory body does not cause a false positive because the sentinel was never appended to that memory's content.

**Test-case implication for the verifier:** a memory whose body contains the literal text `## Project Knowledge` (e.g., a documentation snippet) is selected and rendered by the selector; the orchestrator appends the sentinel on its own line at the bottom of the section; the next dispatch's predicate searches the handoff for `<!-- project-knowledge:carried -->` and correctly detects carry-over. The quoted heading inside the rendered memory bullet does not interfere with the detection.

---

## Recursive context awareness

When an executor is dispatched to modify `brief-injector.md` itself — for example, during the initial implementation or a future revision — the orchestrator's selector still runs and may inject `## Project Knowledge` into the brief. The executor therefore sees both the content it is being asked to edit (`## Scope` names `brief-injector.md`) and the standing rules it implements (`## Project Knowledge` carries the canonical store's memories). This is **recursive context exposure**: the executor reads the rules described in the file it is editing. This is not a correctness issue — the executor processes the injected rules the same way any other dispatch processes them, and the rules do not cause the executor to mis-edit the source. Flagged for awareness only. No mitigation is required at v1.

---

## Failure modes

| Scenario | Selector behavior | Brief impact |
| :--- | :--- | :--- |
| `~/.cross-memory/` directory does not exist (canonical store not yet initialized) | Selector returns empty bytes immediately. No WARN emitted. | `## Project Knowledge` is omitted. Dispatch proceeds normally. |
| `~/.cross-memory/` exists but `config.yaml` is absent or unparseable | Selector falls back to documented defaults: `max_brief_inject_chars = 4096`, `staleness_threshold_days = 90`. | Brief is composed with default budgets; no dispatch interruption. |
| `MEMORY.md` for one of the three canonical scopes is missing | Per the always-on tier edge case table in `skills/cross-memory/always-on-tier.md`, that scope's rule contributes zero entries; the filter continues. | Brief includes whatever the other scopes produced. |
| A memory file has malformed YAML frontmatter | Per `skills/cross-memory/schema-validator.md` reject behavior, the file is skipped at read time; selector emits a one-line WARN. | The malformed memory is omitted; remaining memories proceed normally. |
| Filter output exceeds the `budget_chars` ceiling | The injection-block formatter's existing drop-priority cascade applies: bullets trim bottom-to-top within a sub-section, then whole sub-sections drop in priority order. | Brief contains the most stable subset that fits within the budget. |
| `~/.cross-memory/` is unreadable (permission denied, broken symlink, filesystem error) | Selector catches the error, returns empty bytes, emits a one-line WARN. | `## Project Knowledge` is omitted. Dispatch proceeds. |
| Active project slug cannot be derived (adapter could not determine the current project) | Per the always-on tier edge case table in `skills/cross-memory/always-on-tier.md`, Rule 2 is skipped entirely. | Brief includes user-global and harness-scope memories only; project-scoped memories are absent. |
| Selector is called from a Cursor or generic harness (where `update_sentinel_block` is a no-op) | Selector reads `~/.cross-memory/**` directly, bypassing `update_sentinel_block` entirely. Harness does not affect the read path. | Brief contains the same memories a Claude Code dispatch would receive. The `update_sentinel_block` no-op is irrelevant to this path — see `skills/cross-memory/adapter-cursor.md` for the trust-model disclosure. |
| Predicate misclassifies an agent (false-positive: agent is in `MECHANICAL_AGENTS` but should not be) | Predicate skips. Selector is not called. | `## Project Knowledge` is absent for an agent that should have seen it. The agent operates without injected rules — same posture as pre-injection behavior. Recovery: remove the agent from `MECHANICAL_AGENTS`. |
| Predicate misclassifies an agent (false-negative: agent should be in `MECHANICAL_AGENTS` but is not) | Predicate proceeds. Selector returns bytes. | `## Project Knowledge` is present for a mechanical agent that ignores it. Cost: ~500–2000 bytes per stray dispatch. Recovery: add the agent type to `MECHANICAL_AGENTS`. |
| A memory tagged `exclude:<agent>` is also tagged `always-on` or carries a positive agent-type tag for the same agent | Negative tag wins precedence per the tag vocabulary rule above. The memory is dropped from the intersection result for that agent type. | The memory does not appear in the brief for the excluded agent type. It remains visible to other agent types whose types are positively tagged or whose dispatches have `enable_agent_type_intersection=False`. |
| Concurrent `/cross-memory save` mid-read — partial-write race | Impossible by construction under the atomic-rename protocol: writes go to a sibling temp file first, then atomic-rename to the canonical name (`rename(2)` on POSIX; `MoveFileEx` with `MOVEFILE_REPLACE_EXISTING` on Windows). Readers always see either the pre-save or the post-save state, never a torn intermediate. See `skills/cross-memory/subcommand-save.md` for the full atomicity contract. | Brief either reflects the pre-save state (if the read completed before the rename) or the post-save state (if the read started after the rename). No partial or corrupt content reaches the selector. |

---

## Cross-references

- **Always-on tier filter** (four inclusion rules, dedup, staleness banner, output tuple shape): `skills/cross-memory/always-on-tier.md`.
- **Injection-block formatter** (sub-section layout, 120-character bullet cap, `max_inject_chars` budget, drop priority, within-sub-section trimming, empty-list behavior): `skills/cross-memory/injection-block.md`.
- **Canonical store layout** (scope paths, archive exclusion, `MEMORY.md` index file structure): `skills/cross-memory/indexing.md`.
- **Skill companion index** (this file is orchestrator-only — never loaded by `/cross-memory` subcommands): `skills/cross-memory/indexing.md` § 6.
- **Frontmatter schema and `tags[]` array** (field definitions, type and scope enums, reject behavior for malformed files): `skills/cross-memory/schema-validator.md`.
- **Atomic write contract** (write-to-temp-then-rename semantics at every canonical-store write site): `skills/cross-memory/subcommand-save.md`.
- **Cursor adapter trust-model disclosure** (subagents see `## Project Knowledge` even though `update_sentinel_block` is a no-op at v1; the brief injector bypasses that surface entirely): `skills/cross-memory/adapter-cursor.md`.
