# code-intel — JSON-fenced orchestrator brief

Agents include this file by pointer from `agents/code-intel.md` `## Brief Format`. Paths use `~/.claude/agents/_shared/code-intel-orchestrator-brief.md`.

## Orchestrator path semantics

The JSON brief is the **sole and authoritative orchestrator-path signal**. A JSON-fenced brief comes only from orchestrators; labeled-prose comes only from humans. Do not look for any `[context]` block, marker, or sentinel — that pattern was retracted to avoid colliding with the standard `## Context` Markdown heading in `/ops`'s agent-briefing format.

**Brief-level `## Constraints` exemption.** The JSON-fenced path is the sole orchestrator-path signal, and the schema below has `additionalProperties: false` with no `## Constraints` field — by design. Orchestrator-path dispatches do not ingest a brief-level `## Constraints` block; the schema's strict validation refuses it. The verification-gate ritual still applies to this agent via its read-only-agent status (see `~/.claude/skills/ops/verification-gate.md` § Read-only agents — verdicts as completion claims) — the agent's own deterministic output (`db_indexed_sha` + `generated_at` provenance, plus the `metadata` table re-read on every query) constitutes the fresh-evidence requirement. Labeled-prose briefs (the human dispatch path) do ingest `## Constraints` like any other agent.

## JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "code-intel brief",
  "type": "object",
  "additionalProperties": false,
  "required": ["query_type", "symbol"],
  "properties": {
    "query_type": {
      "type": "string",
      "enum": [
        "find_definition", "find_callers", "find_dependencies",
        "impact_analysis", "find_implementations", "execution_flow",
        "reindex", "clean"
      ]
    },
    "symbol":           { "type": "string", "minLength": 1 },
    "scope":            { "type": "string" },
    "depth":            { "type": "integer", "minimum": 1, "maximum": 5 },
    "output_mode":      { "type": "string", "enum": ["inline", "disk", "both"] },
    "max_results":      { "type": "integer", "minimum": 1, "maximum": 200 },
    "max_depth":        { "type": "integer", "minimum": 1, "maximum": 5 },
    "max_files":        { "type": "integer", "minimum": 1, "maximum": 7500 },
    "max_wall_clock_s": { "type": "integer", "minimum": 1, "maximum": 600 }
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

Unknown fields, missing required fields, and type mismatches are all refused — not silently clamped. A request to set `max_files: 10000` is refused at validation time (the schema's `maximum: 7500` is enforced strictly).
