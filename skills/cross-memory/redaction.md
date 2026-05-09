<!-- Referenced by ~/.claude/skills/cross-memory/SKILL.md. Keep in sync. -->

# Redaction Pipeline

## Pass order

Input bodies go through three stages before store: (1) **`<private>` strip pass** — explicit user-marked regions are replaced first; (2) **regex denylist pass** — known credential shapes are detected and replaced; (3) **confirmation gate** — the post-redaction candidate is shown to the user before any write is committed. Either signal in pass 1 or pass 2 triggers the `redacted: true` frontmatter flag. The confirmation gate is always present — it does not depend on whether redaction fired.

```text
input body
  → Pass A: <private> strip     (replaces <private>...</private> with [REDACTED:private])
  → Pass B: regex denylist      (replaces matching patterns with [REDACTED:<category>])
  → confirmation gate            (shows post-redaction candidate; user confirms or edits)
  → store
```

---

## Pass A — `<private>` parser

**Tag syntax.** The tag pair is `<private>...</private>`. Both tags are **case-sensitive** — `<Private>` or `<PRIVATE>` do not trigger redaction. Tag content may span multiple lines.

**Multiple occurrences.** A single body may contain any number of `<private>...</private>` blocks. Every block is stripped independently. The resulting body may contain multiple `[REDACTED:private]` placeholders.

**Nested tags.** Nesting is **flattened**. The outermost `<private>` opens the redacted region; the first `</private>` encountered closes it. Any inner `<private>` tags within that region are absorbed and treated as body content — they do not open a nested scope. The net effect is that the entire span between the outermost open tag and the first close tag becomes one `[REDACTED:private]` placeholder. Rationale: the safe-default interpretation is to redact the whole region, not to error or partially redact.

**Replacement placeholder.** Each matched region is replaced with the literal string `[REDACTED:private]`. This mirrors the format used by the regex denylist (Pass B), where category names stand in for `private`.

**Recoverability.** The original content inside the tags is **never persisted** — the placeholder is irrecoverable once written. There is no "show original" affordance in any read path. This matches Pass B semantics.

**Unmatched open tag — bounded-fallback rule.** When a `<private>` tag has no matching `</private>`, the parser applies a **bounded fallback**: it redacts from the open tag through the end of the current paragraph (i.e., up to and including the next blank line, or end of body if no blank line follows). Content in subsequent paragraphs is **not** redacted. The parser also emits a redaction warning visible in the confirmation gate:

```
redaction warning: unmatched <private> open tag at line N — redacted to end-of-paragraph
```

Rationale: "redact to end of body" risks unbounded, unintended redaction. "Ignore the tag" risks silently leaking content the user intended to protect. The bounded fallback plus an explicit warning at the confirmation gate is the safe middle ground — the user sees exactly what was redacted and can correct the typo before confirming the write.

**Cosmetic ellipsis on recall render.** When the `recall` path renders a memory body that contains `[REDACTED:private]`, the placeholder is replaced visually with `…` (Unicode horizontal ellipsis, U+2026) in the displayed output. This is a **recall-time cosmetic transform only** — the bytes written to disk remain `[REDACTED:private]`. The on-disk form is used by the audit engine and the supersede path; the ellipsis form is for human readability only.

**Interaction with `--no-redact`.** The `--no-redact` flag bypasses the **regex denylist (Pass B) only**. Pass A always runs — there is no flag that disables `<private>` tag processing. The flag exists to override false positives on the pattern-matching layer; it does not exist to override the user's own explicitly typed intent. Pass A runs *before* `--no-redact` consultation, so `redacted: true` is set whenever `<private>` fires regardless of whether the flag is present.

---

## Pass B — Regex denylist

The denylist is a **starter set, expandable** — the skill must not treat it as exhaustive. The warning UX is paranoid by default.

The `user-tagged-secret` category (row 8) is **advisory** — it fires only via audit re-run, not at save time.

| Category | Pattern (regex) | Example match | Replacement |
| :--- | :--- | :--- | :--- |
| `api-key` | `\b(sk-\|pk_\|ghp_\|gho_\|github_pat_\|xoxb-\|xoxp-\|AIza[0-9A-Za-z_-]{35}\|AKIA[0-9A-Z]{16})[A-Za-z0-9_-]{16,}` | `sk-abc123def456...`, `ghp_abcdef0123...` | `[REDACTED:api-key]` |
| `password` | `(?i)\b(password\|passwd\|pwd)\s*[:=]\s*['"]?[^\s'"]+` | `password = secret123`, `pwd: foo` | `[REDACTED:password]` |
| `bearer-token` | `(?i)\b(bearer\|authorization)\s*[:=]?\s*['"]?[A-Za-z0-9+/_-]{20,}\.[A-Za-z0-9+/_-]{20,}\.[A-Za-z0-9+/_-]{20,}` | `Authorization: Bearer eyJ...` (JWT-shape) | `[REDACTED:bearer-token]` |
| `jwt` | `\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}` | Standalone JWT string (header.payload.sig) | `[REDACTED:jwt]` |
| `aws-secret` | `\b[A-Za-z0-9+/]{40}\b` (proximity to `aws_secret_access_key` or `AKIA*` required) | AWS secret access key (40-char base64) | `[REDACTED:aws-secret]` |
| `env-block` | Multiline: `(?m)^\s*[A-Z_][A-Z0-9_]*\s*=\s*['"]?[^\s]+['"]?\s*$` — fires when 2+ consecutive matching lines are present | `.env`-style multi-line `KEY=value` block | `[REDACTED:env-block]` |
| `private-key-header` | `-----BEGIN (RSA \|EC \|DSA \|OPENSSH \|PGP )?PRIVATE KEY-----[\s\S]*?-----END (RSA \|EC \|DSA \|OPENSSH \|PGP )?PRIVATE KEY-----` | PEM, SSH, PGP private key blocks | `[REDACTED:private-key-header]` |
| `user-tagged-secret` | No regex — context-driven. Advisory: fires only via audit re-run when user explicitly labeled content as a secret in the same session, or content read from a path identified as `.env` / `*.key` / `secrets/*`. **Not triggered at save time.** | User said "keep this secret: …" | `[REDACTED:user-tagged-secret]` |

All patterns are applied case-sensitively unless the pattern includes `(?i)`. The `aws-secret` proximity constraint and `env-block` 2+-line threshold are the primary v1 refinement targets.

### `--no-redact` behavior

- **Scope.** `--no-redact` bypasses Pass B (regex denylist) for the current save invocation only. It does not affect future saves, the audit re-run, or any other path.
- **Pass A always runs.** `--no-redact` has no effect on the `<private>` strip pass. Explicitly tagged regions are redacted regardless of the flag.
- **Trigger condition.** The typed-phrase gate fires when `--no-redact` is set **and** at least one Pass B regex pattern matched the body. If Pass B would have been a no-op (no patterns matched), the flag is accepted silently and no confirmation is required.
- **Warning display.** When the gate fires, the skill displays a warning listing each pattern that matched and a preview of the matched text:

  ```
  warning: --no-redact is set; Pass B would have redacted the following patterns:
    - <category>: <preview of matched text>
    - ...
  Type 'save unredacted' to persist the unredacted memory, or anything else to cancel:
  ```

- **Confirmation phrase.** The user must type the exact phrase `save unredacted` — case-sensitive, no shortcut, no prefix match. Anything else (including `y`, `yes`, empty input) is treated as cancellation.
- **On confirmation.** The unredacted body is persisted. The `redaction_overridden_at` frontmatter field is stamped with the current UTC timestamp in ISO-8601 format. The `redacted` field is persisted as `false` (subject to the Pass A rule: if `<private>` fired, `redacted` remains `true` regardless). The `redaction_overridden_at` field is documented in the optional-fields table in `SKILL.md`'s schema validator.
- **On cancellation.** The save is aborted; nothing is written to disk. The user re-issues the command with or without `--no-redact` as desired.

**Rationale.** The typed phrase is an intentional friction asymmetry: false positives in the starter denylist are real and users need an escape hatch, but a simple `[y/N]` prompt is too easy to confirm by reflex when the input is a genuine secret. The typed phrase makes accidental override structurally difficult.

---

## Replacement format and frontmatter rule

**Replacement format.** Every redacted span is replaced with `[REDACTED:<category>]`, where `<category>` is one of:

- `private` — Pass A match (inline `<private>` tag)
- `api-key`, `password`, `bearer-token`, `jwt`, `aws-secret`, `env-block`, `private-key-header`, `user-tagged-secret` — Pass B matches

The placeholder text is always lowercase-hyphenated to match the category name exactly. Multiple matches in the same body each produce their own placeholder; placeholders are not merged.

**Frontmatter rule.** When **any** redaction fires — Pass A, Pass B, or both — the memory's frontmatter field `redacted` is set to `true`. This is a **single boolean**; no per-pass or per-category breakdown is stored in the frontmatter. If neither pass fires, `redacted` remains `false`. When `--no-redact` is in effect and `<private>` did **not** fire (Pass A was a no-op), the field is persisted as `false` and `redaction_overridden_at` is stamped with the UTC timestamp.

---

## Confirmation-gate hook

The redaction module emits its post-redaction candidate body to the **confirmation gate** (defined in the save flow in `SKILL.md`). The gate displays the full frontmatter and the candidate body — with all `[REDACTED:...]` placeholders visible — before any write is committed. For **auto-proposed saves**, the default answer is No; the user must actively confirm. For **explicit `/cross-memory save` invocations**, the user is trusted but a warning banner is still shown when any Pass A or Pass B pattern fired. The unredacted form is **never persisted** in any path; if the user rejects the candidate, nothing is written.

---

## Cross-references

- **Pass A behavior:** `## Pass A — <private> parser` section above.
- **Pass B starter set:** `## Pass B — Regex denylist` section above; the set is flagged as expandable — add new patterns in the table as credential formats are identified.
- **`--no-redact` interaction:** `### --no-redact behavior` section above.
- **Confirmation gate:** `## Confirmation-gate hook` section above; full UX specification in `SKILL.md` → Gate 3 — Confirm.
