# Using AI-Skills-Agents

## Overview

This repository ships multiple skills — `/ops`, `/deslop`, `/code-review`, `/commit-message`,
`/linter`, `/ralph-loop`, `/kickoff`, `/deploy`, `/doc-sync`, `/cross-memory`, `/clickup`,
and others — each installed at `~/.claude/skills/<name>/SKILL.md`. When the user's conversation
surface signals that one of these skills applies, the top-level Claude should invoke the relevant
slash command before responding. This meta-skill documents the trigger heuristics for that
decision and the rationalization patterns to short-circuit when those heuristics apply.

## When to Invoke

- **Explicit invocation:** User explicitly types `/ops`, `/deslop`, `/code-review`, or any other
  skill name → invoke that skill verbatim. No heuristic needed; the user already decided.
- **Mid-run continuation:** Conversation context shows recent activity from a skill — a task
  board, agent dispatches, deslop findings, code-review verdicts, ralph-loop iteration headers —
  → re-invoke the same skill on the next message to restore full context.
- **Orchestration or pipeline work:** User asks for multi-step execution, a structured pipeline,
  or wants to coordinate multiple agents → suggest `/ops` and invoke it.
- **Cleanup or simplification:** User asks to clean up AI-generated bloat, remove filler, or
  simplify overly verbose output → suggest `/deslop` and invoke it.
- **Code review or quality audit:** User asks for a review, audit, or quality check on a diff,
  branch, or file set → suggest `/code-review` and invoke it.
- **Commit message:** User asks for a commit message or wants to document a change in git
  → suggest `/commit-message` and invoke it.
- **Linting or formatting:** User asks to lint, format, or style-check source files
  → suggest `/linter` and invoke it.
- **Iterative improvement loop:** User wants a reflect-plan-act cycle or ongoing refinement
  → suggest `/ralph-loop` and invoke it.
- **Project scaffold or kickoff:** User is starting a new project and wants a scaffold, README,
  or initial structure → suggest `/kickoff` and invoke it.
- **Deployment:** User wants to deploy or push a release to a remote host → suggest `/deploy`
  and invoke it.
- **Documentation audit:** User asks whether docs are in sync with code → suggest `/doc-sync`
  and invoke it.
- **Memory operations:** User wants to save, recall, search, or audit facts across conversations
  → suggest `/cross-memory` and invoke it.
- **ClickUp task management:** User asks to create, update, or query ClickUp tasks → suggest
  `/clickup` and invoke it.

## When NOT to Invoke

- **Single-line factual question with no implied multi-step work.** "What does this function do?"
  does not require a skill; answer directly.
- **User explicitly opts out.** If the user says "no skill," "just answer," "quick question,"
  or equivalent, respect the preference.
- **Trivial diagnostic or lookup.** Reading a file, explaining a type, checking a value — these
  are not skill-scope tasks.
- **Mid-conversation topic with no skill signal.** If the conversation is already flowing without
  skill ceremony and neither the trigger list above nor any recent skill badge applies, do not
  force one in.

## Rationalization Prevention

| Excuse | Reality |
| :--- | :--- |
| "This is just a simple question" | If answering the question requires multi-step work, the simple-question framing was wrong. Apply the trigger heuristics, not the surface phrasing. |
| "Let me explore the codebase first, then invoke the skill" | Exploration is within the skill's scope when the skill applies. Invoke first; the skill will guide what to explore. |
| "The skill feels like overkill for this" | Match against the trigger list, not against vibes. If a trigger applies, invoke. |
| "The user didn't explicitly ask for the skill" | Several triggers are signal-based, not request-based. Mid-run continuation and orchestration signals are enough. |
| "I already started answering — invoking now would be awkward" | A clean skill invocation mid-answer is less harmful than an unguided response that misses the skill's workflow rules. Pivot cleanly. |
| "I'm not sure if this skill is installed" | The Active Skill Detection table in `~/.claude/CLAUDE.md` lists only installed skills. If it's in the table, it's available. |

## Installation Reference

This skill is referenced from the user-global `~/.claude/CLAUDE.md` under the **Active Skill
Detection** section. The repository ships the skill file itself; the user maintains the
global instruction that activates it. To wire it up, include the following line in
`~/.claude/CLAUDE.md`:

> When you detect a skill applies (per the Active Skill Detection table), invoke it before
> responding.

No code changes, schema changes, or repo-side config are required. The skill file lives at
`~/.claude/skills/using-ai-skills-agents/SKILL.md` after deployment.

## Output Tagging

This meta-skill does not emit an output tagging badge. It governs when to invoke OTHER skills;
those skills carry their own badges. When a skill is invoked as a result of this meta-skill's
trigger heuristics, the badge that appears is the **invoked skill's badge** (e.g., **`Team Manager`**
for `/ops`, **`Deslop`** for `/deslop`), not a badge from this file.
