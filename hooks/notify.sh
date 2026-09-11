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

        # Two mechanisms fire here, not one, because each covers what the
        # other lacks. The tray balloon (NotifyIcon/ShowBalloonTip) is what
        # the user actually sees and hears on screen, including under Do
        # Not Disturb, but its own record in the Notification Center
        # self-deletes within seconds. The WinRT toast (CreateToastNotifier)
        # never presents on screen on this platform, not even under Do Not
        # Disturb, but its record persists in the Notification Center long
        # after the balloon's has already expired. Neither alone is
        # sufficient: drop the balloon and the on-screen alert is gone,
        # drop the toast and the durable record is gone. The balloon fires
        # first because it is the one that gets the user's attention; if
        # the toast spawn below ever fails, the user has still been
        # notified.
        #
        # Start-Sleep -Milliseconds 500 keeps the balloon process alive
        # long enough for the balloon to actually register with the shell;
        # removing it drops delivery to nothing. Do not remove it and do
        # not shorten it. Confirm any change to either mechanism by
        # watching for on-screen delivery or by checking the Notification
        # Center directly, not by assuming a successful call means the
        # user was actually notified.
        #
        # Both invocations are fired detached (trailing &) so this script
        # reaches exit 0 immediately: the hook's wall-clock cost to the
        # session is the time spent waiting for this script, not for what
        # it spawns.
        powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; \$n = New-Object System.Windows.Forms.NotifyIcon; \$n.Icon = [System.Drawing.SystemIcons]::Information; \$n.Visible = \$true; \$n.ShowBalloonTip(5000, '$TITLE_ESCAPED', '$MSG_ESCAPED', 'Info'); Start-Sleep -Milliseconds 500; \$n.Dispose()" 2>/dev/null &

        # The WinRT type accelerator has to be loaded explicitly in every
        # invocation: referencing the type by its short name without it
        # throws "Unable to find type", because each powershell.exe process
        # starts with a clean WinRT projection.
        powershell.exe -NoProfile -Command "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); \$texts = \$template.GetElementsByTagName('text'); \$texts.Item(0).AppendChild(\$template.CreateTextNode('$TITLE_ESCAPED')) | Out-Null; \$texts.Item(1).AppendChild(\$template.CreateTextNode('$MSG_ESCAPED')) | Out-Null; \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$template); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe').Show(\$toast)" >/dev/null 2>&1 &
        ;;
esac

exit 0
