<#
.SYNOPSIS
    Deploy AI agents, skills, hooks, and settings to Claude Code and/or Cursor global directories.

.DESCRIPTION
    Reads tooling/deploy-manifest.json and syncs repo files to the target tool's
    global directories. For Cursor targets, applies automatic transforms:
    - Strips model/tools from agent frontmatter
    - Derives name+description frontmatter for skills
    - Remaps tool names (Bash→Shell, Edit→StrReplace, Agent→Task)
    - Replaces ~/.claude/ paths with ~/.cursor/

.PARAMETER Target
    Which tool to deploy to: all, claude, or cursor. Default: all.

.PARAMETER Category
    Deploy only one category: agents, skills, hooks, or settings. Default: all.

.PARAMETER DryRun
    Show what would change without copying any files.

.PARAMETER Diff
    Show diffs between repo and currently deployed files.

.PARAMETER Force
    Skip the confirmation prompt.

.PARAMETER Prune
    After the upsert pass, enumerate orphan files at each target and delete them
    after confirmation. Orphans are files present at the target that are not in
    the manifest's expected set for that (target, category) tuple.

.PARAMETER PruneOnly
    Skip the upsert pass entirely; perform the prune pass only. Implies -Prune.

.EXAMPLE
    .\deploy.ps1 -Target claude
    .\deploy.ps1 -Target cursor -DryRun
    .\deploy.ps1 -Target all -Category skills -Force
    .\deploy.ps1 -Diff
    .\deploy.ps1 -Prune -DryRun
    .\deploy.ps1 -PruneOnly -Force
    .\deploy.ps1 -PruneOnly -Target cursor -Category skills -DryRun
#>

[CmdletBinding()]
param(
    [ValidateSet("all", "claude", "cursor", "wsl")]
    [string]$Target = "all",

    [ValidateSet("agents", "skills", "hooks", "settings", "")]
    [string]$Category = "",

    [switch]$DryRun,
    [switch]$Diff,
    [switch]$Force,
    [switch]$Prune,
    [switch]$PruneOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $PSScriptRoot "deploy-manifest.json"

if (-not (Test-Path $ManifestPath)) {
    Write-Error "Manifest not found at $ManifestPath"
    return
}

$Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

# --- Transform functions ---

$ToolNameMap = @{
    'Bash'  = 'Shell'
    'Edit'  = 'StrReplace'
    'Agent' = 'Task'
}

function Resolve-TargetPath {
    param([string]$Path)
    $Path -replace '~', $HOME
}

function ConvertFrom-Frontmatter {
    param([string]$Content)
    if ($Content -match '(?s)^---\r?\n(.+?)\r?\n---\r?\n?(.*)$') {
        $fmBlock = $Matches[1]
        $body = $Matches[2]
        $fm = @{}
        foreach ($line in ($fmBlock -split '\r?\n')) {
            if ($line -match '^\s*(\w[\w-]*):\s*(.*)$') {
                $key = $Matches[1]
                $val = $Matches[2].Trim()
                if ($key -eq 'tools') {
                    $fm[$key] = @()
                } elseif ($val -ne '') {
                    $fm[$key] = $val
                }
            } elseif ($line -match '^\s*-\s+(.+)$' -and $fm.ContainsKey('tools')) {
                $fm['tools'] += $Matches[1].Trim()
            }
        }
        return @{ Frontmatter = $fm; Body = $body; HasFrontmatter = $true }
    }
    return @{ Frontmatter = @{}; Body = $Content; HasFrontmatter = $false }
}

function Build-Frontmatter {
    param([hashtable]$Fields)
    $lines = @("---")
    if ($Fields.ContainsKey('name'))        { $lines += "name: $($Fields['name'])" }
    if ($Fields.ContainsKey('description')) { $lines += "description: $($Fields['description'])" }
    $lines += "---"
    return ($lines -join "`n")
}

function Update-ToolNames {
    param([string]$Text)
    foreach ($entry in $ToolNameMap.GetEnumerator()) {
        $from = $entry.Key
        $to = $entry.Value
        $backtickFrom = '`' + $from + '`'
        $backtickTo = '`' + $to + '`'
        $Text = $Text -replace [regex]::Escape($backtickFrom), $backtickTo
        $Text = [regex]::Replace($Text, '(?<=\W|^)' + $from + '(?=\W|$)', $to)
    }
    return $Text
}

function Update-Paths {
    param([string]$Text)
    $Text = $Text -replace '~/\.claude/', '~/.cursor/'
    return $Text
}

function Get-ToolConstraints {
    param([string[]]$AllowedTools)
    $fullSet = @{
        'Read'      = 'Read (file reading)'
        'Glob'      = 'Glob (file search)'
        'Grep'      = 'Grep (content search)'
        'Bash'      = 'Shell (command execution)'
        'Edit'      = 'StrReplace (file editing)'
        'Write'     = 'Write (file creation)'
        'WebSearch' = 'WebSearch (web search)'
        'WebFetch'  = 'WebFetch (URL fetching)'
    }
    $excluded = @()
    foreach ($tool in $fullSet.Keys) {
        if ($tool -notin $AllowedTools) {
            $excluded += "- $($fullSet[$tool])"
        }
    }
    if ($excluded.Count -eq 0) { return "" }
    $lines = @(
        "",
        "## Tool Constraints",
        "",
        "The following tools are NOT available to this agent. Do not use them:",
        ""
    )
    $lines += ($excluded | Sort-Object)
    return ($lines -join "`n")
}

function ConvertTo-AgentFile {
    param([string]$Content)
    $parsed = ConvertFrom-Frontmatter $Content
    $fm = $parsed.Frontmatter
    $body = $parsed.Body

    $newFm = @{}
    if ($fm.ContainsKey('name'))        { $newFm['name'] = $fm['name'] }
    if ($fm.ContainsKey('description')) { $newFm['description'] = $fm['description'] }

    $body = Update-ToolNames $body
    $body = Update-Paths $body

    if ($fm.ContainsKey('tools') -and $fm['tools'].Count -gt 0) {
        $constraints = Get-ToolConstraints $fm['tools']
        if ($constraints -ne "") {
            $body = $body.TrimEnd() + "`n" + $constraints + "`n"
        }
    }

    $header = Build-Frontmatter $newFm
    return "$header`n$body"
}

function ConvertTo-SkillFile {
    param([string]$Content, [string]$SkillName)
    $parsed = ConvertFrom-Frontmatter $Content
    $fm = $parsed.Frontmatter
    $body = $parsed.Body

    # Derive description
    $description = ""
    if ($fm.ContainsKey('description')) {
        $description = $fm['description']
    } else {
        $fullText = if ($parsed.HasFrontmatter) { $body } else { $Content }
        $firstLine = ($fullText -split '\r?\n' | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
        if ($firstLine) {
            $description = $firstLine -replace '\s*Arguments:\s*\$ARGUMENTS\s*$', ''
            $description = $description.Trim()
        }
    }

    $newFm = @{
        'name' = $SkillName
        'description' = $description
    }

    $body = if ($parsed.HasFrontmatter) { $body } else { $Content }
    $body = Update-ToolNames $body
    $body = Update-Paths $body

    $header = Build-Frontmatter $newFm
    return "$header`n$body"
}

# --- File collection ---

function Get-SourceFiles {
    param(
        [string]$SourceDir,
        [string[]]$Include,
        [string[]]$Exclude,
        [string]$CategoryType
    )
    $fullSource = Join-Path $RepoRoot $SourceDir
    if (-not (Test-Path $fullSource)) {
        Write-Warning "Source directory not found: $fullSource"
        return @()
    }

    $files = @()
    foreach ($pattern in $Include) {
        if ($pattern -eq "**/*") {
            $files += Get-ChildItem -Path $fullSource -Recurse -File
        } else {
            $files += Get-ChildItem -Path $fullSource -Filter $pattern -File
        }
    }

    if ($Exclude) {
        $files = $files | Where-Object {
            $rel = $_.Name
            $excluded = $false
            foreach ($ex in $Exclude) {
                if ($rel -eq $ex) { $excluded = $true; break }
            }
            -not $excluded
        }
    }

    $files = $files | Where-Object { $_.Name -ne 'SKILL.cursor.md' }

    return $files | Sort-Object FullName -Unique
}

function Get-ExpectedRelativePaths {
    param(
        [string]$SourceDir,
        [string[]]$Include,
        [string[]]$Exclude,
        [string]$CategoryType
    )
    $fullSource = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $SourceDir))
    $files = Get-SourceFiles -SourceDir $SourceDir -Include $Include -Exclude $Exclude -CategoryType $CategoryType
    $relPaths = @()
    foreach ($file in $files) {
        $rel = $file.FullName.Substring($fullSource.Length).TrimStart('\', '/')
        $relPaths += $rel
    }
    return $relPaths
}

# --- Prune logic ---

function Invoke-PruneSection {
    param(
        [string]$ToolName,
        [string]$CategoryName,
        [PSCustomObject]$Config
    )

    # Check manifest-level prune opt-out (e.g. settings whose target overlaps other categories)
    if ($Config.PSObject.Properties['prune'] -and $Config.prune -eq $false) {
        Write-Host "  [prune] Skipped — pruning disabled for $ToolName/$CategoryName" -ForegroundColor DarkGray
        return @{ Pruned = 0; WouldPrune = 0 }
    }

    $source  = $Config.source
    $target  = Resolve-TargetPath $Config.target
    $include = @($Config.include)
    $exclude = if ($Config.PSObject.Properties['exclude']) { @($Config.exclude) } else { @() }

    # Guardrail: target must exist, be a directory, and live under $HOME
    if (-not (Test-Path $target -PathType Container)) {
        Write-Warning "  [prune] Target directory not found: $target — skipping $ToolName/$CategoryName"
        return @{ Pruned = 0; WouldPrune = 0 }
    }
    $normalTarget = (Resolve-Path $target).ProviderPath.Replace('/', '\')
    $normalHome   = (Resolve-Path $HOME).ProviderPath.Replace('/', '\')
    $wslPrefix    = '\\wsl.localhost\'
    if (-not ($normalTarget.StartsWith($normalHome, [System.StringComparison]::OrdinalIgnoreCase) -or
              $normalTarget.StartsWith($wslPrefix,  [System.StringComparison]::OrdinalIgnoreCase))) {
        Write-Warning "  [prune] Target '$normalTarget' is outside HOME — skipping $ToolName/$CategoryName"
        return @{ Pruned = 0; WouldPrune = 0 }
    }

    # Build expected set
    $expectedPaths = Get-ExpectedRelativePaths -SourceDir $source -Include $include -Exclude $exclude -CategoryType $CategoryName
    $expectedSet   = @{}
    foreach ($p in $expectedPaths) {
        # Normalize to forward slashes and lower-case for comparison on Windows
        $key = $p.Replace('\', '/').ToLowerInvariant()
        $expectedSet[$key] = $true
    }

    # Build actual set — enumerate target directory, skip hidden-dir paths and symlinks
    $actualFiles = Get-ChildItem -Path $normalTarget -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            # Exclude files inside any hidden directory (path segment starts with '.').
            # Scope the check to the suffix after the target root so that hidden-dir
            # components in the target path itself (e.g. C:\Users\user\.claude) are
            # not erroneously matched.
            $suffix = $_.FullName.Substring($normalTarget.Length)
            $suffix -notmatch '[\\/]\.'
        }

    $orphans = @()
    foreach ($f in $actualFiles) {
        # Skip symlinks (reparse points)
        if ($f.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            continue
        }
        $rel = $f.FullName.Substring($normalTarget.Length).TrimStart('\', '/')
        $key = $rel.Replace('\', '/').ToLowerInvariant()
        if (-not $expectedSet.ContainsKey($key)) {
            $orphans += $rel
        }
    }

    $stats = @{ Pruned = 0; WouldPrune = 0 }

    if ($orphans.Count -eq 0) {
        Write-Host "  [prune] No orphans found." -ForegroundColor DarkGray
        return $stats
    }

    # Dry-run / Diff: report only, never delete
    if ($DryRun -or $Diff) {
        foreach ($rel in $orphans) {
            Write-Host "  WOULD PRUNE: $rel" -ForegroundColor Yellow
            $stats.WouldPrune++
        }
        return $stats
    }

    # Real prune: print list, confirm, delete
    Write-Host "  [prune] Orphan files to delete:" -ForegroundColor Yellow
    foreach ($rel in $orphans) {
        Write-Host "    $rel" -ForegroundColor Yellow
    }

    if (-not $Force) {
        $confirm = Read-Host "  Delete $($orphans.Count) orphan file(s)? [y/N]"
        if ($confirm -notin @('y', 'Y', 'yes')) {
            Write-Host "  [prune] Skipped." -ForegroundColor DarkGray
            return $stats
        }
    }

    $dirsToCheck = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($rel in $orphans) {
        $absPath = Join-Path $normalTarget $rel
        # Re-assert prefix check (belt-and-suspenders)
        $normAbs = [System.IO.Path]::GetFullPath($absPath)
        if (-not $normAbs.StartsWith($normalTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning "  [prune] Path escapes target root — skipping: $normAbs"
            continue
        }
        # Skip symlinks (defensive double-check)
        if (Test-Path $normAbs) {
            $item = Get-Item $normAbs -Force -ErrorAction SilentlyContinue
            if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                Write-Warning "  [prune] Skipping symlink: $rel"
                continue
            }
        }
        Remove-Item -Path $normAbs -Force -ErrorAction SilentlyContinue
        Write-Host "  PRUNED: $rel" -ForegroundColor Red
        $stats.Pruned++
        $parentDir = Split-Path $normAbs -Parent
        $dirsToCheck.Add($parentDir) | Out-Null
    }

    # Remove newly-empty directories, walking up to (but not including) the target root
    $sortedDirs = $dirsToCheck | Sort-Object { $_.Length } -Descending
    foreach ($dir in $sortedDirs) {
        $current = $dir
        while ($true) {
            # Stop at the target root
            $normCurrent = [System.IO.Path]::GetFullPath($current)
            if ($normCurrent -eq $normalTarget -or
                -not $normCurrent.StartsWith($normalTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
                break
            }
            if (-not (Test-Path $normCurrent -PathType Container)) { break }
            $children = Get-ChildItem -Path $normCurrent -Force -ErrorAction SilentlyContinue
            if ($children.Count -gt 0) { break }
            $relDir = $normCurrent.Substring($normalTarget.Length).TrimStart('\', '/')
            Remove-Item -Path $normCurrent -Force -ErrorAction SilentlyContinue
            Write-Host "  PRUNED DIR: $relDir" -ForegroundColor Red
            $current = Split-Path $normCurrent -Parent
        }
    }

    return $stats
}

# --- Deploy logic ---

function Deploy-Section {
    param(
        [string]$ToolName,
        [string]$CategoryName,
        [PSCustomObject]$Config
    )

    $source = $Config.source
    $target = Resolve-TargetPath $Config.target
    $include = @($Config.include)
    $exclude = if ($Config.PSObject.Properties['exclude']) { @($Config.exclude) } else { @() }
    $shouldTransform = $Config.transform

    $files = Get-SourceFiles -SourceDir $source -Include $include -Exclude $exclude -CategoryType $CategoryName
    if ($files.Count -eq 0) {
        Write-Host "  No files found for $ToolName/$CategoryName" -ForegroundColor DarkGray
        return @{ Copied = 0; Skipped = 0; Updated = 0 }
    }

    $stats = @{ Copied = 0; Skipped = 0; Updated = 0 }
    $sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $source))

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
        $destPath = Join-Path $target $relativePath

        # Read source content
        $sourceContent = Get-Content $file.FullName -Raw -Encoding UTF8

        # Apply transform if needed
        $outputContent = $sourceContent
        if ($shouldTransform -and $file.Extension -eq '.md') {
            if ($CategoryName -eq 'agents') {
                $outputContent = ConvertTo-AgentFile $sourceContent
            } elseif ($CategoryName -eq 'skills') {
                $isSkillEntry = $file.Name -eq 'SKILL.md'
                if ($isSkillEntry) {
                    $cursorOverride = Join-Path (Split-Path $file.FullName -Parent) 'SKILL.cursor.md'
                    if (Test-Path $cursorOverride) {
                        $outputContent = Get-Content $cursorOverride -Raw -Encoding UTF8
                        Write-Host "    (using SKILL.cursor.md override)" -ForegroundColor Cyan
                    } else {
                        $skillName = Split-Path (Split-Path $file.FullName -Parent) -Leaf
                        $outputContent = ConvertTo-SkillFile $sourceContent $skillName
                    }
                }
                if (-not $isSkillEntry) {
                    $outputContent = Update-ToolNames $sourceContent
                    $outputContent = Update-Paths $outputContent
                }
            }
        }

        # Diff mode
        if ($Diff) {
            if (Test-Path $destPath) {
                $existingContent = Get-Content $destPath -Raw -Encoding UTF8
                if ($outputContent -ne $existingContent) {
                    Write-Host "  CHANGED: $relativePath" -ForegroundColor Yellow
                    $stats.Updated++
                } else {
                    Write-Host "  OK:      $relativePath" -ForegroundColor DarkGray
                    $stats.Skipped++
                }
            } else {
                Write-Host "  NEW:     $relativePath" -ForegroundColor Green
                $stats.Copied++
            }
            continue
        }

        # DryRun mode
        if ($DryRun) {
            if (Test-Path $destPath) {
                $existingContent = Get-Content $destPath -Raw -Encoding UTF8
                if ($outputContent -ne $existingContent) {
                    Write-Host "  WOULD UPDATE: $relativePath" -ForegroundColor Yellow
                    $stats.Updated++
                } else {
                    Write-Host "  UP TO DATE:   $relativePath" -ForegroundColor DarkGray
                    $stats.Skipped++
                }
            } else {
                Write-Host "  WOULD CREATE: $relativePath" -ForegroundColor Green
                $stats.Copied++
            }
            continue
        }

        # Actual deploy
        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        if (Test-Path $destPath) {
            $existingContent = Get-Content $destPath -Raw -Encoding UTF8
            if ($outputContent -ne $existingContent) {
                Set-Content -Path $destPath -Value $outputContent -Encoding UTF8 -NoNewline
                Write-Host "  UPDATED: $relativePath" -ForegroundColor Yellow
                $stats.Updated++
            } else {
                Write-Host "  OK:      $relativePath" -ForegroundColor DarkGray
                $stats.Skipped++
            }
        } else {
            Set-Content -Path $destPath -Value $outputContent -Encoding UTF8 -NoNewline
            Write-Host "  CREATED: $relativePath" -ForegroundColor Green
            $stats.Copied++
        }
    }

    return $stats
}

# --- Main ---

# -PruneOnly implies -Prune
if ($PruneOnly) { $Prune = $true }

$targets = @()
if ($Target -eq "all" -or $Target -eq "claude") { $targets += "claude-code" }
if ($Target -eq "all" -or $Target -eq "cursor")  { $targets += "cursor" }
if ($Target -eq "all" -or $Target -eq "wsl")     { $targets += "claude-code-wsl" }

$categories = @()
if ($Category -eq "" -or $Category -eq "agents") { $categories += "agents" }
if ($Category -eq "" -or $Category -eq "skills") { $categories += "skills" }
if ($Category -eq "" -or $Category -eq "hooks")     { $categories += "hooks" }
if ($Category -eq "" -or $Category -eq "settings")  { $categories += "settings" }

$modeLabel = if ($DryRun) { "DRY RUN" } elseif ($Diff) { "DIFF" } else { "DEPLOY" }
if ($Prune -and $PruneOnly) {
    $modeLabel = if ($DryRun) { "DRY RUN (PRUNE ONLY)" } elseif ($Diff) { "DIFF (PRUNE ONLY)" } else { "PRUNE ONLY" }
} elseif ($Prune) {
    $modeLabel = if ($DryRun) { "DRY RUN (WITH PRUNE)" } elseif ($Diff) { "DIFF (WITH PRUNE)" } else { "DEPLOY + PRUNE" }
}
Write-Host "`n=== $modeLabel ===" -ForegroundColor Cyan
Write-Host "Targets:    $($targets -join ', ')"
Write-Host "Categories: $($categories -join ', ')"
Write-Host ""

# Upsert confirmation (skip if PruneOnly, DryRun, Diff, or Force)
if (-not $PruneOnly -and -not $DryRun -and -not $Diff -and -not $Force) {
    $confirm = Read-Host "Proceed? [y/N]"
    if ($confirm -notin @('y', 'Y', 'yes')) {
        Write-Host "Aborted." -ForegroundColor DarkGray
        return
    }
}

$totalStats = @{ Copied = 0; Skipped = 0; Updated = 0; Pruned = 0; WouldPrune = 0 }

foreach ($t in $targets) {
    $displayName = switch ($t) {
        "claude-code"     { "Claude Code" }
        "claude-code-wsl" { "Claude Code (WSL)" }
        "cursor"          { "Cursor" }
    }

    if ($t -eq "claude-code-wsl") {
        $wslCheck = Resolve-TargetPath $Manifest.$t.agents.target
        if (-not (Test-Path (Split-Path $wslCheck -Parent))) {
            Write-Host "`n[$displayName] Skipped - WSL path not accessible" -ForegroundColor Yellow
            continue
        }
    }

    Write-Host "`n[$displayName]" -ForegroundColor Magenta

    $toolConfig = $Manifest.$t

    foreach ($cat in $categories) {
        $catConfig = $toolConfig.$cat
        if (-not $catConfig) {
            Write-Host "  No config for $t/$cat" -ForegroundColor DarkGray
            continue
        }

        if (-not $PruneOnly) {
            Write-Host "  $cat`:" -ForegroundColor White
            $stats = Deploy-Section -ToolName $t -CategoryName $cat -Config $catConfig
            $totalStats.Copied  += $stats.Copied
            $totalStats.Skipped += $stats.Skipped
            $totalStats.Updated += $stats.Updated
        }

        if ($Prune) {
            Write-Host "  $cat (prune):" -ForegroundColor White
            $pruneStats = Invoke-PruneSection -ToolName $t -CategoryName $cat -Config $catConfig
            $totalStats.Pruned     += $pruneStats.Pruned
            $totalStats.WouldPrune += $pruneStats.WouldPrune
        }
    }
}

Write-Host "`n--- Summary ---" -ForegroundColor Cyan
if (-not $PruneOnly) {
    $action       = if ($DryRun) { "Would create:" } elseif ($Diff) { "New:" } else { "Created:" }
    $updateAction = if ($DryRun) { "Would update:" } elseif ($Diff) { "Changed:" } else { "Updated:" }
    Write-Host ("{0,-15} {1}" -f $action, $totalStats.Copied)
    Write-Host ("{0,-15} {1}" -f $updateAction, $totalStats.Updated)
    Write-Host ("{0,-15} {1}" -f "Up to date:", $totalStats.Skipped)
}
$pruneLabel = if ($DryRun -or $Diff) { "Would prune:" } else { "Pruned:" }
$pruneCount = if ($DryRun -or $Diff) { $totalStats.WouldPrune } else { $totalStats.Pruned }
Write-Host ("{0,-15} {1}" -f $pruneLabel, $pruneCount)
Write-Host ""
