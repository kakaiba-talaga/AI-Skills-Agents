<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->
# Cost Tracking

> **Opt-in reference** — this file is read only when `/ops` is invoked with `--cost` or the user explicitly asks for cost information. Do not read this file by default.

This file defines token and cost estimation for `/ops` runs. Claude Code does not expose actual token counts to the conversation, so all estimates are heuristic-based (rule-of-thumb estimates, not measurements).

---

## 1. What to Track Per Task

For each dispatched task, record the following in its metadata block:

- `metadata.model_used` — the model that executed the task (e.g., `"sonnet"`, `"opus"`)
- `metadata.model_escalations` — number of times the model was escalated during retries (e.g., `1` for a sonnet→opus escalation)
- `metadata.retry_count` — total number of dispatch attempts (initial attempt + retries)

These fields are populated as tasks complete and are used for cost estimation at the end of the run.

---

## 2. Cost Estimation Heuristics

Since actual token counts are not available, estimate based on agent type. These are rough baselines per dispatch attempt.

| Agent Type | Estimated Input Tokens | Estimated Output Tokens | Rationale |
|---|---|---|---|
| executor | 8,000 | 12,000 | Reads files, writes code |
| verifier | 6,000 | 4,000 | Reads code, runs commands, short output |
| code-reviewer | 10,000 | 8,000 | Reads full diff, produces detailed findings |
| code-reviewer-diff | 10,000 | 8,000 | Same as code-reviewer (standalone diff variant) |
| documentor | 6,000 | 10,000 | Reads code, writes substantial text |
| debugger | 12,000 | 10,000 | Investigative, reads many files |
| debugger-build | 8,000 | 6,000 | Focused on specific errors |
| planner | 8,000 | 12,000 | Reads context, produces structured plan |
| project-scoper | 10,000 | 14,000 | Reads many files, produces detailed assessment |
| interviewer | 4,000 | 3,000 | Short, focused interaction |
| critic | 8,000 | 6,000 | Reviews plan, produces findings |
| git-master | 4,000 | 2,000 | Simple git operations |

**Multiply by `retry_count`** to get the total per-task token estimate.

---

## 3. Model Pricing Reference

These are approximate rates and may change. Always label cost figures as "estimated" or "approximate" — never present them as exact.

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|---|---|---|
| Haiku | $0.80 | $4.00 |
| Sonnet | $3.00 | $15.00 |
| Opus | $15.00 | $75.00 |

---

## 4. Per-Run Cost Estimation

Perform this calculation at completion (Phase 4), after timing computation.

**Per-task formula:**

```
est_cost = (input_tokens × input_price_per_token + output_tokens × output_price_per_token) × retry_count
```

Where `input_price_per_token = model_input_price / 1,000,000` and similarly for output.

**Worked example** — executor on sonnet, 1 attempt:

```
input:  8,000 tokens × ($3.00 / 1,000,000) = $0.0240
output: 12,000 tokens × ($15.00 / 1,000,000) = $0.1800
retry_count = 1
est_cost = ($0.0240 + $0.1800) × 1 = ~$0.20
```

**Steps:**

1. For each dispatched task, regardless of its terminal status, apply the per-task formula using the agent type's baseline tokens and the model recorded in `metadata.model_used`. A `failed` task's `retry_count` reflects real dispatches that consumed real tokens; excluding it from this sum would under-report the run's actual cost.
2. Sum across all tasks for the total run cost estimate.
3. Break down by model tier — show how much was attributed to sonnet vs. opus (vs. other tiers if applicable).
4. Compute model escalation overhead: the additional cost added by tasks that were escalated. This is the difference between what the task would have cost at the baseline model vs. what it cost at the escalated model.
5. Flag the overhead: `"Model escalation added ~$X.XX to the run"`

---

## 5. Dashboard Integration

Include a Cost Estimate section in the **completion summary only** (Phase 4). Do not add cost information to mid-run dashboards — it is only meaningful once all tasks have finished.

### 5.1 Format choice

Two acceptable formats; pick based on run shape:

- **Per-task breakdown** (preferred for small runs, <10 tasks) — most informative, shows where cost concentrated.
- **Per-model rollup** (preferred for large runs, ≥10 tasks) — compact; per-task table would be noisy.

You may show both if the run has mixed characteristics (e.g., most tasks on sonnet, a few on opus).

### 5.2 Per-task format

```
### Cost Estimate
| # | Agent                  | Model | Tokens | Tool uses | Cost           |
|---|------------------------|-------|--------|-----------|----------------|
| 3 | debugger               | opus  | ~81K   | 36        | ~$1.50–3.00    |
| 4 | documentor             | opus  | ~37K   | 6         | ~$0.50–1.50    |
| — | Team manager overhead  | opus  | ~30K   | —         | ~$0.50–1.50    |
| **Total** |               |       | **~148K** | **42** | **~$2.50–6** |

Model escalation overhead: ~$1.80 (2 tasks escalated sonnet→opus)
```

### 5.3 Per-model rollup format

```
### Cost Estimate
| Model | Tasks | Tokens | Cost    |
|-------|-------|--------|---------|
| sonnet | 6   | ~120K  | ~$0.54  |
| opus   | 2   | ~60K   | ~$2.25  |
| **Total** | **8** | **~180K** | **~$2.79** |

Model escalation overhead: ~$1.80 (2 tasks escalated sonnet→opus)
```

### 5.4 Required / optional columns

**Required:** Tokens, Cost. Plus the grouping dimension (task # OR model).
**Optional (include when you have them):** Agent, Model (in per-task format), Tool uses, retry_count.

### 5.5 Formatting rules

- All `$` and token figures **must** be prefixed with `~` to signal approximation.
- **Ranges are acceptable and often more honest** than point estimates — e.g., `~$1.50–3.00` when input/output split is uncertain. Use a range when you are materially unsure; use a point estimate when you are not.
- Omit the model escalation overhead line if no escalations occurred.
- If pricing data is unavailable (e.g., `cost-tracking.md` couldn't be Read), output tokens only and add a line `pricing unavailable — $ cost omitted`. Do not fake figures.

### 5.6 Team-manager overhead (mandatory row)

Task-level costs only account for dispatched agents. They exclude the team-manager itself, which also burns tokens on the orchestrating model (typically opus):

- Task board creation (Phase 2) — state file writes, dashboard render
- Dispatch turns (Phase 3) — writing each agent brief, processing each result, writing handoffs, marking state transitions
- Stage transition checkpoints (interactive mode)
- Completion pipeline (Phase 4) — timing, cost, summary, file list, cleanup turns

Ignoring this consistently under-reports run cost. The per-task table **must** include a dedicated `Team manager overhead` row (shown in section 5.2). Rough heuristic, assume the orchestration model is opus:

- ~3–5K tokens for intake + task board creation
- ~2–5K tokens per dispatch turn (brief authoring + result processing)
- ~1–2K tokens per stage transition checkpoint
- ~5–10K tokens for the completion summary (this dashboard itself)

Sum these to estimate overhead tokens, then apply opus pricing. Tokens may be shown as `~?K` if you can't cleanly attribute them; the $ estimate is still required. Use a range if uncertain. Example: a 4-task interactive run might total ~25–50K orchestration tokens ≈ ~$0.50–1.50 on opus.

Omit this row only if the run had zero agent dispatches (e.g., a `status` or `--dry-run` call that stopped before dispatch).

---

## 6. Limitations and Caveats

- **Token estimates are heuristic.** Actual usage varies based on file sizes, diff length, codebase complexity, and conversation history. Real costs may be meaningfully higher or lower.
- **Long files and large diffs increase token usage** — a code-reviewer on a 2,000-line diff will consume far more than the baseline estimate.
- **Retry costs can dominate.** Three retries at opus adds up quickly. Flag this when it occurs.
- **Cost data informs decisions, not blocks them.** The team manager may surface cost context when deciding whether to escalate (e.g., "This task has failed twice on sonnet — escalating to opus will cost approximately $X. Proceeding."), but it must NOT refuse to escalate based on cost alone. Cost tracking is informational only.
- **Cost tracking is not a budget enforcement mechanism.** There are no hard limits, thresholds, or automatic stops based on estimated spend.
- **Prices change.** The rates in Section 3 are snapshots. If a run produces numbers that seem inconsistent with known pricing, note the discrepancy and use the most current rates available.

## Dashboard Cost Format

Display in the completion dashboard only — omit from mid-run dashboards.

Use the canonical table formats defined in **Section 5.2** (per-task breakdown) and **Section 5.3** (per-model rollup). Refer to those sections for column definitions, required rows, and formatting rules.
