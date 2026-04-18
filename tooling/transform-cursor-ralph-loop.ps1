<#
.SYNOPSIS
    Transform skills/ralph-loop/SKILL.md into the Cursor-compatible SKILL.cursor.md.

.DESCRIPTION
    Default behavior: drift-check. If the target SKILL.cursor.md already
    exists and matches what this transform would produce, print "in sync"
    and exit 0. If the target differs, print a drift summary and prompt
    for regeneration (when stdin is a tty) or exit 3 (when stdin is not a
    tty — CI-friendly).

    Both this script and the .sh wrapper invoke the same embedded Python
    logic (byte-identical body), so sh↔ps1 parity is guaranteed by
    construction. Output uses LF line endings.

.PARAMETER In
    Source SKILL.md. Default: skills/ralph-loop/SKILL.md

.PARAMETER Out
    Destination path, or "-" for stdout.
    Default: sibling SKILL.cursor.md of -In when -In ends in /SKILL.md;
    otherwise "-".

.PARAMETER Force
    Skip drift-check; always regenerate and write.

.PARAMETER WhatIf
    Preview only — print line count and SHA256 of what would be written.
    Takes precedence over -Force if both are set.

.EXAMPLE
    .\tooling\transform-cursor-ralph-loop.ps1
    Default: drift-check. Prompts for regeneration on drift, exits 3 on
    non-tty drift (CI-friendly).

.EXAMPLE
    .\tooling\transform-cursor-ralph-loop.ps1 -Force
    Force regenerate, no drift-check.

.EXAMPLE
    .\tooling\transform-cursor-ralph-loop.ps1 -WhatIf
    Preview SHA256 + line count.

.NOTES
    Exit codes:
      0  Success (in-sync, wrote, what-if preview, stdout)
      1  Input error (bad args, source not found)
      3  Drift detected; non-tty stdin (CI-friendly: no prompt shown)
      4  User declined regeneration at interactive prompt
#>

[CmdletBinding()]
param(
    [string]$In   = "skills/ralph-loop/SKILL.md",
    [string]$Out  = "",
    [switch]$Force,
    [switch]$WhatIf,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    exit 0
}

if (-not (Test-Path $In)) {
    Write-Error "Source file not found: $In"
    exit 1
}

# ---------------------------------------------------------------------------
# Derive default Out: sibling SKILL.cursor.md of In when In ends in
# /SKILL.md; otherwise default to stdout ("-").
# ---------------------------------------------------------------------------
if ([string]::IsNullOrEmpty($Out)) {
    $normIn = $In -replace '\\', '/'
    if ($normIn.EndsWith("/SKILL.md")) {
        $Out = $normIn.Substring(0, $normIn.Length - "/SKILL.md".Length) + "/SKILL.cursor.md"
    } else {
        $Out = "-"
    }
}

# ---------------------------------------------------------------------------
# Locate Python (validate each candidate actually runs; Windows Store stubs
# report as found but exit non-zero when invoked without the Store installed)
# ---------------------------------------------------------------------------
$python = $null
$candidates = @(
    "python3", "python",
    "C:\Python311\python.exe", "C:\Python312\python.exe", "C:\Python313\python.exe",
    "C:\Python310\python.exe", "C:\Python39\python.exe"
)
foreach ($candidate in $candidates) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
        try {
            & $candidate -c "import sys; assert sys.version_info >= (3,6)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $python = $candidate
                break
            }
        } catch {
            # skip
        }
    }
}
if (-not $python) {
    Write-Error "Python 3.6+ is required but not found."
    exit 1
}

# ---------------------------------------------------------------------------
# Embedded Python script — byte-identical to the body in transform-cursor-ralph-loop.sh.
# ---------------------------------------------------------------------------
$pyScript = @'
import sys
import hashlib
import os
import difflib

in_path   = sys.argv[1]
out_path  = sys.argv[2]
what_if   = sys.argv[3] == "true"
force     = sys.argv[4] == "true"

with open(in_path, "rb") as f:
    raw = f.read()

# Normalise to LF internally
text = raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n").decode("utf-8")

# ---------------------------------------------------------------------------
# Helper: replace first occurrence of old with new
# ---------------------------------------------------------------------------
def rep(old, new):
    global text
    idx = text.find(old)
    if idx < 0:
        first = old.split("\n")[0][:80]
        print(f"WARNING: PATCH NOT FOUND: {first}...", file=sys.stderr)
        return
    text = text[:idx] + new + text[idx + len(old):]

# ---------------------------------------------------------------------------
# PATCH 0 — Prepend YAML frontmatter
# ---------------------------------------------------------------------------
first_line = text.split("\n")[0]
rep(first_line, "---\nname: ralph-loop\ndescription: Run the Ralph Wiggum loop workflow.\n---\n" + first_line)

# ---------------------------------------------------------------------------
# PATCH 1 — /deslop slash-invocation adjusted for Cursor (no Skill tool)
# ---------------------------------------------------------------------------
rep(
    "- `--full-deslop` forces the full `/deslop` skill to run during every Cleanup stage iteration, regardless of escalation triggers. Use when you want comprehensive structural cleanup every iteration, not just when triggers fire.",
    "- `--full-deslop` forces the full deslop pass to run during every Cleanup stage iteration, regardless of escalation triggers. Use when you want comprehensive structural cleanup every iteration, not just when triggers fire. On Cursor: invoked via read-and-dispatch of `~/.cursor/skills/deslop/SKILL.md`.",
)

# ---------------------------------------------------------------------------
# PATCH 2 — Constraints bullet: "No compound Bash commands" → "No compound Shell commands"
# (both Bash occurrences in this bullet line)
# ---------------------------------------------------------------------------
rep(
    "- No compound Bash commands — never use `&&`, `;`, or `||` to chain commands. Make separate Bash tool calls instead — use parallel calls for independent commands.",
    "- No compound Shell commands — never use `&&`, `;`, or `||` to chain commands. Make separate Shell tool calls instead — use parallel calls for independent commands.",
)

# ---------------------------------------------------------------------------
# PATCH 3 — Constraints bullet: "use a separate Bash call for cd" → "use a separate Shell call for cd"
# ---------------------------------------------------------------------------
rep(
    "If a command genuinely requires a different working directory, use a separate Bash call for `cd` first.",
    "If a command genuinely requires a different working directory, use a separate Shell call for `cd` first.",
)

# ---------------------------------------------------------------------------
# PATCH 4 — Constraints bullet: "absolute paths in Bash commands" → "absolute paths in Shell commands"
# ---------------------------------------------------------------------------
rep(
    "never use absolute paths in Bash commands.",
    "never use absolute paths in Shell commands.",
)

# ---------------------------------------------------------------------------
# Global substitution: any remaining ~/.claude/ → ~/.cursor/
# ---------------------------------------------------------------------------
text = text.replace("~/.claude/", "~/.cursor/")

# ---------------------------------------------------------------------------
# Output / drift-check decision
# ---------------------------------------------------------------------------
result_bytes = text.encode("utf-8")
new_sha = hashlib.sha256(result_bytes).hexdigest()
new_lines = text.count("\n") + (1 if text and not text.endswith("\n") else 0)

if what_if:
    print(f"[WhatIf] Lines: {new_lines} | SHA256: {new_sha}")
    sys.exit(0)

if out_path == "-":
    sys.stdout.buffer.write(result_bytes)
    sys.exit(0)

target_exists = os.path.exists(out_path)

if force or not target_exists:
    with open(out_path, "wb") as f:
        f.write(result_bytes)
    print(f"Written: {out_path}")
    print(f"SHA256:  {new_sha}")
    print(f"Lines:   {new_lines}")
    sys.exit(0)

# drift-check path: target exists, not forced
with open(out_path, "rb") as f:
    existing_bytes = f.read()
existing_sha = hashlib.sha256(existing_bytes).hexdigest()
existing_lines = existing_bytes.decode("utf-8", errors="replace").count("\n") + (1 if existing_bytes and not existing_bytes.endswith(b"\n") else 0)

if existing_sha == new_sha:
    print(f"No drift — {out_path} is in sync.")
    sys.exit(0)

# drift detected
print(f"Drift detected: {out_path}", file=sys.stderr)
print(f"  Old SHA: {existing_sha} ({existing_lines} lines)", file=sys.stderr)
print(f"  New SHA: {new_sha} ({new_lines} lines)", file=sys.stderr)
existing_text = existing_bytes.decode("utf-8", errors="replace").splitlines(keepends=True)
new_text = text.splitlines(keepends=True)
diff_lines = list(difflib.unified_diff(existing_text, new_text, fromfile="existing", tofile="new", n=2))
if diff_lines:
    print("  First differences:", file=sys.stderr)
    for line in diff_lines[:20]:
        print(f"    {line.rstrip()}", file=sys.stderr)

sys.exit(3)
'@

# ---------------------------------------------------------------------------
# Invoke Python. Write the embedded script to a temp file as UTF-8 (no BOM)
# to avoid PowerShell stdin pipeline re-encoding corrupting non-ASCII bytes.
# ---------------------------------------------------------------------------
$whatIfArg = if ($WhatIf) { "true" } else { "false" }
$forceArg  = if ($Force)  { "true" } else { "false" }

$tmpPy = "_tmp_transform-cursor-ralph-loop.py"
$code = 1
try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tmpPy, $pyScript, $utf8NoBom)
    & $python $tmpPy $In $Out $whatIfArg $forceArg
    $code = $LASTEXITCODE

    # -----------------------------------------------------------------------
    # Wrapper drift-check prompt: on exit 3 with stdin tty, offer regeneration.
    # Non-tty stdin → propagate 3 (CI-friendly).
    # -----------------------------------------------------------------------
    if ($code -eq 3 -and -not $Force) {
        if (-not [Console]::IsInputRedirected) {
            $response = Read-Host -Prompt "Regenerate $Out? [y/N]"
            if ($response -match '^(y|Y|yes|Yes|YES)$') {
                & $python $tmpPy $In $Out $whatIfArg "true"
                $code = $LASTEXITCODE
            } else {
                [Console]::Error.WriteLine("Aborted — no changes written.")
                $code = 4
            }
        }
    }
} finally {
    if (Test-Path $tmpPy) { Remove-Item $tmpPy -Force }
}
exit $code
