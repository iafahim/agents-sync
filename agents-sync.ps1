<#
.SYNOPSIS
    AGENTS-SYNC | v1.0.0 | Synchronize AGENTS.md across all projects

.DESCRIPTION
    Keeps your AGENTS.md configuration files synchronized across all projects.
    Maintains a global template and can update all project instances.

.PARAMETER Command
    Command to run: init, local, global, edit, status

.PARAMETER Source
    Source file for init command

.PARAMETER Path
    Specific path to scan (for global mode)

.PARAMETER Patterns
    File patterns to search (comma-separated)

.PARAMETER DryRun
    Preview changes without applying

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER ShowPath
    Show template path only (for edit command)

.EXAMPLE
    agents-sync init
    Initialize with current AGENTS.md as template

.EXAMPLE
    agents-sync local
    Sync current directory only

.EXAMPLE
    agents-sync global --dry-run
    Preview global sync without applying

.EXAMPLE
    agents-sync edit
    Open global template in editor

.NOTES
    Version: 1.0.0
    Author: IAFahim
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'local', 'global', 'edit', 'status', 'help')]
    [string]$Command = 'help',

    [Parameter()]
    [string]$Source = '',

    [Parameter()]
    [string]$Path = '',

    [Parameter()]
    [string]$Patterns = '',

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$ShowPath
)

# =============================================================================
# CONFIGURATION
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

[Version]$ScriptVersion = '1.0.0'

$ConfigDir = [System.IO.Path]::Combine($env:USERPROFILE, '.agents-sync')
$ConfigPath = [System.IO.Path]::Combine($ConfigDir, 'config.json')
$TemplatePath = [System.IO.Path]::Combine($ConfigDir, 'template.md')

$DefaultPatterns = @('AGENTS.md', 'CLAUDE.md', 'GEMINI.md', 'CLAUDE.md.local')
$ExcludedDirs = @('node_modules', '.git', 'vendor', 'bin', 'obj', 'build', 'dist', '.vs', '.idea')

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

function Write-Info {
    param([string]$Message)
    Write-Host '[INFO] ' -NoNewline -ForegroundColor Cyan
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host '[OK] ' -NoNewline -ForegroundColor Green
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host '[WARN] ' -NoNewline -ForegroundColor Yellow
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host '[ERROR] ' -NoNewline -ForegroundColor Red
    Write-Host $Message
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

function Initialize-Config {
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
        Write-Info "Created config directory: $ConfigDir"
    }

    if (-not (Test-Path $ConfigPath)) {
        $Config = @{
            version = '1.0.0'
            templatePath = $TemplatePath
            lastUpdate = [DateTime]::UtcNow.ToString('o')
            patterns = $DefaultPatterns
            excludedPaths = $ExcludedDirs
        }
        $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
        Write-Info "Created config file: $ConfigPath"
    }
}

function Get-Config {
    Initialize-Config
    return Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
}

function Get-TemplateContent {
    if (-not (Test-Path $TemplatePath)) {
        return $null
    }
    return Get-Content -Path $TemplatePath -Raw -Encoding UTF8
}

function Set-TemplateContent {
    param([string]$Content)
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    $Content | Set-Content -Path $TemplatePath -Encoding UTF8

    $Config = Get-Config
    $Config.lastUpdate = [DateTime]::UtcNow.ToString('o')
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
}

function Test-InExcludedDir {
    param([string]$Path)

    $PathParts = $Path -split [IO.Path]::DirectorySeparatorChar
    foreach ($Excluded in $ExcludedDirs) {
        if ($Excluded -in $PathParts) {
            return $true
        }
    }
    return $false
}

function Find-AiDocFiles {
    param([string]$RootPath, [string[]]$FilePatterns)

    $Results = [System.Collections.Generic.List[string]]::new()
    $MaxDepth = 6

    Write-Info "Scanning: $RootPath (max depth: $MaxDepth)"

    foreach ($Pattern in $FilePatterns) {
        try {
            # Use depth-limited recursion
            $Queue = [System.Collections.Generic.Queue[Tuple[string,int]]]::new()
            $Queue.Enqueue([Tuple]::Create($RootPath, 0))

            while ($Queue.Count -gt 0) {
                $Current = $Queue.Dequeue()
                $CurrentPath = $Current.Item1
                $CurrentDepth = $Current.Item2

                if ($CurrentDepth -gt $MaxDepth) {
                    continue
                }

                $Files = Get-ChildItem -Path $CurrentPath -Filter $Pattern -ErrorAction SilentlyContinue -File
                foreach ($File in $Files) {
                    if (-not (Test-InExcludedDir -Path $File.FullName)) {
                        $Results.Add($File.FullName)
                    }
                }

                # Add subdirectories to queue if we haven't hit max depth
                if ($CurrentDepth -lt $MaxDepth) {
                    $SubDirs = Get-ChildItem -Path $CurrentPath -ErrorAction SilentlyContinue -Directory
                    foreach ($Dir in $SubDirs) {
                        if (-not (Test-InExcludedDir -Path $Dir.FullName)) {
                            $Queue.Enqueue([Tuple]::Create($Dir.FullName, $CurrentDepth + 1))
                        }
                    }
                }
            }
        }
        catch {
            # Skip inaccessible directories
        }
    }

    if ($Results.Count -eq 0) {
        return [System.Collections.Generic.List[string]]::new()
    }
    return $Results | Sort-Object -Unique
}

function Show-Diff {
    param([string]$OldPath, [string]$NewContent)

    if (-not (Test-Path $OldPath)) {
        Write-Host "  [NEW] " -NoNewline -ForegroundColor Green
        Write-Host "File will be created"
        return
    }

    $OldContent = Get-Content -Path $OldPath -Raw -Encoding UTF8
    if ($OldContent -eq $NewContent) {
        Write-Host "  [SKIP] " -NoNewline -ForegroundColor Gray
        Write-Host "No changes needed"
        return
    }

    $OldLines = $OldContent -split '\r?\n'
    $NewLines = $NewContent -split '\r?\n'
    $MaxLines = [Math]::Max($OldLines.Count, $NewLines.Count)

    Write-Host "  [DIFF] " -NoNewline -ForegroundColor Yellow
    Write-Host "Content differs:"
    Write-Host "    Lines: $($OldLines.Count) -> $($NewLines.Count)"

    for ($i = 0; $i -lt [Math]::Min(5, $MaxLines); $i++) {
        $OldLine = if ($i -lt $OldLines.Count) { $OldLines[$i] } else { $null }
        $NewLine = if ($i -lt $NewLines.Count) { $NewLines[$i] } else { $null }

        if ($OldLine -ne $NewLine) {
            if ($null -ne $OldLine) {
                Write-Host "    - $OldLine" -ForegroundColor Red
            }
            if ($null -ne $NewLine) {
                Write-Host "    + $NewLine" -ForegroundColor Green
            }
        }
    }
}

function Sync-File {
    param([string]$TargetPath, [string]$Content)

    if (Test-Path $TargetPath) {
        $BackupPath = "$TargetPath.backup"
        Copy-Item -Path $TargetPath -Destination $BackupPath -Force
        Write-Info "Backup created: $BackupPath"
    }
    else {
        $Dir = [System.IO.Path]::GetDirectoryName($TargetPath)
        if (-not (Test-Path $Dir)) {
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        }
    }

    $Content | Set-Content -Path $TargetPath -Encoding UTF8
}

# =============================================================================
# COMMAND HANDLERS
# =============================================================================

function Invoke-Help {
    Write-Host @'

AGENTS-SYNC v1.0.0
==================

Synchronize AGENTS.md across all your projects.

USAGE:
    agents-sync <command> [options]

COMMANDS:
    init              Initialize global template from current directory
    local             Sync current directory only
    global            Sync all projects across entire PC
    edit              Edit global template
    status            Show configuration and statistics

OPTIONS:
    --source <file>   Source file for init (default: ./AGENTS.md)
    --path <dir>      Specific path to scan (for global mode)
    --patterns <list> File patterns to search (comma-separated)
    --dry-run         Preview changes without applying
    --force           Skip confirmation prompts
    --show-path       Show template path only (for edit command)

EXAMPLES:
    agents-sync init
    agents-sync local
    agents-sync global --dry-run
    agents-sync global --path "D:\Projects"
    agents-sync edit
    agents-sync status

'@ -ForegroundColor Cyan
}

function Invoke-Init {
    $SourcePath = if ($Source) { $Source } else { '.\AGENTS.md' }

    if (-not (Test-Path $SourcePath)) {
        Write-Error "Source file not found: $SourcePath"
        Write-Info "Creating empty template..."

        $EmptyTemplate = @'
# AGENTS.md Template

This is your global AGENTS.md template. Edit this file to define
your standard AI agent instructions that will be synchronized across
all your projects.

## Project Context

Add project-specific context here.

## Coding Standards

Define your coding standards and conventions.

## Development Workflow

Describe your preferred development workflow.

'@
        Set-TemplateContent -Content $EmptyTemplate
    }
    else {
        $Content = Get-Content -Path $SourcePath -Raw -Encoding UTF8
        Set-TemplateContent -Content $Content
        Write-Success "Template created from: $SourcePath"
    }

    Write-Info "Template location: $TemplatePath"
    Write-Info "Run 'agents-sync edit' to modify the template"
}

function Invoke-Local {
    $Config = Get-Config
    $Template = Get-TemplateContent

    if (-not $Template) {
        Write-Error "No template found. Run 'agents-sync init' first."
        return
    }

    $CurrentPath = Get-Location
    $TargetFile = [System.IO.Path]::Combine($CurrentPath, 'AGENTS.md')

    Write-Info "Current directory: $CurrentPath"
    Write-Info "Target file: $TargetFile"
    Write-Host ''

    Show-Diff -OldPath $TargetFile -NewContent $Template

    if ($DryRun) {
        Write-Warn "Dry run mode - no changes applied"
        return
    }

    if (-not $Force) {
        $Response = Read-Host "Apply changes? (y/N)"
        if ($Response -ne 'y' -and $Response -ne 'Y') {
            Write-Info "Cancelled"
            return
        }
    }

    Sync-File -TargetPath $TargetFile -Content $Template
    Write-Success "Synced: $TargetFile"
}

function Invoke-Global {
    $Config = Get-Config
    $Template = Get-TemplateContent

    if (-not $Template) {
        Write-Error "No template found. Run 'agents-sync init' first."
        return
    }

    $Patterns = if ($Patterns) { $Patterns -split ',' } else { $Config.patterns }

    Write-Host ''
    Write-Host '============================================================================' -ForegroundColor Cyan
    Write-Host 'GLOBAL SYNC MODE' -ForegroundColor Cyan
    Write-Host '============================================================================' -ForegroundColor Cyan
    Write-Host ''

    $AllFiles = [System.Collections.Generic.List[string]]::new()

    if ($Path) {
        if (-not (Test-Path $Path)) {
            Write-Error "Path not found: $Path"
            return
        }
        $Files = Find-AiDocFiles -RootPath $Path -FilePatterns $Patterns
        if ($Files) { $AllFiles.AddRange($Files) }
    }
    else {
        $Drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
        foreach ($Drive in $Drives) {
            $Files = Find-AiDocFiles -RootPath "$($Drive.Name):\" -FilePatterns $Patterns
            if ($Files) { $AllFiles.AddRange($Files) }
        }
    }

    Write-Info "Found $($AllFiles.Count) files to sync"
    Write-Host ''

    $ChangesNeeded = 0

    foreach ($File in $AllFiles) {
        Write-Host "File: $File"
        Show-Diff -OldPath $File -NewContent $Template

        $CurrentContent = if (Test-Path $File) { Get-Content -Path $File -Raw -Encoding UTF8 } else { '' }
        if ($CurrentContent -ne $Template) {
            $ChangesNeeded++
        }

        Write-Host ''
    }

    Write-Host '============================================================================' -ForegroundColor Cyan
    Write-Host "Files requiring changes: $ChangesNeeded / $($AllFiles.Count)" -ForegroundColor Cyan
    Write-Host '============================================================================' -ForegroundColor Cyan
    Write-Host ''

    if ($DryRun) {
        Write-Warn "Dry run mode - no changes applied"
        return
    }

    if ($ChangesNeeded -eq 0) {
        Write-Success "All files are already up to date"
        return
    }

    if (-not $Force) {
        $Response = Read-Host "Apply changes to all files? (y/N)"
        if ($Response -ne 'y' -and $Response -ne 'Y') {
            Write-Info "Cancelled"
            return
        }
    }

    foreach ($File in $AllFiles) {
        $CurrentContent = if (Test-Path $File) { Get-Content -Path $File -Raw -Encoding UTF8 } else { '' }
        if ($CurrentContent -ne $Template) {
            Sync-File -TargetPath $File -Content $Template
            Write-Success "Synced: $File"
        }
    }

    Write-Success "Global sync complete!"
}

function Invoke-Edit {
    Initialize-Config

    if ($ShowPath) {
        Write-Output $TemplatePath
        return
    }

    if (-not (Test-Path $TemplatePath)) {
        Write-Warn "Template not found. Creating empty template..."
        Invoke-Init
    }

    Write-Info "Opening template: $TemplatePath"
    Invoke-Item -Path $TemplatePath
}

function Invoke-Status {
    $Config = Get-Config
    $TemplateExists = Test-Path $TemplatePath

    Write-Host ''
    Write-Host '============================================================================' -ForegroundColor Cyan
    Write-Host 'AGENTS-SYNC STATUS' -ForegroundColor Cyan
    Write-Host '============================================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Version:        $ScriptVersion"
    Write-Host "Config Path:    $ConfigPath"
    Write-Host "Template Path:  $TemplatePath"
    Write-Host "Template Exists: $(if ($TemplateExists) { 'Yes' } else { 'No' })"

    if ($TemplateExists) {
        $Template = Get-Content -Path $TemplatePath -Raw -Encoding UTF8
        $Lines = ($Template -split '\r?\n').Count
        $Size = (Get-Item $TemplatePath).Length
        Write-Host "Template Size:  $Lines lines, $Size bytes"
    }

    Write-Host ''
    Write-Host "Configured Patterns:"
    foreach ($Pattern in $Config.patterns) {
        Write-Host "  - $Pattern" -ForegroundColor Gray
    }

    Write-Host ''
    Write-Host "Excluded Paths:"
    foreach ($Path in $Config.excludedPaths) {
        Write-Host "  - $Path" -ForegroundColor Gray
    }

    Write-Host ''
    Write-Host "Last Updated: $($Config.lastUpdate)"
    Write-Host ''
}

# =============================================================================
# MAIN
# =============================================================================

switch ($Command) {
    'init' { Invoke-Init }
    'local' { Invoke-Local }
    'global' { Invoke-Global }
    'edit' { Invoke-Edit }
    'status' { Invoke-Status }
    'help' { Invoke-Help }
}
