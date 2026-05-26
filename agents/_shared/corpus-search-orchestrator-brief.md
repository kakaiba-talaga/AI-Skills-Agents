# corpus-search — JSON-fenced orchestrator brief

Agents include this file by pointer from `agents/corpus-search.md` `## Brief Format`. Paths use `~/.claude/agents/_shared/corpus-search-orchestrator-brief.md`.

## Orchestrator path semantics

The JSON brief is the **sole and authoritative orchestrator-path signal**. A JSON-fenced brief comes only from orchestrators; labeled-prose comes only from humans. Do not look for any `[context]` block, marker, or sentinel — that pattern was retracted to avoid colliding with the standard `## Context` Markdown heading in `/ops`'s agent-briefing format.

**Brief-level `## Constraints` exemption.** The JSON-fenced path is the sole orchestrator-path signal, and the schema below has `additionalProperties: false` with no `## Constraints` field — by design. Orchestrator-path dispatches do not ingest a brief-level `## Constraints` block; the schema's strict validation refuses it. The verification-gate ritual still applies to this agent via its read-only-agent status (see `~/.claude/skills/ops/verification-gate.md` § Read-only agents — verdicts as completion claims) — the agent's own deterministic output (`corpus_indexed_sha` + `generated_at` provenance, plus fresh `rg`/`Read` evidence gathered in the current dispatch) constitutes the fresh-evidence requirement. Labeled-prose briefs (the human dispatch path) do ingest `## Constraints` like any other agent.

## JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "corpus-search brief",
  "type": "object",
  "additionalProperties": false,
  "required": ["query_type", "query"],
  "properties": {
    "query_type": {
      "type": "string",
      "enum": [
        "evidence_search",
        "locate",
        "verify_claim",
        "trace_reference"
      ]
    },
    "query": {
      "type": "string",
      "minLength": 1,
      "description": "Primary investigative string: question (evidence_search), file/content clue (locate), exact string or regex (verify_claim), term to follow (trace_reference)."
    },
    "scope": {
      "type": "string",
      "description": "Optional repo-relative glob, e.g. 'skills/ops/**'. Default: project-wide."
    },
    "patterns": {
      "type": "array",
      "items": { "type": "string", "minLength": 1 },
      "maxItems": 10,
      "description": "Additional grep/rg patterns for evidence_search and trace_reference hops."
    },
    "max_hops": {
      "type": "integer",
      "minimum": 1,
      "maximum": 5,
      "description": "Multi-hop depth for evidence_search and trace_reference. Default: 3."
    },
    "max_results": {
      "type": "integer",
      "minimum": 1,
      "maximum": 200
    },
    "max_files": {
      "type": "integer",
      "minimum": 1,
      "maximum": 5000
    },
    "max_wall_clock_s": {
      "type": "integer",
      "minimum": 1,
      "maximum": 600
    },
    "max_snippet_lines": {
      "type": "integer",
      "minimum": 1,
      "maximum": 20,
      "description": "Lines of context per evidence entry. Default: 3."
    },
    "case_sensitive": {
      "type": "boolean",
      "description": "Default: false for evidence_search/locate; true for verify_claim unless query is flagged /.../ regex."
    },
    "output_mode": {
      "type": "string",
      "enum": ["inline", "disk", "both"]
    },
    "claim_mode": {
      "type": "string",
      "enum": ["exists", "absent", "count_at_least"],
      "description": "verify_claim only. Default: exists."
    },
    "claim_threshold": {
      "type": "integer",
      "minimum": 0,
      "description": "verify_claim with claim_mode count_at_least."
    }
  }
}
```

## Validation

```python
brief = parse_json_fenced_block(input)
if brief is None:
    refuse_with_usage_card("malformed: no JSON-fenced block found")
violations = validate_against_schema(brief, BRIEF_SCHEMA)
if violations:
    refuse_with_usage_card(f"malformed: {violations}")
# proceed
```

Unknown fields, missing required fields, and out-of-range numerics are **refused** — not silently clamped. A request to set `max_files: 10000` is refused at validation time (the schema's `maximum: 5000` is enforced strictly).
