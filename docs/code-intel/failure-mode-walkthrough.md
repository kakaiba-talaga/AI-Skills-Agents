# R10 Failure-Mode Walkthrough — code-intel Agent

**Run-id:** `code-intel-agent-2026-04-26`
**Verifier pass:** M5.6
**Date:** 2026-04-28
**Sources checked:**
- `docs/plan/code-intel-agent-requirements.md` — R10 (lines 171–191)
- `agents/code-intel.md` — Failure Matrix (lines 674–690), supporting prose throughout

---

## Purpose

This document walks every row of the R10 failure matrix through a mock brief or DB state, confirms that the agent body specifies the correct refusal / partial / skip / rebuild posture, and records the prose locator and a direct excerpt. Each row is judged PASS or FAIL.

The pattern mirrors M5.3 and M5.5: this is a documented walkthrough, not an executed test. Evidence is prose-locator-level; no SQLite or runtime is exercised.

---

## 13-Row Walkthrough Table

| # | Failure type | Mock fixture | Expected posture | Agent body citation | Agent body prose excerpt | Result |
| :---: | :--- | :--- | :---: | :--- | :--- | :---: |
| 1 | Symbol not found | Brief: `{"query_type":"find_callers","symbol":"nonexistent_fn"}`. DB state: index built, 143 nodes, zero rows match `name = 'nonexistent_fn'`. | refuse | `agents/code-intel.md:678` (Failure Matrix row) + `agents/code-intel.md:559` (status enum) | `"Symbol not found \| Query \| Refuse"` / `"status": "ok" \| "partial" \| "refused"` | PASS |
| 2 | Soft cap hit | Brief: `{"query_type":"find_callers","symbol":"emit"}`. DB state: query returns 847 rows; `max_results` default is 200; soft-cap (100MB DB size or 60s wall-clock) fires mid-index. | partial | `agents/code-intel.md:679` (Failure Matrix row) + `agents/code-intel.md:383` (Caveats footer template) + `agents/code-intel.md:397` (truncation note spec) | `"Soft cap hit \| Indexer/Query \| Partial w/ truncation note"` / `"<truncation note, if results exceeded max_results>"` / `"Truncated: showing N of M results. Re-run with max_results: <larger> or narrow scope."` | PASS |
| 3 | Hard cap hit | Brief: `{"query_type":"reindex"}`. DB state: repo scan returns 6,200 files — exceeds 5,000-file hard cap. | refuse | `agents/code-intel.md:680` (Failure Matrix row) + `agents/code-intel.md:198` (Phase 1 failure prose) + `agents/code-intel.md:665` (Performance Enforcement table) | `"Hard cap hit \| Indexer \| Refuse"` / `"Phase 1 — file count > 5,000 → refuse (R9 hard cap)."` / `"Indexer — files \| Hard cap \| 5,000 \| Abort; refuse 'narrow scope'"` | PASS |
| 4 | Tier-2 only (precision degraded) | Brief: `{"query_type":"find_implementations","symbol":"IRepository"}`. DB state: index built with Grep heuristics (no AST parser for Java); all rows have `precision = 'regex'`. | partial | `agents/code-intel.md:681` (Failure Matrix row) + `agents/code-intel.md:381` (Caveats footer, Tier-2 note) + `agents/code-intel.md:395` (tilde glyph convention) + `agents/code-intel.md:604–632` (consider_tier3_escalation logic) | `"Tier-2 only (precision degraded) \| Query \| Partial w/ precision: regex caveat"` / `"<Tier-2 precision note, if any partition is regex-grade>"` / `"Tier-2 rows carry a ~ glyph next to the citation"` | PASS |
| 5 | Ambiguous symbol | Brief: `{"query_type":"find_definition","symbol":"process"}`. DB state: index has 3 distinct nodes named `process` across different files/modules. | partial | `agents/code-intel.md:682` (Failure Matrix row) + `agents/code-intel.md:384` (Caveats footer, ambiguity note) | `"Ambiguous symbol \| Query \| Partial — return all w/ disambiguation"` / `"<ambiguity note, if the symbol resolved to >1 candidate>"` | PASS |
| 6 | File unreadable | Index run: file `src/locked.py` raises `PermissionError` during Phase 3 parse. DB state: 142 of 143 files indexed; one entry written to `_tmp_indexer-skipped.log`. | skip | `agents/code-intel.md:683` (Failure Matrix row) + `agents/code-intel.md:200` (Phase 3 failure prose) + `agents/code-intel.md:204–213` (skipped-file log spec) | `"File unreadable \| Indexer \| Skip + caveat; log to _tmp_indexer-skipped.log"` / `"Phase 3 — file unreadable → skip + log + continue."` / `"<ISO-8601 timestamp>  unreadable (permission denied)   subdir/locked-file.py"` | PASS |
| 7 | Tier-1 runtime missing | Index run (Phase 2): `which python` returns exit 1; `python --version` also fails. DB state: Python files will be indexed via Tier-2 Grep heuristics; caveat propagated to every subsequent query response. | partial (silent at indexer; caveat in query response) | `agents/code-intel.md:684` (Failure Matrix row) + `agents/code-intel.md:199` (Phase 2 failure prose) + `agents/code-intel.md:383` (Caveats footer, Tier-1 missing note) | `"Tier-1 runtime missing \| Indexer \| Silent fallback to Tier-2 + caveat in next response"` / `"Phase 2 — Tier-1 runtime missing → silent fallback to Tier-2 + caveat propagated to query responses."` / `"<Tier-1 runtime missing note, if applicable>"` | PASS |
| 8 | DB corrupted | Brief: `{"query_type":"find_callers","symbol":"handle_request"}`. DB state: `.code-intel/index.sqlite` exists but `PRAGMA integrity_check` returns errors; Phase 5 SQLite error detected. | refuse | `agents/code-intel.md:685` (Failure Matrix row) + `agents/code-intel.md:202` (Phase 5 failure prose) | `"DB corrupted \| Query \| Refuse + auto-recovery offer"` / `"Phase 5 — SQLite error → refuse + auto-recovery offer."` | PASS (posture specified; no inline format example — see Notes) |
| 9 | Query timeout | Brief: `{"query_type":"find_callers","symbol":"BaseController"}`. DB state: recursive CTE runs for 31 s on a 4,900-node graph — exceeds 30 s hard cap. | refuse | `agents/code-intel.md:686` (Failure Matrix row) + `agents/code-intel.md:670` (Performance Enforcement table) | `"Query timeout (>30s recursive CTE) \| Query \| Refuse w/ narrow-scope hint"` / `"Query — CTE timeout \| Hard \| 30s \| Refuse w/ narrow-scope hint"` | PASS (posture specified; no inline format example — see Notes) |
| 10 | Brief malformed | Human sends plain prose: `"Tell me who calls process_data"`. No JSON-fenced block, no labeled-prose `Query:` field detected. | refuse | `agents/code-intel.md:687` (Failure Matrix row) + `agents/code-intel.md:55` (malformed handling prose) + `agents/code-intel.md:94–100` (validation pseudocode) + `agents/code-intel.md:724–741` (Refusal output example) | `"Brief malformed \| Pre-query \| Refuse w/ usage card"` / `"neither format recognized → refuse immediately with the usage card above. No fuzzy parsing."` / `"[code-intel] Brief malformed — could not parse input."` | PASS |
| 11 | Lane violation (Write outside allow-list) | Orchestrator brief: `{"query_type":"find_callers","symbol":"process_data"}`. During execution, agent attempts to Write to `src/auth/handler.py` (outside `.code-intel/**`, `docs/code-intel/**`, `_tmp_*`). | refuse-and-halt | `agents/code-intel.md:688` (Failure Matrix row) + `agents/code-intel.md:130–135` (Refuse-and-halt on first Write violation) + `agents/code-intel.md:743–754` (Write-allowlist violation example) | `"Lane violation \| Any \| Refuse-and-halt per R8a"` / `"Halt the run. No further Write or Bash operations in the same dispatch."` / `"[code-intel] VIOLATION — Write refused. ... Run halted."` | PASS |
| 12 | Bash violation (command outside allow/deny lists) | Orchestrator brief: `{"query_type":"find_callers","symbol":"deploy"}`. During execution, agent attempts `pip install tree-sitter` (a forbidden package install). | refuse-and-halt | `agents/code-intel.md:689` (Failure Matrix row) + `agents/code-intel.md:150–156` (Bash Scope forbidden list + halt rule) | `"Bash violation \| Any \| Refuse-and-halt per R8b"` / `"Package installs: npm install, pip install, ... Refuse-and-halt per Lane Boundaries applies uniformly to any forbidden invocation."` | PASS |
| 13 | DB missing or stale | Ad-hoc user query: `Query: find_definition\nSymbol: emit_event`. DB state A: `.code-intel/index.sqlite` does not exist. DB state B: file exists but `db_indexed_sha` differs from `git rev-parse HEAD` output. | rebuild (transparent for A; drop-and-rebuild for B) | `agents/code-intel.md:690` (Failure Matrix row) + `agents/code-intel.md:160–174` (Lifecycle § Build trigger + Staleness check) | `"DB missing or stale \| Query \| See Lifecycle (R11)"` / `"if .code-intel/index.sqlite does not exist, build it transparently before answering."` / `"If the SHAs differ, drop and rebuild the index before answering, bounded by R9 caps."` | PASS |

---

## Per-Row Summaries

**Row 1 — Symbol not found:** PASS. The Failure Matrix row (line 678) explicitly states "Refuse" and the Output Dispatch section (line 559) provides the `"status": "refused"` envelope value.

**Row 2 — Soft cap hit:** PASS. The Failure Matrix row (line 679) states "Partial w/ truncation note". The Caveats footer template (line 383) provides the slot, and line 397 gives the verbatim truncation string.

**Row 3 — Hard cap hit:** PASS. The Failure Matrix row (line 680) states "Refuse". Phase 1 failure prose (line 198) and the Performance Enforcement table (line 665) both confirm the hard cap and the "refuse narrow scope" action.

**Row 4 — Tier-2 only:** PASS. The Failure Matrix row (line 681) states "Partial w/ `precision: regex` caveat". The Caveats footer template (line 381), the tilde glyph convention (line 395), and the `consider_tier3_escalation` logic (lines 604–632) all specify how the partial result surfaces and what the Tier-3 escalation path looks like.

**Row 5 — Ambiguous symbol:** PASS. The Failure Matrix row (line 682) states "Partial — return all w/ disambiguation". The Caveats footer template (line 384) provides the `<ambiguity note>` slot. The `find_definition` SQL (line 401–409) `ORDER BY` clause preferring AST-grade matches and returning multiple rows via `LIMIT` confirms the "return all" disposition.

**Row 6 — File unreadable:** PASS. The Failure Matrix row (line 683) states "Skip + caveat; log to `_tmp_indexer-skipped.log`". Phase 3 failure prose (line 200) confirms skip-and-continue. The skipped-file log format (lines 204–216) provides the exact log schema including ISO-8601 timestamp, reason vocabulary, and summary line.

**Row 7 — Tier-1 runtime missing:** PASS. The Failure Matrix row (line 684) states "Silent fallback to Tier-2 + caveat in next response". Phase 2 failure prose (line 199) confirms this is a *silent* fallback at the indexer level. The Caveats footer template (line 383) carries the `<Tier-1 runtime missing note>` slot, ensuring the query response is *not* silent.

**Row 8 — DB corrupted:** PASS (with note). The Failure Matrix row (line 685) states "Refuse + auto-recovery offer". Phase 5 failure prose (line 202) confirms "SQLite error → refuse + auto-recovery offer." The posture is unambiguous. *Note:* the Output Format Examples section provides an inline format example only for the malformed-brief refusal and the write-allowlist violation; there is no inline format example for the DB-corrupted refusal message. This is a notable documentation gap but does not affect posture coverage — the matrix and prose are consistent.

**Row 9 — Query timeout:** PASS (with note). The Failure Matrix row (line 686) states "Refuse w/ narrow-scope hint". The Performance Enforcement table (line 670) confirms "Query — CTE timeout | Hard | 30s | Refuse w/ narrow-scope hint." *Note:* same gap as Row 8 — no inline example of the exact refusal message format. Posture is clear; message format is not illustrated.

**Row 10 — Brief malformed:** PASS. The Failure Matrix row (line 687) states "Refuse w/ usage card". Line 55 instructs "refuse immediately with the usage card above. No fuzzy parsing." Validation pseudocode (lines 94–100) shows the two refusal paths. The Output Format Examples section (lines 724–741) gives the verbatim usage card text.

**Row 11 — Lane violation (Write):** PASS. The Failure Matrix row (line 688) states "Refuse-and-halt per R8a". The Lane Boundaries section (lines 130–135) specifies the four-step protocol (refuse, emit violation report, halt, allow in-flight read-only to complete). The Output Format Examples section (lines 743–754) gives the verbatim violation report format.

**Row 12 — Bash violation:** PASS. The Failure Matrix row (line 689) states "Refuse-and-halt per R8b". The Bash Scope section (lines 148–156) enumerates the forbidden command categories and states "Refuse-and-halt per Lane Boundaries applies uniformly to any forbidden invocation." Both the posture and the mechanism reference the same halt protocol as Row 11.

**Row 13 — DB missing or stale:** PASS. The Failure Matrix row (line 690) says "See Lifecycle (R11)". The Lifecycle section (lines 160–174) fully specifies both sub-cases: transparent build-on-first-query for missing DB; SHA-compare-and-drop-rebuild for stale DB.

---

## Notable Gaps

Two rows reveal a documentation gap that does not affect posture but affects completeness:

- **Row 8 (DB corrupted)** — the "Refuse + auto-recovery offer" posture is stated in the matrix and in Phase 5 prose, but no inline format example exists to show what the auto-recovery offer looks like to the caller (human or orchestrator).
- **Row 9 (Query timeout)** — the "Refuse w/ narrow-scope hint" posture is stated in the matrix and the Performance Enforcement table, but no inline format example shows the narrow-scope hint message.

These are *documentation gaps in the agent body*, not behavioral mismatches. Every row's posture (refuse / partial / skip / rebuild) and the output envelope values (`"status": "refused"`, `"status": "partial"`) are correctly specified. The gaps would be appropriate for a follow-on documentation task.

---

## Overall Verdict

**PASS**

All 13 R10 failure rows have behavioral coverage in the agent body. The posture is correctly specified for every row. Two rows (8 and 9) lack inline output-format examples but carry unambiguous posture prose. No row has a behavioral gap or mismatch against R10.
