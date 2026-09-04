#!/usr/bin/env bash
# PreToolUse guard: refuse compound Bash commands.
#
# Reads the hook payload on stdin and emits a PreToolUse deny decision when the
# command chains separate commands with `&&`, `||` or `;`. Silent (no output,
# exit 0) otherwise.
#
# Why a scanner rather than a substring match: the rule this enforces is about
# chaining SEPARATE COMMANDS, and all three operators appear legitimately
# inside quoted programs. `sed 's/a/b/;s/c/d/'`, a jq filter, an awk body and
# `python -c "import x; y"` are each a single command, and a guard that refused
# them would be switched off within the hour. So quotes, $( ) substitution,
# backticks and heredoc bodies are all skipped, and only a top-level operator
# is reported.
#
# Deliberately NOT blocked: a single `|` pipe and a trailing `&` are not
# command chaining and are left alone.
#
# Always exits 0. A guard that errors out is worse than one that abstains.

set -u

# strip_heredoc_bodies <text>
#
# Drops heredoc bodies so an operator inside one is not read as chaining. The
# line that opens the heredoc is kept, so the rest of that line is still
# scanned.
strip_heredoc_bodies() {
  local text="$1"
  local out="" line delim="" skipping=0 trimmed

  while IFS= read -r line; do
    if [ "$skipping" -eq 1 ]; then
      trimmed="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      if [ "$trimmed" = "$delim" ]; then
        skipping=0
      fi
      continue
    fi

    out="$out$line"$'\n'

    delim="$(printf '%s' "$line" | sed -n \
      "s/.*<<-\{0,1\}[[:space:]]*['\"]\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\)['\"]\{0,1\}.*/\1/p")"
    if [ -n "$delim" ]; then
      skipping=1
    fi
  done <<< "$text"

  printf '%s' "$out"
}

# find_operator <text>
#
# Prints the first command-chaining operator found at the top level, or nothing
# when the command chains nothing. Walks the text tracking quote state, $( )
# nesting depth and backticks, so an operator belonging to a quoted program or
# a subshell is not mistaken for a chain of separate commands.
find_operator() {
  local text
  text="$(strip_heredoc_bodies "$1")"

  local length=${#text}
  local index=0
  local single=0 double=0 backtick=0 depth=0
  local char pair

  while [ "$index" -lt "$length" ]; do
    char="${text:index:1}"
    pair="${text:index:2}"

    if [ "$char" = "\\" ] && [ "$single" -eq 0 ]; then
      index=$((index + 2))
      continue
    fi
    if [ "$char" = "'" ] && [ "$double" -eq 0 ] && [ "$backtick" -eq 0 ]; then
      single=$((1 - single))
      index=$((index + 1))
      continue
    fi
    if [ "$char" = '"' ] && [ "$single" -eq 0 ] && [ "$backtick" -eq 0 ]; then
      double=$((1 - double))
      index=$((index + 1))
      continue
    fi
    if [ "$single" -eq 1 ] || [ "$double" -eq 1 ]; then
      index=$((index + 1))
      continue
    fi
    if [ "$char" = '`' ]; then
      backtick=$((1 - backtick))
      index=$((index + 1))
      continue
    fi
    if [ "$backtick" -eq 1 ]; then
      index=$((index + 1))
      continue
    fi
    if [ "$pair" = '$(' ]; then
      depth=$((depth + 1))
      index=$((index + 2))
      continue
    fi
    if [ "$char" = ')' ] && [ "$depth" -gt 0 ]; then
      depth=$((depth - 1))
      index=$((index + 1))
      continue
    fi
    if [ "$depth" -gt 0 ]; then
      index=$((index + 1))
      continue
    fi
    if [ "$pair" = '&&' ]; then
      printf '%s' '&&'
      return 0
    fi
    if [ "$pair" = '||' ]; then
      printf '%s' '||'
      return 0
    fi
    if [ "$char" = ';' ]; then
      printf '%s' ';'
      return 0
    fi

    index=$((index + 1))
  done
}

payload="$(cat)"

command="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)"
if [ -z "$command" ]; then
  exit 0
fi

operator="$(find_operator "$command")"
if [ -z "$operator" ]; then
  exit 0
fi

reason="Compound Bash command blocked: found \`$operator\` at the top level. \
Make separate Bash tool calls instead, and put independent commands in one \
message as parallel tool calls. Operators inside quotes, \$( ), backticks or \
a heredoc body are allowed and did not trigger this."

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'

exit 0
