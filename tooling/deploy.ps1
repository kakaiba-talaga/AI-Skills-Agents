<#
.SYNOPSIS
    Deploy AI skills and agents to Claude Code and/or Cursor global directories.

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
    Deploy only one category: agents or skills. Default: both.

.PARAMETER DryRun
    Show what would change without copying any files.

.PARAMETER Diff
    Show diffs between repo and currently deployed files.

.PARAMETER Force
    Skip the confirmation prompt.

.EXAMPLE
    .\deploy.ps1 -Target claude
    .\deploy.ps1 -Target cursor -DryRun
    .\deploy.ps1 -Target all -Category skills -Force
    .\deploy.ps1 -Diff
#>

[CmdletBinding()]
param(
    [ValidateSet("all", "claude", "cursor")]
    [string]$Target = "all",

    [ValidateSet("agents", "skills", "")]
    [string]$Category = "",

    [switch]$DryRun,
    [switch]$Diff,
    [switch]$Force
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
    $sourceRoot = Join-Path $RepoRoot $source

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

$targets = @()
if ($Target -eq "all" -or $Target -eq "claude") { $targets += "claude-code" }
if ($Target -eq "all" -or $Target -eq "cursor")  { $targets += "cursor" }

$categories = @()
if ($Category -eq "" -or $Category -eq "agents") { $categories += "agents" }
if ($Category -eq "" -or $Category -eq "skills") { $categories += "skills" }

$mode = if ($DryRun) { "DRY RUN" } elseif ($Diff) { "DIFF" } else { "DEPLOY" }
Write-Host "`n=== $mode ===" -ForegroundColor Cyan
Write-Host "Targets:    $($targets -join ', ')"
Write-Host "Categories: $($categories -join ', ')"
Write-Host ""

if (-not $DryRun -and -not $Diff -and -not $Force) {
    $confirm = Read-Host "Proceed? [y/N]"
    if ($confirm -notin @('y', 'Y', 'yes')) {
        Write-Host "Aborted." -ForegroundColor DarkGray
        return
    }
}

$totalStats = @{ Copied = 0; Skipped = 0; Updated = 0 }

foreach ($t in $targets) {
    $displayName = if ($t -eq "claude-code") { "Claude Code" } else { "Cursor" }
    Write-Host "`n[$displayName]" -ForegroundColor Magenta

    $toolConfig = $Manifest.$t

    foreach ($cat in $categories) {
        $catConfig = $toolConfig.$cat
        if (-not $catConfig) {
            Write-Host "  No config for $t/$cat" -ForegroundColor DarkGray
            continue
        }

        Write-Host "  $cat`:" -ForegroundColor White
        $stats = Deploy-Section -ToolName $t -CategoryName $cat -Config $catConfig

        $totalStats.Copied  += $stats.Copied
        $totalStats.Skipped += $stats.Skipped
        $totalStats.Updated += $stats.Updated
    }
}

Write-Host "`n--- Summary ---" -ForegroundColor Cyan
$action = if ($DryRun) { "Would create" } elseif ($Diff) { "New" } else { "Created" }
$updateAction = if ($DryRun) { "Would update" } elseif ($Diff) { "Changed" } else { "Updated" }
Write-Host "$action`:    $($totalStats.Copied)"
Write-Host "$updateAction`: $($totalStats.Updated)"
Write-Host "Up to date: $($totalStats.Skipped)"
Write-Host ""
