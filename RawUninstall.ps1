#Requires -Version 5.1
<#
.SYNOPSIS
    Executes a raw uninstall command string exactly as provided.

.DESCRIPTION
    Accepts any complete command line string and runs it as-is.
    No registry lookups, no flag injection - what you pass is what runs.
    Designed for RMM / SYSTEM context execution where you already know
    the exact silent parameters needed.

.PARAMETER CommandString
    The full command to execute, exactly as you would type it.
    Wrap the entire string in single quotes when calling from PowerShell
    to avoid shell interpretation of special characters.

.PARAMETER WaitForExit
    Wait for the process to complete before exiting. Default: $true

.PARAMETER TimeoutMinutes
    Maximum time to wait in minutes. Default: 30

.PARAMETER LogPath
    Full path to the log file.
    Default: C:\Windows\Logs\RawUninstall_<timestamp>.log

.EXAMPLE
    # EXE with custom flags
    .\Invoke-RawUninstall.ps1 -CommandString '"C:\Program Files\Opera\opera.exe" --uninstall --runimmediately --deleteuserprofile=1'

    # MSI with extra properties
    .\Invoke-RawUninstall.ps1 -CommandString 'MsiExec.exe /X{12345678-ABCD-1234-ABCD-1234567890AB} /qn /norestart REBOOT=ReallySuppress'

    # NSIS
    .\Invoke-RawUninstall.ps1 -CommandString '"C:\Program Files\MyApp\uninstall.exe" /S'

    # Inno Setup
    .\Invoke-RawUninstall.ps1 -CommandString '"C:\Program Files\MyApp\unins000.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART'

    # Fire and forget
    .\Invoke-RawUninstall.ps1 -CommandString '"C:\Program Files\App\uninst.exe" /silent' -WaitForExit $false
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$CommandString,

    [bool]$WaitForExit = $true,

    [int]$TimeoutMinutes = 30,

    [string]$LogPath = ""
)

$ErrorActionPreference = "Stop"

# ==============================================================================
# LOGGING
# ==============================================================================

if (-not $LogPath) {
    $ts      = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogPath = "C:\Windows\Logs\RawUninstall_$ts.log"
}

$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts][$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

Write-Log "======================================================"
Write-Log "Invoke-RawUninstall started"
Write-Log "Command       : $CommandString"
Write-Log "WaitForExit   : $WaitForExit"
Write-Log "Timeout (min) : $TimeoutMinutes"
Write-Log "LogPath       : $LogPath"
Write-Log "Running As    : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Log "======================================================"

# ==============================================================================
# PARSER  -  splits  "path\to\exe"  from  its arguments
# ==============================================================================

function Parse-CommandLine {
    param([string]$Raw)

    $Raw = $Raw.Trim()

    # Case 1: executable is wrapped in double quotes  ->  "C:\path\to\exe.exe" args
    if ($Raw -match '^"([^"]+)"\s*(.*)$') {
        return @{
            Exe  = $Matches[1].Trim()
            Args = $Matches[2].Trim()
        }
    }

    # Case 2: no quotes - split on first whitespace  ->  C:\no\spaces\exe.exe args
    if ($Raw -match '^(\S+)\s*(.*)$') {
        return @{
            Exe  = $Matches[1].Trim()
            Args = $Matches[2].Trim()
        }
    }

    throw "Cannot parse command string: $Raw"
}

# ==============================================================================
# EXECUTE
# ==============================================================================

try {
    $parsed = Parse-CommandLine -Raw $CommandString
} catch {
    Write-Log "Failed to parse command string: $_" "ERROR"
    Exit 1
}

$exe  = $parsed.Exe
$args = $parsed.Args

Write-Log "Executable    : $exe"
Write-Log "Arguments     : $args"

# Validate the executable exists (skip for msiexec / system binaries in PATH)
$isMsi       = ($exe -imatch 'msiexec')
$isSystemBin = (-not [System.IO.Path]::IsPathRooted($exe))   # no drive letter = probably in PATH

if (-not $isMsi -and -not $isSystemBin) {
    if (-not (Test-Path $exe)) {
        Write-Log "Executable not found at path: $exe" "ERROR"
        Exit 1
    }
}

# Build Start-Process arguments
$spParams = @{
    FilePath    = $exe
    PassThru    = $true
    ErrorAction = "Stop"
}

if ($args) {
    $spParams.ArgumentList = $args
}

# ==============================================================================
# LAUNCH
# ==============================================================================

try {
    Write-Log "Launching process..."
    $proc = Start-Process @spParams

    Write-Log "Process started. PID: $($proc.Id)"

    if ($WaitForExit) {
        Write-Log "Waiting for completion (timeout: $TimeoutMinutes min)..."

        $timeoutMs = $TimeoutMinutes * 60 * 1000
        $finished  = $proc.WaitForExit($timeoutMs)

        if (-not $finished) {
            Write-Log "Process did not complete within $TimeoutMinutes minutes. Exiting script without killing it." "WARN"
            Exit 1
        }

        $exitCode = $proc.ExitCode

        # Common exit codes worth noting
        $knownCodes = @{
            0    = "Success"
            1    = "General error"
            2    = "Not found / bad arguments"
            3010 = "Success - reboot required (not forced)"
            1603 = "MSI fatal error during install"
            1605 = "Product not found (already removed)"
            1614 = "Product uninstalled"
            1618 = "Another MSI install already in progress"
            1619 = "MSI package could not be opened"
        }

        $codeNote = if ($knownCodes.ContainsKey($exitCode)) { $knownCodes[$exitCode] } else { "Unknown" }

        Write-Log "Process exited. Code: $exitCode  ($codeNote)"

        if ($exitCode -in @(0, 3010, 1605, 1614)) {
            Write-Log "Uninstall completed successfully."
        } else {
            Write-Log "Non-success exit code. Review the application's own logs for detail." "WARN"
        }

        Write-Log "======================================================"
        Write-Log "Finished. Exit code: $exitCode"
        Write-Log "======================================================"

        Exit $exitCode

    } else {
        Write-Log "Process launched. Not waiting for exit (-WaitForExit:`$false)."
        Write-Log "======================================================"
        Write-Log "Finished. Process running in background."
        Write-Log "======================================================"
        Exit 0
    }

} catch {
    Write-Log "Error launching process: $_" "ERROR"
    Write-Log "======================================================"
    Write-Log "Finished with error."
    Write-Log "======================================================"
    Exit 1
}
