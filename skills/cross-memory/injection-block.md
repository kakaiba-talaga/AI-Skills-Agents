<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Injection block

The injection-block formatter consumes the ordered entry list produced by the always-on tier filter and renders the bytes that the harness adapter splices between the `<!-- cross-memory:begin -->` and `<!-- cross-memory:end -->` sentinel markers in the harness-native `MEMORY.md`. The formatter is strictly a renderer: it takes entries in, produces bytes out, and makes no decisions about scope selection, staleness, or deduplication — all of that is the filter's job.

### Output contract

The formatter's output is **exactly** the bytes the adapter passes to `update_sentinel_block(content)`. The formatter does **not** emit the sentinel marker lines themselves — those are part of the file structure managed by the adapter. The output begins with the `[CROSS-MEMORY]` header line and ends with the last sub-section's last bullet line. There is no trailing blank line and no trailing marker in the formatter's output.

This means:

- The adapter writes `<!-- cross-memory:begin -->\n`, then the formatter's output, then `\n<!-- cross-memory:end -->` (the exact byte layout is the adapter's concern; the formatter is unaware of it).
- If the formatter produces zero bytes (see empty-list edge case below), the region between the markers is empty — the markers remain present but contain nothing.

### Block structure

A fully populated block looks like this:

```
[CROSS-MEMORY]

User Profile:
- <bullet 1>
- <bullet 2>

Project Knowledge:
- <bullet 1>
- <bullet 2>
```

Key layout rules:

- There is **one blank line** after the `[CROSS-MEMORY]` header line (before the first sub-section).
- There is **one blank line** between sub-sections.
- There is **no blank line** after the last bullet of the last sub-section — the formatter's output ends with that bullet line.
- Sub-section headers use the form `<Name>:` — a plain text label terminated with a colon, not a Markdown heading. This keeps the always-on injection block visually flat inside the harness's MEMORY.md.

At v1, the block contains **two active sub-sections**: `User Profile:` and `Project Knowledge:`. The `Relevant Memories:` sub-section is reserved in the design but not emitted at v1 (see Relevant Memories below).

### Sub-section sourcing rules

#### User Profile

The `User Profile:` sub-section is populated from two sources, combined in this order:

1. All filter Rule 1 entries — scope `user-global`, type in `{preference, rule, fact}`.
2. All filter Rule 3 entries (harness-scope) — scope `harness:<current-harness>`, type in `{rule, feedback}`.

The harness-scope entries (Rule 3) are folded into User Profile rather than given their own sub-section. This is a deliberate v1 simplification: harness-specific standing rules are user-level rules that happen to be harness-specific. A dedicated harness sub-section would be sparse in practice (most users have few harness-scoped memories) and would add visual noise without benefit. The fold collapses two structurally similar categories into a single coherent identity block.

Additionally, any `tag=always-on` entries from the `user-global` scope that entered via Rule 4 (and were not already selected by Rule 1) are appended at the end of the User Profile list. Plus any `tag=always-on` entries from the harness scope that entered via Rule 4 (and were not already selected by Rule 3) — these fold into User Profile alongside the harness-scope Rule 3 entries.

Within each source group, entries are ordered as delivered by the filter (most recently updated first within each group). Source groups appear in the order listed above — Rule 1 entries, then Rule 3 entries, then Rule 4 user-global additions, then Rule 4 harness-scope additions.

#### Project Knowledge

The `Project Knowledge:` sub-section is populated from:

1. All filter Rule 2 entries — scope `project:<current-slug>`, type in `{feedback, project, rule}`.
2. Any `tag=always-on` entries from the `project:<current-slug>` scope that entered via Rule 4 and were not already selected by Rule 2.

Entries are ordered as delivered by the filter (most recently updated first within each group).

If no active project slug was resolved (the adapter could not determine the current project), Rule 2 contributes zero entries and the sub-section is omitted from the output.

#### Relevant Memories — deferred at v1

The `Relevant Memories:` sub-section is **reserved** in the injection block design but is **not emitted at v1**. Its header line is not written, and no bullets are produced for it. The sub-section will be populated in a future release by a relevance-ranking step that scores memories against the current session context. At v1 the always-on tier surfaces every qualifying memory via type and tag rules rather than ranking — there is no ranking signal to drive a relevance sub-section.

This is not a gap or omission; it is an explicit deferral. The sub-section slot is documented here so the formatter spec is complete: when relevance ranking is introduced post-v1, the `Relevant Memories:` sub-section will be inserted after `Project Knowledge:` and will carry its own drop-priority position in the size budget.

### Bullet format

Each memory entry is rendered as a single Markdown list item:

```
- <description_with_banner>
```

The leading `- ` prefix is literal (hyphen, space). The `<description_with_banner>` field is the `description_with_banner` value from the filter output tuple — the memory's `description` frontmatter field with the staleness banner appended if applicable.

**120-character cap.** The rendered bullet (excluding the leading `- `) is capped at **120 characters**. If `description_with_banner` exceeds 120 characters, the description portion is truncated and a `…` (Unicode ellipsis, U+2026, single character) is appended such that the full `description_with_banner` in the rendered bullet is exactly 120 characters. The truncation preserves the staleness banner: if a staleness banner is present, the description is shortened to make room, not the banner.

**Truncation with staleness banner.** When a staleness banner is present, the cap is applied to the full `description_with_banner` string. If that string exceeds 120 characters, the description is shortened (from its right end) until `<shortened_description> + <banner>` fits within 120 characters, then `…` replaces the last character of the shortened description (keeping the total at exactly 120). The banner is never truncated.

**No metadata.** The bullet contains only the `description_with_banner` value. No memory `name`, `type`, `category`, `scope`, `verified_at`, or confidence score is rendered. No bullet IDs, no source attribution. The simplest possible line.

### Size budget enforcement

The formatter must fit its output within the byte budget configured by `max_inject_chars` (default: 2048 bytes). The budget is measured in UTF-8 encoded bytes of the formatter's full output string. When the output would exceed the budget, sub-sections are dropped in a defined priority order until the output fits.

#### Drop priority

Sub-sections drop in this order (last item drops first, first item drops last):

1. **`[CROSS-MEMORY]` header line** — **never dropped**. The header line always appears in the output. If even the bare header line (seven bytes: `[CROSS-MEMORY]`) does not fit within the budget, the formatter emits **zero bytes** rather than a partial header. A 2048-byte budget is unlikely to be smaller than the header, but the rule is documented for completeness.
2. **User Profile sub-section** — drops last. User Profile represents the most stable, identity-shaping context. It is the last sub-section to be sacrificed.
3. **Project Knowledge sub-section** — drops second-to-last. Project Knowledge is valuable but more volatile than user identity.

The `Relevant Memories:` sub-section is already deferred at v1 and does not participate in drop-priority at this time. When introduced post-v1, it will occupy the first-to-drop position.

Harness-scope entries (Rule 3), folded into User Profile, drop together with User Profile — they do not get independent drop-priority.

#### Sub-section atomicity

A sub-section either fits in full or is dropped entirely. Partial sub-sections are not emitted. The user-experience cost of a half-rendered sub-section (a header with only some of its bullets) is worse than its complete omission, because a partial block gives a misleading picture of the memory tier's content.

When computing whether a sub-section fits within the remaining budget, the formatter must account for **all bytes** the sub-section would contribute:

- The sub-section header line (e.g., `User Profile:\n`).
- The blank line preceding the sub-section header (one `\n`).
- Every bullet line (`- <description_with_banner>\n`).

If the total byte cost of the sub-section plus all previously committed bytes exceeds `max_inject_chars`, the sub-section is dropped in its entirety.

#### Within-sub-section bullet trimming

Before applying whole-sub-section drop, the formatter trims individual bullets bottom-to-top (lowest-priority bullet drops first). The filter's sort order establishes priority: within a sub-section, the last entry in the sorted list is the first to be trimmed. Bullets are dropped one at a time until either the sub-section fits within the remaining budget or no bullets remain (in which case the sub-section itself is dropped — an empty sub-section is not emitted).

The combination of bullet trimming and whole-sub-section drop means:
1. Try to fit the full sub-section. If it fits, emit it.
2. If it does not fit, drop bullets bottom-to-top until it does.
3. If trimming all bullets still doesn't bring the cost within budget (i.e., even the sub-section header alone overflows), drop the entire sub-section.

### Edge cases

| Scenario | Behavior |
| :--- | :--- |
| Filter returns an empty list | Emit only the `[CROSS-MEMORY]` header line (seven bytes plus a trailing newline). No sub-section headers, no bullets. This signals the always-on tier is active but has no qualifying entries for this session. Emitting the header alone rather than zero bytes allows the user to confirm the skill is wired up correctly — an empty block is a meaningful signal. |
| All sub-sections fit within budget | Emit the complete block with all sub-sections and all bullets. No truncation. |
| User Profile fits but Project Knowledge does not | Drop Project Knowledge. Emit the header line and the User Profile sub-section. (Drop priority: Project Knowledge drops before User Profile.) |
| Project Knowledge fits but User Profile does not | Drop User Profile. Emit the header line and the Project Knowledge sub-section only. This is unusual — User Profile is typically smaller and more stable — but the drop priority is applied mechanically regardless. |
| A single bullet's description exceeds 2048 bytes on its own | Apply the 120-character cap first. A 120-character bullet is 122 bytes (120 + `- ` prefix); well within the default 2048-byte budget. In practice, a single bullet will not exhaust the budget on its own under default config. If a user sets `max_inject_chars` to an unusually small value (e.g., 64 bytes), bullets that cannot coexist with even the sub-section header are dropped at the bullet-trimming step. |
| A staleness banner inflates a bullet past 120 characters | The 120-character cap is applied to `description_with_banner` as a whole. The description is shortened to make room for the banner. The banner text is never truncated — only the description is shortened. The truncated description ends with `…`, and the full rendered bullet is exactly 120 characters. |
| `max_inject_chars` is set below the header length (pathological config) | Emit zero bytes. The formatter does not emit a partial header under any circumstance. |

### Cross-references

- **Always-on tier filter** (produces the ordered entry list this formatter consumes): `always-on-tier.md`.
- **`update_sentinel_block` operation** (how the formatter's output bytes are spliced between the sentinel markers in the harness-native `MEMORY.md`): `adapter-claude-code.md` § 6.
- **`max_inject_chars` config field** (controls the byte budget): `## Config` section above.
