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

        # A single WinRT toast, fired under the tray balloon's own
        # generated notifier identity, does the job that used to take a
        # tray balloon and a separate toast. That identity,
        # NotifyIconGeneratedAumid_3595418665412157742, is registered in
        # HKCU:\SOFTWARE\Classes\AppUserModelId with a DisplayName, and
        # only identities with a DisplayName can be added to the Do Not
        # Disturb priority list, so a toast fired under it presents on
        # screen even with Do Not Disturb on. The identity this toast used
        # to borrow, {1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe,
        # carries no such registration and gets silently suppressed. A
        # toast built by hand also carries no bannerOnly attribute, so its
        # Notification Center record persists instead of self-deleting the
        # way a native tray balloon's record does.
        #
        # NotifyIconGeneratedAumid_3595418665412157742 is a value the shell
        # generates for this machine's user profile, not a fixed constant.
        # If notifications ever stop presenting, that identity is the first
        # thing to check, and the way to check it is to fire a tray balloon
        # and read which NotifyIconGeneratedAumid_* it lands under in
        # %LOCALAPPDATA%\Microsoft\Windows\Notifications\wpndatabase.db,
        # not to assume this value still holds.
        #
        # Confirm any change to this mechanism by watching for the banner
        # on screen and listening for the sound, not by querying the
        # notification store alone: a row there proves Windows filed a
        # notification, never that the user actually saw or heard one.
        #
        # This invocation is fired detached (trailing &) so this script
        # reaches exit 0 immediately: the hook's wall-clock cost to the
        # session is the time spent waiting for this script, not for what
        # it spawns.
        #
        # The WinRT type accelerator has to be loaded explicitly in every
        # invocation: referencing the type by its short name without it
        # throws "Unable to find type", because each powershell.exe process
        # starts with a clean WinRT projection.
        powershell.exe -NoProfile -Command "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); \$texts = \$template.GetElementsByTagName('text'); \$texts.Item(0).AppendChild(\$template.CreateTextNode('$TITLE_ESCAPED')) | Out-Null; \$texts.Item(1).AppendChild(\$template.CreateTextNode('$MSG_ESCAPED')) | Out-Null; \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$template); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('NotifyIconGeneratedAumid_3595418665412157742').Show(\$toast)" >/dev/null 2>&1 &
        ;;
esac

exit 0
