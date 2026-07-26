# AI-Skills-Agents

A collection of reusable AI agents and multi-file skills for Claude Code and Cursor, with automated deployment and Cursor portability transforms.

## Git Conventions

Do not include `Co-Authored-By`, `Signed-off-by`, or any other trailer in commit messages. This overrides the default system commit instructions.

## Source of Truth & Deployment

> **Mirror:** This section is duplicated in `.cursor/rules/source-of-truth-and-deployment.mdc` (project-local; excluded from the Cursor deploy in `tooling/deploy-manifest.json`). Changes here must be applied there too, and vice versa.

This repository is the **source of truth** for every agent, skill, hook, rule, and settings file. Content is deployed *outward* to live harness locations by `tooling/deploy.{ps1,sh}` (per `tooling/deploy-manifest.json`): `agents/` and `skills/` land in `~/.claude/` (Claude Code — Windows and WSL are separate destinations) and `~/.cursor/` (Cursor); global instructions deploy from `CLAUDE-root.md` to `~/.claude/CLAUDE.md`.

**Never edit a deployed copy — always edit the repo source.**

- Edit `agents/<name>.md` here — never `~/.claude/agents/<name>.md` or `~/.cursor/agents/<name>.md`.
- Edit `skills/<skill>/**` here — never `~/.claude/skills/<skill>/**`.
- Edit `CLAUDE-root.md` (plus its `.cursor/rules/*.mdc` mirrors) here — never `~/.claude/CLAUDE.md` directly.

An agent's read-only self-read of its own definition at `~/.claude/agents/<type>.md` during dispatch is the *only* legitimate touch of a deployed path; it must never become an edit target.

**Why this matters:** deploy is idempotent — it overwrites each destination from the repo, reporting `OK` when a destination already matches and `UPDATED` when it writes. Editing a deployed copy directly creates silent drift: the change appears to work in one harness, never lands in git, and is erased on the next deploy. (Observed: an agent edited `~/.claude/agents/executor.md` instead of `agents/executor.md`; git never saw the change, and a later deploy reported `OK` for that target while the genuinely-stale Cursor and WSL copies showed `UPDATED`.)

## Documentation Sync

Documentation-to-code mapping for the doc-sync skill. Run `/doc-sync` to audit.

> **Mirror:** This section is duplicated in `.cursor/rules/documentation-sync.mdc`. Changes here must be applied there too, and vice versa.

### Map

| Documentation | Code / Config |
| :--- | :--- |
| `CLAUDE.md` § Documentation Sync | `.cursor/rules/documentation-sync.mdc` (mirror) |
| `CLAUDE.md` § Source of Truth & Deployment | `.cursor/rules/source-of-truth-and-deployment.mdc` (mirror, project-local — excluded from `cursor` deploy in `tooling/deploy-manifest.json`) |
| `README.md` | Repo structure, `tooling/deploy-manifest.json` |
| `CLAUDE-root.md` | `tooling/deploy-manifest.json` (settings → `~/.claude/CLAUDE.md`; `cursor` → `rules`), `~/.claude/CLAUDE.md` (deployed global instructions), `.cursor/rules/*.mdc` (one rule mirror per section, excl. Maintenance Note + `documentation-sync.mdc`) |
| `docs/ASSESSMENT.md` | All agents, skills, and tooling |
| `docs/portability-guide.md` | `tooling/deploy.ps1`, `tooling/deploy.sh`, `tooling/deploy-manifest.json` |
| `tooling/README.md` | `tooling/transform-cursor-{ops,deploy,ralph-loop}.{ps1,sh}`, `.github/workflows/transform-drift.yml` (CI drift gate when tracked) |
| `agents/README.md` | `agents/_shared/**`, `agents/*.md` (agent definitions + shared snippets); self-contained agent reference: catalog, per-agent usage, workflow/handoffs/parallelization, full permissions reference |
| `skills/ops/phase-intake.md` | `skills/ops/SKILL.md` (Triage Gate → pipeline/trivial/save; Phase 1–2, state file on disk invariant), `tooling/transform-cursor-ops.{ps1,sh}` |
| `skills/ops/phase-dispatch.md` | `skills/ops/SKILL.md` (Phase 2.5 validation; Phase 3 dispatch loop, self-contained brief invariant, memory injection), `tooling/transform-cursor-ops.{ps1,sh}` |
| `skills/ops/phase-preflights.md` | `skills/ops/SKILL.md` (Phase 2.5b/2.5c/2.5d pointers), `tooling/transform-cursor-ops.{ps1,sh}` |
| `skills/ops/phase-completion.md` | `skills/ops/SKILL.md` (Phase 4, status dashboard), `tooling/transform-cursor-ops.{ps1,sh}` |
| `agents/code-intel.md` | `agents/code-intel.md`, `agents/_shared/code-intel-orchestrator-brief.md`, `skills/ops/phase-preflights.md` (Phase 2.5b), `tooling/deploy-manifest.json` |
| `agents/corpus-search.md` | `agents/corpus-search.md`, `agents/_shared/corpus-search-orchestrator-brief.md`, `skills/ops/phase-preflights.md` (Phase 2.5c), `tooling/deploy-manifest.json` |
| `agents/web-research.md` | `agents/web-research.md`, `skills/ops/phase-intake.md` (Agent Assignment Rules row + lane-boundary row), `tooling/deploy-manifest.json` |
| `agents/generalist.md` | `agents/generalist.md`, `skills/ops/phase-intake.md` (Agent Assignment Rules row + lane-boundary row), `skills/ops/tool-restrictions.md` (Delegate-First Table row, "What the Team Manager MAY Do Directly" dispatch note, Subagent Dispatch Decision Framework rows), `tooling/deploy-manifest.json` (deploy-by-glob — new agent file needs no manifest edit) |
| `agents/infra.md` | `agents/infra.md`, `skills/ops/phase-intake.md` (Agent Assignment Rules row + lane-boundary row), `skills/ops/tool-restrictions.md` (Delegate-First Table row, § Model Escalation for `infra`/`db`), `tooling/deploy-manifest.json` (deploy-by-glob — new agent file needs no manifest edit) |
| `agents/db.md` | `agents/db.md`, `skills/ops/phase-intake.md` (Agent Assignment Rules row + lane-boundary row), `skills/ops/tool-restrictions.md` (Delegate-First Table row, § Model Escalation for `infra`/`db`), `tooling/deploy-manifest.json` (deploy-by-glob — new agent file needs no manifest edit) |
| `agents/scout.md` | `agents/scout.md`, `skills/ops/phase-intake.md` (Agent Assignment Rules row + lane-boundary row), `skills/ops/tool-restrictions.md` (Delegate-First Table row + Subagent Dispatch Decision Framework `Explore`→`scout` swap), `tooling/deploy-manifest.json` (deploy-by-glob — new agent file needs no manifest edit) |
| `agents/docs-lookup.md` | `agents/docs-lookup.md`, `agents/README.md` (catalog/model/usage), `README.md` (compatibility/count), `skills/ops/phase-preflights.md` (Phase 2.5d), `skills/ops/SKILL.md` (flag/registry/sequence/pointer), `skills/ops/phase-intake.md` (assignment + lane rows), `skills/ops/tool-restrictions.md` (Delegate-First Table row + Subagent Dispatch Decision Framework row), `tooling/deploy-manifest.json` (deploy-by-glob — new agent file needs no manifest edit) |
| `agents/preflight.md` | `agents/preflight.md`, `agents/README.md` (catalog/usage), `skills/ops/phase-intake.md` (Agent Assignment Rules row + lane-boundary row), `skills/ops/phase-dispatch.md` (Phase 2.5 preflight-validation dispatch + `MECHANICAL_AGENTS` set), `skills/ops/SKILL.md` (Pipeline-sequence table — Phase 2.5 preflight validation), `skills/ops/phase-completion.md` (Status Dashboard `### Preflight` section), `agents/work-verifier.md` (per-agent-type timeout budget table), `tooling/deploy-manifest.json` (deploy-by-glob — new agent file needs no manifest edit) |
| `agents/rollback.md` | `agents/rollback.md`, `agents/README.md` (catalog/usage), `skills/ops/phase-intake.md` (Agent Assignment Rules row + lane-boundary row), `skills/ops/phase-dispatch.md` (`MECHANICAL_AGENTS` set + Failure Handling broken-verdict rollback dispatch), `skills/ops/SKILL.md` (Failure Handling + Model Escalation rollback references), `agents/work-verifier.md` (per-agent-type timeout budget table + broken-verdict handoff), `tooling/deploy-manifest.json` (deploy-by-glob — new agent file needs no manifest edit) |
| `agents/_shared/code-review-contract.md` | `skills/code-review/SKILL.md`, `agents/code-reviewer.md`, `agents/code-reviewer-diff.md`, `tooling/deploy-manifest.json` |
| `docs/code-intel-integration-test.md` | `agents/code-intel.md`, `skills/ops/phase-preflights.md` (Phase 2.5b), `skills/ops/phase-completion.md` (Phase 4 cleanup) |
| `docs/corpus-search-integration-test.md` | `agents/corpus-search.md`, `skills/ops/phase-preflights.md` (Phase 2.5c), `skills/ops/phase-intake.md` (Trivial Dispatch), `skills/ops/phase-completion.md` (Phase 4 cleanup) |
| `agents/cross-memory.md` | `agents/cross-memory.md`, `skills/cross-memory/SKILL.md` (audit subcommand brief shape; init+doctor non-trigger boundary; distill intent brief shape and output contract), `skills/cross-memory/README.md` (Audit section; synthesize, audit, and distill intent coverage) |
| `~/.claude/CLAUDE.md` (What NOT to save in memory) | `skills/cross-memory/SKILL.md` (reflect filter — LLM-prompt-applied exclusion corpus drawn from this rule), `agents/cross-memory.md` (distill brief — exclusion corpus passed as constraint field at distill-intent dispatch) |
| `skills/clickup/README.md` | `skills/clickup/SKILL.md` |
| `skills/cross-memory/brief-injector.md` | `skills/ops/SKILL.md` (Phase 3 Step 3), `skills/deslop/SKILL.md` (steps 5c and 7), `skills/deploy/SKILL.md` (Phase 4), `skills/ralph-loop/SKILL.md` (fan-out sites), `skills/ops/brief-contract.md` (Optional Sections + § Section Precedence) |
| `skills/cross-memory/README.md` | `skills/cross-memory/SKILL.md`, `skills/cross-memory/schema-validator.md`, `skills/cross-memory/adapter-selection.md`, `skills/cross-memory/reflect-decline-ledger.md`, `skills/cross-memory/subcommand-init.md`, `skills/cross-memory/subcommand-doctor.md`, `skills/cross-memory/subcommand-reflect.md`, `skills/cross-memory/subcommand-save.md`, `skills/cross-memory/subcommand-recall-list-search.md`, `skills/cross-memory/subcommand-forget.md`, `skills/cross-memory/subcommand-audit.md`, `skills/cross-memory/always-on-tier.md`, `skills/cross-memory/injection-block.md`, `skills/cross-memory/redaction.md`, `skills/cross-memory/indexing.md` (§6 skill companion index — tiered subcommand loads), `skills/cross-memory/adapter-claude-code.md`, `skills/cross-memory/adapter-cursor.md`, `skills/cross-memory/adapter-generic.md`, `agents/cross-memory.md` (full nine-subcommand surface; README mirrors the post-optimization sub-file layout) |
| `skills/cross-memory/SKILL.md` (§ Per-project state file) and `skills/cross-memory/reflect-decline-ledger.md` | `skills/cross-memory/SKILL.md` (§ Per-project state file) — state.toml schema (fields: `last_reflect_at`, `reflect_count`); `skills/cross-memory/reflect-decline-ledger.md` — decline-ledger schema (fields: `declined_at`, `candidate_id`, `proposed_name`, `category`, `scope`, `tags`, `body_preview`, `source_evidence`, `run_id`); both consumed by `skills/cross-memory/README.md` (Reflect section) |
| `skills/code-review/README.md` | `skills/code-review/SKILL.md` |
| `skills/commit-message/README.md` | `skills/commit-message/SKILL.md` |
| `skills/deploy/README.md` | `skills/deploy/SKILL.md`, `skills/deploy/SKILL.cursor.md`, `skills/deploy/*.md` |
| `skills/deploy/SKILL.cursor.md` | `skills/deploy/SKILL.md`, `tooling/transform-cursor-deploy.{ps1,sh}` |
| `skills/deslop/README.md` | `skills/deslop/SKILL.md` |
| `skills/kickoff/README.md` | `skills/kickoff/SKILL.md`, `skills/kickoff/project-template/**` |
| `skills/doc-sync/README.md` | `skills/doc-sync/SKILL.md` |
| `skills/linter/README.md` | `skills/linter/SKILL.md` |
| `skills/ops/brief-contract.md` | `skills/ops/SKILL.md` (Agent Briefing Format), `agents/{executor,verifier,debugger,git-master,project-scoper}.md` (`## Brief Format` subsections) |
| `skills/ops/README.md` | `skills/ops/SKILL.md`, `skills/ops/SKILL.cursor.md`, `skills/ops/*.md` |
| `skills/ops/SKILL.cursor.md` | `skills/ops/SKILL.md`, `tooling/transform-cursor-ops.{ps1,sh}` |
| `skills/ops/verification-gate.md` | `skills/ops/SKILL.md` (§ Shared Brief Constraints — references `verification-gate.md` as the canonical ritual source) |
| `skills/ops/subcommand-save.md` | `skills/ops/SKILL.md` (Save Subcommand subsection + Phase 4 cleanup paragraph), `skills/ops/state-schema.md` (resume_phase open-set list), `skills/ops/interruption-recovery.md` (Pause vs Save subsection), `skills/cross-memory/redaction.md` (Pass A + Pass B reuse — read-only) |
| `skills/ops/dispatch-policy.md` (canonical dispatch-mode rule) and `skills/ops/timing-edge-cases.md` (canonical timing edge-case rules and their count) | `skills/ops/phase-dispatch.md` (dispatch-loop wiring, liveness gate, nested-skill write-before/clear-after ritual and skill-call bookkeeping, in-flight accounting rule), `skills/ops/interruption-recovery.md` (cancel, pause, and resume behavior), `skills/ops/phase-intake.md` (`resume` row's orphan test), `skills/ops/phase-completion.md` (completion phase's re-entrant guarding; also carries two of the three timing-rule-count restatements), `skills/ops/completion-options.md` (completion menu's dispatch mode), `skills/ops/integrations.md` (cleanup-skill entry gate and its re-verification dispatch mode), `skills/ops/subcommand-save.md` (save path's nested-skill entry gate), `agents/work-verifier.md` (Handoff verdict table's liveness qualifier), `skills/ops/README.md` (third timing-rule-count restatement) |
| `skills/ralph-loop/README.md` | `skills/ralph-loop/SKILL.md`, `skills/ralph-loop/*.md` |
| `skills/ralph-loop/SKILL.cursor.md` | `skills/ralph-loop/SKILL.md`, `tooling/transform-cursor-ralph-loop.{ps1,sh}` |
| `skills/timing-calibrator/README.md` | `skills/timing-calibrator/SKILL.md` |
| `skills/ralph-loop/templates/README.md` | `skills/ralph-loop/templates/*.yaml` |
| `docs/authoring-skills.md` | `skills/*/SKILL.md` (file layout, flat-markdown convention, output tagging, sub-file extraction, transform-regen rule — contributor conventions derived from existing skills) |

### Rules

- Make targeted edits — preserve tone, structure, and detail level.
- Check diagrams against prose when either changes.
- Update multiple docs consistently when they reference the same concept (e.g., pipeline order appears in `agents/README.md` and individual agent files).
- Defer doc updates during debugging, experimental, or exploratory changes.
- Defer doc updates while the Ralph Wiggum Loop skill is active.
