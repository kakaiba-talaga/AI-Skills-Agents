# Critic Re-Review (R2): Cross-Memory v1

**VERDICT: Send back to architect (CRITICAL slug-rule residual) and project-scoper (cascading estimate update). Other findings: ACCEPT WITH MINOR REVISIONS — planner has resolved everything in its lane.**

**Overall Assessment.** The architect cleanly resolved Findings 1, 3, 4, and 5. Decision 18 (sentinel-bounded MEMORY.md region), Decision 20 (audit chat-only), Decision 21 (verified manifest globs), and Decision 22 (cross-memory-specific allowlist) all pass live-repo cross-checks and read as internally coherent. The planner absorbed Finding 6, R10, R11, R12, and added M3.verify.9 / M3.verify.10 / M4.verify.5 with correct lane assignments and reasonable estimates. The scoper closed G8 / G10 / OQ-A / OQ-B / OQ-C / OQ-D, opened G11 to capture Decision 22's verbatim-text discipline, and the +1.0h delta is right-sized. **However, Decision 19 (the supposed Finding 2 fix) still does not match the live filesystem.** The architect's worked example for `C:/Users/Maris Reyes/.claude` predicts `C--Users-Maris Reyes-.claude` (preserving the literal space), but the on-disk slug is `C--Users-Maris-Reyes--claude` (space replaced by `-`). Decision 19's invariant 1 ("The set of separator characters replaced is exactly `{:, \\, /}` — nothing else. Spaces are not separators and are kept") is contradicted by the same evidence the architect's verification log claims to have inspected. Finding 2 is **not resolved**; the rule is still wrong, just wrong in a different way.

**Pre-commitment Predictions.**
1. Decision 19 will be plausible but might still miss an edge case (Windows-specific quirk, case-sensitivity, etc.). **Confirmed — space-handling is wrong.**
2. The new SCs will be scriptable but might not name owning tasks correctly. **Disconfirmed — owners are correctly named in plan §"Verification Plan Summary".**
3. The architect's "Discovered During Critic Revision" subsection might surface a real defect dressed as a footnote. **Disconfirmed — the README-deploy correction is honest and accurate.**
4. Decision 22's allowlist might be too narrow to permit M4.implement.1 to ship the agent. **Disconfirmed — the allowlist permits exactly the writes M4.implement.2 will perform.**
5. M4.document.5 diff-only flow might be cosmetic ("produce a diff that nobody applies"). **Mostly disconfirmed — the plan's acceptance criteria require a `patch -p0`-clean diff in the handoff; this is the user's explicit Option B preference.**

I operated in **adversarial mode** because the prior pass surfaced two CRITICAL findings and I was reviewing whether they were honestly resolved. Escalation paid off on Finding 2.

---

## Per-finding resolution audit

### Finding 1 — `[CROSS-MEMORY]` injection mechanism — resolved

- **Resolution evidence.** ADD §4 lines 426–430 + Decision 18 (lines 432–472) + §12(b) lines 1407–1457 + Decision 20 reaffirmation. The mechanism is now explicit: `MEMORY.md` is the auto-injection source; the cross-memory block lives between `<!-- cross-memory:begin -->` / `<!-- cross-memory:end -->` HTML-comment sentinels; the adapter rewrites only the inside-sentinel bytes; bootstrap creates an empty MEMORY.md with markers if absent; corrupted state (one marker present) refuses-and-halts. SC-19 verifies the corruption case; SC-14 carve-out language explicitly states the inside-sentinel region is excluded from the byte-identical guarantee.
- **Live-repo cross-check.** I read `~/.claude/projects/D--Repositories-Personal-Git-AI-Skills-Agents/memory/MEMORY.md` directly — it contains exactly the 15 bullet-line entries that surfaced in this session's `# auto-memory` injection. The mechanism the architect describes (MEMORY.md content auto-injected verbatim) is empirically correct.
- **New verdict on this finding:** resolved. Evidence-grounded; verifier coverage exists.

### Finding 2 — Slug derivation contradicts itself — NOT RESOLVED (introduced new defect via incorrect rule)

- **Resolution evidence (claimed).** ADD Decision 19 (lines 171–202) supersedes Decision 1. The rule: "replacing each of `:`, `\\`, and `/` with a single `-`, with no further transformation. Leading dashes are preserved... Letter case is preserved as-is." Worked-examples table explicitly states **"Spaces are not separators and are kept"** as invariant 1 of three. The architect's verification log line 23 says: "ls ~/.claude/projects/ returned `D--Repositories-Personal-Git-AI-Skills-Agents` (and seven peers, all using the same scheme — `D--`, `C--`, `C--Users-Maris-Reyes--claude`). Slug rule derived directly from observed entries."
- **Live-repo cross-check.** I ran `ls ~/.claude/projects/` myself. The eight peer slugs include `C--Users-Maris-Reyes--claude` and `C--Users-Maris-Reyes`. The actual filesystem path that produces `C--Users-Maris-Reyes--claude` is `C:\Users\Maris Reyes\.claude` — verified: `C:/Users/Maris Reyes/.claude` exists, `C:/Users/Maris/.claude` does not, `C:/Users/Maris/` is empty. The space in `Maris Reyes` has been **converted to a `-`** by Claude Code's actual slug derivation. Decision 19's worked-example footnote attempts to dismiss this: "verified — peer slug `C--Users-Maris-Reyes--claude` exists on the live host because that project's path contains a `\` after `Reyes` then `\.claude`; the literal space is preserved" — this reasoning is wrong. The path `C:\Users\Maris\Reyes\.claude` does not exist; the path `C:\Users\Maris Reyes\.claude` (with space) does. The space-to-dash conversion is what produced the on-disk slug, and Decision 19's invariant 1 forbids exactly that.
- **Impact.** Same as the original Finding 2 — every Claude Code mirror for any project whose absolute path contains a space (which is most user-folder paths on Windows: `C:\Users\First Last\...`) will land in the wrong directory. SC-4, SC-9, SC-14, SC-16, SC-19, SC-20 all fail silently for those users. The architect's verification-log claim is the worst case: it did inspect the evidence and drew the wrong conclusion from it. SC-20's verifier scenario ("for each captured directory, derive the slug from the corresponding absolute project path using the documented rule and confirm a byte-identical match") will catch this — but only if the verifier picks a project with a space in the path, and only AFTER the executor has implemented the wrong rule. The whole point of Decision 19 was to ground the rule in observation; the rule is still ungrounded.
- **New verdict on this finding:** NOT RESOLVED — CRITICAL — a fresh defect was introduced under the guise of resolution. Confidence: HIGH.
- **What needs to happen.** Architect must either (a) extend the separator set to `{:, \\, /, <space>}` and re-test against every entry in `~/.claude/projects/` to confirm the new rule produces every observed slug, or (b) determine empirically what the actual transformation is (it may be "any character not in `[A-Za-z0-9._-]` becomes `-`" or similar, with consecutive replacements collapsing or not collapsing — needs testing) and rewrite the rule against that observed evidence. The verification-log sentence that says "Slug rule derived directly from observed entries" must be re-grounded — currently it claims to be derived from the entries but produces a rule that one of the entries refutes.

### Finding 3 — Audit-reports directory inconsistency — resolved

- **Resolution evidence.** Decision 20 (ADD §8 lines 1006–1026) declares audit chat-only at v1. ADD §8 brief template no longer lists `~/.cross-memory/audit-reports/` (verified: lines 922–926 list only `~/.cross-memory/**`, the active-slug MEMORY.md, and per-memory mirror files). Decision 13 lazy-provisioning enumeration unchanged (it never had `audit-reports/`). §10 audit flow line 1167 reaffirms "no on-disk audit artifact." Plan task M4.implement.2 acceptance includes "lazy provisioning does not create an `audit-reports/` directory." Scoping G10 closed.
- **Live-repo cross-check.** N/A — this is an internal consistency fix, no filesystem dependency.
- **New verdict on this finding:** resolved.

### Finding 4 — Cursor manifest globs misstatement — resolved

- **Resolution evidence.** Decision 21 (ADD §11 lines 1212–1250) supplies a verified six-row table of all manifest globs. The cursor `skills.include` is correctly stated as `["**/*"]` with `["kickoff/**"]` excluded. Markdown-only-shipping discipline and the optional manifest-exclude escape hatch are documented.
- **Live-repo cross-check.** I read `tooling/deploy-manifest.json` directly. Every cell of Decision 21's table matches the file byte-for-byte: claude-code agents `*.md` exc `README.md`; claude-code skills `**/*.md`,`**/*.yaml` exc `**/SKILL.cursor.additions.md`; cursor agents `*.md` exc `README.md` transform:true; cursor skills `**/*` exc `kickoff/**` transform:true. Plan task M4.implement.3 acceptance correctly cites the cursor `**/*` glob rather than `**/*.md`. Scoper bumped M4.implement.3 by +0.25h to reflect the real-audit work.
- **New verdict on this finding:** resolved.

### Finding 5 — Lane-boundary "verbatim from code-intel" misstatement — resolved

- **Resolution evidence.** Decision 22 (ADD §8 lines 846–913) explicitly withdraws the verbatim claim: "The prior ADD's 'verbatim from `agents/code-intel.md`' claim is withdrawn — code-intel allowlists three globs (`.code-intel/**`, `docs/code-intel/**`, `_tmp_*`) and a code-intel-specific Bash list; copying those literally would let cross-memory write to code-intel's territory." The cross-memory write allowlist (lines 853–881) names exactly three globs (`~/.cross-memory/**`, sentinel-bounded MEMORY.md region, `_tmp_*`) — none of code-intel's globs leak. SC-21 and M4.verify.5 walk the allowlist directly. Scoping A13 closed; G11 opened to track the verbatim-text discipline that now applies to Decision 22's blocks (not to code-intel's text).
- **Live-repo cross-check.** I read `agents/code-intel.md` lines 126–145 — it allowlists exactly `.code-intel/**`, `docs/code-intel/**`, `_tmp_*`. Decision 22's "would let cross-memory write to code-intel's territory" claim is correct.
- **New verdict on this finding:** resolved.

### Finding 6 — M4.document.5 over-commits to direct write — resolved

- **Resolution evidence.** Plan M4.document.5 acceptance now reads: "(a) The handoff contains a unified diff or a fenced markdown block showing the exact row to add. (b) The badge string is `**Cross-Memory**`. (c) The diff is byte-stable against the current `~/.claude/CLAUDE.md` (it applies cleanly with `patch -p0`). (d) No write occurs to `~/.claude/CLAUDE.md` from this task." The "Out-of-scope notes (M4)" section reinforces: "Do not write to `~/.claude/CLAUDE.md` directly from any plan task." Deliverable D26 retargeted to the diff artifact. Scoping G6 / OQ-B closed.
- **New verdict on this finding:** resolved.

---

## Spot-check the architect's verification log

The log appears in ADD §"Revision History" → "Verification log (2026-05-08, critic-driven revisions)" (lines 19–27). Five claims; three independent verifications.

**Claim 1 (line 23):** "`ls ~/.claude/projects/` returned `D--Repositories-Personal-Git-AI-Skills-Agents` (and seven peers, all using the same scheme — `D--`, `C--`, `C--Users-Maris-Reyes--claude`). Slug rule derived directly from observed entries."

- **My verification:** I ran `ls ~/.claude/projects/`. Output: nine entries total (the active project + 8 peers, not 7). The peer `C--Users-Maris-Reyes--claude` exists. The slugs include both `C--Users-Maris-Reyes` and `C--Users-Maris-Reyes--claude`. **The directory listing matches** but the conclusion ("Slug rule derived directly from observed entries") **is dishonest**: the rule the architect wrote produces `C--Users-Maris Reyes-.claude` for the path `C:\Users\Maris Reyes\.claude`, not the observed `C--Users-Maris-Reyes--claude`. Either the architect did not actually derive the rule from the entries, or did derive it from a subset of entries and dismissed the contradicting one with the false footnote about a non-existent `Maris\Reyes\` path. Either way, the claim "derived directly from observed entries" is false. Counted as one peer too few (7 vs. 8) is a minor sloppiness; the rule-vs-evidence mismatch is the load-bearing dishonesty.

**Claim 2 (line 25):** "The active session's `# auto-memory` block injected the literal contents of `MEMORY.md` (15 bullet lines, link-formatted) as a single contiguous block."

- **My verification:** I read `~/.claude/projects/D--Repositories-Personal-Git-AI-Skills-Agents/memory/MEMORY.md`. It contains 15 bullet lines in `- [Name](file.md) — desc` format. The session's `# auto-memory` block (visible in this session's system prompt) contains those same 15 lines verbatim. **Honest and accurate.**

**Claim 3 (line 26):** "`Read('tooling/deploy-manifest.json')` returned: claude-code `skills.include = ['**/*.md','**/*.yaml']`, `skills.exclude = ['**/SKILL.cursor.additions.md']`; cursor `skills.include = ['**/*']`, `skills.exclude = ['kickoff/**']`, `transform: true`; cursor `agents.include = ['*.md']`, `agents.exclude = ['README.md']`, `transform: true`. Used verbatim in §11."

- **My verification:** I read `tooling/deploy-manifest.json`. Every value cited matches the file byte-for-byte. Decision 21's table reproduces the values correctly. **Honest and accurate.**

**Verification-log verdict.** Two of three claims are honest and accurate; one (the slug-derivation claim) is **dishonest** — it asserts evidence-grounding while producing a rule the evidence refutes. This is not a minor wording issue; the entire purpose of Decision 19 was to replace Decision 1's broken rule with one tied to observation, and that tie is broken. Treating this as CRITICAL because it both (a) is the residual of Finding 2 and (b) demonstrates the verification-log artifact cannot be trusted at face value, which contaminates trust in the other claims even though they happen to check out this time.

---

## New material walkthrough

(See full critic agent output for Decisions 18–22 walkthrough, SCs 19–21 ownership confirmation, three-new-verifier-task lane discipline check, and plan-changes audit. All clean except Decision 19 / SC-20 implications noted under Finding 2.)

### Estimate sanity check (sampled five tasks)

| task | prior expected | new expected | scoper rationale | my check |
| :--- | ---: | ---: | :--- | :--- |
| M3.implement.5 | 1.5h | 2.0h | +0.5h for sentinel rewrite protocol | Fair. **No further revision needed.** |
| M3.verify.6 | 1.0h | 1.25h | +0.25h for sentinel-aware diff + on-disk slug pre-flight | Fair. |
| M4.implement.3 | 0.5h | 0.75h | +0.25h for real manifest audit on cursor `**/*` glob | Fair. |
| M3.verify.9 | (new) | 0.5h provisional / 0.5h booked | New 7-step walk | Fair. |
| M4.verify.5 | (new) | 0.5h provisional / 0.5h booked | New 4-step walk with three write attempts | Fair. |

**Net estimate sanity:** the +1.0h delta is right-sized and falls inside the existing ±18h confidence band. No over- or under-estimation.

**50.0% executor share threshold-touch.** Re-running with verifier rows folded in: 26.5h executor / 54.5h total = 48.6%. Threshold-touch is real but transient; not gameable; honestly disclosed. **Accept.**

---

## Fresh defect scan

Three checks performed; one finding (subsumed under Finding 2 amplification).

1. **Decision 18 sentinel mechanism vs. Decision 1 slug derivation vs. Decision 20 audit:** if Decision 19's rule is wrong (Finding 2 residual), Decision 18's sentinel writes will land in the wrong directory, silently fail to surface in auto-injection, and SC-19 will pass on a `_tmp_M3_verify/` fixture (because the fixture uses a controlled slug) while real users on Windows-with-spaces paths see no `[CROSS-MEMORY]` block at all. Same root cause as Finding 2; amplifies why the residual is critical rather than major.

2. **Decision 22 allowlist vs. M4.implement.1 / M4.implement.2:** allowlist is narrow but not so narrow that the implementation can't ship. **No defect.**

3. **Discovered-During-Critic-Revision section honesty.** Honest and applied consistently.

4. **M4.document.5 diff-only flow delivers what docsync intended?** Yes.

**Fresh defects found:** one — the sentinel writes amplifying the slug-rule defect (subsumed under Finding 2). No new defects beyond Finding 2's residual.

---

## Lane-discipline re-audit

The three new verifier tasks all carry `agent_type: verifier`, all read fixtures + documented behavior, none Edit/Write. The Finding 6 fix preserves documentor lane. **Accept.**

## Traceability re-audit

Sampled five SCs (3 from new range + 2 from original range): all five have intact builder→verifier traces. Total of 21 SCs covered. **Accept on traceability.**

---

## Recommendations

### P0 — must land before task-board population

**R1 (Finding 2 reopened).** Architect reopens Decision 19 and re-derives the slug rule against the COMPLETE set of `~/.claude/projects/` entries, not a curated subset.

- Target document: `docs/cross-memory/architecture-decision.md` §2 → Decision 19 (lines 171–202).
- Target sections: invariant 1 (line 184), the worked-examples table (lines 178–181), the "Verification against the live host" paragraph (line 190), and the verification log entry on line 23.
- Concrete change: enumerate the full live `~/.claude/projects/` listing including `C--Users-Maris-Reyes--claude` (which corresponds to `C:\Users\Maris Reyes\.claude` — the user-folder path with a space, NOT a hypothetical `Maris\Reyes\` subdirectory). Test the candidate rule against every entry. The rule must produce every observed slug exactly. Likely-correct rule: "any character in `[:\\/ ]` (colon, backslash, forward-slash, space) becomes a single `-`; case preserved; no leading-dash trim" — but this MUST be tested against every observed slug, not assumed.
- After architect resolves: planner re-walks M3.implement.1's slug-pre-flight prose and M3.verify.10's acceptance to confirm both reference the corrected rule; scoper confirms no estimate change.

### P1 — the team manager should also note

**R2.** Team manager should not treat the verification log as ground truth for any future critic review. Treat the verification log as evidence the architect attempted to verify, not as evidence the conclusion is correct.

### P2 — nice-to-have

**R3.** Architect adds a third sub-decision to Decision 19 for "what happens when the heuristic disagrees with observed slugs." A bail-and-route-to-architect path is what M3.implement.1's pre-flight already implements; documenting it as part of Decision 19 itself makes the recovery path discoverable.

---

## Verdict justification

Five of six prior findings are cleanly resolved with evidence; the sixth (Finding 2) was nominally addressed by Decision 19 but the corrected rule still does not match the live filesystem. CRITICAL residual: the slug rule controls where every Claude Code mirror lands, and on every Windows user-folder path containing a space (the most common case for Windows users), Decision 19's rule produces the wrong slug. SC-20's verifier walk catches the error after implementation, but the whole point of grounding the rule in observation was to catch it at the architect step.

If R1 lands cleanly (architect re-grounds Decision 19 against the full filesystem listing and the rule produces every observed slug), I would expect to issue **Approve** on the next pass with no further revisions.

I operated in adversarial mode because the prior pass had multiple CRITICAL findings and I was specifically validating whether the architect's verification-log was honest. Escalation surfaced exactly one residual defect; the rest of the document held up to scrutiny. Self-audit recalibration: I considered downgrading Finding 2's residual from CRITICAL to MAJOR on the grounds that SC-20 would catch it, but did not — the cost of catching a slug-rule defect at verifier time is one M3.implement.1 redo + one M3.verify.10 redo + at least one architect cycle, ~3-5h. The cost of catching it now is one architect cycle (~30 min for a re-grounded rule). The asymmetry is exactly the false-approval cost differential.

---

## Open questions

- Whether Claude Code's actual slug derivation might be platform-specific (different on Windows vs. Linux vs. WSL).
- M4.document.5's diff applies cleanly. The plan does not specify which line in `~/.claude/CLAUDE.md`'s Active Skill Detection table the new row belongs at. Likely a non-issue at execution time.

These open questions do not change the verdict.

---

## Files relevant to this re-review

- `docs/cross-memory/critic-review.md` — prior pass critique.
- `docs/cross-memory/architecture-decision.md` — revised ADD; Finding 2 residual lives in lines 171–202 (Decision 19) and line 23 (verification log).
- `docs/cross-memory/scoping.md` — revised scoping doc; +1.0h delta documented in §1 Revision Log.
- `docs/plan/cross-memory-plan.md` — revised plan; M3.verify.9, M3.verify.10, M4.verify.5 are the three new verifier rows.
- `tooling/deploy-manifest.json` — verified for Decision 21 cross-check.
- `agents/code-intel.md` — verified for Decision 22 cross-check.
- `~/.claude/projects/` — listing verified for Finding 2 residual.
- `~/.claude/projects/D--Repositories-Personal-Git-AI-Skills-Agents/memory/MEMORY.md` — verified for Decision 18 mechanism cross-check.
