# TDD Skill

## Overview

The TDD skill imposes a strict RED-GREEN-REFACTOR discipline on the executor's source-code work.
It is **opt-in**: it activates when the `/ops` invocation includes the `--tdd` flag or when the
task brief explicitly requests TDD discipline via a `## Mode: tdd` section. When active, no
production code may be written before a failing test has been observed running. The verifier
enforces this after the fact by checking that a failing-test commit precedes the implementation
commit on the working branch. For projects that choose to opt in, TDD mode provides a hard
guarantee — not a planner suggestion — that every new behavior is tested before it is implemented.

## When to Use

- Triggered when `--tdd` is passed to `/ops` or when the executor brief contains `## Mode: tdd`
- Applies to the executor's source-code work: new functions, new modules, new behavior added to
  existing modules
- Does **not** apply to:
  - Markdown edits — agent contracts, skill files, plan docs, README updates
  - Config-only changes (`.toml`, `.json`, `.yaml`, `.env`) with no accompanying logic
  - Schema migrations (those follow their own migration discipline)
  - Refactors where comprehensive tests already exist and no new behavior is being introduced
- The team-manager makes the applicability call at planner-time and encodes it in the brief;
  when a task mixes source and markdown, TDD applies only to the source portions

## Core Pattern — RED-GREEN-REFACTOR

### RED — Write the failing test first

1. Identify the **smallest single behavior** to add next. If the behavior feels large, break it
   down further — the smallest shippable slice of observable behavior is the right unit.
2. Write a test that asserts that behavior and nothing else.
3. **Run the test and observe it fail.** This step is mandatory. "It obviously fails" is not an
   observation. Capture the failure output (test runner name, file, line, assertion message).
4. Commit the failing test on its own commit (preferred for clean history) or stash it before
   proceeding to GREEN. The commit is the verifier's evidence that RED was real.

**Anti-pattern:** "I'll write the test after I implement." An after-test verifies the
implementation, not the specification. It locks in whatever the code happens to do — including
bugs — and cannot distinguish between "correct" and "coincidentally passing."

### GREEN — Minimum code to pass

1. Write the **minimum production code** that makes the failing test pass.
2. **Run the test and observe it pass.** Mandatory. Capture the passing output.
3. Do not generalize, do not add helper utilities, do not refactor while in this phase. Implement
   exactly what the failing test demands — nothing more.

**Why minimum matters:** Every line of unrequested code is a line that has not been driven by a
test. It may be correct, but it is untested by construction, and it makes the next test harder to
isolate.

**Anti-pattern:** "I'll generalize the helper while I'm in here." That is refactoring. Keep it
for the REFACTOR phase. If generalization requires new behavior, defer it to a new RED cycle.

### REFACTOR — Improve structure with tests as safety net

1. With all tests green, improve readability, naming, structure, and duplication in both the
   production code and the test code.
2. **Run tests after every individual refactor edit.** If any test goes red, revert the last edit
   immediately — do not accumulate failures before running.
3. The REFACTOR phase is **optional**. If the GREEN code is already readable and well-structured,
   skip it and move on to the next RED.

**Anti-pattern:** Batching multiple refactor edits before running the test suite. Each structural
change must be independently verified green before the next begins; stacking edits makes failure
attribution impossible and turns REFACTOR into a debugging session.

## Quick Reference

The complete cycle in six bullets:

- **RED:** Identify the smallest behavior → write a test → run it → confirm failure → commit
- **GREEN:** Write minimum production code → run the test → confirm it passes → commit
- **REFACTOR (optional):** If refactoring: improve structure → run tests after each edit → revert immediately on red → commit
- Never write production code before an observed-failing test exists for that behavior
- Never skip a run step — "it obviously fails/passes" is the entry point to rationalization
- REFACTOR is optional; RED and GREEN are mandatory and non-negotiable

## Implementation

### Team-manager dispatch

When `/ops --tdd` is invoked, the team-manager adds the following section to the executor's brief:

```
## Mode: tdd

TDD discipline is active. Follow RED-GREEN-REFACTOR strictly.
Every new behavior requires a failing test committed before any
production code is written. Capture observed test runner output
at both the RED step and the GREEN step.
```

The brief contract treats `## Mode: tdd` as an optional section. Its presence overrides any
softer language in the task description (e.g., "add tests where appropriate"). The executor must
not downgrade TDD discipline based on perceived simplicity of the task.

### Verifier TDD-discipline check

After the executor completes, the verifier runs the following check when `## Mode: tdd` is
present in the brief:

1. Inspect the commit log on the working branch since it diverged from the base branch.
2. Identify commits that add or modify production source files.
3. Classify test files using these default glob patterns: `**/test_*.py`, `**/*_test.py`,
   `**/tests/**`, `**/__tests__/**` (Python); `**/*.test.{js,ts,jsx,tsx}`,
   `**/*.spec.{js,ts,jsx,tsx}` (JS/TS); `**/*_test.go` (Go); `**/*_spec.rb`, `**/spec/**`
   (Ruby); or paths explicitly named as test files in the executor's brief.
4. For each such commit, confirm that a preceding commit on the same branch adds or modifies a
   test file covering the same module or behavior.
5. **Failure condition:** A production-code commit with no preceding failing-test commit on the
   branch causes the verifier to issue a `FAILED` verdict with the offending commit hash cited.

The verifier does **not** re-run the failing test — it relies on commit ordering as the primary
signal. Captured test output in the commit message or brief handoff is supporting evidence.

### Failure modes the verifier catches

- Implementation commit appears before any test commit on the branch → `FAILED`
- Test commit added *after* the implementation commit ("retroactive RED") → `FAILED`
- No test commits at all on a branch with production-code commits under TDD mode → `FAILED`
- Test commit present but test file is unrelated to the changed module → verifier flags for
  human review rather than issuing an automatic `FAILED`

## Common Mistakes and Rationalization Prevention

### Rationalization Prevention

| Excuse | Reality |
| :--- | :--- |
| "The test would just verify what I obviously wrote" | If it's obvious, the test will be trivial to write and run. Trivial tests catch real bugs when interfaces drift. |
| "I'll add tests after I see the implementation works" | After-tests verify against the implementation, not the spec. They lock in bugs as features. |
| "This is too small to need a test" | Then writing the test is also too small to skip. |
| "I need to explore the design first" | Exploration without tests becomes commits without tests. Sketch in a scratch file, then start with RED. |
| "The test setup is more code than the test" | Then the design is wrong. Reduce dependencies until the test is small. |
| "I already know this works — I ran it manually" | Manual verification is not a test. It does not run on the next commit, or the one after that. |
| "The CI will catch regressions" | CI catches regressions in tests that exist. It cannot catch regressions in behavior that was never tested. |

### Common mistakes

- **Writing the test after the implementation.** The test now verifies the implementation, not
  the spec. All bugs present at implementation time are baked in as "passing."
- **Skipping the observed-RED step.** Running a test and watching it fail is information: it
  confirms the test exercises the right code path. A test that passes immediately when first
  written is a broken test — it cannot fail, so it cannot protect anything.
- **Adding unrequested behavior during GREEN.** GREEN is not a license to expand scope. Write
  only enough code to pass the failing test. New behavior requires a new RED cycle.
- **Batching refactor edits without intermediate test runs.** Each structural change must be
  independently verified before the next. Stacking changes makes failure attribution impossible.

## Output Tagging

**`TDD`** appears on the **opening line** of each assistant turn when TDD mode is active. Do
**not** prefix every bullet or heading in the same turn.

**Sub-mode badge — no standalone `/tdd` command exists.** The **`TDD`** badge is activated via
`/ops --tdd`, not via a standalone slash command. The user-global CLAUDE.md "Active Skill
Detection" re-invoke reminder does **not** apply to this badge — there is no `/tdd` command to
re-invoke. When the **`TDD`** badge appears mid-run, the correct action is to continue the active
`/ops` workflow, not to type `/tdd <message>`.

The **first line** of each assistant turn for this skill MUST begin with: **`TDD`**

Apply the badge on the opening line for: RED phase setup, GREEN phase verification, REFACTOR
pass, verifier discipline-check results, failure reports, and any communication about test
discipline during an active TDD run.

**Format:** **`TDD`** (bold backtick-wrapped) as the **first element** on the **opening line** of
the turn.

**Example:**

```text
**`TDD`** RED phase complete — `test_calculate_total.py` fails with AssertionError as expected.

Observed output:

    FAILED test_calculate_total.py::test_empty_cart - AssertionError: expected 0, got None
```
