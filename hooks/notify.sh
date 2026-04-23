#!/bin/bash
# notify.sh
# Sends a desktop notification using the platform-appropriate tool.
# Called by the Notification hook in ~/.claude/settings.json.
# Works on macOS, Linux, and Windows (Git Bash / WSL).

MSG="${1:-Claude Code needs your attention.}"
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
        powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; \$n = New-Object System.Windows.Forms.NotifyIcon; \$n.Icon = [System.Drawing.SystemIcons]::Information; \$n.Visible = \$true; \$n.ShowBalloonTip(5000, '$TITLE', '$MSG', 'Info'); Start-Sleep -Milliseconds 500; \$n.Dispose()" 2>/dev/null
        ;;
esac

exit 0
