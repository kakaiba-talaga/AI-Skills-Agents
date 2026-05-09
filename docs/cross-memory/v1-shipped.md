# Cross-Memory v1 — Shipped Artifact Traceability

This document is the closing artifact of the cross-memory v1 build. It records what shipped, what was deferred, and which verifier task confirmed each Success Criterion. It is not a restatement of the plan — for full context see `docs/cross-memory/requirements.md`, `docs/cross-memory/architecture-decision.md`, and `docs/plan/cross-memory-plan.md`.

---

## Shipped

Cross-memory v1 delivers a `/cross-memory` skill, a `cross-memory` agent, and a set of supporting files that together form a harness-portable memory layer on top of Claude Code's existing per-project store. All artifacts are Markdown — there is no compiled code.

**Skill files** (`skills/cross-memory/`)

- `SKILL.md` — subcommand router (save / recall / list / forget / search / audit), redaction pipeline, supersede flow, auto-propose gate, always-on tier filter, `[CROSS-MEMORY]` injection block formatter, adapter selection, mirror-failure handling. See `skills/cross-memory/README.md` for usage.
- `redaction.md` — denylist patterns and `<private>` markup parser; consumed by `SKILL.md` before any write reaches the user confirmation prompt.
- `indexing.md` — `MEMORY.md` line-format conventions and slug derivation rule; implements Decision 19 (ADD §19).
- `adapter-claude-code.md` — mirror logic for Claude Code (`~/.claude/projects/<slug>/memory/MEMORY.md`), including sentinel-bounded region and collision detection.
- `adapter-cursor.md` — mirror logic for Cursor (`.cursor/memory/MEMORY.md`), parallel conventions.
- `adapter-generic.md` — no-op adapter for harnesses without a known native memory location.
- `README.md` — user-facing documentation: installation, subcommand reference, privacy model, adapter behavior.

**Agent file** (`agents/`)

- `agents/cross-memory.md` — Opus agent handling `intent: synthesize` (filtered recall for injection blocks) and `intent: audit` (contradiction detection, staleness scan, allowlist enforcement); enforces write-to-canonical-only restriction (SC-21).

**Handoff artifact** (`docs/cross-memory/handoff/`)

- `cross-memory-active-skill-detection.diff` — patch file adding the `/cross-memory` row to `~/.claude/CLAUDE.md`'s Active Skill Detection table.
- `cross-memory-active-skill-detection.md` — instructions for applying the diff.

---

## Deferred (post-v1)

| Item | Where deferred | When to revisit |
| :--- | :--- | :--- |
| `/cross-memory init` codebase-fact distillation | requirements.md OQ-3, ADD §17 | post-v1 |
| Per-bullet confidence scoring in `[CROSS-MEMORY]` block | ADD §4 (Decision 15 note) | post-v1 alongside indexing |
| Embedding / keyword indexing for filtered auto-inject | ADD §10 (Decision 16 note) | post-v1 (perf / scale) |
| Aggregate `MEMORY.md` index across scopes | scoping.md gap list | post-v1 alongside indexing |
| Boundary policy on memories referencing repo paths | scoping.md OQ-B | v1.x patch — single-question planner re-engagement |
| Team-shared scope identifier | requirements.md OQ-6, ADD §16 | post-v1 |
| `/cross-memory profile` subcommand | not in requirements | post-v1 |
| Cross-session reflection: observe accumulated session record, curate memories, surface unknown patterns | conversation 2026-05-09; composes auto-propose gate, `/cross-memory audit`, `/timing-calibrator capture` | post-v1.1 (after init+doctor ship) — requires `--brainstorm` gate before scoping |
| Preemptive compaction integration | not in requirements | post-v1 |
| OpenCode / Cline / Aider adapters beyond generic fallback | scoping.md gap list | post-v1 |
| `/cross-memory export` and `/cross-memory import` | not in requirements | post-v1 |
| Custom `tooling/transform-cursor-cross-memory.{ps1,sh}` | scoping.md gap list | if integration testing surfaces a Cursor-specific syntax requirement |
| Heuristic auto-propose detection (NLP-based) | scoping.md gap list | post-v1 |
| `intent: apply` for audit (auto-applying findings) | ADD §8 (Decision 20 note) | post-v1 |
| Inverse opt-out tag (`never-on`) | ADD §12 | post-v1 |
| Codebase indexing integration with code-intel | not planned (separate lanes) | not planned |

The cross-session reflection placeholder above intentionally defers three design questions before any scoping run can produce a useful spec: (1) **input data source** — on-disk artifacts only (handoff files, dispatch logs, cross-memory state), git history, harness-native session transcripts, or composed; (2) **cadence** — on-demand subcommand, periodic schedule, or end-of-session per ops/ralph-loop run; (3) **pattern taxonomy** — the explicit list of pattern categories the reflection agent is allowed to surface (behavioral regularities, stale-memory candidates, implicit conventions, workflow shortcuts), since reflection without precise pattern definitions degenerates into hallucination. This work also has a natural composition relationship with the deferred `Relevant Memories:` sub-section ranking (`SKILL.md:1184`) — both depend on a relevance-or-pattern signal over the canonical store. Sequence the brainstorm gate (interviewer → architect → scoping → critic) for this only after v1.1 (init + doctor) has shipped and the v1 surface is behaviorally validated.

---

## Verified Success Criteria

All 21 SCs were verified at the contract level against the shipped `SKILL.md` and supporting files during the corresponding verifier pass.

| SC | Description | Verified by |
| :--- | :--- | :--- |
| SC-1 | User-global preference surfaces in a different project | M3.verify.1 |
| SC-2 | Project memory persists across harness switch | M3.verify.2 |
| SC-3 | Auto-propose flow runs end-to-end | M2.verify.1 |
| SC-4 | Canonical write produces mirror in adapter target | M3.verify.3 |
| SC-5 | Forget removes entry from canonical store and mirror | M3.verify.4 |
| SC-6 | Denylist auto-redacts an API key before write | M1.verify.2 + M2.verify.2 |
| SC-7 | Explicit save warns when a secret is detected | M2.verify.2 |
| SC-8 | Audit flags a memory unverified for more than 91 days | M4.verify.1 |
| SC-9 | Stale memory still loads (no silent drop on age) | M3.verify.5 |
| SC-10 | Supersede archives the predecessor entry | M2.verify.3 |
| SC-11 | Synthesis returns a relevant, tier-filtered block | M4.verify.2 |
| SC-12 | Audit detects contradictions without auto-resolving | M4.verify.3 |
| SC-13 | Agent write is restricted to the canonical store | M4.verify.4 |
| SC-14 | Pre-existing per-project files are left byte-identical | M3.verify.6 |
| SC-15 | `<private>` markup is honored (content withheld from store) | M2.verify.4 |
| SC-16 | `[CROSS-MEMORY]` injection block format is correct | M3.verify.7 |
| SC-17 | `category` field round-trips through save and recall | M2.verify.5 |
| SC-18 | Project-fact distillation reaches the injection block | M3.verify.8 |
| SC-19 | Sentinel markers in `MEMORY.md` survive a write pass | M3.verify.9 |
| SC-20 | Slug derivation is checked against the live filesystem | M3.verify.10 |
| SC-21 | Cross-memory agent refuses writes outside the allowlist | M4.verify.5 |

**Contract-level vs. behavioral coverage.** SC-1, SC-2, SC-3, SC-4, SC-5, SC-15, and SC-16 describe integration behaviors that span harness boundaries (cross-harness round-trip, auto-injection pickup, end-to-end proposal flow). These were verified through static walks against the adapter contracts as documented in `SKILL.md` and the three adapter files. Behavioral end-to-end coverage for these seven SCs requires deploying via `tooling/deploy.ps1` and running a fresh-session regression pass across at least two harness configurations.
