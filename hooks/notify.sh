#!/bin/bash
# notify.sh
# Sends a desktop notification using the platform-appropriate tool.
# Called by the Notification hook in ~/.claude/settings.json.
# Works on macOS, Linux, and Windows (Git Bash / WSL).

DEFAULT_MSG="Claude Code needs your attention."

# The Notification hook is wired in settings.json with no positional
# argument, so the session's actual message arrives as JSON on stdin. Fall
# back to the default text on empty or unparseable input, but a positional
# $1 still wins if one is ever supplied by hand.
if [ -n "$1" ]; then
    MSG="$1"
else
    STDIN_PAYLOAD="$(cat 2>/dev/null)"
    MSG=""
    if [ -n "$STDIN_PAYLOAD" ] && command -v jq >/dev/null 2>&1; then
        MSG="$(printf '%s' "$STDIN_PAYLOAD" | jq -r '.message // empty' 2>/dev/null)"
    fi
    MSG="${MSG:-$DEFAULT_MSG}"
fi

TITLE="Claude Code"

OS="$(uname -s)"

case "$OS" in
    Darwin)
        osascript -e "display notification \"$MSG\" with title \"$TITLE\"" 2>/dev/null
        ;;
    Linux)
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "$TITLE" "$MSG" 2>/dev/null
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
        # Escape single quotes with a bash builtin, not sed: sed costs an
        # extra process spawn (measured ~260ms slower under Git Bash than
        # the substitution below) for work the shell can already do.
        MSG_ESCAPED="${MSG//\'/\'\'}"
        TITLE_ESCAPED="${TITLE//\'/\'\'}"

        # This uses the tray-balloon (NotifyIcon/ShowBalloonTip), not a
        # WinRT toast, because the balloon is the one path observed to
        # actually present on screen on this platform, including under Do
        # Not Disturb (silently, but visibly). A WinRT toast was tried here
        # and never appeared on screen; it only ever showed up filed in the
        # Notification Center, which does not meet the point of a hook that
        # is supposed to get the user's attention. Do not switch this back
        # to a toast without first confirming on-screen delivery, not just
        # that the call succeeded or that the notification was logged
        # somewhere.
        #
        # Start-Sleep -Milliseconds 500 keeps the process alive long enough
        # for the balloon to actually register with the shell; removing it
        # drops delivery to nothing. Do not remove it and do not shorten it.
        #
        # The whole invocation is still fired detached (trailing &) so this
        # script reaches exit 0 immediately: the hook's wall-clock cost to
        # the session is the time spent waiting for this script, not for
        # what it spawns, and that holds regardless of which notification
        # mechanism runs inside it.
        powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; \$n = New-Object System.Windows.Forms.NotifyIcon; \$n.Icon = [System.Drawing.SystemIcons]::Information; \$n.Visible = \$true; \$n.ShowBalloonTip(5000, '$TITLE_ESCAPED', '$MSG_ESCAPED', 'Info'); Start-Sleep -Milliseconds 500; \$n.Dispose()" 2>/dev/null &
        ;;
esac

exit 0
