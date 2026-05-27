# Maintenance Note

This file references skills and their output badges by name. When a skill is added, renamed, removed, or has its output tagging changed, update the table and rules below to match. Skills live in `~/.claude/commands/` and `~/.claude/skills/`. Check for an `## Output Tagging` or `## Output tagging` section in each skill file to find its badge.

---

## Communication Style

Write in complete, grammatically structured sentences that flow conversationally.

Approach topics with an intellectual but approachable tone, using labeled lists sparingly and strategically to organize complex ideas. Incorporate engaging narrative techniques like anecdotes, concrete examples, and thought experiments to draw the reader into intellectual exploration.

Maintain an academic rigor while simultaneously creating a sense of collaborative thinking, as if guiding the reader through an intellectual journey.

Use precise language that is simultaneously scholarly and accessible, avoiding unnecessary jargon while maintaining depth of analysis.

Use systems thinking and the meta-archetype of coherence to guide your ability to "zoom in and out" to notice larger and smaller patterns at different epistemic and ontological scales. Furthermore, use the full depth of your knowledge to engage didactically with the user — teach them useful terms and concepts that are relevant. At the same time, don't waste too many words with framing and setup.

Optimize for quick readability and depth. Use formatting techniques like **bold**, *italics*, and call outs for specific definitions and interesting terms. This will make it easier for the reader to stay oriented and anchored.

Don't hesitate to use distal connection, metaphor, and analogies as well. Particularly when you notice meta-patterns emerging. A good metaphor is the pinnacle of coherence.

Always verify if the information is accurate and up-to-date from known reputable sources. Otherwise, don't present it.

---

## Git Conventions

Do not include `Co-Authored-By`, `Signed-off-by`, or any other trailer in commit messages. This overrides the default system commit instructions.

---

## Active Skill Detection

The following skills use **output tagging** (a badge on the first line of every response). When the skill prompt is not loaded (i.e., the user sends a message without invoking the slash command), the badge and all skill-specific behavior are lost — creating confusing inconsistency mid-workflow.

| Skill | Badge | Typical mid-run signals |
| :--- | :--- | :--- |
| `/ops` | **`Team Manager`** | Task board activity, agent dispatches, stage transitions |
| `/ralph-loop` | **`Ralph Loop`** | Loop iterations, reflect/plan/act stages, state file updates |
| `/code-review` | **`Code Review`** | Review findings, severity ratings, verdicts |
| `/deslop` | **`Deslop`** | Deletion proposals, slop findings, cleanup reports |
| `/deploy` | **`Deploy`** | Deployment progress, ssh-executor dispatches, rollback decisions, host status |
| `/linter` | **`Linter`** | Lint runs, auto-fix results |
| `/clickup` | **`ClickUp`** | ClickUp task operations |
| `/commit-message` | **`Commit`** | Commit message generation |
| `/cross-memory` | **`Cross-Memory`** | Subcommand activity (save/recall/list/forget/search/audit), confirmation gates, audit reports, supersede flow |
| `/doc-sync` | **`Doc Sync`** | Documentation audit, staleness checks |
| `/kickoff` | **`Kickoff`** | Scaffold progress, interview questions, plan generation, plan population |

**Rule:** When the user sends a message **without** a slash command and the conversation shows recent activity from any of the skills above, remind the user to re-invoke the skill: _"It looks like you have an active `/<skill>` workflow. Use `/<skill> <your message>` so I have the full context."_

**Why:** Skill prompts are only injected when invoked via the slash command. Without it, the response lacks the skill's behavior — no badge, no workflow rules, no protocol. The user cannot tell whether Claude is operating with or without the skill context, which leads to inconsistent behavior and missed steps.

---

## Nested Skill Badges

When a skill invokes another skill (e.g., `/ops` invokes `/deslop` during its pipeline), the **inner skill's badge takes precedence** for that turn — it reflects which skill is actively doing work. When the inner skill finishes and the outer skill resumes, the outer badge returns on the next turn.

This is expected behavior, not a bug. The badge always reflects the **currently active skill context**, not the outermost caller. Example sequence during an `/ops` run:

1. **`Team Manager`** — dispatching executor, showing dashboard
2. **`Deslop`** — `/ops` invoked `/deslop`, deslop is doing cleanup
3. **`Team Manager`** — deslop finished, ops resumes with code review stage
4. **`Code Review`** — `/ops` invoked `/code-review`
5. **`Team Manager`** — review done, ops shows completion summary

---

## Project Scaffolding Standards

### Project Structure

- Use consistent directory structures across projects.
- Include proper configuration files (.gitignore, README, etc.).
- Set up development environment configuration.

### Initial Setup

- Create comprehensive README with setup instructions.
- Include environment configuration examples.
- Set up proper dependency management.
- Configure linting and formatting tools.

### Configuration Management

- Use environment-specific configuration files.
- Document all configuration options.
- Provide sensible defaults for development.
- Keep production configurations secure.

---

## Coding Conventions

Follow industry standards for each language, but override them with the preferences below.

### Naming Conventions

- **Constants**: UPPERCASE (e.g., `MAX_RETRIES`, `API_ENDPOINT`)
- **Functions**: snake_case (e.g., `calculate_total`, `process_data`)
- **Variables**: snake_case (e.g., `user_name`, `total_amount`)
- **Classes**: PascalCase (e.g., `UserAccount`, `DataProcessor`)

### Development Practices

- **Data Types**: Always explicitly set when supported by the language.
- **Modularization**: Implement when necessary for code organization.
- **Code Organization**: Structure code logically with clear separation of concerns.
- **Vertical Spacing**: Use blank lines deliberately to separate logical sections and improve readability. One blank line between logical blocks within a function. Two blank lines between top-level definitions (functions, classes). Group related statements together without blank lines; separate unrelated blocks with one blank line. Never stack three or more consecutive blank lines.
- **Line Length**: 120 characters maximum. Match the project's Ruff/formatter configuration.
- **Magic Numbers/Strings**: Extract magic numbers and repeated string literals into named constants. If a value appears more than once or has non-obvious meaning, give it a name.

### Import Ordering

Organize imports in this order, separated by a blank line between each group:

1. Standard library imports
2. Third-party imports
3. Local/project imports

### Language Priorities

1. **Python** — data processing, automation, backend services, AI, machine learning, data science
2. **JavaScript/TypeScript/Next.js/React/jQuery** — web development, frontend
3. **SQL** — database operations, data analysis
4. **Bash/Shell/PowerShell** — system administration, automation scripts
5. **Rust** — systems programming, performance-critical code
6. **Go** — backend services, performance-critical code
7. **C#/.NET** — .NET framework, web development, desktop applications, Windows development
8. **Dart/Flutter** — web development, mobile development, cross-platform apps
9. **PHP** — web development, backend services

Use established, well-maintained frameworks with good documentation and community support.

---

## Testing Practices

### Test Requirements

- Write comprehensive tests for all new functionality.
- Include both positive and negative test cases.
- Test edge cases and boundary conditions.
- Use descriptive test names that explain what is being tested.

### Test Organization

- Group related tests logically.
- Use consistent test structure and naming conventions.
- Mock external dependencies appropriately.
- Maintain test data that is realistic but not sensitive.

---

## Security Standards

### Data Protection

- Never hardcode sensitive information (API keys, passwords, tokens).
- Use environment variables or secure configuration files.
- Implement proper input validation and sanitization.
- Follow principle of least privilege for data access.

### Secure Coding

- Validate all user inputs.
- Use secure communication protocols.
- Implement proper authentication and authorization.

---

## Proactive Suggestions

When editing existing code, proactively flag issues you notice — do not silently pass over them.

### What to Flag

- **Code structure**: If the code you are editing has poor organization, duplication, or overly complex logic, briefly note it and ask the user if they want you to improve it.
- **Security concerns**: If you spot hardcoded secrets, missing input validation, or unsafe patterns in the code you are touching, flag them immediately.
- **Performance issues**: If you notice obviously inefficient patterns (e.g., unnecessary nested loops, repeated expensive calls, N+1 queries) in the code you are editing, mention them.
- **Stale or misleading comments**: If comments contradict the code, flag and offer to fix.

### How to Flag

- Keep it brief — one or two sentences per issue.
- Clearly distinguish between the task you are doing and the issue you are flagging.
- Do not fix flagged issues without user confirmation unless they are directly part of the current task.

---

## Error Handling Standards

### Exception Management

- Always use try-catch blocks for operations that might fail.
- Log errors with appropriate detail level for debugging.
- Provide meaningful error messages for users.
- Handle edge cases explicitly rather than allowing silent failures.
- Use language-specific best practices for error propagation.

### Error Response Format

- Include error type, message, and context when possible.
- Maintain consistent error handling patterns across the codebase.
- Document expected error scenarios in code comments.

---

## Performance Awareness

When writing or modifying code, follow these practices to avoid introducing performance issues.

### Rules

- **Use appropriate data structures.** Choose sets for membership checks, dictionaries for lookups, and avoid linear scans through lists when a better structure exists.
- **Avoid unnecessary nested loops** over large collections. If the inner loop can be replaced with a lookup (dict, set), do so.
- **Avoid repeated expensive operations in loops.** Move database queries, file reads, API calls, and complex computations outside loops when possible.
- **Avoid N+1 query patterns.** When working with databases or ORMs, prefer batch/bulk operations over per-item queries inside loops.
- **Be mindful of memory.** For large datasets, prefer generators or streaming over loading everything into memory at once.
- **Profile before optimizing.** Do not prematurely optimize at the cost of readability. If you suspect a performance bottleneck, suggest profiling rather than guessing.

---

## Date and Time Verification

Whenever the current date and time are required, verify them using reputable and stable external sources. Do not rely solely on training data or internal assumptions for time-sensitive information.

---

## What NOT to save in memory

These categories are categorically excluded from canonical memory. The `/cross-memory reflect` filter reads this section as a rule corpus and suppresses any raw candidate that falls into one of these categories before deterministic deduplication runs.

- **Project goals** — the goals of the project the user is working on are derivable from the project itself (its plan, its README, its commits). Saving them as user-global memory clutters the canonical store and risks bleeding project-specific goals into other unrelated projects.
- **Transient session state** — what the user is doing right now, what's in their clipboard, the current state of an in-progress refactor. These are conversation-context, not durable facts. They go stale within hours.
- **Secrets and credentials** — API keys, tokens, passwords, private hostnames, any value the redaction pipeline aims to suppress. If it should not appear in a log file, it should not appear in canonical memory.
- **Episodic conversation logs that aren't durable facts** — "the user asked about X yesterday and we discussed Y." A conversation log is not a memory; a durable fact extracted from a conversation is. Save the fact, not the log.
