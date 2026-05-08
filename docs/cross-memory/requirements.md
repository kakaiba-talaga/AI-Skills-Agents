# Requirements: Cross-Memory Skill and Agent

## Summary

Cross-memory is a new harness-portable memory layer that lets AI harnesses retain user-shared information across sessions and across projects. It introduces a single canonical store at `~/.cross-memory/`, a `/cross-memory` skill with six commands for explicit user interaction, and a `cross-memory` agent for synthesis and audit. The system **extends** Claude Code's existing per-project memory at `~/.claude/projects/<slug>/memory/` rather than replacing it — adapters mirror project-scoped memories into the harness's native location where one exists, preserving auto-injection for hosts that support it.

The goal is to move the assistant from stateless-per-session toward continuing-collaborator behavior: a preference shared while working on Project A surfaces unprompted while working on Project B; a project decision recorded today is still available six months later, possibly with a staleness banner.

This document is the synthesis of a complete decision set captured through prior interview rounds. All keystone decisions are settled. Items that remain open are deferred to the architect with reason notes; they do not block planning.

---

## 1. Goals and Non-Goals

### Goals

| # | Goal | Concrete shape |
| :--- | :--- | :--- |
| G1 | Continuing-collaborator behavior across sessions | A memory written in session N on harness H1 is retrievable in session N+1 on harness H2 without re-explanation |
| G2 | Cross-project memory for the same user | A `user-global` memory persists and surfaces regardless of which project the user is working in |
| G3 | Per-project memory that survives harness changes | A `project:<slug>` memory written from Claude Code is readable from Cursor and from a generic harness |
| G4 | Harness-agnostic canonical store | Single source of truth at `~/.cross-memory/`; no path under `~/.claude/` is canonical |
| G5 | Preserve Claude Code auto-injection | The Claude Code adapter mirrors `project:<slug>` memories into `~/.claude/projects/<slug>/memory/` so existing auto-injection keeps working |
| G6 | Explicit user control over writes | No silent writes; every persisted memory either originated from `/cross-memory save` or from a user-confirmed auto-proposal |
| G7 | Privacy by default | Auto-redaction of known-sensitive patterns runs before any auto-proposed write reaches the user's confirmation prompt |

### Non-Goals (explicit)

- **Not a general knowledge base or RAG system.** Cross-memory does not store arbitrary documents, books, or external knowledge. Only user/project facts qualify.
- **Not a conversation transcript archive.** Raw conversation history is never persisted. Only distilled memories are stored.
- **Not a replacement for the harness's own memory.** Cross-memory extends Claude Code's existing per-project memory; it does not attempt to take over.

### Non-Goals (deliberately left open)

- Boundary against project documentation systems (READMEs, ADDs, plan docs in repos) is **not** declared a non-goal in this requirements pass. The architect should revisit this. See **Open Questions**.

---

## 2. Storage Layout

### Root

- Canonical root: `~/.cross-memory/` (harness-agnostic; explicitly **not** under `~/.claude/` or `~/.cursor/`).
- Adapters MAY mirror selected memories into harness-native paths. Mirrored copies are **derived** artifacts, never canonical.

### Scopes

Three explicit scopes, each backed by a directory under the canonical root:

| Scope | Path | Purpose |
| :--- | :--- | :--- |
| `user-global` | `~/.cross-memory/user-global/` | Applies to the user across all projects and harnesses (preferences, identity, hard rules) |
| `project:<slug>` | `~/.cross-memory/projects/<slug>/` | Bound to a specific project. Slug derived from project absolute path using the same scheme Claude Code uses for `~/.claude/projects/<slug>/` (path with separators replaced by `-`) |
| `harness:<name>` | `~/.cross-memory/harnesses/<name>/` | Bound to a specific harness (e.g., `harness:claude-code`, `harness:cursor`, `harness:generic`) |

### Tags

- Each memory carries a flat `tags: [...]` array in its frontmatter for cross-cutting groupings (e.g., `python`, `security`, `preferences`).
- Tags are orthogonal to scope; a memory's tags do not change its scope and vice versa.
- Tag matching is case-insensitive and exact (no fuzzy match required at v1).

### Archive

- Superseded and forgotten memories move to `~/.cross-memory/archive/`.
- Filename pattern: `<original-stem>-<UTC-timestamp>.md` where timestamp is `YYYYMMDDTHHMMSSZ`.
- Archived memories are **never** loaded by adapters or the read surface. They exist for audit and recovery only.

### File Naming Convention

- Pattern: `<type>_<slug>.md` (e.g., `feedback_no_commit_trailers.md`, `project_kickoff_design_principles.md`).
- Slug is lowercase, hyphen-separated, derived from the memory's `name` field.
- File extension is always `.md`.

This pattern matches the existing per-project memory convention at `~/.claude/projects/<slug>/memory/`. Adopting it verbatim is intentional — it eases mirroring.

### MEMORY.md Index

**Sub-decision (architect to confirm):** One `MEMORY.md` index **per scope directory** rather than one global index.

- `~/.cross-memory/user-global/MEMORY.md`
- `~/.cross-memory/projects/<slug>/MEMORY.md`
- `~/.cross-memory/harnesses/<name>/MEMORY.md`

**Rationale:** This mirrors the existing per-project pattern (`~/.claude/projects/<slug>/memory/MEMORY.md`) and keeps each scope's index small enough to inject cheaply. A global index would grow unbounded across projects and would be redundant with the per-scope indexes.

**Deferred to Open Questions:** Whether an additional aggregate index (read-only, mechanically rebuilt) is needed for cross-scope search performance.

---

## 3. Schema

### Frontmatter — Required

| Field | Type | Notes |
| :--- | :--- | :--- |
| `name` | string | Human-readable title; matches the file's slug |
| `description` | string | One-line summary; used in indexes and tooltips |
| `type` | enum | One of `feedback`, `project`, `preference`, `fact`, `rule`. Other values rejected at v1 |
| `scope` | enum | One of `user-global`, `project:<slug>`, `harness:<name>`. The `<slug>` / `<name>` portion is required when applicable |
| `tags` | array of strings | May be empty (`[]`); never absent |
| `created_at` | ISO-8601 UTC | Set on first write, immutable |
| `updated_at` | ISO-8601 UTC | Updated on every supersede |

### Frontmatter — Optional

| Field | Type | Notes |
| :--- | :--- | :--- |
| `originSessionId` | string | Session ID at time of capture (matches existing convention) |
| `redacted` | boolean | True if any auto-redaction rule fired during the write that produced this memory |
| `harness` | string | Set automatically when the write originated from a specific harness; informational only |
| `superseded_by` | string | Filename of the replacement memory (only set on archived copies) |
| `verified_at` | ISO-8601 UTC | Last time the user explicitly confirmed the memory is still accurate; used for staleness calculation |

### Body Conventions

The body of every memory file SHOULD lead with the rule or fact in a single sentence or short paragraph, followed by two labeled sections:

1. **`**Why:**`** — the reason the memory exists (user feedback context, decision rationale, observed pattern).
2. **`**How to apply:**`** — concrete guidance on when and how to use the memory.

This matches the existing `feedback` and `project` body style at `~/.claude/projects/<slug>/memory/`. The audit command MAY warn when these sections are missing; it MUST NOT auto-rewrite bodies.

---

## 4. Write Surface

### Two Paths

1. **Explicit save** — user invokes `/cross-memory save` with arguments. The user is trusted; redaction warnings are shown but not blocking.
2. **Auto-propose with confirmation** — the assistant detects something memorable (preference, decision, project fact) during a session and proposes a save. The user must confirm before any file is written.

### Confirmation UX Requirements

- **Auto-proposed save (new memory):** Present the redacted candidate (frontmatter + body) in a fenced block. Ask explicitly: "Save this memory? [y/N]". Default is no.
- **Auto-proposed save (supersede):** Present a unified diff between the existing memory and the proposed replacement. Both versions show their redacted form. Ask explicitly: "Replace existing memory with this version? [y/N]". Default is no.
- **Explicit save with detected sensitive pattern:** Show the redacted candidate plus a warning listing which pattern fired. Ask: "Sensitive pattern detected: <name>. Save anyway? [y/N]". Default is no.
- **Explicit save without detected sensitive pattern:** Save directly. Echo the path of the written file.

### No Silent Writes

- The assistant MUST NOT write to `~/.cross-memory/**` without one of the three confirmation paths above (or the audit command's user-driven prune; see Lifecycle).
- The assistant MUST NOT write to `~/.cross-memory/**` from background or autonomous workflows without a confirmed user message in the same conversation authorizing the write.

---

## 5. Read Surface

### Hybrid Model

Three complementary read paths:

1. **Auto-inject (always-on tier).** Small, focused set injected at session start by adapters.
2. **Explicit recall.** `/cross-memory recall <topic>` — topic-targeted, user-driven.
3. **On-demand agent synthesis.** Other agents dispatch the `cross-memory` agent when they need a synthesized context block.

### Always-On Tier (auto-inject)

The always-on tier is the **only** content adapters auto-inject. It is intentionally minimal to keep prompt budget under control.

| Inclusion rule | Rationale |
| :--- | :--- |
| All memories in `user-global` with `type` in (`preference`, `rule`, `fact`) | Identity and hard preferences belong in every session |
| All memories in `project:<current-slug>` with `type` in (`feedback`, `project`, `rule`) | Current-project context is high-value and bounded |
| `harness:<current-harness>` memories with `type` in (`rule`, `feedback`) | Harness-specific rules apply on every session in that harness |
| Memories tagged `always-on` regardless of type/scope (escape hatch) | Lets the user opt specific memories into the tier without changing type |

Memories with a staleness banner are **still injected** (the banner is preserved verbatim). Auto-deletion is never triggered by the read surface.

### `/cross-memory recall <topic>` Semantics

- Argument `<topic>` is a free-text query.
- Match strategy at v1: case-insensitive substring match against `name`, `description`, `tags`, and body.
- Optional flags:
  - `--scope <scope>` — restrict to one scope.
  - `--type <type>` — restrict to one type.
  - `--tag <tag>` — restrict to one tag.
  - `--include-stale` — include memories past the staleness threshold (default behavior already includes them; the flag is a no-op at v1, reserved for future filtered behavior).
- Output: ordered list of matching memories, each shown with full body. Order: most-recently-`updated_at` first.

### Agent Synthesis Contract

When another agent (or the user) wants a curated context block instead of a raw match list, it dispatches the `cross-memory` agent. See section 11 for the input/output contract.

---

## 6. Lifecycle

### Creation

1. Trigger: explicit save command OR confirmed auto-proposal.
2. Redaction pass runs against the candidate body.
3. Confirmation UX runs (per section 4).
4. On confirm: write file under the appropriate scope directory; set `created_at` and `updated_at` to the same UTC timestamp; append entry to that scope's `MEMORY.md` index.
5. Adapter mirroring (per section 9) runs after the canonical write succeeds, never before.

### Update / Supersede

1. Trigger: a new memory is proposed whose `name` collides with an existing memory in the same scope, OR the user explicitly invokes a save with the same `name`.
2. Confirmation UX runs with a unified diff.
3. On confirm:
   - Move the existing file to `~/.cross-memory/archive/<stem>-<UTC-timestamp>.md`. Set `superseded_by` in the archived copy's frontmatter to point at the replacement filename.
   - Write the new memory to the canonical path. Preserve `created_at` from the predecessor; set `updated_at` to now.
   - Update the scope's `MEMORY.md` index entry.
   - Re-run adapter mirroring.

### Forget

- `/cross-memory forget <name>` archives the memory. Same archive mechanism as supersede, but `superseded_by` is not set.
- Forgotten memories are removed from `MEMORY.md` indexes and from any mirrored copies.
- Forgotten memories are NEVER auto-restored by adapters.

### Staleness

- Default threshold: **90 days** since the latter of `verified_at` and `updated_at`.
- Threshold is configurable per-user via a config field (defer exact mechanism to architect; see Open Questions).
- A stale memory is **still loaded and still injected** if the always-on rules apply. The recall command still returns it.
- A staleness banner is rendered at the top of the body when the memory is presented in any read surface. Banner format: `> [!STALE] Last verified <date>; <N> days unverified. Refresh, archive, or forget?`
- Staleness is recomputed lazily at read time, not stored on disk.

### Audit

- `/cross-memory audit` is the manual cadence — the user runs it on demand. Cross-memory does **not** schedule audits.
- The audit dispatches the `cross-memory` agent with an audit brief. The agent scans for staleness, duplication, contradictions, and redaction misses, then returns a structured report. See section 11.
- The audit MUST NOT modify or delete any memory without user confirmation.

---

## 7. Privacy and Redaction

### Redaction Categories (denylist)

The denylist is applied to candidate memory bodies before any user confirmation prompt:

| Category | Example pattern signal |
| :--- | :--- |
| API keys | High-entropy strings matching common provider key prefixes (e.g., `sk-`, `pk_`, `ghp_`, `gho_`, AWS access key shape) |
| Passwords | Lines containing `password`, `passwd`, `pwd` followed by `=`, `:`, or value assignment |
| Tokens | OAuth/JWT-shaped strings (three base64 segments separated by `.`); bearer-token assignments |
| `.env` contents | Any block that looks like an `.env` file (multiple `KEY=VALUE` lines with quoting) |
| Secrets explicitly tagged | Any content the user marks as secret in the same session, or content read from a file the user identified as secret |

The exact regex/pattern set is **deferred to the architect** (see Open Questions). The categories above are the floor.

### Redaction Behavior

- Detected sensitive substrings are replaced with `[REDACTED:<category>]` in the candidate body.
- The `redacted` frontmatter field is set to `true` if any pattern fired.
- The redacted candidate is what the user sees in the confirmation prompt. The original (unredacted) text is **never** persisted.

### Confirmation Gate (auto-proposed saves)

- Auto-proposed saves are **always** subject to the confirmation gate, redaction or not. This is independent of the redaction pass.
- If redaction fired, the confirmation prompt highlights which categories triggered.

### Warning Behavior (explicit saves)

- Explicit `/cross-memory save` invocations trust the user but still run the redaction pass for warning purposes.
- If a pattern fires on an explicit save, the user sees the redacted candidate plus a warning and must confirm. The user MAY choose to save the unredacted form by passing `--no-redact` (deferred — see Open Questions).

### Archive Policy for Redacted Memories

- Archived copies retain the `redacted: true` flag and the `[REDACTED:...]` placeholders.
- Original unredacted content is NEVER recoverable from the archive — it was never written to disk.

---

## 8. Relationship to Claude Code's Existing Memory System

### Mode: Extend (superset / sibling layer)

- Existing files at `~/.claude/projects/<slug>/memory/` keep working unchanged.
- Cross-memory adds new tiers (`user-global`, `harness:<name>`) and a canonical store at `~/.cross-memory/`.
- No migration of existing files is performed at v1. Existing per-project memories continue to live where Claude Code already finds them and continue to be auto-injected by Claude Code's native mechanism.

### Adapter Mirroring (Claude Code)

- The Claude Code adapter mirrors **canonical** `project:<slug>` memories from `~/.cross-memory/projects/<slug>/` into `~/.claude/projects/<slug>/memory/` so Claude Code's existing auto-injection picks them up.
- Mirroring is one-way: canonical → mirror. The mirror is derived; it MUST NOT be edited directly.
- The adapter MUST detect collisions: if a file with the same name exists in `~/.claude/projects/<slug>/memory/` and is **not** a mirror of a canonical memory, the adapter leaves it alone and reports the collision in the next audit. (Detection mechanism deferred — see Open Questions.)

### Index Style Reuse

- New tier indexes (`user-global/MEMORY.md`, `harnesses/<name>/MEMORY.md`) reuse the existing `MEMORY.md` line format: `- [Name](file.md) — <description>`. Style continuity matters more than schema novelty.

### Out of Scope (this skill)

- Cross-memory does NOT migrate, modify, or delete existing per-project memory files at `~/.claude/projects/<slug>/memory/`. Any pre-existing file there remains owned by Claude Code's native system.

---

## 9. Harness Portability

### First-Class Targets (v1)

| Harness | Role | Adapter behavior |
| :--- | :--- | :--- |
| Claude Code | Rich memory host | Mirror `project:<slug>` canonical memories into `~/.claude/projects/<slug>/memory/`. Auto-inject the always-on tier via Claude Code's native mechanism (the mirror IS the injection path) |
| Cursor | Rich memory host | Mirror per Cursor's memory layout. Follow the existing `tooling/transform-cursor-*.{ps1,sh}` pattern in this repo for path translation. Always-on tier surfaces via the harness's session-start injection if available, otherwise via the skill's manual recall |
| Generic / unknown | Fallback target | No mirroring. No auto-injection. The skill's `/cross-memory recall` command and the agent's on-demand synthesis are the only read paths. Portable file format remains identical |

### Adapter Responsibilities

Each adapter is a thin layer per supported harness. Responsibilities:

1. **Mirror writes** — when a canonical memory is created/updated/superseded, propagate to the harness-native path (where one exists).
2. **Detect harness identity** — declare which `harness:<name>` value applies for the current session.
3. **Surface always-on tier** — either via mirror+native-injection (rich hosts) or via session-start prompt insertion (if the harness supports it) or fall back to manual recall (primitive hosts).
4. **Detect collisions** — flag files in the harness-native path that are not mirrors of canonical memories.

### Harness Detection Strategy

**Architect to choose** between (or combine) the following options:

- **Explicit config.** A `~/.cross-memory/config.yaml` (or similar) with `current_harness:` set per session.
- **Environment-variable-based.** Adapters read `CROSS_MEMORY_HARNESS` from env, falling back to a per-harness sentinel (e.g., `CLAUDE_CODE_SESSION_ID` set, `CURSOR_*` env vars set).
- **Adapter-per-harness manifest.** Each adapter ships with a self-identification function; cross-memory invokes them in priority order until one claims ownership.

This is **deferred to the architect** (see Open Questions). The requirements only mandate that detection is deterministic, repeatable, and auditable.

### Generic Fallback Behavior

- Read: `/cross-memory recall` works identically across all harnesses (same canonical store).
- Write: `/cross-memory save` works identically across all harnesses.
- Auto-inject: not assumed. The user is expected to use `recall` explicitly on primitive hosts.
- Mirroring: not performed.

---

## 10. Skill Surface Area

The `/cross-memory` skill exposes six commands at v1.

| Command | Argument shape | Purpose |
| :--- | :--- | :--- |
| `/cross-memory save` | `[--scope <scope>] [--type <type>] [--tags <t1,t2>] [--name <name>] [<inline-body>]` | Write a memory. If `<inline-body>` omitted, prompt the user for it. If scope/type/name omitted, derive from context and confirm |
| `/cross-memory recall <topic>` | `[--scope] [--type] [--tag]` | Topic-targeted retrieval; returns full memories matching the topic |
| `/cross-memory list [filter]` | `[--scope] [--type] [--tag] [--stale-only]` | Show store contents filterable by scope, type, tag, staleness |
| `/cross-memory forget <name>` | `<name>` (required) | Archive a memory by name; user-confirmed |
| `/cross-memory search <query>` | `<query>` (required) | Grep-style full-text search across the canonical store. Distinct from `recall` — no synthesis, no ranking, returns raw matches with file:line citations |
| `/cross-memory audit` | (no required args) | Dispatch the `cross-memory` agent for staleness/duplication/contradiction/redaction-miss scan |

### Output Format Requirements

- All commands print to the chat in markdown.
- `recall` and `list` return memories rendered with their staleness banner if applicable.
- `search` returns `<path>:<line>: <matched-line>` triples (grep-style).
- `audit` returns a structured report (see section 11).
- `save` and `forget` echo the canonical path of the affected file plus the path of any archived predecessor or mirror.

### Deferred to Post-v1

- `/cross-memory export` — bundle the canonical store for backup/transport.
- `/cross-memory import` — restore from a bundle.

These are explicitly **out of scope for v1**. They MUST NOT be implemented in the v1 plan.

---

## 11. Agent Surface Area

### Dispatch Triggers

The `cross-memory` agent is dispatched in two situations:

1. **Audit** — `/cross-memory audit` dispatches the agent for curation work.
2. **On-demand from other agents and skills** — `/ops`, `/kickoff`, planner, executor, etc. MAY dispatch via the Agent tool when they need a synthesized context block.

### Explicit Non-Triggers

- The agent is **NOT** auto-dispatched at session start by adapters. Session-start work belongs to the always-on tier injection, not to agent synthesis.
- The agent is **NOT** dispatched on every auto-proposed write. The skill handles drafting and redaction directly. The agent is reserved for synthesis and audit.

### Input Contract (Brief Format)

The brief sent to the `cross-memory` agent follows the existing brief format used by other agents in this repo (see `skills/ops/brief-contract.md`). Required fields:

| Field | Purpose |
| :--- | :--- |
| `intent` | One of `synthesize`, `audit` |
| `query` (when `intent: synthesize`) | Free-text description of what context is needed (e.g., "Python preferences and security rules relevant to the current task") |
| `scope_filter` (optional) | Restrict synthesis to specific scopes/tags/types |
| `current_project_slug` (optional) | Used to bound `project:<slug>` synthesis |
| `current_harness` (optional) | Used to bound `harness:<name>` synthesis |

### Output Contract

For `intent: synthesize`:

- A single markdown context block under 4000 characters by default (configurable).
- Sections: **User preferences**, **Project context**, **Harness rules**, **Notes / staleness warnings**.
- Inline citations: each memory's filename appears in parentheses after the relevant claim.
- The block MUST exclude memories that don't match the query — relevance is part of the agent's job.

For `intent: audit`:

- A structured report listing:
  - **Stale memories** (`name`, days since last verified, suggested action).
  - **Duplicates** (groups of memories with same/similar `name` or overlapping content).
  - **Contradictions** (memories whose content conflicts; agent flags only — does not resolve).
  - **Redaction misses** (memories with frontmatter `redacted: false` that contain patterns matching the denylist).
- The report ends with recommended actions, each requiring user confirmation before any change is applied.

### Required Tools

The `cross-memory` agent has scoped permissions:

- `Read`, `Glob`, `Grep` — across `~/.cross-memory/**`.
- `Write` — **only** to paths under `~/.cross-memory/**`. Writes outside this tree MUST fail.
- No `Bash` (no shell execution required for v1).
- No `Agent` (no nested dispatch).

### Lane Boundaries

The agent does **not**:

- Write to harness-native mirror paths (the adapter does that).
- Modify project source code.
- Decide on contradictions unilaterally — it flags, the user resolves.
- Auto-prune stale memories — it surfaces, the user decides.

---

## 12. Success Criteria

Each item below is a concrete behavioral assertion. Pass/fail must be checkable with a small scripted scenario or manual run.

### Cross-Session, Cross-Project Persistence

- [ ] **SC-1: User-global preference surfaces in a different project.** User shares preference X (e.g., "prefer pytest over unittest") in a session on project A. Cross-memory writes a `user-global` memory after confirmation. In a later session on project B, the assistant surfaces X without being prompted (auto-inject of always-on tier).
- [ ] **SC-2: Project memory persists across harness changes.** A `project:<slug>` memory written from Claude Code is retrievable via `/cross-memory recall` from a Cursor session on the same project.

### Auto-Propose Flow

- [ ] **SC-3: End-to-end auto-propose loop.** Auto-propose flow detects a memorable preference, shows the redacted candidate, user confirms with `y`. Memory persists at the canonical path. A later `/cross-memory recall <topic>` returns it. Memory's `originSessionId` matches the originating session.

### Adapter Mirroring (Claude Code)

- [ ] **SC-4: Canonical write produces a mirror.** A canonical `project:<slug>` memory write triggers the Claude Code adapter to create a mirror at `~/.claude/projects/<slug>/memory/`. On the next Claude Code session start for that project, the mirrored memory is auto-injected by Claude Code's native mechanism.
- [ ] **SC-5: Forget removes the mirror.** A `/cross-memory forget <name>` on a `project:<slug>` memory archives the canonical file AND removes the mirrored copy. The archive carries `superseded_by` if the forget was actually a supersede.

### Privacy and Redaction

- [ ] **SC-6: Denylist redacts an API-key-shaped string.** An auto-propose flow sees a body containing `sk-abc123...` (API-key shape). The redaction pass replaces the substring with `[REDACTED:api-key]`. The redacted candidate is what the user sees in the confirmation diff. `redacted: true` is set in the persisted frontmatter.
- [ ] **SC-7: Explicit save warns on detected secret.** A `/cross-memory save` invocation with a body containing a JWT-shaped token shows a warning, displays the redacted candidate, and requires explicit confirmation before writing.

### Staleness

- [ ] **SC-8: Audit flags a 91-day-unverified memory.** Run `/cross-memory audit` against a store containing a memory whose `verified_at` is 91 days ago. The agent's report lists it under stale memories with suggested actions (refresh, archive, forget).
- [ ] **SC-9: Stale memory still loads.** A memory past the staleness threshold is still returned by `recall` and still injected in the always-on tier, with its staleness banner rendered at the top of the body.

### Supersede

- [ ] **SC-10: Supersede archives the predecessor.** A new memory with the same `name` as an existing one triggers the diff confirmation flow. On confirm: the predecessor moves to `~/.cross-memory/archive/<stem>-<timestamp>.md` with `superseded_by` set. The new memory's `created_at` matches the predecessor's; `updated_at` is now.

### Agent Synthesis

- [ ] **SC-11: Synthesis returns a relevant filtered block.** `/ops` dispatches the `cross-memory` agent with a synthesis brief for a Python task. The returned context block includes user preferences relevant to Python work, excludes preferences relevant only to other languages, excludes project memories from unrelated projects, and stays under the configured size budget.
- [ ] **SC-12: Audit contradiction detection.** Two memories with overlapping `tags: [git]` and contradicting content (e.g., one says "always rebase", another says "always merge") trigger a contradiction flag in the audit report. The agent does NOT auto-resolve; it surfaces both with their paths.

### Lane Boundaries

- [ ] **SC-13: Agent write is restricted to the canonical store.** An attempt by the `cross-memory` agent to write outside `~/.cross-memory/**` (e.g., to a project source file) fails. The lane enforcement is testable.
- [ ] **SC-14: Existing per-project memory files are untouched.** A v1 install runs against a system with pre-existing files at `~/.claude/projects/<slug>/memory/`. After install + first audit run, those pre-existing files are byte-identical to their pre-install state (no migration occurred).

---

## Open Questions

These items are genuinely ambiguous after the captured decisions. They are deferred to the architect with reason. They do **not** block the planner.

| # | Question | Reason deferred |
| :--- | :--- | :--- |
| OQ-1 | Harness-detection strategy specifics — explicit config vs. environment-variable-based vs. per-harness manifest | Depends on cross-platform feasibility and on what each harness exposes at runtime. Architect should evaluate trade-offs (portability, reliability, user friction) |
| OQ-2 | MEMORY.md index granularity — per-scope only, or per-scope plus a rebuilt aggregate index for cross-scope search | Depends on the chosen search backend. If `search` is grep-style across the tree, the aggregate is unnecessary. If it ever becomes a keyword/embedding index, the aggregate may be a build target |
| OQ-3 | Exact redaction pattern set — the categories are fixed but the regex/pattern library is not | Depends on a security review of false-positive vs. false-negative trade-offs. Should be revisited per harness if any harness exposes unique secret formats |
| OQ-4 | Sync conflict model when the same memory is edited via two harnesses (e.g., Claude Code adapter mirrors a stale version while Cursor adapter rewrites it) | The adapter design hasn't selected a canonical-vs-mirror reconciliation strategy. Two candidates: (a) canonical-store-is-truth with periodic mirror-overwrite, (b) last-writer-wins with conflict markers |
| OQ-5 | Embedding/keyword indexing for filtered auto-inject (post-v1) | Out of scope for v1 by user decision; flagged here so the architect can leave hooks for it |
| OQ-6 | Boundary against project documentation systems (READMEs, ADDs in repos) — is cross-memory disjoint from these, or can a memory reference / link them? | The user explicitly did not declare this a non-goal. The architect should decide whether memories may reference repo paths and what happens when those paths move |
| OQ-7 | Mirror-collision detection mechanism (section 8) — how does the adapter tell its own mirrored files apart from native-only files? | Two candidates: (a) a marker frontmatter field `mirrored_from: <canonical-path>`, (b) a sidecar manifest tracking what the adapter wrote. Architect chooses |
| OQ-8 | Configuration mechanism for the staleness threshold | Could be a field in `~/.cross-memory/config.yaml`, a CLI flag on `/cross-memory audit`, or both. Architect to choose; pick the same mechanism used for OQ-1 if possible |
| OQ-9 | `--no-redact` flag for explicit saves (section 7) — keep, drop, or require an extra confirmation step | Tension between user trust and accidental disclosure. Architect to decide based on threat model |

---

## Success Criteria Lock

- **Status:** Locked.
- **Confirmation:** All keystone decisions were captured through prior interview rounds conducted by the team manager. This document synthesizes those decisions verbatim. The 14 success criteria in section 12 are the testable acceptance conditions for v1. The Open Questions are deferred to the architect by design and do not block planning.

---

## Interview Log

This document was produced as a synthesis pass, not through an interactive interview. The decision rounds were conducted by the team manager directly because the harness does not support resuming agents. The captured decisions cover:

| Round | Topic | Decision |
| :--- | :--- | :--- |
| 1 | Relationship to existing per-project memory | Extend (superset / sibling layer) |
| 2 | Architecture | Two-layer: canonical store + per-harness adapters |
| 3 | First-class harnesses at v1 | Claude Code, Cursor, generic fallback |
| 4 | Read surface | Hybrid: minimal auto-inject + manual recall + on-demand synthesis |
| 5 | Write surface | Hybrid: explicit saves + auto-propose with confirmation; no silent writes |
| 6 | Privacy and redaction | Strict denylist + confirmation gate |
| 7 | Storage root | `~/.cross-memory/` (harness-agnostic) |
| 8 | Scope hierarchy | Three scopes + cross-cutting tags |
| 9 | Contradiction handling | Supersede with audit trail |
| 10 | Staleness | Soft banners + manual prune; default 90 days |
| 11 | Skill commands at v1 | save, recall, list, forget, search, audit; export/import deferred |
| 12 | Agent dispatch triggers | Audit + on-demand; not session-start, not per-write |
| 13 | Explicit non-goals | Not RAG, not transcript archive, not memory replacement |

The interviewer pass added the following sub-decisions and flagged them for architect review:

- MEMORY.md index granularity recommendation (one per scope; section 2)
- Mirror-collision detection mechanism (Open Question OQ-7)
- Staleness threshold configuration mechanism (Open Question OQ-8)
- `--no-redact` flag for explicit saves (Open Question OQ-9)

No further interview rounds are needed before the architect engages.
