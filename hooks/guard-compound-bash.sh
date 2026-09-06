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
#
# Lines are split with pure parameter-expansion string manipulation instead of
# a `<<< "$text"` herestring loop. Bash backs `<<<` with a temp file on every
# platform, not just here; what is specific to this machine is that creating
# that file has been measured to intermittently cost seconds, most likely
# antivirus scanning it on write. That risk is real on every Bash call this
# hook runs before, though measurement traced this hook's actual dominant cost
# to the per-line `sed` forks replaced below, not to the herestring itself. Do
# not reintroduce a herestring here, and process substitution is not a
# fallback either: it measured roughly 19x slower than the herestring in this
# environment (about 16ms per iteration against about 0.8ms).
#
# Finding the opener itself used to be a plain regex match against the raw
# line, with no idea whether the `<<` it just matched was sitting inside a
# quoted string. That let a quoted or herestring `<<` (`echo "cat <<EOF"`,
# `grep foo <<<bar`) turn on heredoc-skipping for real, at which point every
# line after it got silently discarded until a line happened to match the
# fabricated delimiter - usually never, so the rest of the command vanished
# along with any genuine `&&`/`||`/`;` it contained. The fix is a
# character-by-character scan of the line that tracks single quotes, double
# quotes, backslash escapes, backticks and `$( )` depth - the exact same
# state find_operator() below tracks - and only treats `<<` as a real opener
# once that state says we're at the top level, not inside a string or a
# subshell. This can't just call find_operator() to get that state:
# find_operator() consumes THIS function's output, so calling it from in here
# would be circular. The state machine is duplicated on purpose, not shared.
#
# Backtick tracking is not optional, even though a bare `<<` never legally
# appears inside one: an odd number of quote characters inside a backtick
# span (`` echo `it's here` ``) has to be recognized as backtick content and
# left alone, or the apostrophe reads as an unbalanced quote and every `<<`
# for the rest of the command is wrongly treated as still being inside a
# string - which refuses to open a heredoc that is actually there, and the
# body text after it gets scanned as live command text instead. Quote state
# also has to persist across lines, not reset at each newline, because a
# quoted string (or a `$( )`) can legitimately span more than one line.
strip_heredoc_bodies() {
  local text="$1"
  local out="" line delim="" skipping=0 trimmed
  local remaining="$text"
  local single=0 double=0 backtick=0 depth=0
  local pos len char pair opener_delim scan qchar word wchar prev_char

  while [ -n "$remaining" ]; do
    if [[ "$remaining" == *$'\n'* ]]; then
      line="${remaining%%$'\n'*}"
      remaining="${remaining#*$'\n'}"
    else
      line="$remaining"
      remaining=""
    fi

    if [ "$skipping" -eq 1 ]; then
      trimmed="${line#"${line%%[![:space:]]*}"}"
      trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
      if [ "$trimmed" = "$delim" ]; then
        skipping=0
      fi
      continue
    fi

    out="$out$line"$'\n'

    opener_delim=""
    len=${#line}
    pos=0
    while [ "$pos" -lt "$len" ]; do
      char="${line:pos:1}"
      pair="${line:pos:2}"

      if [ "$char" = "\\" ] && [ "$single" -eq 0 ]; then
        pos=$((pos + 2))
        continue
      fi
      if [ "$char" = "'" ] && [ "$double" -eq 0 ] && [ "$backtick" -eq 0 ]; then
        single=$((1 - single))
        pos=$((pos + 1))
        continue
      fi
      if [ "$char" = '"' ] && [ "$single" -eq 0 ] && [ "$backtick" -eq 0 ]; then
        double=$((1 - double))
        pos=$((pos + 1))
        continue
      fi
      if [ "$single" -eq 1 ] || [ "$double" -eq 1 ]; then
        pos=$((pos + 1))
        continue
      fi
      if [ "$char" = '`' ]; then
        backtick=$((1 - backtick))
        pos=$((pos + 1))
        continue
      fi
      if [ "$backtick" -eq 1 ]; then
        pos=$((pos + 1))
        continue
      fi
      if [ "$pair" = '$(' ]; then
        depth=$((depth + 1))
        pos=$((pos + 2))
        continue
      fi
      if [ "$char" = ')' ] && [ "$depth" -gt 0 ]; then
        depth=$((depth - 1))
        pos=$((pos + 1))
        continue
      fi
      if [ "$depth" -gt 0 ]; then
        pos=$((pos + 1))
        continue
      fi

      if [ "$char" = '#' ]; then
        # A `#` starts a comment only when it begins a word: at the start of
        # the line, or right after whitespace or one of ; & | ( ). A `#` in
        # the middle of a word (http://x/#frag, echo a#b) is not a comment.
        # Once a real comment starts it runs to the end of this physical
        # line, so the rest of the line - including any `<<` - must never be
        # examined; a commented-out heredoc opener must not start skipping.
        if [ "$pos" -eq 0 ]; then
          prev_char=""
        else
          prev_char="${line:$((pos - 1)):1}"
        fi
        case "$prev_char" in
          "" | " " | $'\t' | ";" | "&" | "|" | "(" | ")")
            break
            ;;
        esac
      fi

      if [ "$pair" = '<<' ]; then
        # Parse the delimiter positionally from the characters right after
        # "<<" instead of matching a regex against the whole line. This
        # closes the herestring bypass for free: "<<<bar" leaves "<bar"
        # here, "<" cannot start a delimiter, so no opener is recorded and
        # the line is left alone.
        scan=$((pos + 2))
        if [ "${line:scan:1}" = '-' ]; then
          scan=$((scan + 1))
        fi
        while [ "${line:scan:1}" = ' ' ] || [ "${line:scan:1}" = $'\t' ]; do
          scan=$((scan + 1))
        done
        qchar="${line:scan:1}"
        if [ "$qchar" = "'" ] || [ "$qchar" = '"' ]; then
          scan=$((scan + 1))
        fi
        word=""
        while :; do
          wchar="${line:scan:1}"
          if [[ "$wchar" == [A-Za-z0-9_] ]]; then
            word="$word$wchar"
            scan=$((scan + 1))
          else
            break
          fi
        done
        if [ -n "$word" ] && [[ "${word:0:1}" == [A-Za-z_] ]]; then
          # Last opener on the line wins: assign on every match instead of
          # stopping at the first, so a line that opens two heredocs at
          # once (`cmd <<A <<B`) keeps skipping through both bodies back to
          # back, the same way bash reads them.
          opener_delim="$word"
        fi
        pos=$((pos + 2))
        continue
      fi

      pos=$((pos + 1))
    done

    if [ -n "$opener_delim" ]; then
      delim="$opener_delim"
      skipping=1
    fi
  done

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
  local char pair prev_char rest before_nl

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

    if [ "$char" = '#' ]; then
      # Same word-boundary rule as strip_heredoc_bodies(): a `#` only opens a
      # comment when it starts a word. Both scanners have to agree on this or
      # one of them ends up scanning text the other one is hiding, which is
      # exactly the kind of mismatch that manufactures a false denial.
      if [ "$index" -eq 0 ]; then
        prev_char=""
      else
        prev_char="${text:$((index - 1)):1}"
      fi
      case "$prev_char" in
        "" | " " | $'\t' | $'\n' | ";" | "&" | "|" | "(" | ")")
          # A real comment runs to the end of the physical line, and an
          # operator sitting inside a comment is not a chained command, so
          # jump straight past it instead of scanning it character by
          # character.
          rest="${text:index}"
          before_nl="${rest%%$'\n'*}"
          index=$((index + ${#before_nl}))
          continue
          ;;
      esac
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

command="$(jq -r '.tool_input.command // empty' 2>/dev/null)"
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
