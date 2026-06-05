<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Verification Gate

This rule exists as insurance against a plausible failure mode — an agent claiming completion at a dispatch boundary where the verifier-loop safety net is not running. The trivial dispatch route is the case that matters most: when the team manager takes the trivial path, Phase 3 is bypassed entirely and no downstream verifier demands fresh evidence. Without a gate at the brief level, an agent on that path has only its own discipline standing between a real check and a plausible-sounding "tests should pass now." The ritual below is the explicit form that discipline takes.

## The ritual — IDENTIFY / RUN / READ / VERIFY / CLAIM

**IDENTIFY.** Before writing any completion claim, identify precisely what "done" means for this task. Name the command that proves it — the test suite invocation, the build command, the lint run, the specific file read, or the criterion-specific check. If you cannot name the command, you do not yet know what completion looks like. Clarify first.

**RUN.** Execute that command in this message — not a previous one, not a cached invocation, but a fresh call made right now. If the command was already run earlier in this dispatch and nothing has changed since, you may cite it forward (see "When to re-run vs. cite existing output" below). Otherwise, run it again.

**READ.** Read the output in full. Do not skim. The goal is not to scan for a green indicator and move on — it is to understand what the output actually says. Failures buried in a long stdout are still failures. A passing summary that hides skipped tests is still hiding something. Read the whole thing.

**VERIFY.** Confirm that the output satisfies the acceptance criterion, not that it looks plausible or that you expect it to. A passing test count that does not include the specific test you wrote is not evidence the specific test passes. A build that succeeds on a different configuration is not evidence this configuration builds. Match output to criterion, explicitly.

**CLAIM.** Only after IDENTIFY → RUN → READ → VERIFY all pass may you state completion. The claim must cite the evidence produced in this dispatch: which command, what output, which criterion it satisfies.

## What counts as fresh evidence

- Tests re-run in this message, with output shown.
- Build output produced by a command called in this dispatch.
- Lint or type-check output from the current message.
- File content read via a Read tool call in this message.
- A command's exit code checked in this message.
- A grep or search result produced in this message.

## What does not count

- Output from a prior message in the conversation, even if nothing seems to have changed.
- A previous agent's summary of what it found.
- The executor's last message asserting that tests pass.
- Output produced before the most recent code edit.
- Phrases like "should work," "probably fine," "seems correct," "looks good to me," or "the diff looks right."
- Reasoning about why the code is correct, offered in place of running it.
- A file you wrote but did not read back after writing.

## Read-only agents — verdicts as completion claims

Agents that produce verdicts rather than code changes — the critic, the work-verifier, the change-analyzer, the code-intel agent, the corpus-search agent, and read-only review agents generally — still make completion claims. The verdict itself is the claim. The fresh-evidence requirement maps directly: to issue a verdict, the agent must have re-read the files being assessed in the current message, must cite specific `file_path:line_number` references rather than paraphrasing from memory or from the dispatcher's summary, and must not rely on what a prior agent reported. The ritual applies to verdicts the same way it applies to code-change completion — IDENTIFY (what files and criteria does this verdict cover), RUN (read those files now), READ (read the content, not a summary), VERIFY (confirm the verdict follows from what the files actually say), CLAIM (state the verdict with citations).

## When to re-run vs. cite existing output

| Situation | Action |
| :--- | :--- |
| Output produced in this message, no file changes since | Cite it forward — acceptable. |
| Output produced in a previous message | Re-run. |
| A prior agent produced the output | Re-run. The prior agent's context is not yours. |
| Any file has been edited since the output was produced | Re-run. The earlier output no longer reflects the current state. |
| You are uncertain whether anything changed | Re-run. The cost is low; the risk of stale evidence is not. |

## Cross-references

See `~/.claude/skills/ops/SKILL.md` § Non-negotiables for the team-manager-level enforcement points (non-negotiables #3 and #4 govern timing and deliverables on disk). See `~/.claude/skills/ops/SKILL.md` § Verify → Fix Loop for how the pipeline enforces fresh evidence at the verifier stage. This file governs the agent-level ritual that runs before any completion claim, at every dispatch route.
