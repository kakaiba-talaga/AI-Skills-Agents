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

        # Stay on Windows PowerShell (powershell.exe), not pwsh: the WinRT
        # toast API this branch depends on is unavailable under PowerShell 7
        # (pwsh exits 1 with "Unable to find type
        # [Windows.UI.Notifications.ToastNotificationManager]"), and
        # powershell.exe is also the faster host to start on this platform.
        # The WinRT type accelerator below has to be loaded explicitly in
        # every invocation: referencing the type by its short name without
        # it first also throws "Unable to find type", because each
        # powershell.exe process starts with a clean WinRT projection.
        #
        # Build the toast body with CreateTextNode rather than LoadXml on a
        # hand-built XML string: escaped double quotes inside -Command do
        # not survive PowerShell argument parsing and LoadXml fails with
        # "Missing ')' in method call". CreateTextNode only needs single
        # quotes, which pass through -Command cleanly, and it escapes XML
        # metacharacters in the message for free.
        #
        # Fire the whole invocation detached (trailing &) and exit
        # immediately: a hook's wall-clock cost to the session is the time
        # spent waiting for this script, not for whatever it spawns. There
        # is no Start-Sleep in this branch and none should be added back:
        # that sleep belonged to the old NotifyIcon/Dispose() balloon path,
        # which this branch no longer uses, and its absence does not affect
        # delivery here.
        powershell.exe -NoProfile -Command "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); \$texts = \$template.GetElementsByTagName('text'); \$texts.Item(0).AppendChild(\$template.CreateTextNode('$TITLE_ESCAPED')) | Out-Null; \$texts.Item(1).AppendChild(\$template.CreateTextNode('$MSG_ESCAPED')) | Out-Null; \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$template); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe').Show(\$toast)" >/dev/null 2>&1 &
        ;;
esac

exit 0
