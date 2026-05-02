#Requires -Version 5.1
<#
.SYNOPSIS
    Finds an installed application by display name and silently uninstalls it.
.PARAMETER AppName
    Name as shown in Add/Remove Programs. Wildcards (*) supported.
.PARAMETER ExactMatch
    Require an exact (case-insensitive) name match.
.PARAMETER UninstallAll
    If multiple matches found, uninstall all of them.
.PARAMETER WaitForExit
    Wait for the uninstall process to complete. Default: $true
.PARAMETER TimeoutMinutes
    Max wait time in minutes. Default: 30
.PARAMETER LogPath
    Log file path. Default: C:\Windows\Logs\SilentUninstall_<AppName>.log
.EXAMPLE
    .\Invoke-SilentUninstall.ps1 -AppName "Google Chrome"
    .\Invoke-SilentUninstall.ps1 -AppName "Microsoft Visual C++*" -UninstallAll
    .\Invoke-SilentUninstall.ps1 -AppName "Zoom" -WaitForExit $false
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$AppName,
    [switch]$ExactMatch,
    [switch]$UninstallAll,
    [bool]$WaitForExit = $true,
    [int]$TimeoutMinutes = 30,
    [string]$LogPath = ""
)

$ErrorActionPreference = "Stop"

# ==============================================================================
# LOGGING
# ==============================================================================

if (-not $LogPath) {
    $safeName = $AppName -replace '[\\/:*?"<>|]', '_'
    $LogPath  = "C:\Windows\Logs\SilentUninstall_$safeName.log"
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
Write-Log "Script started  : $AppName"
Write-Log "ExactMatch      : $($ExactMatch.IsPresent)"
Write-Log "UninstallAll    : $($UninstallAll.IsPresent)"
Write-Log "WaitForExit     : $WaitForExit"
Write-Log "Running As      : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Log "======================================================"

# ==============================================================================
# REGISTRY SEARCH
# ==============================================================================

function Get-UninstallEntries {
    param(
        [string]$Filter,
        [bool]$Exact
    )

    $hives = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $results = New-Object System.Collections.Generic.List[PSObject]

    foreach ($hive in $hives) {
        if (-not (Test-Path $hive)) { continue }

        $keys = Get-ChildItem -Path $hive -ErrorAction SilentlyContinue

        foreach ($key in $keys) {
            try {
                $p = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
            } catch {
                continue
            }

            if (-not $p.DisplayName) { continue }

            if ($Exact) {
                $hit = ($p.DisplayName -ieq $Filter)
            } else {
                $hit = ($p.DisplayName -ilike $Filter)
            }

            if (-not $hit) { continue }

            $obj = [PSCustomObject]@{
                DisplayName           = $p.DisplayName
                DisplayVersion        = $p.DisplayVersion
                Publisher             = $p.Publisher
                UninstallString       = $p.UninstallString
                QuietUninstallString  = $p.QuietUninstallString
                SilentUninstallString = $p.SilentUninstallString
                RegistryKeyName       = $key.PSChildName
                WindowsInstaller      = $p.WindowsInstaller
            }
            $results.Add($obj)
        }
    }

    return $results
}

if ($ExactMatch) {
    $nameFilter = $AppName
} elseif ($AppName -notmatch '\*') {
    $nameFilter = "*$AppName*"
} else {
    $nameFilter = $AppName
}

Write-Log "Registry filter : '$nameFilter'"

$foundApps = Get-UninstallEntries -Filter $nameFilter -Exact $ExactMatch.IsPresent

if ($foundApps.Count -eq 0) {
    Write-Log "No application found matching '$nameFilter'. Exiting." "WARN"
    Exit 0
}

Write-Log "Found $($foundApps.Count) match(es):"
foreach ($a in $foundApps) {
    Write-Log "  -> '$($a.DisplayName)' v$($a.DisplayVersion) [$($a.Publisher)]"
}

if (($foundApps.Count -gt 1) -and (-not $UninstallAll)) {
    Write-Log "Multiple matches found but -UninstallAll not specified. Exiting." "WARN"
    Write-Log "Use -UninstallAll to remove all, or provide a more specific name." "WARN"
    Exit 2
}

# ==============================================================================
# COMMAND LINE PARSER
# ==============================================================================

function Parse-CommandLine {
    param([string]$Raw)

    $Raw = $Raw.Trim()

    if ($Raw -match '^"([^"]+)"\s*(.*)$') {
        return @{ Exe = $Matches[1].Trim(); Args = $Matches[2].Trim() }
    }

    if ($Raw -match '^(\S+)\s*(.*)$') {
        return @{ Exe = $Matches[1].Trim(); Args = $Matches[2].Trim() }
    }

    throw "Cannot parse uninstall string: $Raw"
}

# ==============================================================================
# INSTALLER TYPE DETECTION
# ==============================================================================

function Get-InstallerType {
    param(
        [PSObject]$Entry,
        [string]$ExePath
    )

    # Inno Setup registry keys always end in _is1
    if ($Entry.RegistryKeyName -match '_is1$') {
        return "InnoSetup"
    }

    # MSI - Windows Installer flag set in registry
    if ($Entry.WindowsInstaller -eq 1) {
        return "MSI"
    }

    # MSI - msiexec present in uninstall string
    if ($Entry.UninstallString -imatch 'msiexec') {
        return "MSI"
    }

    # Inspect EXE file version info
    if ($ExePath -and (Test-Path $ExePath)) {
        try {
            $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExePath)
            $vs = "$($vi.FileDescription)|$($vi.ProductName)|$($vi.CompanyName)|$($vi.Comments)".ToLower()

            if ($vs -match 'nullsoft|nsis')             { return "NSIS" }
            if ($vs -match 'inno setup|innosetup')      { return "InnoSetup" }
            if ($vs -match 'installshield')              { return "InstallShield" }
            if ($vs -match '\bwise\b')                   { return "Wise" }
            if ($vs -match 'squirrel')                   { return "Squirrel" }
            if ($vs -match 'advanced installer')         { return "AdvancedInstaller" }
            if ($vs -match 'wix|windows installer xml') { return "MSI" }
        } catch {
            # Cannot read version info - fall through to Unknown
        }
    }

    return "Unknown"
}

# ==============================================================================
# SILENT FLAG INJECTION
# ==============================================================================

function Add-SilentFlags {
    param(
        [string]$InstallerType,
        [string]$Arguments
    )

    if ($InstallerType -eq "MSI") {
        $Arguments = $Arguments -ireplace '/I\s*\{', '/X {'
        $Arguments = $Arguments -ireplace '/I\s*"',  '/X "'
        if ($Arguments -notmatch '/qn|/quiet')  { $Arguments = "$Arguments /qn" }
        if ($Arguments -notmatch '/norestart')  { $Arguments = "$Arguments /norestart" }
        if ($Arguments -notmatch 'REBOOT')      { $Arguments = "$Arguments REBOOT=ReallySuppress" }
    }
    elseif ($InstallerType -eq "NSIS") {
        # /S is case-sensitive in NSIS - must be uppercase
        if ($Arguments -cnotmatch '/S') {
            $Arguments = "/S $Arguments"
        }
    }
    elseif ($InstallerType -eq "InnoSetup") {
        if ($Arguments -notmatch '/VERYSILENT')       { $Arguments = "$Arguments /VERYSILENT" }
        if ($Arguments -notmatch '/SUPPRESSMSGBOXES') { $Arguments = "$Arguments /SUPPRESSMSGBOXES" }
        if ($Arguments -notmatch '/NORESTART')        { $Arguments = "$Arguments /NORESTART" }
        if ($Arguments -notmatch '/SP-')              { $Arguments = "$Arguments /SP-" }
    }
    elseif ($InstallerType -eq "InstallShield") {
        if ($Arguments -notmatch '(^|\s)/s(\s|$)') { $Arguments = "/s $Arguments" }
        if ($Arguments -notmatch '/sms')            { $Arguments = "$Arguments /sms" }
    }
    elseif ($InstallerType -eq "Wise") {
        if ($Arguments -cnotmatch '/S') {
            $Arguments = "/S $Arguments"
        }
    }
    elseif ($InstallerType -eq "Squirrel") {
        if ($Arguments -notmatch '--uninstall') { $Arguments = "$Arguments --uninstall" }
        if ($Arguments -notmatch '--silent')    { $Arguments = "$Arguments --silent" }
    }
    elseif ($InstallerType -eq "AdvancedInstaller") {
        if ($Arguments -notmatch '/exenoui')   { $Arguments = "$Arguments /exenoui" }
        if ($Arguments -notmatch '/qn')        { $Arguments = "$Arguments /qn" }
        if ($Arguments -notmatch '/norestart') { $Arguments = "$Arguments /norestart" }
    }
    else {
        Write-Log "Installer type Unknown - using UninstallString as-is. Silent not guaranteed." "WARN"
    }

    return $Arguments.Trim()
}

# ==============================================================================
# UNINSTALL EXECUTOR
# ==============================================================================

function Invoke-Uninstall {
    param([PSObject]$Entry)

    Write-Log "------------------------------------------------------"
    Write-Log "Processing : '$($Entry.DisplayName)' v$($Entry.DisplayVersion)"

    # Pick best available uninstall string
    $rawString  = $null
    $fromSource = ""

    if ($Entry.QuietUninstallString) {
        $rawString  = $Entry.QuietUninstallString
        $fromSource = "QuietUninstallString"
    } elseif ($Entry.SilentUninstallString) {
        $rawString  = $Entry.SilentUninstallString
        $fromSource = "SilentUninstallString"
    } elseif ($Entry.UninstallString) {
        $rawString  = $Entry.UninstallString
        $fromSource = "UninstallString"
    } else {
        Write-Log "No uninstall string found. Skipping." "ERROR"
        return 1
    }

    Write-Log "Source : $fromSource"
    Write-Log "Raw    : $rawString"

    # Parse into executable + arguments
    try {
        $parsed = Parse-CommandLine -Raw $rawString
    } catch {
        Write-Log "Parse failed: $_" "ERROR"
        return 1
    }

    $exe  = $parsed.Exe
    $args = $parsed.Args

    # Only augment plain UninstallString - Quiet/Silent variants are already baked
    if ($fromSource -eq "UninstallString") {
        $type = Get-InstallerType -Entry $Entry -ExePath $exe
        Write-Log "Installer type : $type"
        $args = Add-SilentFlags -InstallerType $type -Arguments $args
    }

    Write-Log "Exe  : $exe"
    Write-Log "Args : $args"

    # Execute
    try {
        $isMsi = ($exe -imatch 'msiexec')

        if ($isMsi) {
            Write-Log "Launching via msiexec..."
            if ($args) {
                $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $args -PassThru -ErrorAction Stop
            } else {
                $proc = Start-Process -FilePath "msiexec.exe" -PassThru -ErrorAction Stop
            }
        } else {
            Write-Log "Launching EXE uninstaller..."
            if ($args) {
                $proc = Start-Process -FilePath $exe -ArgumentList $args -PassThru -ErrorAction Stop
            } else {
                $proc = Start-Process -FilePath $exe -PassThru -ErrorAction Stop
            }
        }

        if ($WaitForExit) {
            Write-Log "Waiting for process (PID $($proc.Id)) - timeout $TimeoutMinutes min..."
            $finished = $proc.WaitForExit($TimeoutMinutes * 60 * 1000)

            if (-not $finished) {
                Write-Log "Process did not finish within $TimeoutMinutes minutes." "WARN"
                return 1
            }

            $code         = $proc.ExitCode
            $successCodes = @(0, 3010, 1605, 1614)

            Write-Log "Exit code : $code"

            if ($code -in $successCodes) {
                Write-Log "Exit code $code - success."
            } else {
                Write-Log "Exit code $code - may indicate a problem. Check vendor documentation." "WARN"
            }

            return $code
        } else {
            Write-Log "Process launched (PID $($proc.Id)). Not waiting (-WaitForExit:`$false)."
            return 0
        }
    } catch {
        Write-Log "Execution error: $_" "ERROR"
        return 1
    }
}

# ==============================================================================
# MAIN
# ==============================================================================

$overallExit  = 0
$successCodes = @(0, 3010, 1605, 1614)

foreach ($app in $foundApps) {
    $rc = Invoke-Uninstall -Entry $app
    if ($rc -notin $successCodes) {
        $overallExit = $rc
        Write-Log "'$($app.DisplayName)' returned non-success code: $rc" "WARN"
    }
}

Write-Log "======================================================"
Write-Log "Finished. Overall exit code: $overallExit"
Write-Log "======================================================"

Exit $overallExit
