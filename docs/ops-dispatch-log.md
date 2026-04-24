# Ops Dispatch Decision Log

Optional audit trail of dispatch decisions made during `/ops` runs. Appended to **only when `/ops` is invoked with `--dispatch-log`** (opt-in, off by default). When the flag is set, the team manager writes one entry per agent dispatch and per framework-guided direct-tool choice. Records intent at dispatch time, not outcome.

- **Enable:** `/ops --dispatch-log <spec>` or add `--dispatch-log` to any `/ops` invocation.
- **Framework:** [Subagent Dispatch Decision Framework](../skills/ops/tool-restrictions.md) (see `## Subagent Dispatch Decision Framework` section)
- **Format spec:** [skills/ops/dispatch-log.md](../skills/ops/dispatch-log.md)
- **Retention:** persistent — not cleaned at `/ops` Phase 4, regardless of whether the flag was set on that run. Archival rotation is manual, not automatic.

## How to read this log

Each `## <run-id>` section represents one flagged `/ops` run. Bullets under a section are dispatch decisions in chronological order. The `Framework row` field ties each research-decision back to the row of the decision framework table that governed it — or `n/a` for work dispatches (which are governed by delegate-first, not by the research framework).

To audit: invoke `/ops "audit the dispatch log"` and the team manager will compare entries against the framework. If the log is empty (no runs used the flag), the audit will say so.

## Entries

_No entries yet. Run `/ops --dispatch-log <spec>` to start appending entries per the procedure in `skills/ops/dispatch-log.md`._
