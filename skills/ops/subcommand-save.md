<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Subcommand: save

Write a manual checkpoint: flush the current state to disk and write a small save file capturing the conversation-side context that the state file does not preserve — verbal decisions the user made mid-run, the working hypothesis, where the run was headed, and open questions still awaiting a decision. The user-supplied text fields are redacted unconditionally before write. After the save file is written, the subcommand optionally dispatches `/cross-memory reflect` to surface durable memories from the run.

### Command syntax

```
/ops save
```

No flags. No positional arguments. The subcommand is only valid inside an active run (a board file must exist at `.ops-state/<run-id>-board.json`).

### Save file schema

The save file is JSON and is written to `.ops-state/<run-id>-save.json`, alongside the board file. This keeps Phase 4 cleanup simple and means `/ops resume` finds the save file in the same directory as the board file. The schema is fixed — eight fields, no extensibility bag.

**Redaction applies in-place to field values, not via a schema field.** Secret-shaped substrings inside the four user-supplied text fields are replaced with `[REDACTED:<category>]` tokens before the file is written to disk. There is no per-field "was-redacted" boolean and no envelope flag — the placeholder tokens themselves are the evidence of redaction.

#### Example

```json
{
  "run_id": "auth-middleware-2026-05-19",
  "saved_at": "2026-05-19T14:22:03Z",
  "saved_by": "user-requested",
  "next_action": "Continue executor dispatch on task-3 after reviewing the verifier's findings on task-2.",
  "verbal_decisions": [
    "Switched task-2 approach from JWT-in-header to JWT-in-cookie after user feedback at 14:05.",
    "Dropped task-7 (rate-limit middleware) — user said defer to v2."
  ],
  "working_hypothesis": "task-4 verifier failure is likely a fixture-loading order issue, not the schema migration itself.",
  "open_questions": [
    "Should the cookie be Secure-flagged in dev? Awaiting user decision."
  ],
  "cross_skill_state": {
    "last_nested_skill": "/deslop",
    "last_nested_outcome": "no changes; proceeded to code-review stage"
  }
}
```

#### Field definitions

| Field | Type | Required | Redacted in-place? | Meaning |
| :--- | :--- | :--- | :--- | :--- |
| `run_id` | string | yes | no | Must match the board file's `run_id`. Used by `/ops resume` to confirm the save file belongs to the same run. |
| `saved_at` | ISO-8601 string | yes | no | UTC timestamp of save. |
| `saved_by` | enum: `user-requested` \| `auto` | yes | no | `user-requested` for `/ops save` invocations. `auto` is reserved for future auto-save points. |
| `next_action` | string | yes | **yes** | "Where I was when I cleared" — a free-text note describing what the team manager (or user) was about to do next. ≤ 500 chars. Redacted by Pass A + Pass B before write. |
| `verbal_decisions` | string[] | yes (may be empty) | **yes (per-entry)** | One-line entries describing mid-run user decisions not yet written into a plan doc or memory. Newest last. Each entry is redacted independently by Pass A + Pass B. |
| `working_hypothesis` | string \| null | yes | **yes** | Current theory of what is going on (especially during debug investigations). Null when there is no active investigation. Redacted by Pass A + Pass B before write. |
| `open_questions` | string[] | yes (may be empty) | **yes (per-entry)** | Questions awaiting a user decision that would block resume if forgotten. Each entry is redacted independently by Pass A + Pass B. |
| `cross_skill_state` | object \| null | yes | no | Free-form key-value object for any cross-skill state not captured by the board file's `pending_nested_skill`. Typical keys: `last_nested_skill`, `last_nested_outcome`. Null when nothing applies. Values are sourced from the team manager's own state, not from user free-text, and do not pass through redaction. |

### Invocation flow

When the user types `/ops save`, the team manager executes these nine steps in order.

**Step 1 — Verify an active run exists.**

Read `.ops-state/<run-id>-board.json` for the current run. If no board file exists, print the exact message:

```
/ops save requires an active run. Start one with /ops <spec> or /ops resume.
```

Stop. Do not proceed to step 2.

**Step 2 — Flush the state file to disk.**

Re-write the current state-cache snapshot to disk so that anything in-memory but not yet persisted is captured. This is a no-op when the cache and the disk are already in sync, but is cheap insurance. The flush happens before composing the save object so that the board file and the save file are consistent on disk.

**Step 3 — Compose the save object.**

Build the save object with the eight schema fields. The team manager fills `run_id`, `saved_at`, `saved_by: "user-requested"`, and `cross_skill_state` from its own state. For `next_action`, `verbal_decisions`, `working_hypothesis`, and `open_questions`, the team manager drafts an initial value from its working memory and presents it to the user for confirmation or edit (interactive mode), or writes it directly (autonomous mode). Empty arrays are valid for `verbal_decisions` and `open_questions`; `null` is valid for `working_hypothesis`.

**Step 4 — Redact secrets from the four user-supplied text fields.**

Pass each value of `next_action` and `working_hypothesis`, and each individual entry of `verbal_decisions` and `open_questions`, through the redaction module documented at `~/.claude/skills/cross-memory/redaction.md`.

Both passes apply:

- **Pass A** — `<private>` strip: every `<private>...</private>` span is replaced with `[REDACTED:private]`. This pass always runs.
- **Pass B** — regex denylist: all eight pattern categories (api-key, password, bearer-token, jwt, aws-secret, env-block, private-key-header, user-tagged-secret) are scanned; each match is replaced with `[REDACTED:<category>]`.

Redaction is **unconditional** — there is no `--redact` flag, no `--no-redact` flag, and no opt-out. The user cannot disable redaction for save-file content. The four user-supplied text fields are always routed through both Pass A and Pass B before write.

The four metadata and state fields (`run_id`, `saved_at`, `saved_by`, `cross_skill_state`) are **not** redacted. Their content is structurally constrained and cannot contain user-typed secrets.

The redaction module's **confirmation gate is not invoked at this point**. That gate is owned by `/cross-memory save`, not by `/ops save`. If the user disagrees with a redaction, they can decline to confirm at step 6 and re-author the save file's source values before re-invoking.

**Step 5 — Write the save file to disk atomically.**

Write the redacted save payload to `.ops-state/<run-id>-save.json.tmp` (the `.tmp` suffix prevents a partial file from appearing under the final name).

Then read the temp file back from disk and parse it as JSON to verify the bytes round-tripped correctly. If the read-back parse fails — for example due to a disk-full condition, an encoding mismatch, or a write-tool error — delete the temp file immediately and surface the error to the user. Stop before proceeding to step 6. The user must see the error before any partial file is exposed under the final name.

If the read-back parse succeeds, rename `.ops-state/<run-id>-save.json.tmp` to `.ops-state/<run-id>-save.json`. The rename is atomic within the same directory on every supported filesystem (`Move-Item` semantics on Windows; POSIX `rename(2)` on Linux and macOS). After the rename, verify the final-name file exists with one more read before proceeding to step 6. If the final-name file is absent after the rename (e.g., the rename silently failed or the path was otherwise not materialized), surface an error to the user and do NOT print the step 6 success line — the checkpoint has not been saved.

**Step 6 — Display a one-line confirmation.**

Print verbatim:

```
Saved checkpoint to .ops-state/<run-id>-save.json (Xms). Run still active — use /ops resume to pick up.
```

where `Xms` is the wall-clock time for the save itself (steps 4 and 5 combined).

**Step 7 — Prompt for `/cross-memory reflect`, with a `pending_nested_skill` non-null guard.**

Before displaying any prompt, read the state file's `pending_nested_skill` field. This guard runs **before** the y/N prompt is shown, not after.

If `pending_nested_skill` is **non-null** — meaning a prior nested skill (e.g., `/deslop`, `/clickup`) is already in flight and its return path has not yet executed — do not show the reflect prompt. Print the following line verbatim, substituting the in-flight skill name from the marker:

```
Save complete; reflect skipped because a nested skill (<name>) is already in flight.
```

Stop. The user can invoke `/cross-memory reflect` manually after the in-flight nested skill returns.

If `pending_nested_skill` is **null**, display the following prompt verbatim:

```
Run /cross-memory reflect to surface any durable memories from this run? (y/N)
```

Default is N. If the user says no or presses Enter without input, stop — the save is complete and the run remains active. If the user says yes, proceed to step 8.

**Step 8 — Invoke `/cross-memory reflect` as a nested skill.**

Apply the standard write-before / clear-after ritual documented in SKILL.md Non-negotiable #10.

**Write-before** (immediately before the `/cross-memory reflect` call): write the following `pending_nested_skill` object to the state file:

```json
{
  "skill": "/cross-memory",
  "invoked_at": "<ISO-8601-UTC>",
  "resume_phase": "phase-3-save-followup",
  "resume_notes": "subcommand-save.md step 9: print one-line reflect summary; do not terminate the active run."
}
```

The `resume_phase` value `"phase-3-save-followup"` is a documented open-set entry in `~/.claude/skills/ops/state-schema.md`.

The write-before only occurs because the step 7 guard confirmed `pending_nested_skill` is null. If the guard had fired (non-null marker present), step 8 is never reached and the write-before never executes — preserving the in-flight marker for the original nested skill's return path.

Invoke reflect with `--from .ops-state/<run-id>-save.json` to seed Source 5 with the save file alongside the default Sources 3 and 4. The reflect skill's Source 5 reads the bytes as opaque seed text — it does not parse the save-file schema. Redacted tokens in the save file's body are surfaced to the agent's distill pass as part of the content; the user can decline any candidate that draws from a redacted region.

**Step 9 — On reflect return.**

Apply the clear-after steps of the `pending_nested_skill` ritual:

1. Re-read the state file from disk (cache invalidated by nested-skill return per the existing invalidation rule).
2. Read `pending_nested_skill.resume_phase` and `resume_notes`.
3. No handoff file is written — the reflect output is informational and does not need to be threaded into a downstream agent brief.
4. Set `pending_nested_skill` to `null` and write the state file.
5. Print a one-line summary referencing reflect's run summary.

Do not terminate the active run. `/ops save` returns control to the user, but the run remains in whatever state it was in before save (paused, awaiting next dispatch, between dispatches, etc.).

### `/ops resume` interaction

When `/ops resume` reads the board file and finds a sibling `<run-id>-save.json` in `.ops-state/`, it:

1. **Loads the save file** alongside the board file. No new state-cache key is needed; the save file is read once at resume time and surfaced to the user.
2. **Displays a "Saved Context" block** in the recovered dashboard, above the task board, showing the five user-authored fields (`next_action`, `verbal_decisions`, `working_hypothesis`, `open_questions`, `cross_skill_state`) and the `saved_at` timestamp. Redacted tokens are displayed as-is — there is no recall-time un-redaction, matching the cross-memory module's "never persisted, never recoverable" rule.
3. **Asks the user to confirm** before resuming. The save file is informational — the user reads it, acknowledges the context, and the team manager proceeds with the existing resume flow (`pending_nested_skill` check, work-verifier dispatch for orphaned in-progress tasks, etc.).
4. **Does not auto-act** on `open_questions` or `next_action`. Those fields are surfaced to the user; the user decides how to proceed.

If no save file exists, `/ops resume` behaves exactly as it does today — the save file is purely additive.

### Pause vs save

These two verbs do related but distinct things. `pause` is a mid-run mid-loop interruption — the user types it during an active dispatch loop to say "stop dispatching but keep the state file." The team manager finishes the agents currently running, marks no further pending tasks as dispatched, and waits. Conversation context is still alive. The user can type `resume` in the same conversation window to continue immediately. Pause is the right verb when the user wants a temporary halt without context loss — a coffee break, a quick lookup, a side conversation in the same session.

`save` is a checkpoint for **context loss**. The user invokes it as a deliberate prelude to `/clear`-ing the context window, closing the terminal, or stepping away across session boundaries. The save file captures the conversation-side context that `pause` does not preserve — the verbal user decisions, the working hypothesis, the "where I was" note. After `save`, the user typically clears the window and later runs `/ops resume` in a fresh session that reads both the board file and the save file.

A mental model: `pause` is a bookmark; `save` is a journal entry. You bookmark a book mid-chapter to pick it up in five minutes; you journal at the end of a session so future-you knows what past-you was thinking.

`/ops save` does not stop dispatch — it is independent of whether the run is currently paused, mid-loop, or between dispatches. The user can pause first, then save, then clear; or save first and keep working; or save once and never resume. The two verbs do not block each other.

### Phase 4 cleanup

The save file is ephemeral and run-scoped. The Phase 4 cleanup step that deletes the board file also deletes `.ops-state/<run-id>-save.json` if present. No manual cleanup is required.
