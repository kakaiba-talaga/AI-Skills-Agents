# AI-Skills-Agents

A collection of reusable AI agents and multi-file skills for Claude Code and Cursor, with automated deployment and Cursor portability transforms.

## Git Conventions

Do not include `Co-Authored-By`, `Signed-off-by`, or any other trailer in commit messages. This overrides the default system commit instructions.

## Documentation Sync

Documentation-to-code mapping for the doc-sync skill. Run `/doc-sync` to audit.

> **Mirror:** This section is duplicated in `.cursor/rules/documentation-sync.mdc`. Changes here must be applied there too, and vice versa.

### Map

| Documentation | Code / Config |
| :--- | :--- |
| `CLAUDE.md` (Documentation Sync) | `.cursor/rules/documentation-sync.mdc` (mirror) |
| `README.md` | Repo structure, `tooling/deploy-manifest.json` |
| `docs/ASSESSMENT.md` | All agents, skills, and tooling |
| `docs/portability-guide.md` | `tooling/deploy.ps1`, `tooling/deploy.sh`, `tooling/deploy-manifest.json` |
| `agents/README.md` | `agents/*.md` (21 agent definitions) |
| `agents/code-intel.md` | `agents/code-intel.md`, `skills/ops/SKILL.md` (Phase 2.5b), `tooling/deploy-manifest.json` |
| `docs/code-intel/integration-test.md` | `agents/code-intel.md`, `skills/ops/SKILL.md` (Phase 2.5b, Phase 3 state cache, Phase 4 cleanup), `skills/ralph-loop/SKILL.md` |
| `agents/cross-memory.md` | `agents/cross-memory.md`, `skills/cross-memory/SKILL.md` (audit subcommand brief shape; init+doctor non-trigger boundary; distill intent brief shape and output contract), `skills/cross-memory/README.md` (Audit section; synthesize, audit, and distill intent coverage) |
| `docs/cross-memory/v1-shipped.md` | `skills/cross-memory/SKILL.md`, `skills/cross-memory/*.md`, `agents/cross-memory.md` (v1 traceability — shipped surface, deferred items, SC verification map) |
| `docs/cross-memory/v1.1-shipped.md` | `skills/cross-memory/SKILL.md`, `skills/cross-memory/*.md`, `agents/cross-memory.md` (v1.1 traceability — shipped surface, deferred items, verifier closures) |
| `docs/cross-memory/v1.2-shipped.md` | `skills/cross-memory/SKILL.md` (reflect subcommand, staleness nudge, state.toml and reflect_declined.md substrate), `agents/cross-memory.md` (distill intent), `skills/cross-memory/README.md` (Reflect section) — v1.2 traceability: shipped surface, deferred items, SC verification closures |
| `~/.claude/CLAUDE.md` (What NOT to save in memory) | `skills/cross-memory/SKILL.md` (reflect filter — LLM-prompt-applied exclusion corpus drawn from this rule), `agents/cross-memory.md` (distill brief — exclusion corpus passed as constraint field at distill-intent dispatch) |
| `skills/clickup/README.md` | `skills/clickup/SKILL.md` |
| `skills/cross-memory/README.md` | `skills/cross-memory/SKILL.md`, `skills/cross-memory/redaction.md`, `skills/cross-memory/indexing.md`, `skills/cross-memory/adapter-claude-code.md`, `skills/cross-memory/adapter-cursor.md`, `skills/cross-memory/adapter-generic.md`, `agents/cross-memory.md` (full nine-subcommand surface including init, doctor, and reflect; Reflect section covers four-source pipeline, filter thresholds, decline ledger, staleness nudge, and cross-harness applicability) |
| `skills/cross-memory/SKILL.md` (§ Per-project state file; § Reflect decline ledger) | `skills/cross-memory/SKILL.md` — state.toml schema (fields: `last_reflect_at`, `reflect_count`) and reflect_declined.md schema (fields: `id`, `reason`, `timestamp`); consumed by `skills/cross-memory/README.md` (Reflect section) and `docs/cross-memory/v1.2-shipped.md` (SC verification map) |
| `skills/code-review/README.md` | `skills/code-review/SKILL.md` |
| `skills/commit-message/README.md` | `skills/commit-message/SKILL.md` |
| `skills/deploy/README.md` | `skills/deploy/SKILL.md`, `skills/deploy/SKILL.cursor.md`, `skills/deploy/*.md` |
| `skills/deslop/README.md` | `skills/deslop/SKILL.md` |
| `skills/kickoff/README.md` | `skills/kickoff/SKILL.md`, `skills/kickoff/project-template/**` |
| `skills/doc-sync/README.md` | `skills/doc-sync/SKILL.md` |
| `skills/linter/README.md` | `skills/linter/SKILL.md` |
| `skills/ops/brief-contract.md` | `skills/ops/SKILL.md` (Agent Briefing Format), `agents/{executor,verifier,debugger,git-master,project-scoper}.md` (`## Brief Format` subsections) |
| `skills/ops/README.md` | `skills/ops/SKILL.md`, `skills/ops/SKILL.cursor.md`, `skills/ops/*.md` |
| `skills/ops/SKILL.cursor.md` | `skills/ops/SKILL.md`, `tooling/transform-cursor-ops.{ps1,sh}` |
| `skills/ralph-loop/README.md` | `skills/ralph-loop/SKILL.md`, `skills/ralph-loop/*.md` |
| `skills/ralph-loop/SKILL.cursor.md` | `skills/ralph-loop/SKILL.md`, `tooling/transform-cursor-ralph-loop.{ps1,sh}` |
| `skills/timing-calibrator/README.md` | `skills/timing-calibrator/SKILL.md` |
| `skills/ralph-loop/templates/README.md` | `skills/ralph-loop/templates/*.yaml` |
| `docs/agent-audits/tier-a-opus-4-7-audit.md` | `agents/{executor,verifier,debugger,git-master,project-scoper}.md` (Opus 4.7 critic audit, 2026-05-04) |

### Rules

- Make targeted edits — preserve tone, structure, and detail level.
- Check diagrams against prose when either changes.
- Update multiple docs consistently when they reference the same concept (e.g., pipeline order appears in `agents/README.md` and individual agent files).
- Defer doc updates during debugging, experimental, or exploratory changes.
- Defer doc updates while the Ralph Wiggum Loop skill is active.
