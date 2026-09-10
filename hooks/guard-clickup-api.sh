#!/usr/bin/env bash
# PreToolUse guard: refuse hand-rolled ClickUp API calls.
#
# Reads the hook payload on stdin and emits a PreToolUse deny decision when a
# Bash command would send a request to api.clickup.com. Silent (no output,
# exit 0) otherwise, so an unrelated command is never slowed down.
#
# Why this exists: the standing rule is that ClickUp access goes through the
# clickup skill and that its transport must not be re-derived. A hand-written
# request loses what the skill carries alongside the endpoints -- notably that
# structured content belongs in the block-based `comment` array rather than
# plain `comment_text`. A hand-written write that used `comment_text` shipped a
# comment whose paragraph breaks landed mid-sentence; that incident is a write
# defect, and the guard's job is to stop requests that could reproduce it.
#
# Scoped to commands that genuinely make a request: the host name has to appear
# AND an HTTP client has to be invoked. A bare mention is left alone, so
# grepping for the host or reading these comments is not blocked. Blocking
# those would erode the guard for no safety gain.
#
# A command shaped exactly like a read is let through: see
# is_get_shaped_curl below for what "shaped like a read" means and why the
# exemption only fires for curl. Everything else that names the host and
# invokes a client, including a curl invocation this guard can't positively
# clear, still denies.
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

# is_get_shaped_curl <text>
#
# True only for a curl invocation that cannot be carrying a body and cannot
# be naming a mutating method -- the shape of the read that this guard used
# to block outright. Every other recognized client (wget, the PowerShell web
# cmdlets, httpie, xh) still falls through to the deny below even when the
# command looks like a plain GET, because none of them can be classified this
# way from the command text alone:
#   - wget resolves its long options with GNU getopt, which accepts any
#     unambiguous abbreviation of a flag name, so a write flag typed as a
#     shortened prefix would not match a literal string check here.
#   - PowerShell binds parameter names the same way -- `-Met` can resolve to
#     `-Method` -- for the same reason.
#   - httpie and xh signal a write with a bare positional word (`http POST
#     url`) or with unflagged `field=value` arguments, not with a flag this
#     guard can grep for.
# curl has neither hazard: it requires the exact spelling of a long option and
# does not support abbreviation, so its flag surface can be checked directly.
#
# Takes the case-preserved, heredoc-stripped command (not the lower-cased
# copy used for the host/client checks above). curl gives capital and
# lowercase forms of the same letter unrelated meanings -- -F/--form (a body)
# versus -f/--fail (unrelated), -T/--upload-file (a body) versus
# -t/--telnet-option (unrelated), -X/--request (a method) versus -x/--proxy
# (unrelated) -- so lower-casing first would blur exactly the distinction
# this check depends on.
is_get_shaped_curl() {
  local cmd="$1"
  local cmd_lower="${cmd,,}"

  local curl_re='(^|[^[:alnum:]._-])curl([^[:alnum:]_-]|$)'
  if ! printf '%s' "$cmd_lower" | grep -qE "$curl_re"; then
    return 1
  fi

  # Only curl is being classified here. If another recognized client also
  # appears in the same command, the flag surface below would need to be
  # attributed to the right binary, which this guard does not attempt.
  local other_clients_re='(^|[^[:alnum:]._-])(wget|httpie|http|xh|invoke-webrequest|invoke-restmethod|iwr|irm)([^[:alnum:]_-]|$)'
  if printf '%s' "$cmd_lower" | grep -qE "$other_clients_re"; then
    return 1
  fi

  # A flag that attaches a request body rules out a read. -F, -T and -d are
  # matched with an optional run of other bundled short flags in front (curl
  # allows "-sFkey=value", "-skTfile", "-sd@file"), since only the last flag
  # in a bundle may carry a value. That value may be glued directly to the
  # flag letter with no separator at all -- "-dfoo=bar", "-Fkey=value" and
  # "-Tfile.txt" are all valid curl invocations -- so nothing is required to
  # follow the matched flag letter. An earlier version of this pattern did
  # require a boundary character there, which meant a glued value was only
  # caught when it happened to start with a non-alphanumeric character (as
  # "-sd@file" does); a value starting with a letter, like the three examples
  # just given, was misclassified as a read. Requiring no trailing context
  # trades a theoretical false positive (denying a read whose text merely
  # resembles "-F" or "-T" or "-d" followed by letters) for closing that
  # false negative, which is the direction this guard is meant to fail in.
  local body_flags_re='(^|[^[:alnum:]._-])-[A-Za-z]*[FTd]'
  body_flags_re="$body_flags_re"'|(^|[^[:alnum:]._-])--(data|data-ascii|data-binary|data-raw|data-urlencode|form|form-string|upload-file|json)([^[:alnum:]_-]|$)'
  if printf '%s' "$cmd" | grep -qE "$body_flags_re"; then
    return 1
  fi

  # A method flag naming a mutating verb also rules out a read. -X is matched
  # the same bundled way as the body flags above ("-sXPOST", "-skXPUT"); the
  # verb itself is matched in either case since curl passes it through
  # unmodified and a caller could type it either way.
  local verbs='(POST|PUT|PATCH|DELETE|post|put|patch|delete)'
  local method_re="(^|[^[:alnum:]._-])-[A-Za-z]*X[[:space:]=]*[\"']?${verbs}([^[:alnum:]_-]|\$)"
  method_re="$method_re"'|(^|[^[:alnum:]._-])--request[[:space:]=]*["'"'"']?'"${verbs}"'([^[:alnum:]_-]|$)'
  if printf '%s' "$cmd" | grep -qE "$method_re"; then
    return 1
  fi

  return 0
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

# A curl invocation that is positively shaped like a read is not what this
# guard exists to stop.
if is_get_shaped_curl "$scanned"; then
  exit 0
fi

reason="This request to api.clickup.com is blocked; use the clickup skill for \
it instead. The skill puts structured content in the block-based \`comment\` \
array rather than plain \`comment_text\`, which is the rule a request built \
outside it is prone to miss. A plain curl read -- no -d/--data/-F/--form/-T/\
--upload-file/--json and no -X/--request naming POST, PUT, PATCH or DELETE -- \
passes without going through this deny; every other shape, and every other \
HTTP client, still routes through the skill."

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'

exit 0
