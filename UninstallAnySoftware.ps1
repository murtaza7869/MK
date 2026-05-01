<#
.SYNOPSIS
    Locates a software application by display name in the Windows registry
    and performs a silent, unattended uninstall.

.DESCRIPTION
    Searches all standard Uninstall hives:
      - HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall          (64-bit)
      - HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall (32-bit on 64-bit OS)
      - HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall          (per-user installs)

    String priority (first found wins):
      1. QuietUninstallString   — used as-is, already silent
      2. SilentUninstallString  — used as-is, already silent
      3. UninstallString        — augmented with silent flags based on auto-detected
                                  installer type (MSI, NSIS, Inno Setup, InstallShield, etc.)

    Designed for unattended RMM execution under SYSTEM or admin context.
    No reboot is forced.

.PARAMETER AppName
    Display name as shown in Add/Remove Programs. Supports wildcards (*).
    Case-insensitive. E.g. "Google Chrome", "Microsoft Visual C++*", "7-Zip*"

.PARAMETER ExactMatch
    Require an exact display name match (still case-insensitive).
    Default: $false

.PARAMETER UninstallAll
    When multiple matches are found, uninstall ALL of them.
    When $false (default), the script exits if more than one match is found
    (you must narrow down the name or use a wildcard with -UninstallAll).
    Default: $false

.PARAMETER WaitForExit
    Wait for the uninstall process to finish before exiting.
    Default: $true

.PARAMETER TimeoutMinutes
    Maximum time to wait for the uninstall process. Default: 30 minutes.

.PARAMETER LogPath
    Full path to the log file.
    Default: C:\Windows\Logs\SilentUninstall_<sanitised-AppName>.log

.EXAMPLE
    # Exact name, wait for completion
    .\Invoke-SilentUninstall.ps1 -AppName "Google Chrome"

    # Wildcard — removes ALL matching VC++ redists
    .\Invoke-SilentUninstall.ps1 -AppName "Microsoft Visual C++ 2015*" -UninstallAll

    # Fire-and-forget (RMM task sequence style)
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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#region ── Logging ─────────────────────────────────────────────────────────────

if (-not $LogPath) {
    $safeName = $AppName -replace '[\\/:*?"<>|]', '_'
    $LogPath  = "C:\Windows\Logs\SilentUninstall_$safeName.log"
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

# Ensure log directory exists
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

Write-Log "======================================================"
Write-Log "Invoke-SilentUninstall started"
Write-Log "AppName       : $AppName"
Write-Log "ExactMatch    : $($ExactMatch.IsPresent)"
Write-Log "UninstallAll  : $($UninstallAll.IsPresent)"
Write-Log "WaitForExit   : $WaitForExit"
Write-Log "TimeoutMinutes: $TimeoutMinutes"
Write-Log "LogPath       : $LogPath"
Write-Log "Running As    : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Log "======================================================"

#endregion

#region ── Registry Search ─────────────────────────────────────────────────────

$registryHives = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
)

function Get-RegistryUninstallEntries {
    param ([string]$DisplayNameFilter, [bool]$Exact)

    $results = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($hive in $registryHives) {
        if (-not (Test-Path $hive)) { continue }

        Get-ChildItem -Path $hive -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            } catch { return }

            if (-not $props.DisplayName) { return }

            $isMatch = if ($Exact) {
                $props.DisplayName -ieq $DisplayNameFilter
            } else {
                $props.DisplayName -ilike $DisplayNameFilter
            }

            if ($isMatch) {
                $results.Add([PSCustomObject]@{
                    DisplayName           = $props.DisplayName
                    DisplayVersion        = $props.DisplayVersion
                    Publisher             = $props.Publisher
                    UninstallString       = $props.UninstallString
                    QuietUninstallString  = $props.QuietUninstallString
                    SilentUninstallString = $props.SilentUninstallString
                    RegistryKeyName       = $_.PSChildName
                    RegistryHive          = $hive
                    RegistryPath          = $_.PSPath
                    SystemComponent       = $props.SystemComponent
                    WindowsInstaller      = $props.WindowsInstaller
                })
            }
        }
    }
    return $results
}

# Normalise the filter — if no wildcard present, wrap with * for partial matching
$nameFilter = if ($ExactMatch) {
    $AppName
} elseif ($AppName -notmatch '\*') {
    "*$AppName*"
} else {
    $AppName
}

Write-Log "Searching registry with filter: '$nameFilter'"

$matches = Get-RegistryUninstallEntries -DisplayNameFilter $nameFilter -Exact $ExactMatch.IsPresent

if ($matches.Count -eq 0) {
    Write-Log "No application found matching '$nameFilter'. Exiting." -Level "WARN"
    Exit 0
}

Write-Log "Found $($matches.Count) match(es):"
$matches | ForEach-Object { Write-Log "  - '$($_.DisplayName)' v$($_.DisplayVersion) [$($_.Publisher)]" }

if ($matches.Count -gt 1 -and -not $UninstallAll) {
    Write-Log "Multiple matches found and -UninstallAll was not specified." -Level "WARN"
    Write-Log "Re-run with a more specific name or add -UninstallAll to remove all matches." -Level "WARN"
    Write-Log "Matched names:"
    $matches | ForEach-Object { Write-Log "  '$($_.DisplayName)'" -Level "WARN" }
    Exit 2
}

#endregion

#region ── Installer Type Detection ────────────────────────────────────────────

function Get-InstallerType {
    <#
    Detection order:
      1. Registry key suffix _is1  → Inno Setup
      2. WindowsInstaller = 1      → MSI (WI)
      3. UninstallString contains msiexec → MSI
      4. File version info of the uninstaller EXE
      5. Unknown
    #>
    param (
        [PSObject]$Entry,
        [string]$ExePath
    )

    # Inno Setup keys always end in _is1
    if ($Entry.RegistryKeyName -match '_is1$') {
        return "InnoSetup"
    }

    # Windows Installer flag in registry
    if ($Entry.WindowsInstaller -eq 1) {
        return "MSI"
    }

    # msiexec in string
    if ($Entry.UninstallString -imatch 'msiexec') {
        return "MSI"
    }

    # Inspect the EXE file version info
    if ($ExePath -and (Test-Path $ExePath)) {
        try {
            $vi      = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExePath)
            $vString = "$($vi.FileDescription)|$($vi.ProductName)|$($vi.CompanyName)|$($vi.Comments)".ToLower()

            if ($vString -match 'nullsoft|nsis')              { return "NSIS" }
            if ($vString -match 'inno setup|innosetup')       { return "InnoSetup" }
            if ($vString -match 'installshield')               { return "InstallShield" }
            if ($vString -match '\bwise\b')                    { return "Wise" }
            if ($vString -match 'squirrel')                    { return "Squirrel" }
            if ($vString -match 'advanced installer')          { return "AdvancedInstaller" }
            if ($vString -match 'wix|windows installer xml')  { return "MSI" }
        } catch {
            # file version read failed — continue to Unknown
        }
    }

    return "Unknown"
}

function Add-SilentFlags {
    <#
    Given an installer type and an existing uninstall command string,
    returns the executable and argument list that should produce a silent uninstall.
    #>
    param (
        [string]$InstallerType,
        [string]$Executable,
        [string]$Arguments
    )

    switch ($InstallerType) {

        "MSI" {
            # Normalise: /I (install) → /X (uninstall), add /qn /norestart
            $Arguments = $Arguments -ireplace '/I\{', '/X{'
            $Arguments = $Arguments -ireplace '/I "\{', '/X "{'
            if ($Arguments -notmatch '/qn|/quiet')     { $Arguments += " /qn" }
            if ($Arguments -notmatch '/norestart')      { $Arguments += " /norestart" }
            # Ensure REBOOT=ReallySuppress for good measure on some MSIs
            if ($Arguments -notmatch 'REBOOT')          { $Arguments += " REBOOT=ReallySuppress" }
        }

        "NSIS" {
            # /S is CASE-SENSITIVE in NSIS — must be uppercase
            if ($Arguments -cnotmatch '/S') { $Arguments = "/S $Arguments" }
        }

        "InnoSetup" {
            # /VERYSILENT suppresses all dialogs; /NORESTART prevents reboot
            $flags = @()
            if ($Arguments -notmatch '/VERYSILENT')       { $flags += "/VERYSILENT" }
            if ($Arguments -notmatch '/SUPPRESSMSGBOXES') { $flags += "/SUPPRESSMSGBOXES" }
            if ($Arguments -notmatch '/NORESTART')        { $flags += "/NORESTART" }
            if ($Arguments -notmatch '/SP-')              { $flags += "/SP-" }
            if ($flags) { $Arguments = "$Arguments $($flags -join ' ')" }
        }

        "InstallShield" {
            # /s = silent, /sms = synchronous (waits for completion)
            # Works for both InstallScript and Basic MSI EXE wrappers
            if ($Arguments -notmatch '\s/s(\s|$)') { $Arguments = "/s $Arguments" }
            if ($Arguments -notmatch '/sms')        { $Arguments += " /sms" }
        }

        "Wise" {
            if ($Arguments -cnotmatch '/S') { $Arguments = "/S $Arguments" }
        }

        "Squirrel" {
            # Squirrel-based apps (Slack, Teams classic, etc.)
            # UninstallString is usually: Update.exe --uninstall
            if ($Arguments -notmatch '--uninstall') { $Arguments += " --uninstall" }
            if ($Arguments -notmatch '--silent')    { $Arguments += " --silent" }
        }

        "AdvancedInstaller" {
            if ($Arguments -notmatch '/exenoui') { $Arguments += " /exenoui" }
            if ($Arguments -notmatch '/qn')      { $Arguments += " /qn" }
            if ($Arguments -notmatch '/norestart') { $Arguments += " /norestart" }
        }

        "Unknown" {
            # Best-effort: many EXE uninstallers respond to at least one of these
            # We log a warning but run as-is; QuietUninstallString path avoids this entirely
            Write-Log "Installer type unknown — running UninstallString as-is. Silent uninstall is not guaranteed." -Level "WARN"
        }
    }

    return $Arguments.Trim()
}

#endregion

#region ── Command Parser ───────────────────────────────────────────────────────

function Parse-CommandLine {
    param ([string]$CommandLine)

    $CommandLine = $CommandLine.Trim()

    if ($CommandLine -match '^"([^"]+)"\s*(.*)$') {
        return @{ Executable = $Matches[1].Trim(); Arguments = $Matches[2].Trim() }
    }
    elseif ($CommandLine -match '^(\S+)\s*(.*)$') {
        return @{ Executable = $Matches[1].Trim(); Arguments = $Matches[2].Trim() }
    }
    else {
        throw "Unable to parse command line: $CommandLine"
    }
}

#endregion

#region ── Uninstall Executor ───────────────────────────────────────────────────

function Invoke-Uninstall {
    param (
        [PSObject]$Entry
    )

    Write-Log "------------------------------------------------------"
    Write-Log "Processing: '$($Entry.DisplayName)' v$($Entry.DisplayVersion)"

    # ── Select the best uninstall string ──────────────────────────────────────
    $selectedString = $null
    $stringSource   = ""

    if ($Entry.QuietUninstallString) {
        $selectedString = $Entry.QuietUninstallString
        $stringSource   = "QuietUninstallString"
    }
    elseif ($Entry.SilentUninstallString) {
        $selectedString = $Entry.SilentUninstallString
        $stringSource   = "SilentUninstallString"
    }
    elseif ($Entry.UninstallString) {
        $selectedString = $Entry.UninstallString
        $stringSource   = "UninstallString (will augment with silent flags)"
    }
    else {
        Write-Log "No uninstall string found for '$($Entry.DisplayName)'. Skipping." -Level "ERROR"
        return 1
    }

    Write-Log "String source : $stringSource"
    Write-Log "Raw string    : $selectedString"

    # ── Parse into executable + arguments ─────────────────────────────────────
    try {
        $parsed = Parse-CommandLine -CommandLine $selectedString
    }
    catch {
        Write-Log "Failed to parse command line: $_" -Level "ERROR"
        return 1
    }

    $exe  = $parsed.Executable
    $args = $parsed.Arguments

    # ── If using plain UninstallString, detect type and augment flags ──────────
    if ($stringSource -eq "UninstallString (will augment with silent flags)") {
        $installerType = Get-InstallerType -Entry $Entry -ExePath $exe
        Write-Log "Detected installer type: $installerType"
        $args = Add-SilentFlags -InstallerType $installerType -Executable $exe -Arguments $args
    }

    Write-Log "Executable    : $exe"
    Write-Log "Arguments     : $args"

    # ── msiexec special handling: call directly, not via Start-Process filepath ─
    $isMsi = ($exe -imatch 'msiexec')

    # ── Execute ───────────────────────────────────────────────────────────────
    try {
        if ($isMsi) {
            # msiexec arguments include everything; safest to call cmd /c
            Write-Log "Invoking MSI uninstall via msiexec..."
            $procArgs = $args
            $process  = Start-Process -FilePath "msiexec.exe" `
                                      -ArgumentList $procArgs `
                                      -Wait:$WaitForExit `
                                      -PassThru `
                                      -ErrorAction Stop
        }
        else {
            if ($args) {
                $process = Start-Process -FilePath $exe `
                                         -ArgumentList $args `
                                         -Wait:$WaitForExit `
                                         -PassThru `
                                         -ErrorAction Stop
            }
            else {
                $process = Start-Process -FilePath $exe `
                                         -Wait:$WaitForExit `
                                         -PassThru `
                                         -ErrorAction Stop
            }
        }

        if ($WaitForExit) {
            # If -Wait was used, WaitForExit already happened inside Start-Process
            $exitCode = $process.ExitCode
            Write-Log "Uninstall completed. Exit code: $exitCode"

            # Common success codes
            $successCodes = @(0, 3010, 1605, 1614)   # 3010 = reboot required (soft), 1605/1614 = product not found (already gone)
            if ($exitCode -in $successCodes) {
                Write-Log "Exit code $exitCode is considered successful." 
            }
            else {
                Write-Log "Exit code $exitCode may indicate a problem. Check vendor documentation." -Level "WARN"
            }

            return $exitCode
        }
        else {
            Write-Log "Uninstall process launched (PID: $($process.Id)). Not waiting for completion as per -WaitForExit:`$false."
            return 0
        }
    }
    catch {
        Write-Log "Exception during uninstall: $_" -Level "ERROR"
        return 1
    }
}

#endregion

#region ── Main Loop ───────────────────────────────────────────────────────────

$overallExitCode = 0

foreach ($app in $matches) {
    $result = Invoke-Uninstall -Entry $app

    if ($result -notin @(0, 3010, 1605, 1614)) {
        $overallExitCode = $result
        Write-Log "Uninstall of '$($app.DisplayName)' returned non-success code: $result" -Level "WARN"
    }
}

Write-Log "======================================================"
Write-Log "Invoke-SilentUninstall finished. Overall exit code: $overallExitCode"
Write-Log "======================================================"

Exit $overallExitCode

#endregion
