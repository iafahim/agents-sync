<#
.SYNOPSIS
    AGENTS-SYNC Windows Installer

.DESCRIPTION
    Installs agents-sync as a Git alias and system command on Windows.

.PARAMETER SkipGitAlias
    Skip creating git alias

.EXAMPLE
    .\install.ps1
    Install with git alias

.EXAMPLE
    .\install.ps1 -SkipGitAlias
    Install without git alias
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$SkipGitAlias
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

$Version = '1.0.0'
$InstallDir = Join-Path $env:USERPROFILE '.agents-sync'
$BinDir = Join-Path $InstallDir 'bin'
$ScriptPath = Join-Path $BinDir 'agents-sync.ps1'
$WrapperPath = Join-Path $BinDir 'agents-sync.cmd'
$GitAliasPath = Join-Path $InstallDir 'git-alias.sh'

Write-Host ''
Write-Host '============================================================================' -ForegroundColor Cyan
Write-Host "AGENTS-SYNC v$Version - Windows Installer" -ForegroundColor Cyan
Write-Host '============================================================================' -ForegroundColor Cyan
Write-Host ''

# Create directories
Write-Info 'Creating installation directories...'
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
New-Item -ItemType Directory -Path $BinDir -Force | Out-Null

# Copy main script
Write-Info 'Installing agents-sync.ps1...'
Copy-Item -Path (Join-Path $PSScriptRoot 'agents-sync.ps1') -Destination $ScriptPath -Force

# Create batch wrapper
Write-Info 'Creating agents-sync.cmd...'
@"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0agents-sync.ps1" %*
"@ | Set-Content -Path $WrapperPath -Encoding ASCII

# Add to PATH
Write-Info 'Adding to user PATH...'
$PathEnv = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($PathEnv -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$PathEnv;$BinDir", 'User')
    Write-Success 'Added to PATH (restart terminal required)'
}
else {
    Write-Info 'Already in PATH'
}

# Create git alias
if (-not $SkipGitAlias) {
    Write-Info 'Creating git alias...'

    # Detect git config location
    $GitConfigPath = if (Test-Path $env:USERPROFILE\.gitconfig) {
        $env:USERPROFILE\.gitconfig
    }
    else {
        Join-Path $env:USERPROFILE '.gitconfig'
    }

    # Check if alias already exists
    $AliasExists = $false
    if (Test-Path $GitConfigPath) {
        $GitConfig = Get-Content $GitConfigPath -Raw
        if ($GitConfig -match '\[alias\].*agents-sync') {
            $AliasExists = $true
        }
    }

    if (-not $AliasExists) {
        $AliasCommand = "!powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

        # Try to add alias using git config
        $GitExe = Get-Command git -ErrorAction SilentlyContinue
        if ($GitExe) {
            try {
                & git @('config', '--global', 'alias.agents-sync', $AliasCommand)
                Write-Success 'Git alias created: git agents-sync'
            }
            catch {
                Write-Warn "Could not create git alias: $_"
            }
        }
        else {
            Write-Warn 'Git not found, skipping git alias'
        }
    }
    else {
        Write-Info 'Git alias already exists'
    }
}

Write-Host ''
Write-Host '============================================================================' -ForegroundColor Green
Write-Host 'INSTALLATION COMPLETE' -ForegroundColor Green
Write-Host '============================================================================' -ForegroundColor Green
Write-Host ''
Write-Host 'Installation location:' -ForegroundColor Gray
Write-Host "  $BinDir"
Write-Host ''
Write-Host 'Usage:' -ForegroundColor Gray
Write-Host '  agents-sync init'
Write-Host '  agents-sync local'
Write-Host '  agents-sync global'
Write-Host '  agents-sync edit'
Write-Host '  agents-sync status'
Write-Host ''
Write-Host 'Git alias (if installed):' -ForegroundColor Gray
Write-Host '  git agents-sync init'
Write-Host '  git agents-sync local'
Write-Host ''
Write-Host 'NOTE: Restart your terminal for PATH changes to take effect' -ForegroundColor Yellow
Write-Host ''
