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

# strip_inert_heredoc_bodies <text>
#
# Drops the body of a heredoc whose opener line hands it to `cat` or `tee` --
# both write the body out unread, so its content is data, never a command.
# That is NOT true of a heredoc handed to an interpreter: `bash <<'EOF'` and
# `ssh host <<'EOF'` both execute their body, so a request hidden inside one
# is real and has to stay visible to the scan below. Gating the skip on the
# opener line's first word, instead of stripping every heredoc the way the
# compound-bash guard does, is what preserves that distinction -- this guard
# only wants to ignore data, and `cat`/`tee` bodies are the only ones
# guaranteed to be that.
#
# This is deliberately not shared with the compound-bash guard's own
# strip_heredoc_bodies(). The two need different rules -- that guard skips
# anything bash treats as a heredoc body, this one skips only bodies that are
# inert data -- so the bodies diverge immediately. Sourcing a separate file
# for either would also trade a guard that fails closed for one that fails
# open: if the source target is ever missing, bash warns and continues, the
# function call resolves to nothing, and a command that should have been
# denied is allowed silently. Staying self-contained keeps this guard's only
# failure mode "abstain", never "silently allow".
#
# Lines are split with parameter-expansion string manipulation rather than a
# `<<<` herestring loop, for the same reason the compound guard avoids it:
# the temp file backing `<<<` has been measured to occasionally cost seconds
# on this machine.
strip_inert_heredoc_bodies() {
  local text="$1"
  local out="" line delim="" skipping=0
  local left first_word term
  local remaining="$text"
  local hd_re=".*<<-?[[:space:]]*[\"']?([A-Za-z_][A-Za-z0-9_]*)"

  while [ -n "$remaining" ]; do
    if [[ "$remaining" == *$'\n'* ]]; then
      line="${remaining%%$'\n'*}"
      remaining="${remaining#*$'\n'}"
    else
      line="$remaining"
      remaining=""
    fi

    if [ "$skipping" -eq 1 ]; then
      left="${line#"${line%%[![:space:]]*}"}"
      term="${left%"${left##*[![:space:]]}"}"
      if [ "$term" = "$delim" ]; then
        skipping=0
      fi
      continue
    fi

    out="$out$line"$'\n'

    delim=""
    if [[ "$line" =~ $hd_re ]]; then
      left="${line#"${line%%[![:space:]]*}"}"
      first_word="${left%%[[:space:]]*}"
      case "${first_word,,}" in
        cat|tee)
          delim="${BASH_REMATCH[1]}"
          ;;
      esac
    fi
    if [ -n "$delim" ]; then
      skipping=1
    fi
  done

  printf '%s' "$out"
}

command="$(jq -r '.tool_input.command // empty' 2>/dev/null)"
if [ -z "$command" ]; then
  exit 0
fi

# Only pay for the line-by-line scan when a heredoc is actually present; the
# common case has no "<<" at all and skips straight to the checks below.
scanned="$command"
case "$command" in
  *'<<'*) scanned="$(strip_inert_heredoc_bodies "$command")" ;;
esac

# The host must be named. Lower-cased so a capitalised URL still matches.
lowered="${scanned,,}"
case "$lowered" in
  *api.clickup.com*) ;;
  *) exit 0 ;;
esac

# An HTTP client must actually be invoked, or this is only a mention. The
# trailing boundary excludes further identifier characters (letters, digits,
# `_`, `-`) so "curling" is not read as "curl", but treats `.` as a valid
# boundary rather than an excluded one: `curl.exe` and `wget.exe` are real
# invocations of the Windows-native binaries, not a longer identifier that
# merely starts with a client name.
clients='(^|[^[:alnum:]._-])(curl|wget|httpie|http|xh|invoke-webrequest|invoke-restmethod|iwr|irm)([^[:alnum:]_-]|$)'
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
