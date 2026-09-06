#!/usr/bin/env bash
# PreToolUse guard: refuse hand-rolled ClickUp API calls.
#
# Reads the hook payload on stdin and emits a PreToolUse deny decision when a
# Bash command would send a request to api.clickup.com. Silent (no output,
# exit 0) otherwise, so an unrelated command is never slowed down.
#
# Why this exists: the standing rule is that ClickUp access goes through the
# clickup skill and that its transport must not be re-derived. Reading the
# skill's endpoints out of its file and then hand-writing curl satisfies the
# letter of knowing how, and loses what the skill carries alongside the
# endpoints -- notably that structured content belongs in the block-based
# `comment` array rather than plain `comment_text`. Bypassing it produced a
# comment whose paragraph breaks landed mid-sentence.
#
# Scoped to commands that genuinely make a request: the host name has to appear
# AND an HTTP client has to be invoked. A bare mention is left alone, so
# grepping for the host or reading these comments is not blocked. Blocking
# those would erode the guard for no safety gain.
#
# Always exits 0. A guard that errors out is worse than one that abstains.

set -u

command="$(jq -r '.tool_input.command // empty' 2>/dev/null)"
if [ -z "$command" ]; then
  exit 0
fi

# The host must be named. Lower-cased so a capitalised URL still matches.
lowered="${command,,}"
case "$lowered" in
  *api.clickup.com*) ;;
  *) exit 0 ;;
esac

# An HTTP client must actually be invoked, or this is only a mention.
clients='(^|[^[:alnum:]._-])(curl|wget|httpie|http|xh|invoke-webrequest|invoke-restmethod|iwr|irm)([^[:alnum:]._-]|$)'
if ! printf '%s' "$lowered" | grep -qE "$clients"; then
  exit 0
fi

reason="Direct requests to api.clickup.com are blocked. Invoke the clickup \
skill instead of hand-rolling the transport: it carries the decision rules \
alongside the endpoints, notably that structured content goes in the \
block-based \`comment\` array rather than plain \`comment_text\`. Reading the \
skill file and re-implementing its curl calls is the bypass this guard exists \
to stop, not a substitute for invoking it."

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'

exit 0
