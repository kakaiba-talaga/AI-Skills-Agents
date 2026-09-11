<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Handoff Documents — Full Reference

When a task completes and its output feeds into a downstream task, create a **handoff document** — a structured summary that preserves context across stage transitions. This is critical because each agent starts fresh with no memory of prior agents.

**Handoff documents are persisted to disk**, not kept only in conversation context. This ensures they survive session loss, context compression, and rate-limit interruptions.

## Run identity

A **new run** is created only when the team manager enters Phase 1 with a new spec AND proceeds to Phase 2 (task board creation). All other `/ops` invocations (`resume`, `status`, `add`, `pause`, mid-run instructions, checkpoint approvals) are **continuations** of the current run and reuse its run ID.

**When is it a new run?**

| Invocation | New run? |
| :--- | :--- |
| `/ops <new spec>` with no active tasks | Yes |
| `/ops <new spec>` with active tasks | **Prompt**: "You have an active run with N pending tasks. Start a new run or add to the current?" |
| `/ops resume/status/add/pause/stop` | No — continuation |
| `/ops` with mid-run instructions ("yes proceed", "also do X") | No — continuation |

**Run ID format:** `<plan-slug>-<ISO-date>` derived from the plan document name + run start date (e.g., `caching-layer-2026-04-09`). Stored in the state file's root `run_id` field. This allows any invocation to check "am I part of an existing run?" by reading the state file.

## Storage location

Each run gets its own subdirectory under `.agents/handoffs/`:

```
.agents/handoffs/
  caching-layer-2026-04-09/
    handoff-001-implement-to-verify.md
    handoff-003-verify-to-review.md
  auth-refactor-2026-04-09/
    handoff-001-implement-to-verify.md
```

This ensures multiple concurrent sessions (or sequential runs) never interfere with each other's handoff files.

## Naming convention

`handoff-<task_number>-<from_stage>-to-<to_stage>.md`

- Example: `handoff-003-implement-to-verify.md`
- Example: `handoff-007-verify-to-review.md`
- For verify→fix loops, append the iteration: `handoff-003-verify-to-fix-iter2.md`

## Template

```
## Handoff: [completed stage] → [next stage]
### Run context
- **Run ID:** [run_id from task metadata]
- **Plan document:** [path to plan doc, if one exists]
- **Task #:** [task number]
- **Timestamp:** [ISO-8601]

### What was done
[Summary of the completed work — which files changed, what was implemented/verified/reviewed]

### Key decisions
[Any non-obvious choices the agent made and why]

### Files changed
- `path/to/file.py:42-78` — [what changed]
- `path/to/other.py:10` — [what changed]

### Open items
[Anything the agent flagged but did not address — edge cases, TODO notes, uncertainties]

### For the next agent
[Specific guidance for the downstream task — what to focus on, what to watch for]
```

## Writing handoffs

After marking a task `completed` in the dispatch loop (Phase 3, Step 4), immediately write the handoff document to the run's subdirectory on disk. Store the handoff file path in the task's `handoff_file` field in the state file: `"handoff_file": ".agents/handoffs/<run_id>/handoff-003-implement-to-verify.md"`. This allows `resume` to locate handoffs from the state file.

## Reading handoffs for downstream briefs

When composing an agent brief, read the relevant handoff file(s) from the run's subdirectory and include the content in the **Context** section of the brief. For converging chains (multiple executors → single verifier), concatenate all relevant handoff files.

Open items travel with the handoff, and the agent receiving them is barred from acting on out-of-scope work just as the agent that raised them was. Carrying a finding forward is not dispositioning it. The orchestrator does that at Step 4 of the dispatch loop, in the same beat as the return that raised it, rather than leaving it to the end-of-run relocation sweep. See `orchestrator-obligations.md`.

## Handoff accumulation

Each stage transition writes a new handoff file. The full chain of handoff files for a task represents its complete history. When briefing a downstream agent, include the most recent handoff plus a summary of earlier ones (to avoid oversized briefs).

## Handoff cleanup

Handoff files are scoped per run and cleaned up based on run lifecycle:

1. **On successful completion (Phase 4):** Delete the run's handoff subdirectory. The run is done — `resume` won't be needed, and the deliverable artifacts (plan doc, committed code, documentation) are the permanent record. This deletion is preceded by the Phase 4 step 9a relocation sweep (see `~/.claude/skills/ops/phase-completion.md` step 9a), which reads the handoffs before they go and routes anything durable to its real home. A handoff's `### Open items` section is the most common thing the sweep needs to rescue: it holds flagged-but-unaddressed work that would otherwise vanish along with the file.
2. **On pause/cancel/abort:** Keep the run's handoff subdirectory intact. The user may `resume` later. This is a continuation of an unfinished run, not a retention decision: Phase 4 owns the eventual cleanup once the run does complete.
3. **Never delete another run's subdirectory.** Each run only manages its own files. This prevents multi-session interference.
4. **Stale run detection:** At the start of a new run (Phase 1), check `.agents/handoffs/` for subdirectories that have no matching state file in `.ops-state/` and whose age exceeds the staleness threshold (default: **7 days**, adjustable). Age is measured by the date component of the run-id suffix (e.g., `caching-layer-2026-04-09` → `2026-04-09`); if the run-id carries no parseable date, fall back to the directory's filesystem mtime. If found, warn the user: "Found stale handoffs from run `<run_id>` (older than the staleness threshold — default 7 days — and no active run). The relocation sweep has not yet run. Clean up?" Only delete on explicit user approval — never auto-delete. Once that approval is in hand and before the first delete, run the step 9a relocation sweep against the stale run's handoff subdirectory, because it is the same class of directory item 1's own Phase 4 deletion sweeps before removing it; nothing is deleted that has not been swept. Delete each qualifying subdirectory individually; never a directory-level or glob delete across multiple stale runs.
5. **Stale cleanup records:** The same check extends to orphaned cleanup record files, `.ops-state/<run-id>-cleanup.json`, left behind by a run interrupted between step 9b and step 10's delete (see `~/.claude/skills/ops/phase-completion.md`'s Phase 4 completion section, step 10). At the start of a new run, check `.ops-state/` for a `<run-id>-cleanup.json` with no matching board file and whose age exceeds the same staleness threshold used above. If found, warn the user with the same phrasing pattern as item 4 but without item 4's sentence about the relocation sweep, substituting the cleanup record's path, and only delete on explicit approval; never auto-delete. This item runs no relocation sweep, so its warning omits any claim about a sweep's status.
6. **Stale terminal boards:** Items 4 and 5 both detect artifacts left behind after a board is already gone. This item covers the case where the board itself is still sitting on disk: a `.ops-state/<run-id>-board.json` belonging to a run other than the current one, where every task's `status` (see `~/.claude/skills/ops/state-schema.md` § Status enum) has reached a terminal value (`completed`, `failed`, `blocked`, `deleted`, or `cancelled`), and whose age exceeds the same staleness threshold used above. Both conditions must hold together: a run carrying any `pending` or `in_progress` task is paused, not abandoned, within this threshold, and that presumption expires only at the much longer abandonment threshold item 7 below applies. At the start of a new run, check `.ops-state/` for boards meeting both conditions. Such a board never reached Phase 4, so it never went through the step 9a relocation sweep that routes durable content to its real home before deletion (see item 1 above and `~/.claude/skills/ops/phase-completion.md` step 9a). That is precisely how it ended up sitting here. Warn the user with the same phrasing pattern as item 4, substituting the run ID and board path, and stating that the relocation sweep has not yet run. Only delete on explicit approval; never auto-delete. Once that approval is in hand and before the first delete, run that same relocation sweep against the stale board, its run's handoff subdirectory, and its save file when the user's approval names it, because the sweep exists to protect content before it is deleted; nothing is deleted that has not been swept first. Delete one file at a time: the board, then the handoff subdirectory, and the save file only when the approval names it; a bare approval removes the board and the handoff subdirectory and leaves the save file in place. Never a directory-level or glob delete.
7. **Abandoned non-terminal boards:** Item 6 covers a board every one of whose tasks has reached a terminal value. This item covers the board item 6 leaves alone: a `.ops-state/<run-id>-board.json` belonging to a run other than the current one, carrying at least one task whose `status` (see `~/.claude/skills/ops/state-schema.md` § Status enum) is `pending`, `in_progress`, or unrecognized, whose **file mtime** age exceeds an **abandonment threshold (default: 30 days, adjustable)**. This check ages the board by its file mtime rather than by the date encoded in the run-id suffix, because the question it answers is when the run last did anything, not when it started; a run that resumed work last week after starting months earlier is not abandoned no matter how old its run-id date reads. At the start of a new run, check `.ops-state/` for boards meeting both conditions. This item follows item 6's shape and sweep ordering. Warn the user with the same phrasing pattern as item 4, substituting the run ID, the board path, the idle age, and the count of non-terminal tasks, and — when a save file exists for the run — its path and its `saved_at` value together with one sentence saying what a save file holds, plus the same clause item 6 carries stating that the relocation sweep has not yet run. Only delete on explicit approval; never auto-delete. Once that approval is in hand and before the first delete, run the step 9a relocation sweep against the board, the run's handoff subdirectory, and the save file when the user's approval names it; nothing is deleted that has not been swept. Delete one file at a time: the board, then the handoff subdirectory, and the save file only when the approval names it; a bare approval removes the board and the handoff subdirectory and leaves the save file in place. Never a directory-level or glob delete.
8. **Unreadable boards:** This item covers a `.ops-state/<run-id>-board.json` whose JSON does not parse, and whose mtime age exceeds the same abandonment threshold item 7 uses rather than the shorter staleness threshold items 4 through 6 use: a board nobody can read carries less evidence of pending work than either readable case above, so it waits at least as long as an abandoned board, not less. Run identity here comes from the filename's `<run-id>` segment alone, because `run_id` cannot be read out of a file that will not parse; a board whose filename segment matches the current run is this run's own and is out of scope. This item has to exist because items 6 and 7 both read every task's `status` to decide whether a board qualifies, so without a check that fires on parse failure, a board nobody can parse is exempt from this entire section at any age.

   Read on its own, the rule running through items 6 and 7 — nothing is deleted that has not been swept — would forbid this item from ever acting, since a sweep can rescue durable content only from a file it can read. This item satisfies that rule instead of standing outside it: the step 9a relocation sweep is still attempted against the board, after the approval and before the delete, on the same ordering items 6 and 7 use. It necessarily comes back with nothing, because the sweep cannot parse the file either, so nothing can confirm what is inside. That is not a reason to skip the sweep; it is exactly why the warning here carries an unsalvaged-content disclosure that items 6 and 7 do not need. The invariant holds in this item's own terms: the sweep runs, and nothing is deleted that the sweep has not been run against. A save file belonging to the same run id is a separate matter and is genuinely readable: it is swept and disclosed exactly as item 7 requires, on the same post-approval ordering.

   Warn the user with the same phrasing pattern as item 4, substituting the board path, the idle age, the size on disk, and the parser's own error message and position, plus one sentence making the limit explicit: the file could not be read, nothing has been salvaged from it, and approving removal means removing content nobody has inspected. A board can also fail to parse because another session is part-way through writing it, which is a reason to never auto-delete rather than a reason to shorten the threshold. Delete only on explicit approval; never auto-delete; and never attempt a partial or hand-rolled parse to reach a verdict the parser declined to give.

Items 4 through 8 render **one batched prompt**, not one per artifact: the report groups by item, lists each group's artifacts as lines beneath that item's heading, and takes **one approval per group** rather than one per file. A user who wants finer control declines the whole group and removes files by hand from the paths already listed in it. **A group approval never removes a save file**, in the same breath as the batching rule itself, so a reader of this paragraph alone is not left assuming a group approval reaches everything under it: the save file still needs the separate approval that names it, required by items 6 and 7. No relocation sweep runs before this prompt. For the four items that run one, **4, 6, 7, and 8**, the sweep runs once that item's group is approved and before that group's first delete, and none of the four deletes anything the sweep has not been run against; item 8's sweep is attempted and comes back empty, for the reason item 8 gives where it states that rule for itself. **Item 5 runs no relocation sweep today, and this paragraph does not add one.** The no-delete-without-a-sweep rule reaches only the four items that carry a sweep, not all five: stating it as a blanket rule over items 4 through 8 would either forbid item 5 from deleting anything at all, or quietly hand a check this change is not otherwise touching a sweep obligation it has never had. Batching carries one known limit worth stating plainly rather than leaving to be discovered: a declined artifact is offered again on the next run, because nothing this skill writes records the decline. Batching is what keeps that an annoyance rather than an obstruction, since a user facing a long list declines it in one motion rather than one prompt per file. In autonomous mode, the same grouped report renders, nothing is prompted for, nothing is deleted, and the run continues.
