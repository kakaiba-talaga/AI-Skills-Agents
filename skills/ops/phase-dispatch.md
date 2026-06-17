# Phase 3 dispatch loop

> **Parent:** `~/.claude/skills/ops/SKILL.md` — Non-negotiables, Agent Briefing Format, and Handoff Documents live in the hub. This file holds the residual Phase 2.5 *validation* entry (a short preamble) and the Phase 3 dispatch loop; the Phase 2.5b/2.5c advisory preflight contracts live in `phase-preflights.md`.

## Phase 2.5b / 2.5c — Advisory preflights (moved)

> **Reference:** You MUST Read `~/.claude/skills/ops/phase-preflights.md` for the Phase 2.5b (code-intel) and Phase 2.5c (corpus-search) advisory-preflight contracts — trigger predicates, dispatch contracts, JSON brief/response shapes, and the shared preflight blocks. They run before each Phase 3 Step 2 dispatch. If the file is missing, skip the advisory preflights — they are advisory and never block a dispatch.

## Phase 2.5 — Preflight Validation

After the task board is created and before the first dispatch, run a preflight check to confirm the environment is ready. Dispatch a **preflight** agent (see `~/.claude/agents/preflight.md`). If any critical check fails, stop and report to the user. If standard checks fail, attempt auto-fix once. Warnings are logged but do not block dispatch.

## Cursor: state file sync (mandatory)

> Applies only when the active harness is **Cursor**. Claude Code has no `TodoWrite` tool — skip this section there.

Cursor exposes `TodoWrite` for an IDE-visible task list. Models often update `TodoWrite` alone and **never** write `.ops-state/<run-id>-board.json` after the initial board creation. That breaks `resume`, `status`, timing, handoffs, and nested-skill recovery.

| Layer | Role |
| :--- | :--- |
| `.ops-state/<run-id>-board.json` | **Source of truth** — dependencies, timing, `blocked_by`, adaptations, `pending_nested_skill` |
| `TodoWrite` | **Display only** — mirrors status for the IDE; never authoritative |

**Forbidden:** Calling `TodoWrite` for a status change without completing **Write → Read verify** on the board file in the **same assistant turn** first.

**Required ritual** (every status change: `pending` → `in_progress`, completion, failure, new task, cancel, adaptation):

1. `Read` the board file (or use cache only if this turn already wrote and verified it).
2. Mutate the JSON in memory (`status`, `started_at`, `completed_at`, `duration_seconds`, `attempts`, etc.).
3. `Write` the **full** board JSON to `.ops-state/<run-id>-board.json`.
4. `Read` the file back; confirm the mutated field(s) match. If not, stop and rewrite — **do not** call `TodoWrite` until verify passes.
5. **Then** `TodoWrite(merge=true, todos=[{id, content, status}])` (or `merge=false` when recreating the full board after `resume`).

Use **separate tool calls** for steps 3–5. Never treat `TodoWrite` as satisfying Non-negotiable #1 or #3.

**Before every subagent spawn:** If the board file does not show the task as `in_progress` with a fresh `started_at`, run the ritual for that transition first.

**Dashboard and `/ops status`:** Derive timing, dependencies, and progress from the board file — not from `TodoWrite`.

## Phase 3 — Dispatch Loop

This is the core orchestration loop. Repeat until all tasks are completed or the user intervenes:

**Step 1 — Scan for ready tasks.** Use the cached state; read the state file from disk only on invalidation events (read-on-change). If the file doesn't exist, stop and re-create it (Phase 2 step 1). A task is ready when `status == "pending"` and all `blocked_by` entries are `"completed"`.

**State cache** — maintain an in-memory snapshot of the last-known state. Invalidate the cache (re-read from disk) on these events only:
- **Bootstrap**: before the first dispatch of each loop invocation (initial read).
- **Task completed**: immediately after Step 4 writes task completion to disk (state file just mutated).
- **Resume / status subcommand**: always re-read on `resume` or `status` — external changes may have occurred.
- **User mid-run command** (`add`, `drop`, `reprioritize`, `do #N next`, `skip`) — re-read after processing the command.
- **Nested skill return** — after any nested-skill call returns, the cache is invalidated. The state file on disk may have been written by the team manager in the same turn (via the `pending_nested_skill` write-before step). Re-read before processing the return. See `state-schema.md` and Non-negotiable #10.

Between these events, operate on the cached snapshot. Do not re-read on routine Step 1 → Step 2 → Step 3 cycles within one dispatch iteration.

> **Safety note:** If the user manually edits the state file JSON between invalidation events, those changes won't be visible until the next invalidation trigger. Manual out-of-band edits are not a supported workflow; the safety note in `state-schema.md` documents this caveat.

**Step 2 — Batch parallel work.** Dispatch tasks on different files/modules concurrently up to `--parallel N`. Never parallelize tasks that share files. When in doubt, run sequentially.

**Step 3 — Dispatch agents.** For each task (or parallel batch):

1. Update the state file: set `status` to `"in_progress"`, record `started_at` with ISO-8601 timestamp, record `model_used`. Write the state file to disk. **Cursor only:** follow § **Cursor: state file sync** (Write → Read verify → then `TodoWrite`) in the same turn before step 2.
2. **Resolve description_ref (self-contained brief — mandatory before dispatch):** If the task has a `description_ref`, read the plan doc at the pointer (e.g., `Read("docs/plan/<name>-plan.md")`) and extract the referenced section to obtain the full task description, acceptance criteria, and implementation notes. Use this resolved content to compose the Context, Scope, and Acceptance Criteria sections of the brief. The final agent prompt must be fully self-contained — `description_ref` is resolved here so the agent never receives a bare pointer. If the task has `description_inline` instead, use that directly.
3. **Evaluate the memory-injection predicate (Lever 1) and call the selector (Lever 2).** Before spawning an agent, determine whether to inject `## Project Knowledge` into the brief. The rules below say when to skip (the user turned it off, the agent ignores project rules, or a retry already carried the notes) and how to avoid injecting the section twice.

   **Override flag.** The run-level flag `--memory-inject=off|auto|always` controls injection:
   - `off` — skip injection unconditionally for every dispatch in this run.
   - `auto` (default) — apply the full predicate below.
   - `always` — skip the predicate; call the selector with `enable_agent_type_intersection=false` (pure always-on tier output, no agent-type tag filtering).

   **Mechanical agents.** Some agents are convention-blind: their output does not change based on project rules because they are read-only analysis tools or mechanical revert agents. These agents derive no benefit from rule injection and incur unnecessary brief overhead. The list at v1 is:

   > **Literal constant definition — keep fenced.** The block below is a code-style definition used for reference, not a user-facing UI output. Do not unfence it.

   ```
   MECHANICAL_AGENTS = {code-intel, corpus-search, work-verifier, preflight, change-analyzer, rollback}
   ```

   An agent belongs on this list when project conventions do not change its output — read-only or convention-blind agents that neither author files nor apply coding standards. To add or remove an agent from the list, edit it here.

   **Predicate decision tree.** Evaluate top-to-bottom; the first matching branch governs:

   | Condition | Action |
   | :--- | :--- |
   | `--memory-inject=off` | Skip injection. Proceed to spawn without `## Project Knowledge`. |
   | `agent_type` ∈ `MECHANICAL_AGENTS` | Skip injection. Proceed to spawn without `## Project Knowledge`. |
   | `attempt > 1` AND the prior handoff body contains the exact sentinel (a fixed hidden marker the system writes so a later step can detect it) `<!-- project-knowledge:carried -->` | Skip injection (section was already carried in the prior attempt's handoff). |
   | `--memory-inject=always` | Call selector with `enable_agent_type_intersection=false`. Inject if bytes returned. |
   | Otherwise (default `auto` path) | Call selector with `enable_agent_type_intersection=true`. Inject if bytes returned. |

   **Handoff-detection rule (sentinel marker).** On retry (attempt > 1), the predicate searches the prior handoff body for the sentinel marker `<!-- project-knowledge:carried -->`. The prior handoff body is the content of the file referenced by the upstream task's `handoff_file` field in the state JSON. Detection is **exact-byte grep** — no regular expressions, no whitespace tolerance, no case folding. The literal byte sequence `<!-- project-knowledge:carried -->` must match or the predicate proceeds as if the sentinel is absent.

   Behavior on detection: skip injection — the downstream agent already received the section in the prior attempt's handoff and the content is considered carried.
   Behavior on no detection: proceed with the normal predicate flow above.

   **Why the sentinel approach?** A naïve substring scan for `## Project Knowledge` at the start of a line produces false positives when a handoff body contains a Markdown code fence that quotes a brief structure as an example — code fences do not indent their content, so column-0 matching cannot distinguish a real heading from a fenced example. The HTML-comment sentinel does not appear inside rendered Markdown code fences in normal output, eliminating this false-positive class.

   **Failure shapes (both non-correctness-breaking):**
   - Sentinel emitted but not detected on retry → predicate proceeds, brief carries the section a second time. Cost: duplicate bytes on attempt-2+ dispatches. Recovery: tighten the sentinel grep or verify the handoff file was written correctly.
   - Sentinel detected but content removed from the prior handoff (e.g., the handoff file was edited after the orchestrator wrote it) → predicate skips, agent retry operates without rules. Cost: same posture as pre-injection behavior. Recovery: none needed; the next fresh dispatch will re-inject.

   **Selector call.** Call the function documented in `skills/cross-memory/brief-injector.md` with a context object derived from the dispatch state:
   - `agent_type` — the task's `agent_type` value from the state file
   - `task_subject` — the task's `subject` field
   - `stage` — the task's `stage` field
   - `attempt` — the current attempt number
   - `prior_handoff` — full body of the upstream handoff file, or `None` if attempt == 1
   - `enable_agent_type_intersection` — `true` for default-inject, `false` for `always`-override
   - `budget_chars` — pass the call-site budget (default: read `max_brief_inject_chars` from `~/.cross-memory/config.yaml`, default `4096`)

   **Post-selector rule.** If the selector returns empty bytes, omit `## Project Knowledge` entirely — do not render an empty heading. If the selector returns non-empty bytes, render them as the `## Project Knowledge` section in the brief, placed **between `## Context` and `## Scope`**. After rendering, append the sentinel marker on its own line at the bottom of the section:

   > **Literal sentinel string — keep fenced.** The block below is an exact byte sequence written into agent brief text, not a user-facing UI output. Do not unfence it.

   ```
   <!-- project-knowledge:carried -->
   ```

   This sentinel enables the next attempt's predicate to detect that the section was carried, avoiding re-injection.

   **Cursor first-time awareness banner.** When the active harness is **Cursor** AND this is the first dispatch in the current session that fires injection (i.e., the selector returned non-empty bytes AND the run-level state field `memory_inject_banner_emitted` is not yet `true`), emit the following one-line banner to the user before the dispatch:

   > **Literal banner text — keep fenced.** The block below is the exact one-line string emitted to the user as a plain text message, not a formatted dashboard output. Do not unfence it.

   ```
   [memory-inject] Subagent briefs now carry ## Project Knowledge from your canonical store; top-level Cursor turns do not yet see this — see adapter-cursor.md §6 for the trust-model implication.
   ```

   After emitting the banner, set `memory_inject_banner_emitted: true` in the state file. The banner fires exactly once per session. Under **Claude Code**, suppress this banner — the top-level turn already sees `[CROSS-MEMORY]` injected by the always-on tier, so there is no trust-model inversion to disclose. At v1.1, once Cursor's `update_sentinel_block` lands and the top-level turn also sees the canonical store, this banner becomes unnecessary; the harness-conditional remains in place but evaluates to false.

4. Spawn the agent via the **Agent** tool using the task's `agent_type` from the state file. Follow the dispatch procedure below.
5. For parallel batches, issue all Agent tool calls in a **single message** so they run concurrently.

**Agent Dispatch Procedure** (applies to ALL agent dispatches throughout the workflow, not just Phase 3):

The Agent tool's `subagent_type` parameter accepts any agent type that has a definition file at `~/.claude/agents/` (Claude Code) or `~/.cursor/agents/` (Cursor). All agents in this taxonomy are registered `subagent_type` values in both environments. For each dispatch:

   a. **Manager read (frontmatter only):** Open `~/.claude/agents/<agent_type>.md` for `<agent_type>` from the state file; extract `model` from YAML frontmatter **only**. Never read or retain the agent body in the team manager's context — YAML frontmatter is the sole manager read; the spawned agent loads the full definition via the self-read prompt (rule e).
   b. **`model`**: Set from the agent's frontmatter `model` field (e.g., `"sonnet"`, `"opus"`).
   c. **`subagent_type`**: Always set to the task's `agent_type`. All agents with definition files at `~/.claude/agents/` are registered `subagent_type` values — no whitelist check is needed. The agent's definition still materializes via the self-read prompt (rule e) for full context.
   d. **`description`**: Always set to just `"<task subject>"`. The UI prefixes the `subagent_type` name automatically — wrapping the description with the agent_type (e.g., `"executor(Implement auth middleware)"`) produces double-labeling: `executor(executor(Implement auth middleware))`.
   e. **`prompt`**: Compose using the self-read template below, followed by the task brief (see Agent Briefing Format). The agent reads its full definition as its first action — self-containment is preserved because the agent body materializes in the agent's own context, not the team manager's.

**Self-read prompt template** (use verbatim, substituting `<agent_type>` and `<task brief>`):

> **Literal prompt string — keep fenced.** This is the exact text passed to each spawned agent as its prompt, not a user-facing UI output. Do not unfence it.

```
You are running as agent type: <agent_type>.

**First action:** Read `~/.claude/agents/<agent_type>.md` in full before any other work.

**Before any completion claim** — re-read the brief's `## Constraints` in full (load-bearing for scope, evidence, and verdict validity).

---

<task brief here>
```

**Dispatch example:**

> **Code invocation example — keep fenced.** The block below is a code-style invocation example, not a user-facing UI output. Do not unfence it.

```
Agent(
  description: "Implement auth middleware",
  model: "sonnet",
  subagent_type: "executor",
  prompt: <self-read template + task brief>
)
UI renders: executor(Implement auth middleware)
```

DO NOT set `description: "executor(Implement auth middleware)"` when `subagent_type: "executor"` is set.
This produces `executor(executor(Implement auth middleware))` in the UI.

Use the brief format below.

**Dispatch Log Append (opt-in via `--dispatch-log`)** — when the `--dispatch-log` flag is set, append a one-line entry to `docs/ops-dispatch-log.md` after each dispatch (or direct-tool choice governed by the Subagent Dispatch Decision Framework), capturing kind, framework row, and short description. This applies universally when enabled: Phase 3 dispatch loop, Trivial Dispatch, Brainstorm Gate, Phase 1a scoper/critic, Phase 2.5 preflight, and every other agent dispatch. When the flag is not set, skip entirely — do not touch the log file. The log is persistent across runs and serves as the audit trail for framework adherence.

> **Reference:** See `~/.claude/skills/ops/dispatch-log.md` for the file location, append procedure, entry format, kinds table, and audit usage. If the file is missing, proceed using the summary above. Read only when `--dispatch-log` is set.

**Foreground vs. Background Dispatch Policy**

Default dispatch is **foreground**; background criteria live in the companion.

> **Reference:** You MUST Read `~/.claude/skills/ops/dispatch-policy.md` for foreground/background decision criteria, batch rules, and interaction with health monitoring and worktree isolation. If the file is missing, default to **foreground** dispatch.

**Nested skill invocations:** When the team manager invokes a nested skill (e.g., `/deslop`, `/clickup`) during the dispatch loop, execute the write-before / clear-after ritual to prevent the turn from ending on the nested skill's return. The ritual has eleven steps (5 write-before + 6 clear-after):

- **Write-before** (immediately before the nested-skill call): (1) build the `pending_nested_skill` record with fields `skill`, `invoked_at`, `resume_phase`, `resume_notes`; (2) read the state file from disk; (3) set the `pending_nested_skill` field on the root object; (4) write the state file to disk; (5) issue the nested-skill call.
- **Clear-after** (immediately after the nested skill returns, in the same turn): (1) read the state file from disk (cache was invalidated — see Step 1); (2) read `pending_nested_skill.resume_phase` and `resume_notes` to identify where to resume and how to proceed; (3) capture any output the nested skill produced that downstream phases need — write it into a handoff file where one exists, or hold it in-turn for the next agent's brief when no handoff procedure applies; (4) set `pending_nested_skill` back to `null`; (5) write the state file to disk; (6) execute the `resume_phase`-specified next action. **Do not end the turn.** See Non-negotiable #10.

**Step 4 — Process results.** When an agent returns, **immediately** update the state file: record `completed_at` with ISO-8601 timestamp, calculate and store `duration_seconds`, increment `attempts`. Write the state file to disk. **Cursor only:** after Write, Read-verify per § **Cursor: state file sync**, then update `TodoWrite` for any `status` change in the outcome table below. `TodoWrite` alone does not satisfy Non-negotiable #3. (Non-negotiable — see #3.)

After updating timing, check elapsed time of all in-progress background agents against their estimates. Emit a `⚠️ SLOW` warning when elapsed exceeds 1.5× estimate, or `🔴 OVERRUN` when elapsed exceeds 2.5× estimate. Warnings are emitted once per threshold crossing per task. For tasks with `estimate_source: "ops"` (rough estimates), suppress SLOW and emit OVERRUN only.

| Outcome | Action |
| :--- | :--- |
| **Passed** — acceptance criteria met | Update state file: `status` → `"completed"`. **Cursor:** Write → verify → `TodoWrite`, then write handoff (see Handoff Documents). Check for newly unblocked tasks. |
| **Failed — 1st attempt** | Re-dispatch with the error appended to the brief. Narrow the scope or add constraints based on what went wrong. |
| **Failed — 2nd attempt** | Dispatch a **debugger** agent (or **debugger-build** if the failure is a build/import/type error) to diagnose the root cause. Use its findings to re-brief the original agent with a corrected approach. |
| **Failed — 3rd attempt** | Escalate model (sonnet → opus, opus → fable) and re-dispatch with full error history. Skip if already on fable; security-reviewer caps at opus and never escalates to fable. See Model Escalation in Adaptability. The `opus → fable` step goes through the **`fable`-escalation confirmation gate** (see Model Escalation in Adaptability): interactive (and `--supervised`) waits for the user; autonomous waits best-effort ~1 minute then defaults NO and runs the 3rd attempt on the original `opus` model. `security-reviewer` never reaches the gate. |
| **Failed — at the loop cap** | Escalate to the user with: the task, all attempts, errors, debugger findings, and your diagnosis. Pause this chain; continue other independent chains. Cap is mode-aware: 3 loops in interactive/supervised, 5 loops in autonomous. In autonomous mode, loops 4 and 5 re-dispatch on the already-escalated model (opus after the fable gate defaults NO) with debugger findings from the 2nd attempt carried forward — the model tier does not climb further and the fable gate does not re-fire. |
| **Blocked** — agent hit an external dependency or environment issue | Create a new blocker task describing the issue. Pause dependent chain. Flag to user. |
| **Scope issue** — agent says the plan is wrong or incomplete | Pause chain. Ask the user whether to re-plan or adjust. |
| **NEEDS_CLARIFICATION** — brief is well-formed but agent has one clarifying question before starting | See handling below. |

**NEEDS_CLARIFICATION handling:**

- **Interactive mode:** Present the agent's question and context to the user verbatim. Get the answer. Re-dispatch the same agent with the answer appended to `## Context` under a heading like `**Clarification answer:**`.
- **Autonomous mode:** The team manager answers if it has the information from the state file, plan doc, or prior handoff context. If it does not have the information, escalate to the user (same as interactive mode for this question).
- **Round-trip cap:** Allow at most one NEEDS_CLARIFICATION round-trip per task. If the re-dispatched agent returns NEEDS_CLARIFICATION a second time, treat it as a **Scope issue** and escalate to the user — do not answer autonomously a second time.
- Do not mark the task `failed` or increment the attempt counter on a NEEDS_CLARIFICATION return. The re-dispatch after clarification is attempt 1.

**Special cases:** the health-action sub-step (background-agent orphan recovery) and the budget model-escalation consultation sit below the primary outcome path above.

**Health-action sub-step (background agents only).** After the `⚠️ SLOW` / `🔴 OVERRUN` emission, the orchestrator evaluates the **sustained-`OVERRUN`** trigger for each in-progress **background** agent. An agent is in *sustained* `OVERRUN` when **either** holds:

- its elapsed time has stayed past the **2.5× display threshold** across **N = 2 consecutive check-in events** (provisional — pending more timing data); **OR**
- its elapsed time has crossed a **higher multiple of the 2.5× display threshold — `≥ 4× estimate`** (provisional — pending more timing data).

Either condition is sufficient in the structural definition; the current **provisional calibration requires BOTH** (N = 2 AND ≥ 4×) to hold before firing, pending real health-action telemetry. When that telemetry accumulates, the values can be re-derived and the provisional flag dropped.

The trigger is a **prompt to diagnose, not a decision to act** — firing it dispatches the read-only `work-verifier` and does not by itself re-dispatch or mutate anything. It is a **third, distinct number**, not to be conflated with: the **2.5× display threshold** (`phase-dispatch.md:466`, which lights `🔴 OVERRUN`; a single instantaneous 2.5× crossing never fires this sub-step, and `⚠️ SLOW` at 1.5× never does); nor the **orphan-suspicion timeout** `MIN(agent-type default, 3× task estimate)` (`work-verifier.md:176`, which drives `👻 ORPHAN?`), which is usually below 3× (for example, an executor on a 15-min estimate → `MIN(15, 45) = 15 = 1×`). The higher multiple is deliberately derived **from the 2.5× display threshold, not the orphan timeout** — anchoring to the orphan timeout would fire *after* the dashboard already showed `👻 ORPHAN?`, an inverted ordering.

The trigger is evaluated at **every** check-in event (after foreground returns, after background completion notifications, before responding to user messages, per `dispatch-policy.md:38-40`) — not only after a foreground return.

**Diagnosis: dispatch the read-only `work-verifier`.** When the sustained-`OVERRUN` trigger fires, the orchestrator dispatches the read-only `work-verifier` to inspect the suspected-orphan's *work-state*. The dispatch uses the **existing mechanical-agent dispatch shape**: no memory injection (`work-verifier` is in `MECHANICAL_AGENTS`, `phase-dispatch.md:346,356`), with a standard `## Task` / `## Scope` / `## Constraints` brief and orphan detection enabled (the same enablement the `status` command uses, `phase-intake.md:12`). The dispatch is read-only — `work-verifier` inspects files and git state and reports findings; it modifies nothing and re-dispatches nothing (`work-verifier.md:14`, `:234-240`). Because the diagnosis is read-only, it requires **no pre-approval in any mode**. The `work-verifier` returns a *work-state* verdict — `completed` / `partial` / `not-started` / `broken` (`work-verifier.md:32-37`) — which describes how much work landed. It does **not** return process liveness; that is outside its lane (`work-verifier.md:234-240`) and is supplied separately by the orchestrator's own dispatch bookkeeping.

**Verdict branch and liveness gate.** The sub-step branches on the `work-verifier` work-state verdict. The **re-dispatch leg additionally requires the orchestrator's own "no live agent" signal**: the task is `in_progress`, its `OVERRUN` is sustained, AND no completion/heartbeat notification has arrived on its background handle — the same "no completion received" signal the `👻 ORPHAN?` flag uses (`phase-completion.md:78`). No path re-dispatches on the bare `OVERRUN` signal alone, and no path re-dispatches on a `partial` work-state while the orchestrator's handle still shows the agent alive.

- **`completed`** — the agent finished and the orchestrator missed the notification. Mark the task done in the state file and write any missing handoff (`work-verifier.md:219`). **No re-dispatch.** Append one `type: health-action` entry to `adaptations` with `action_taken: diagnosed-alive`.
- **`not-started` or `partial` AND the orchestrator confirms no live agent** — confirmed orphan. Enter the recovery path below. Append one `type: health-action` entry to `adaptations` with `action_taken: re-dispatched` (or `action_taken: re-dispatch-escalated` if the recovery escalates).
- **`not-started` or `partial` but the background handle is still live or a notification is pending** — the agent is slow but alive; a `partial` result reflects how much work has landed, not whether the writer is gone. Keep watching. **No re-dispatch.** Append one `type: health-action` entry to `adaptations` with `action_taken: diagnosed-alive`.
- **`broken`** — a wrong-output event, not a liveness event. Route through the existing rollback-then-re-dispatch path (`work-verifier.md:222`, `SKILL.md:417`): dispatch a **rollback** agent to revert the broken output, then re-dispatch the original agent on a clean slate. Append one `type: health-action` entry to `adaptations` with `action_taken: re-dispatched`.

**Recovery rule (confirmed orphan).** A confirmed-orphan recovery is governed by **exactly one** rule: the Failure Handling row "Agent timeout or crash → Retry once with same brief, then escalate" (`SKILL.md:413`) — one same-brief re-dispatch, then escalate to the user if that also orphans or fails (logging `action_taken: re-dispatch-escalated`). The confirmed orphan does **not** enter the four-step Step-4 outcome ladder above and no debugger is interposed — a debugger diagnoses output, build, or logic failures, whereas an orphan is a liveness event the `work-verifier` plus the orchestrator's own signal have already diagnosed. The retry cap stays single-sourced in `SKILL.md:413` by cross-reference; it is not restated here.

The re-dispatched orphan inherits the **same foreground/background and worktree posture** as the original dispatch: a background-with-worktree orphan is re-dispatched background-with-worktree, reusing the surviving worktree if `work-verifier` reports it intact (`work-verifier.md:202-208`), else falling back to the main tree. The orphan re-dispatch **inherits the `attempts` counter** — it continues the same task's attempt count rather than resetting it. The re-dispatched orphan is **itself health-monitored** under the same sustained-`OVERRUN` trigger — no exemption. The recursion is bounded by the single-retry `attempts` cap from `SKILL.md:413`: at most one orphan re-dispatch per task; a re-dispatched orphan that also orphans escalates to the user rather than triggering another re-dispatch.

**Parallel safety on re-dispatch.** Before re-dispatching a confirmed orphan, the orchestrator applies the **existing** Parallel Safety Rules (`SKILL.md:376-393`): if the re-dispatched task would touch a file an in-flight sibling task touches, the re-dispatch is **sequenced** (waits for the sibling) rather than parallelized. The `work-verifier` already checks worktree state and file conflicts between parallel tasks as part of its procedure (`work-verifier.md:194-208`); the orchestrator consumes that finding rather than re-deriving it. The re-dispatch is bound by the same parallel-safety floor every dispatch is — no new rule is introduced.

**Mode-conditional surfacing.** In **autonomous mode (`--autonomous`)**, the diagnose-and-recover sequence proceeds automatically (no human is watching), with each action logged to `adaptations`; the *escalation* leg of the reused retry rule (`SKILL.md:413` — "then escalate") still stops for the user, consistent with the Autonomy table's stop conditions (`SKILL.md:426`). In **interactive or supervised mode**, before re-dispatching a confirmed orphan the orchestrator surfaces a one-line note such as: "Task #N's agent appears orphaned (sustained OVERRUN; work-verifier confirms no live agent); re-dispatching per the timeout/retry rule." The one-line note rides the existing check-in cadence (`dispatch-policy.md:38-40`) and does not introduce a new checkpoint. The **read-only diagnosis** (the `work-verifier` dispatch) requires no pre-approval in any mode.

Orphan detection is handled by the **work-verifier** agent (see `~/.claude/agents/work-verifier.md`), which includes timeout budgets per agent type and orphan detection heuristics.

**Budget governor (model-escalation consultation).** This sub-step runs only when the user set a run-level dispatch-count ceiling with `--budget`. When no budget is set, the entire sub-step is a strict no-op: there is no accumulator, no consultation, and no `budget` object written to the state file, and every path below behaves byte-for-byte as it does on a run without a budget.

When a budget **is** set, the orchestrator maintains `budget.consumed_so_far` (see `state-schema.md`) as a running count of dispatches in the run, incrementing it as dispatches complete. The accumulator only counts; it **never interrupts, kills, or re-dispatches an agent that is already running** to enforce the budget — in-flight work always runs to completion under the existing parallel-safety rules. The governor is consulted only *before* a new, not-yet-started cost-affecting action.

Before a **model escalation** — the "Failed — 3rd attempt" escalate-model action in the outcome table above, where a task is about to be retried on a higher model tier — the orchestrator consults the budget:

- **Near ceiling (a fixed default of 80% of the ceiling consumed, first crossing only).** Surface a one-line advisory — "budget ~80% consumed; the next escalation would spend more" — and **proceed** with the escalation. The note is informational and **never blocks, in any mode** (interactive, supervised, autonomous). It fires **once per threshold crossing**: set `budget.near_note_fired` so subsequent choice points below the at-ceiling line stay silent and the run does not degrade into confirmation-prompt noise. Append a `type: budget-escalation` adaptation with `action_taken: budget-near`.
- **At ceiling (this escalation would cross the ceiling).** **Escalate to the user** — in interactive, supervised, **and** autonomous mode alike; like a blocker, a budget ceiling is a decision point the user must resolve, never silently auto-resolved. Flush `budget.consumed_so_far` and `budget.near_note_fired` to the state file **before** the escalation surfaces, so a `resume` mid-escalation recovers the budget context. The escalation states the task, the action about to be taken (escalate this task to the higher model tier), the estimated marginal cost (one more dispatch), and exactly three options: **spend it** (proceed with the escalation), **defer the task with user approval**, or **stop the run**. It **never** offers "silently drop the task" — hitting the ceiling escalates; it never drops, skips, or marks-done a task to stay under budget. Record the user's resolution with the matching `action_taken` (`budget-escalated` when the escalation surfaces, then `budget-spent` or `budget-deferred` for the resolution). When the action about to be taken is the gated `opus → fable` escalation, the budget escalation and the `fable`-escalation confirmation gate are the **same stop** — not sequential; see Escalation composition below.

**Escalation composition (one decision point, never two stacked stops).** When an at-ceiling budget escalation and the "Failed — at the loop cap" escalate-to-user action fire on the **same task**, they compose into **one** decision point: the budget trade-off is surfaced *as part of* that single escalate-to-user stop, not a second stop layered on top of it. The same composition holds when an at-ceiling budget escalation and an orphan-recovery escalation (`SKILL.md:413` — "then escalate") fire on the same task: they compose into one decision point, never two stacked stops. The same composition holds when an at-ceiling budget escalation and the `fable`-escalation confirmation gate (see Model Escalation) fire on the same 3rd-attempt escalation: they compose into one decision point — the budget trade-off is surfaced as part of the single fable-confirm stop, never a second stop layered on top.

**Never above a correctness gate.** This consultation is wired only in front of the model-escalation choice. It is **never** placed above the Verify → Fix loop or its mode-aware loop cap, the agent-level verification-gate ritual (`verification-gate.md`), the deliverables-on-disk / timing / lane non-negotiables, or the security-review stage. A budget ceiling can defer or escalate a *cost* choice; it can never cause a correctness gate to be skipped, shortened, or marked satisfied without fresh evidence.

**`fable`-escalation autonomous timeout (mechanism).** When the `fable`-escalation confirmation gate (see Model Escalation in Adaptability) fires in **autonomous mode**, the orchestrator does not block. It surfaces the confirmation prompt to the user, then writes a `pending_fable_confirm` record to the state file (see `state-schema.md`) carrying the task id, the pre-escalation model (`opus`), and an ISO-8601 UTC `deadline` set to **now + ~60 seconds**. The deadline is a *best-effort* SLA, not a real-time timer: it is evaluated at the **next orchestrator beat** (the existing check-in cadence — after a foreground return, after a background completion notification, or before responding to a user message, per `dispatch-policy.md:38-40`), exactly like the sustained-`OVERRUN` health trigger. There is no wall-clock interrupt.

Resolution, at the first beat at or after the deadline:
- **A "yes" arrived before the deadline** (the user replied in the window): clear `pending_fable_confirm`, escalate the 3rd attempt to `fable`, and proceed.
- **No reply by the deadline → default NO:** clear `pending_fable_confirm`, run the 3rd attempt on the recorded original `opus` model, and keep the run unblocked. The Verify → Fix loop cap still applies — in autonomous mode, loops 4 and 5 re-dispatch on the opus model before escalating to the user at the 5-loop cap.
- **A "no" arrived before the deadline:** clear `pending_fable_confirm`, run the 3rd attempt on the original `opus` model (same as the timeout path).

A `resume` of a run interrupted while `pending_fable_confirm` is set re-reads the deadline from the state file: if the deadline has already passed, the default-NO path fires on resume; if not, the orchestrator continues waiting until the next beat at or after the deadline. Flushing the record before surfacing the prompt (same before-the-stop discipline the budget object uses) means the timeout survives an interruption. **Never pause indefinitely** — the deadline guarantees the autonomous run always proceeds, with or without a reply.

**Step 5 — Stage transition check.** When all tasks in a pipeline stage finish:

**Step 5a — Reflection beat (pipeline route only).** Before rendering the stage summary and dashboard, perform one short self-critique: given what the stage that just finished produced, does the remaining plan still hold — is any downstream task now redundant, mis-sequenced, or under-specified? Write the answer as a single bounded paragraph (one paragraph, roughly 80 words or fewer) and append it to the run-level `adaptations` array with `type: reflection`, the finishing stage, and an `action_taken` value. Do this exactly once per stage transition. The beat runs only on the `pipeline` route — the trivial route has no stage transitions, so it never fires there. **The beat does NOT fire after the final stage:** once the last stage finishes there is no remaining plan to reflect on, so reflecting would only produce a vacuous "nothing left" entry. Fire it only on transitions *into* a subsequent stage. If nothing is flagged on a firing transition, still write a single-line "no remaining-plan concern" entry with `action_taken: logged`, so the log shows the beat ran.

The beat is advisory and additive-only. Branch on what it surfaces:

- **Addition or re-sequencing** — if the beat finds work to add or a step to re-order, route it through the existing Mid-run plan adjustment mechanisms (see Adaptability) and record the entry with `action_taken: proposed-addition` or `proposed-resequence`. Both are already-allowed adaptations. **A re-sequence may only re-order tasks — it must never orphan, drop, or cancel a task.** A re-sequence that would remove a task from the plan is a scope reduction in disguise: treat it as a reduction and escalate (next branch) rather than recording it as `proposed-resequence`.
- **Reduction** — if the beat finds work that should be removed (a task now redundant), do not remove or mark-cancelled any task. Escalate to the user and record the entry with `action_taken: escalated`. Scope reduction always requires user approval (see the Adaptability guardrail). When **two or more** remaining tasks are now-redundant, that case routes through the Re-plan escalation sub-step's scope-drop gate rather than the single-task escalate path above.

These two branches are mutually exclusive for a given finding. The beat only writes the note and, at most, proposes through the existing mechanism or escalates. It does not call the planner, does not re-score estimates, and does not mutate the dependency graph itself.

**Step 5b — Re-plan escalation (pipeline route only).** When the reflection beat finds material remaining-graph invalidation — meaning it identifies a case that exceeds what the advisory beat can handle — the orchestrator executes a controlled re-plan of the unfinished task graph. This sub-step is the controlled escalation target the beat hands to when it cannot resolve the problem in-place; the beat itself is left capped at "does not call the planner."

**Trigger predicate.** The re-plan fires only when the finished stage's real output makes **two or more** remaining `pending` or `blocked` tasks impossible-as-written, now-redundant, or dependent on an assumption the stage falsified. The evaluation is post-stage against the finished stage's real output, at the same moment as the reflection beat — it is never pre-emptive. Single-task drift stays in the existing Mid-run plan adjustment table (see Adaptability); a whole-plan invalidation that renders every remaining task invalid still escalates to the user rather than triggering a re-plan. A re-plan that would change nothing is a no-op (idempotent re-evaluation — if the planner's revision leaves every pending/blocked task identical, no board rewrite occurs and the event is logged with `action_taken: logged`).

Two path-exclusion rules apply at this evaluation point. First, the Step 4 / agent-return Scope-issue path (around line 440: "Scope issue — agent says the plan is wrong or incomplete → Pause chain. Ask the user whether to re-plan or adjust.") pre-empts this sub-step for the same stage: a paused chain never reaches a clean stage boundary, so the two never both fire for a single stage. Second, if two or more remaining tasks are now-redundant (rather than impossible-as-written or falsely-assumed), those tasks must route through the scope-drop gate (user approval) rather than being silently removed — redundancy-removal is not laundered past the reflection beat's escalate-as-reduction branch.

**Boundary guard.** The re-plan fires only at a clean stage boundary: all tasks in the finished stage have `status: completed`, no parallel-dispatch window is open, and no task is `in_progress`. When a parallel window is still open (one or more tasks are still running), the re-plan waits — it does not interrupt in-flight work. Tasks that are `in_progress` or in an open parallel window are never revision candidates; only `pending` and `blocked` tasks are eligible. This uses the same stage-boundary point the reflection beat uses — not a new boundary. Additionally, the re-plan trigger is suppressed when the run is wrapped in `ralph` (see the SKILL.md Ralph Loop Integration section): in that mode, ralph owns per-iteration re-planning and the team manager must not interpose a mid-run re-plan.

**Cap guard.** A default of **1** in-flight re-plan is allowed per run; a second re-plan requires explicit user approval at the checkpoint before it may proceed. The cap is enforced by counting every `adaptations` entry with `type: replan`, including entries with `action_taken: replan-escalated` — escalated re-plan attempts count against the cap. When the cap has been consumed by a prior re-plan (applied or escalated), the orchestrator surfaces the situation to the user and requests explicit approval before dispatching the planner again.

**Planner re-dispatch.** When the trigger fires at a clean boundary within cap, the orchestrator dispatches the `planner` agent on the `pending` and `blocked` tasks, accompanied by the finished stage's real output as evidence. Completed work is passed as immutable context — it is never a revision candidate. The planner updates the existing `plan_file` in place (it does not create a new plan document). The planner's brief instructs it to: keep stable slugs for surviving tasks; for replaced tasks, retain their existing ids while assigning a new heading and anchor; give genuinely new tasks a fresh id and heading. The planner's lane is plans-only: it does not estimate, implement, or review. The mid-run re-plan does not route back through the project-scoper for re-estimation — it reuses the critic loop only. The re-plan planner spawn and the critic re-dispatch both **count toward the budget accumulator** like any other dispatch; the at-ceiling new-dispatch escalation fires **once per re-plan**, before the planner is spawned — the critic re-dispatch within the same approved re-plan does **not** re-fire it.

**Critic loop re-entry.** After the planner delivers the revision, it re-enters the existing Phase 1a Critic Verdict Handling loop — see `plan-validation.md` for the REVISE/ACCEPT/REJECT table and the hard cap on revision loops. The mid-run re-plan does not carry its own separate cap; it reuses the Phase 1a loop wholesale, including its cap number and escalation condition (which are single-sourced in `plan-validation.md` and are not restated here). On a critic ACCEPT — and only if no scope drop is required — the board rewrite proceeds. On `ACCEPT WITH RESERVATIONS`, the team manager stops and surfaces the reservations to the user before any board rewrite, regardless of mode.

**Cap-exhaustion escalation.** When the critic loop reaches its cap mid-run without converging on an ACCEPT, the orchestrator escalates to the user with the critic's findings and the remaining graph marked "known-invalid — re-plan did not converge." Both silent resume of the invalidated plan and silent abandonment of the run are forbidden. The event is logged with `action_taken: replan-escalated`. This is the Phase 1a cap-exhaustion posture applied at a mid-run stage boundary — see `plan-validation.md` for the canonical escalation condition.

**Board-rewrite invariants.** On a critic-ACCEPTED, non-scope-dropping revision, the board rewrite proceeds subject to five invariants: (a) only `pending` and `blocked` tasks are revision candidates — no other status is touched; (b) `completed` and `in_progress` tasks are immutable; (c) the run-id, state file, and `plan_file` are retained — no new run, no new plan document; (d) `blocked_by` chains remain valid after rewrite — no orphaned or dangling edges; (e) for every revised task, the stored `description_ref` anchor is re-derived from the task's (possibly new) heading slug in the updated `plan_file`, so the Phase 3 Step 3 heading-grep (`state-schema.md:225`) resolves — no `pending` or `blocked` task is left with a `description_ref` whose heading is absent from the updated plan document. The board write is ordered last in the transition so that an interrupted rewrite never points the board at headings the plan document lacks.

**Scope-drop gate.** A critic ACCEPT validates quality but does not grant scope authority. If the critic-ACCEPTED revision drops any committed task (any task already on the board), the orchestrator stops and presents the proposed removal to the user for explicit approval before applying the rewrite, regardless of mode — this applies in interactive, autonomous, and supervised modes alike. The two gates are stacked, not substituted: critic ACCEPT is required first, then the scope-drop gate clears the removal. The SKILL.md Adaptability no-silent-scope-reduction guardrail ("The team-manager … must not silently remove tasks or reduce scope. Scope reduction always requires user approval.") is unchanged. A user-approved scope-dropping re-plan logs `action_taken: replan-escalated`.

**Mode-conditional surfacing.** When a re-plan proceeds (critic ACCEPT, no scope drop, or a user-approved scope-dropping re-plan), the surfacing behavior follows the existing Step 5 mode branch: interactive surfaces a one-line checkpoint to the user before resuming the dispatch loop; autonomous proceeds on a non-scope-dropping result with the logged `type: replan` adaptation recorded in `adaptations`, EXCEPT a scope-dropping re-plan always stops for user approval even in autonomous mode; supervised is already checking in per-dispatch, so the stage-boundary note covers it. The promotion pattern follows the same one-line checkpoint and logged-adaptation surfacing pattern the existing Step 5 mode branch uses — the procedure is not duplicated here.

| Mode | Behavior |
| :--- | :--- |
| Interactive (default) | Show stage summary + dashboard (`phase-completion.md`; full if ≥ 3 tasks; one-liner per task if ≤ 2). Ask user to proceed, adjust, or stop. |
| Autonomous | Proceed automatically. Stop on escalation/scope issues and any brainstorm design-approval checkpoint. |
| Supervised | Already checking in per-task — just note the stage boundary. |

**Step 6 — Loop.** Return to Step 1.
