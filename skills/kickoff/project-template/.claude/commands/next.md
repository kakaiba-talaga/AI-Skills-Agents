Execute the next phase in the project's planning queue. Reads QUEUE.md to identify the next pending phase, runs investigation, implementation, and review stages, then updates all planning files and commits.

**Workflow:** `Pre-Flight → Investigation → Implement → Review → After Completion`

## Pre-Flight: Queue Check

**Entry criteria:** `/next` has been invoked.
**Exit criteria:** The next phase is identified, the correct branch is confirmed, and no CRITICAL items exist above it in the queue.

Before doing ANY work, read and understand the current state:

**Verify planning infrastructure exists:** Check that `plan/QUEUE.md`, `plan/INDEX.md`, and `plan/BLOCKERS.md` all exist. If any are missing, STOP and notify the user: which files are missing, and suggest running `/kickoff` to set up the planning infrastructure (or create them manually). Do not proceed to step 1 until all three files exist.

1. **Read `plan/QUEUE.md`** — the ordered execution queue of ALL pending phases.
2. **Read `plan/INDEX.md`** — the master plan status.
3. **Read `plan/BLOCKERS.md`** — hard gates.
4. **Identify the NEXT phase in QUEUE.md** — this is the phase you will execute. Do NOT skip phases unless:
   - The phase is technically blocked by an incomplete dependency (marked `[B]`), in which case move to the next unblocked phase.
   - A deliberate reordering decision has been made with an alternative that provides the same functionality with better tradeoffs — document this in QUEUE.md with rationale.
   - **NEVER skip a phase just because it is "LOW priority".** Every phase has a path to completion. Low priority means it comes later in the queue, not that it gets dropped.

5. **Check that the plan document for the next phase exists:**
   - Parse the `Plan` column of the identified phase row in QUEUE.md. The link format is `[Phase Name](./NN-name.md)` — extract the filename (e.g., `05-new-feature.md`) and the link text (e.g., `New Feature`).
   - Check whether `plan/<filename>` exists.
   - **If the file exists:** continue to step 6.
   - **If the file is missing:**
     - Notify the user: which plan doc is missing and which phase references it.
     - Check whether `plan/PLAN-STUB-TEMPLATE.md` exists.
       - **If the template is missing:** warn the user that no stub template is available (the project may not have been set up with `/kickoff`) and continue to step 6 — do not block execution.
       - **If the template exists:** offer to create a stub from the template. Ask the user to confirm before writing anything.
         - **If the user accepts:** read `plan/PLAN-STUB-TEMPLATE.md`, then replace each `<!-- KICKOFF:FIELD -->` marker as follows, and write the result to `plan/<filename>`:
           - `KICKOFF:PLAN_NUMBER` → the zero-padded number extracted from the filename (e.g., `05`)
           - `KICKOFF:PLAN_NAME` → the link text extracted from QUEUE.md (e.g., `New Feature`)
           - `KICKOFF:PLAN_STATUS` → `PENDING`
           - `KICKOFF:CREATED_DATE` → today's date in `YYYY-MM-DD` format
           - `KICKOFF:PLAN_OVERVIEW` → `<!-- Add an overview of this plan -->`
           - `KICKOFF:PHASES` → `<!-- Add phases for this plan -->`
           - `KICKOFF:DEFERRED_ITEMS` → *(leave empty — no deferred items yet)*
         - **If the user declines:** warn the user that the plan doc is missing and execution may fail when the phase attempts to read it, then continue to step 6 without blocking.

6. **If the next phase is marked `[H]` (human action required):**
   - **STOP immediately.** Do NOT proceed to another phase.
   - Notify the user explicitly: what human action is needed, why it's blocking, and what the downstream impact is.
   - Wait for the user to either complete the action or explicitly authorize skipping/reordering.
   - If the blocker is CRITICAL (security, data loss risk), emphasize this clearly.

   **Resuming after `[H]`:**
   Never assume an `[H]` was completed. Always verify via the files before continuing. When the user signals that the human action is done, follow these steps before proceeding:
   1. Re-read QUEUE.md, BLOCKERS.md, and the relevant plan file.
   2. Verify the `[H]` marker has been cleared (either removed or replaced with a status change from the user).
   3. Confirm that whatever the human was asked to do is reflected in the files (e.g., credentials present, certificate purchased, env var set).
   4. Resume with the standard Pre-Flight: Queue Check from step 1.

7. **If any CRITICAL items exist above the current phase in the queue** (e.g., security issues), the agent must address those first regardless of what was previously "in progress."

#### Branch routing

Every phase targets a specific branch. Confirm the correct branch before writing any code.

| Phase range | Target branch | Notes |
| :--- | :--- | :--- |
| Feature-isolated phases (e.g., platform-specific work) | `feature/<name>` | Keep isolated until the feature milestone is ready to merge |
| All other phases | `main` (or the active release branch) | Default for every standard phase |

**Merge strategy:** Feature branches merge back to `main` when all phases in the feature milestone are complete, or when the user explicitly requests a merge.

**Fallback rule:** If the next phase in the queue does not belong on the currently active branch, **STOP** and ask the user which branch to switch to. Do not switch branches silently.

**Detecting feature-isolated phases:** A phase is feature-isolated if the QUEUE.md entry includes a `feature/` branch reference in its Notes column, or if the plan document for the phase explicitly names a feature branch. When no branch is specified, default to `main`.

---

#### Subagent dispatch

**Dispatch method:** Use the `Agent` tool directly with a `prompt` parameter. Do NOT use `subagent_type` — the target project may not have registered agent definitions. Every subagent prompt must be fully self-contained with the task description, scope, and constraints inline.

**Role mapping for each workflow stage:**

| Stage | Role | What it does | Prompt guidance |
| :--- | :--- | :--- | :--- |
| Investigation | Technical investigator | Researches where/how code will be implemented | "Explore the codebase to understand [scope]. Read relevant files. Report: file paths, current implementation patterns, integration points, and any risks." |
| Investigation | Plan alignment auditor | Validates approach + audits queue | "Read plan/QUEUE.md, plan/INDEX.md, and [plan doc]. Validate the approach is aligned with the broader project direction. Audit the queue for stale entries, missing items, ordering issues." |
| Implement | Implementor | Writes/modifies code per the plan | "Implement [task description] per the acceptance criteria below. Modify only the files listed in Scope. Do not expand scope." |
| Review: Plan Alignment | Plan reviewer | Checks code matches plan intent | "Review the changes in [files] against the plan at [plan doc]. Verify the implementation matches the stated approach." |
| Review: Static Analysis | Static analyzer | Runs linters/type checkers | "Run the project's static analysis tools against [files]. Report any errors or warnings." |
| Review: Code Quality | Quality reviewer | Checks code structure and style | "Review [files] for code quality: simplicity, DRY, modularity, no stubs or placeholders." |
| Review: Security | Security reviewer | Checks for vulnerabilities | "Review [files] for security: input validation, injection risks, hardcoded secrets, auth issues." |
| Review: Tests | Test runner | Runs test suites | "Run all test suites. Report pass/fail counts, any new failures, and coverage gaps." |

**Constraints for all subagents** (include verbatim in every prompt):
- Do not modify files outside the specified scope
- Do not commit changes
- Report uncertainty rather than guessing

**Parallel dispatch:** Investigation subagents (technical investigator + plan alignment auditor) can be dispatched in a single message for concurrent execution. Review subagents should also be dispatched in parallel where they examine different concerns on the same files.

---

## Phase Execution

### Investigation

**Entry criteria:** Pre-Flight complete — the next phase is identified, the correct branch is confirmed, and no CRITICAL items exist above it in the queue.
**Exit criteria:** Technical investigation is done, the queue audit is complete, and QUEUE.md reflects any audit-driven updates.

Launch these subagents in parallel:

**1. Technical investigation subagent(s):**
Research/investigate where code will be implemented and how it will be integrated, if not already explicit in the plan document.

**2. Plan alignment + queue audit subagent:**
This subagent has a dual role. It must read QUEUE.md, INDEX.md, and the relevant plan documents, then:

**Part A — Plan alignment:** Validates the *approach* before implementation — is the plan sound?

- Compare the current phase with the high-level direction of future plans
- Ensure the implementation approach is aligned with both the immediate plan and the broader project strategy
- If any conflicts or misalignments are found, the process should be stopped and the user informed

**Part B — Queue audit:**

- **Check if QUEUE.md is still accurate.** Have any blockers been resolved since last update? Have any new phases been created by other plans? Are there stale entries?
- **Check ordering.** Given what was learned from the last completed phase, does the queue order still make sense? Should anything be promoted (e.g., a dependency that was discovered) or does a newly-unblocked phase need to move up?
- **Check for missing items.** Scan INDEX.md deferred items tracker and all active plan documents for any pending phases that are NOT in QUEUE.md. Every pending phase must be in the queue.
- **Check for items that should be merged or split.** If two queue items are essentially the same work, flag for merge. If a queue item has grown in scope, flag for split.
- **Report any queue changes needed.** The coordinator applies these changes to QUEUE.md before proceeding with implementation.

If the queue audit finds issues (missing items, wrong ordering, stale blockers), the coordinator must update QUEUE.md BEFORE starting implementation. If the audit reveals the current phase is no longer the right next step (e.g., a higher-priority item was missed), the coordinator must switch to the correct phase.

### Implement

**Entry criteria:** Investigation has completed, QUEUE.md reflects any audit-driven updates, and the phase plan doc is the open source of truth.

Use a subagent to perform the implementation, subject to the following rules:

**Preflight (before the subagent writes any code):**

- Confirm the active git branch matches the phase target branch (see Branch Routing in Pre-Flight).
- Confirm the phase scope is frozen — no mid-phase scope additions are permitted without assigning a new phase number first.
- Confirm the plan doc "Tasks" list is the working checklist and has not changed since Investigation completed.

**Scope-creep rule:**
Any finding that is not within the phase's stated scope is *deferred*, not implemented. Deferrals follow the Deferral / Blocker Policy verbatim — every deferred item must target a concrete numbered phase in QUEUE.md.

**Checkpoint rule:**
Implementation stops at the phase acceptance-criteria boundary, even if adjacent improvements look easy. Anything adjacent becomes a new phase. The subagent does not implement beyond what the acceptance criteria require.

**Exit criteria:** All acceptance criteria for the phase are met or explicitly deferred with phase numbers.

### Review

**Entry criteria:** Implementation complete — all acceptance criteria have been addressed or explicitly deferred with phase numbers.
**Exit criteria:** Pass criteria met (all active reviewers approve or note non-blocking) OR fail criteria met (3 rounds exhausted with blocking issues remaining).

Use multiple subagents to perform the review phase. This phase should include all of the relevant subagents below:

> **Note:** Plan Alignment appears twice by design — once in Investigation (approach check) and once here in Review (implementation check). See Investigation Part A for the pre-check.

 1. **Plan Alignment:** Validates the *implementation* after it exists — does the code match the plan? Review the implemented code to ensure it aligns with the immediate plan and the higher level direction of future plans.
 2. **Static Analyzer:** Use the proper static analysis or build command to check for issues in the implementation as well as any tests.
 3. **Code Quality:** Ensure code is simplified, modular, extensible, low on tech-debt, DRY, aligned with over-arching high-level plan goals, and doesn't introduce scope-creep. Includes stub/placeholder detection — ensure no stubs or placeholders remain where implementation should be.
 4. **Security:** Ensure no security issues are introduced in the code.
 5. **Performance:** Ensure no performance issues are introduced in the code.
 6. **Documentation:** Ensure code is well-documented, with clear comments and updated documentation files as necessary.
 7. **Test Coverage:** Ensure adequate test coverage for new and modified code. Tests must cover:
    - Primary use-cases (happy path)
    - Edge cases and error conditions
    - **Real-world usage patterns** — tests should reflect how the code is actually used in production, not just synthetic scenarios
    - Review existing tests for quality: do they test meaningful behavior or just exercise code paths?
 8. **UX:** Ensure any user-facing changes meet UX standards and provide a good user experience.
 9. **Test Execution:** Execute all test suites — integration, unit, end-to-end, and regression. Ensure new code integrates well with existing systems, passes all unit tests, works as intended from start to finish in a real-world scenario, and does not break or degrade existing functionality.

#### Review scope selector

The coordinator reads the phase scope from the plan document and selects the appropriate review profile before dispatching reviewers. Default to the **Code** profile when the scope is ambiguous.

| Profile | Active reviewers | Skip by default |
| :--- | :--- | :--- |
| **Docs-only** | Plan Alignment, Documentation | all others |
| **Config-only** | Static Analyzer, Security, Test Execution | UX, Documentation, others |
| **Code** (default) | Full roster — all 9 reviewers | none |

**Profile override:** The user can force the full roster on any phase by including an explicit instruction (e.g., "use full review"). This overrides any auto-selected profile.

**Audit requirement:** The coordinator records which profile was used in the phase completion summary (e.g., "Review profile: Config-only").

You are to remain coordinator only. Run up to **3 review rounds**. After each round, evaluate the results against the pass and fail criteria below. Ensure you don't overload your own context with too much information — and that you ensure subagents provide you back enough context to continue whilst understanding the status, feedback, issues and tradeoffs, and especially any gaps and limitations that are identified.

**Pass criteria (exit loop as succeeded):**

- All active reviewers return either "approve" or a "non-blocking note" (a finding that does not require a code change before merging).
- No reviewer returns a blocking issue.
When pass criteria are met at the end of any round, proceed to After Completion.

**Fail criteria (exit loop as failed):**

- After 3 rounds, one or more reviewers still return a blocking issue.
When fail criteria are met, do NOT attempt a 4th round. Exit to the Review Failure: Rollback and Recovery branch (see below).

**Escalation on loop exhaustion:**
If the review loop reaches 3 rounds without achieving pass criteria, the coordinator MUST report all of the following to the user before stopping:

1. The phase name and identifier.
2. The list of reviewers that still have unresolved blocking issues.
3. The specific blocking issue each dissenting reviewer raised.
4. A summary of what changed between rounds (which findings were fixed, which were not, and what was attempted).
Then follow the Review Failure: Rollback and Recovery procedure below.

### Review Failure: Rollback and Recovery

When the review loop exits on fail criteria (3 rounds exhausted with blocking issues remaining), the coordinator MUST NOT commit any implementation changes. Instead, choose one of the two recovery options below and execute it fully before stopping.

**Option A — Revert:**
Revert any commit-staged changes on the working tree to reset to the pre-phase state. Do not touch already-committed history. Use this option only when the implementation is trivially reproducible (i.e., the work would be faster to redo than to track).

**Option B — Tracking phase (DEFAULT):**
Open a tracking phase in the relevant plan document and QUEUE.md that captures the deferred work. Record what was attempted, what blocked review, and what remains to be resolved. Stop cleanly without committing any implementation changes. Use this option when the phase produced partial work worth preserving or the fix is non-trivial.

**Recovery procedure for both options:**

1. Execute Option A or Option B as selected above.
2. Report a summary to the user before stopping. The summary must include: the phase name, which option was taken, why the review loop failed (from the escalation report), and what the tracking phase number is (Option B only) or what was reverted (Option A only).

**Partial-commit state recovery:**
A partial-commit state occurs when bookkeeping updates (plan file, QUEUE.md, INDEX.md, BLOCKERS.md) were written to disk but the final `git commit` failed, leaving a dirty working tree with no commit.

- **Detection:** Run `git status`. If QUEUE.md, INDEX.md, BLOCKERS.md, or the plan file appear as modified with no corresponding commit, you are in a partial-commit state.
- **Recovery:** Re-run the deferral-target validation scan (step 5 of the After Completion bookkeeping order), then retry `git commit`. If the retry fails a second time, escalate to the user — do not leave partial state on disk unresolved.

### Deferral / Blocker Policy

**Rule statement:** Every deferred item — skipped requirement, known limitation, or blocked work — must be documented in the plan document and INDEX.md with its reason, added to QUEUE.md at the appropriate priority position, and assigned to a **concrete, numbered phase**. Complex blocker resolutions must be isolated in their own phase. If a blocker phase is added, a corresponding follow-up phase (now unblocked) must also be added. Known limitations that cannot be resolved (e.g., environment constraints) must still be tracked with their impact and any workarounds. Items that are intentionally out of scope because the existing approach is sufficient should be labeled **"Design decision"** — not a deferral — and require no phase assignment.

**Invalid deferral targets** (NEVER valid — fix before committing):

- "Backlog", "Future", "Later", "TBD"
- A plan name without a phase number (e.g., "Plan 04" — must be "Phase 4.3")
- "Demand-triggered" without a phase number

If no existing phase fits, create a new one: add the phase definition to the plan document, add it to QUEUE.md with a number, and reference that number in the deferral note. Before committing, scan all deferred items and verify each resolves to a phase number that exists in QUEUE.md.

**Enforcement contexts** — the rule statement applies in all three of these situations:

- **(a) Deferred work:** any skipped requirement or out-of-scope finding from implementation or review.
- **(b) Hard blockers (`[H]`):** flag with `[H]` in QUEUE.md, communicate the required action to the user, and STOP if the blocker is on a critical path. Full `[H]` stop behavior is defined in Pre-Flight.
- **(c) Test failures:** all failures — pre-existing or new — must be fixed in the current phase or tracked in a concrete numbered phase. A failure is never acceptable as "just pre-existing" without a phase assignment.

**Test failure baseline:** A baseline of known-failing tests is recorded in `plan/test-baseline.md`. Only failures *new to the current phase* block the phase — pre-existing failures in the baseline must still be tracked (per the deferral rule above) but do not re-trigger blocking on every run. If a previously baselined failure starts passing, remove it from the baseline in the same commit. Every baseline addition must include a pointer to a concrete numbered phase in QUEUE.md for its eventual resolution. If `plan/test-baseline.md` does not exist, create it when the first baseline entry is needed. The file is a simple markdown table with columns: Test Name, Failure Description, Assigned Phase, Date Added.

---

## After Completion

**Entry criteria:** Review passed — all active reviewers approved or noted non-blocking findings (success path).
**Exit criteria:** All six bookkeeping steps are committed in a single commit and a summary has been provided to the user.

**One phase = one commit. Do not split bookkeeping across commits.**

Complete the following steps in this exact order. All six steps are part of a single atomic unit that ends with one git commit.

**Success path** (review loop passed): follow steps 1–6 below.
**Failure path** (review loop exhausted without passing): follow the Review Failure: Rollback and Recovery procedure instead of steps 1–6.

> **QUEUE.md Current Position rule:** The first line after the title of `plan/QUEUE.md` MUST be a `Current Position:` note naming the next phase to execute and its status. This note is updated in step 2 below and must be present before committing.

1. **Update the specific plan file** (source of truth for the phase) with the new status and timestamp of completion.

2. **Update QUEUE.md:**
   - Mark the completed phase as `[x]` with completion timestamp
   - Update any phases that are now unblocked (change `[B]` to `[ ]`)
   - Add any new phases discovered during implementation
   - Verify the next item in queue is correct
   - **Update the `Current Position:` note** (first line after the title) with the next phase name and its status

3. **Update INDEX.md** with summary of changes and new status, and timestamp of completion.

4. **Update BLOCKERS.md** with summary of any blockers that were resolved, and any new blockers that were identified.

5. **Deferral-target validation scan (mandatory before committing):**
   - Read QUEUE.md and confirm every deferred item in the plan document points to a concrete, numbered phase that exists in QUEUE.md.
   - Scan for any items targeting "Backlog", "Future", "Later", "TBD", or missing a phase number.
   - For each violation: either create a new phase (add to plan doc + QUEUE.md) or reclassify as a design decision.
   - **Do not proceed to step 6 until every deferred item has a concrete phase number in QUEUE.md.**

6. **Commit all of the above** to git in a single commit using the git CLI. NEVER attempt to read or modify anything in the .git directory directly as this will cause repo corruption.

   **Commit message format:**
   - First line: `Phase x.x — <short description>`
   - Body: a paragraph describing what changed and why

    **Commit failure handling:** If the `git commit` in step 6 fails, re-run the deferral-target validation scan (step 5), then retry the commit. Never leave partial state on disk without a commit. If the retry fails twice, follow the Partial-commit state recovery procedure in the Review Failure: Rollback and Recovery section.

7. **Provide a high-level summary** of what was completed, including:
   - Issues or tradeoffs identified
   - An explicit list of any deferred tasks with their assigned follow-up phase and position in QUEUE.md
   - An explicit list of any known limitations discovered, with their assigned follow-up phase or documented workaround
   - An explicit list of any human-action blockers that were identified
   - **The next phase in QUEUE.md** and whether it is ready to execute or blocked
