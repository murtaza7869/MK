<#
.SYNOPSIS
    Deep Freeze Cloud / Data Igloo - Thawed Profile Maintenance Script

.DESCRIPTION
    Two modes controlled by -Mode parameter:

    -Mode Setup    : Run ONCE per machine (e.g. via RMM at image build time or first deployment).
                      - Applies registry tweaks to speed up first-time profile creation
                      - Disables OneDrive auto-provisioning, consumer features, first logon animation
                      - Removes bloat provisioned Appx packages
                      - Creates a Scheduled Task that fires the cleanup routine on profile unload
                      - Writes a marker file so it will not re-run Setup accidentally

    -Mode Cleanup  : Run at logoff (via GPO logoff script) or via the Scheduled Task created by
                      -Mode Setup (fires on profile unload event, runs as SYSTEM).
                      - Deletes user-session-generated content only
                      - Leaves NTUSER.DAT, UsrClass.dat, and folder structure intact

.NOTES
    - ASCII only, no Unicode characters (RMM-safe)
    - Non-interactive, no prompts
    - Structured exit codes:
        0  = success
        1  = partial failure (some items could not be removed / some tweaks failed)
        2  = invalid parameters or unsupported context
        3  = setup already applied (Setup mode only, informational, not an error)
    - Designed to run under SYSTEM context where noted

.PARAMETER Mode
    "Setup" or "Cleanup"

.PARAMETER LogPath
    Optional override for log file location. Defaults to C:\ProgramData\Faronics\ProfileMaintenance\logs

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File DFC-ProfileCleanup-Setup.ps1 -Mode Setup

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File DFC-ProfileCleanup-Setup.ps1 -Mode Cleanup
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Setup", "Cleanup")]
    [string]$Mode,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\ProgramData\Faronics\ProfileMaintenance\logs"
)

$ErrorActionPreference = "SilentlyContinue"
$script:HadFailure = $false

# ----------------------------------------------------------------------------------
# Logging helper
# ----------------------------------------------------------------------------------
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Write-Output $line
    try {
        if (-not (Test-Path $LogPath)) {
            New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
        }
        $logFile = Join-Path $LogPath ("ProfileMaintenance_" + (Get-Date -Format "yyyyMMdd") + ".log")
        Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue
    }
    catch {
        # Logging failure should never break the script
    }
}

# ----------------------------------------------------------------------------------
# MODE: SETUP  (run once per machine / at image build time)
# ----------------------------------------------------------------------------------
function Invoke-Setup {

    $installDir = "C:\ProgramData\Faronics\ProfileMaintenance"
    $installedScriptName = "DFC-ProfileCleanup.ps1"
    $installedScriptPath = Join-Path $installDir $installedScriptName
    $markerFile = Join-Path $installDir "setup_complete.marker"

    if (-not (Test-Path $installDir)) {
        New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    }

    # Always copy/refresh the script into the persistent ProgramData location, regardless of the
    # marker check below. RMM tools typically download and run the script from C:\Windows\Temp
    # under a transient GUID filename, which is not safe to point a long-lived scheduled task at -
    # anything that clears Temp (cleanup utilities, disk cleanup policies, etc.) would silently
    # break the logoff cleanup task. Copying it to ProgramData first, and pointing the scheduled
    # task at that copy, decouples the task from wherever the RMM happened to stage the script.
    # This also means re-pushing an updated script via RMM refreshes the persistent copy even if
    # Setup has already run once on this machine.
    $sourceScriptPath = $PSCommandPath
    if (-not $sourceScriptPath) {
        $sourceScriptPath = $MyInvocation.MyCommand.Path
    }

    try {
        if ($sourceScriptPath -and (Test-Path $sourceScriptPath) -and ($sourceScriptPath -ne $installedScriptPath)) {
            Copy-Item -Path $sourceScriptPath -Destination $installedScriptPath -Force
            Write-Log "Copied script to persistent location: $installedScriptPath" "INFO"
        }
        elseif ($sourceScriptPath -eq $installedScriptPath) {
            Write-Log "Already running from persistent location: $installedScriptPath" "INFO"
        }
        else {
            Write-Log "Could not determine source script path to copy. Scheduled task will be created pointing at $installedScriptPath - verify this file exists before relying on it." "WARN"
            $script:HadFailure = $true
        }
    }
    catch {
        Write-Log "Failed to copy script to persistent location: $($_.Exception.Message)" "WARN"
        $script:HadFailure = $true
    }

    if (Test-Path $markerFile) {
        Write-Log "Setup marker found at $markerFile. Setup has already been applied on this machine." "INFO"
        Write-Log "Delete the marker file and re-run with -Mode Setup if you need to force re-apply." "INFO"
        exit 3
    }

    Write-Log "Starting Setup mode." "INFO"

    # ---- 1. Registry tweaks: skip first logon animation ----
    try {
        $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        if (-not (Test-Path $winlogonPath)) { New-Item -Path $winlogonPath -Force | Out-Null }
        New-ItemProperty -Path $winlogonPath -Name "EnableFirstLogonAnimation" -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Log "Disabled first logon animation." "INFO"
    }
    catch {
        Write-Log "Failed to disable first logon animation: $($_.Exception.Message)" "WARN"
        $script:HadFailure = $true
    }

    # ---- 2. Disable Windows Consumer Features (stops Store app re-provisioning) ----
    try {
        $cloudContentPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        if (-not (Test-Path $cloudContentPath)) { New-Item -Path $cloudContentPath -Force | Out-Null }
        New-ItemProperty -Path $cloudContentPath -Name "DisableWindowsConsumerFeatures" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $cloudContentPath -Name "DisableSoftLanding" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $cloudContentPath -Name "DisableWindowsSpotlightFeatures" -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Log "Disabled Windows consumer features and Spotlight suggestions." "INFO"
    }
    catch {
        Write-Log "Failed to set CloudContent policies: $($_.Exception.Message)" "WARN"
        $script:HadFailure = $true
    }

    # ---- 3. Prevent OneDrive from provisioning into new profiles ----
    try {
        $oneDrivePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        if (-not (Test-Path $oneDrivePolicyPath)) { New-Item -Path $oneDrivePolicyPath -Force | Out-Null }
        New-ItemProperty -Path $oneDrivePolicyPath -Name "DisableFileSyncNGSC" -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Log "Disabled OneDrive file sync / provisioning policy." "INFO"

        # Remove per-machine run key that triggers OneDriveSetup.exe for each new profile
        $runKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
        )
        foreach ($rk in $runKeys) {
            if (Test-Path $rk) {
                Remove-ItemProperty -Path $rk -Name "OneDriveSetup" -ErrorAction SilentlyContinue
            }
        }
        Write-Log "Removed OneDriveSetup auto-run entries if present." "INFO"
    }
    catch {
        Write-Log "Failed to disable OneDrive provisioning: $($_.Exception.Message)" "WARN"
        $script:HadFailure = $true
    }

    # ---- 4. Remove bloat provisioned Appx packages (machine-wide, applies to all future profiles) ----
    # Get-AppxProvisionedPackage calls into the DISM servicing API, which can hang indefinitely if a
    # reboot is pending or the servicing stack (TiWorker.exe) is holding a lock. Run it as a background
    # job with a hard timeout so a stuck DISM call cannot freeze the whole Setup run.
    try {
        $appxStartTime = Get-Date

        # Check for a pending reboot first - this is the most common cause of a DISM hang, and a
        # reboot is cheap to detect vs. discovering it via a multi-minute timeout.
        $rebootPendingPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
        if (Test-Path $rebootPendingPath) {
            Write-Log "A Windows servicing reboot is pending on this machine. Skipping Appx cleanup for this run to avoid a DISM lock hang. Reboot the machine and re-run -Mode Setup after deleting the setup marker." "WARN"
            $script:HadFailure = $true
        }
        else {
            $bloatPatterns = @(
                "Xbox", "Solitaire", "MicrosoftOfficeHub", "People", "SkypeApp",
                "GetHelp", "Getstarted", "YourPhone", "MixedReality", "3DBuilder",
                "BingWeather", "BingNews", "BingFinance", "ZuneMusic", "ZuneVideo",
                "WindowsFeedbackHub", "MicrosoftStickyNotes", "MicrosoftSolitaireCollection"
            )

            $appxJob = Start-Job -ScriptBlock { Get-AppxProvisionedPackage -Online }
            $completed = Wait-Job -Job $appxJob -Timeout 120

            if (-not $completed) {
                Write-Log "Get-AppxProvisionedPackage did not return within 120 seconds. This usually means a DISM servicing lock (pending reboot or stuck TiWorker.exe). Aborting Appx cleanup for this run - check C:\Windows\Logs\DISM\dism.log and consider rebooting before retrying Setup." "WARN"
                Stop-Job -Job $appxJob -ErrorAction SilentlyContinue
                Remove-Job -Job $appxJob -Force -ErrorAction SilentlyContinue
                $script:HadFailure = $true
            }
            else {
                $provisioned = Receive-Job -Job $appxJob
                Remove-Job -Job $appxJob -Force -ErrorAction SilentlyContinue

                $removed = 0
                $removedNames = @()
                foreach ($pkg in $provisioned) {
                    foreach ($pattern in $bloatPatterns) {
                        if ($pkg.DisplayName -match $pattern) {
                            try {
                                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                                $removed++
                                $removedNames += $pkg.DisplayName
                                Write-Log "Removed provisioned package: $($pkg.DisplayName) (version $($pkg.Version))" "INFO"
                            }
                            catch {
                                Write-Log "Could not remove provisioned package $($pkg.DisplayName): $($_.Exception.Message)" "WARN"
                            }
                            break
                        }
                    }
                }
                Write-Log "Appx cleanup summary: removed $removed bloat provisioned package(s)." "INFO"
                if ($removedNames.Count -gt 0) {
                    Write-Log ("Removed package list: " + ($removedNames -join ", ")) "INFO"
                }
            }
        }

        $appxElapsed = (Get-Date) - $appxStartTime
        Write-Log ("Appx cleanup step took " + [math]::Round($appxElapsed.TotalSeconds, 1) + " seconds.") "INFO"
    }
    catch {
        Write-Log "Appx cleanup step failed: $($_.Exception.Message)" "WARN"
        $script:HadFailure = $true
    }

    # ---- 5. Create Scheduled Task that runs Cleanup mode on profile unload (Event ID 4, User Profile Service) ----
    try {
        $taskName = "Faronics-ProfileCleanupOnLogoff"

        # Remove existing task if present, so re-running Setup is idempotent
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installedScriptPath`" -Mode Cleanup"

        # Trigger on User Profile Service event ID 4 (profile unloaded), Microsoft-Windows-User Profile Service log
        # Build the CIM trigger instance first, then pass it directly into New-ScheduledTask via -Trigger.
        # (New-ScheduledTask leaves .Triggers as $null when no -Trigger is supplied, so appending
        # after the fact with .Triggers.Add() fails with "cannot call a method on a null-valued expression".)
        $CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace "Root/Microsoft/Windows/TaskScheduler"
        if (-not $CIMTriggerClass) {
            throw "Could not load MSFT_TaskEventTrigger CIM class."
        }
        $trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
        $trigger.Subscription =
            '<QueryList><Query Id="0" Path="Microsoft-Windows-User Profile Service/Operational">' +
            '<Select Path="Microsoft-Windows-User Profile Service/Operational">*[System[(EventID=4)]]</Select>' +
            '</Query></QueryList>'
        $trigger.Enabled = $true
        # Small delay so file locks release before cleanup runs
        $trigger.Delay = "PT15S"

        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances Queue

        $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings

        Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null

        Write-Log "Scheduled task '$taskName' created, triggered on profile unload event (Event ID 4), runs as SYSTEM." "INFO"
    }
    catch {
        Write-Log "Failed to create scheduled task: $($_.Exception.Message)" "WARN"
        $script:HadFailure = $true
    }

    # ---- 6. Write marker so Setup does not re-run unintentionally ----
    try {
        Set-Content -Path $markerFile -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "Failed to write setup marker file: $($_.Exception.Message)" "WARN"
    }

    Write-Log "Setup mode complete." "INFO"

    if ($script:HadFailure) {
        exit 1
    } else {
        exit 0
    }
}

# ----------------------------------------------------------------------------------
# MODE: CLEANUP  (run at logoff via GPO logoff script, or via scheduled task on profile unload)
# ----------------------------------------------------------------------------------
function Invoke-Cleanup {

    Write-Log "Starting Cleanup mode." "INFO"

    # When triggered by the SYSTEM-context scheduled task, USERPROFILE / env vars point to the
    # SYSTEM profile, not the student's profile. Resolve the most recently modified profile folder
    # instead so this works correctly whether invoked as a GPO logoff script (user context) or
    # as the scheduled task (SYSTEM context).

    $runningAsSystem = ([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)

    $profilesToClean = @()

    if ($runningAsSystem) {
        Write-Log "Running under SYSTEM context. Resolving target profile(s) under C:\Users." "INFO"
        $excluded = @("Public", "Default", "Default User", "All Users", "SYSTEM", "LocalService", "NetworkService")
        $candidates = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $excluded -notcontains $_.Name }

        # Pick profile(s) unloaded most recently (last write time on NTUSER.DAT is a reasonable proxy)
        $recent = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($recent) {
            $profilesToClean += $recent.FullName
        }
    }
    else {
        Write-Log "Running under user context: $env:USERPROFILE" "INFO"
        $profilesToClean += $env:USERPROFILE
    }

    if ($profilesToClean.Count -eq 0) {
        Write-Log "No target profile resolved. Nothing to clean." "WARN"
        exit 1
    }

    $subfoldersToWipe = @(
        "Downloads",
        "Documents",
        "Pictures",
        "Desktop",
        "Videos",
        "Music",
        "AppData\Local\Temp",
        "AppData\Roaming\Microsoft\Windows\Recent"
    )

    $browserCacheTargets = @(
        "AppData\Local\Microsoft\Edge\User Data\Default\Cache",
        "AppData\Local\Microsoft\Edge\User Data\Default\Code Cache",
        "AppData\Local\Microsoft\Edge\User Data\Default\GPUCache",
        "AppData\Local\Microsoft\Edge\User Data\Default\History",
        "AppData\Local\Microsoft\Edge\User Data\Default\Cookies",
        "AppData\Local\Microsoft\Edge\User Data\Default\Visited Links",
        "AppData\Local\Microsoft\Edge\User Data\Default\Login Data",
        "AppData\Local\Google\Chrome\User Data\Default\Cache",
        "AppData\Local\Google\Chrome\User Data\Default\Code Cache",
        "AppData\Local\Google\Chrome\User Data\Default\GPUCache",
        "AppData\Local\Google\Chrome\User Data\Default\History",
        "AppData\Local\Google\Chrome\User Data\Default\Cookies",
        "AppData\Local\Google\Chrome\User Data\Default\Visited Links",
        "AppData\Local\Google\Chrome\User Data\Default\Login Data",
        "AppData\Local\Mozilla\Firefox\Profiles"
    )

    foreach ($profilePath in $profilesToClean) {

        Write-Log "Cleaning profile: $profilePath" "INFO"

        foreach ($sub in $subfoldersToWipe) {
            $full = Join-Path $profilePath $sub
            if (Test-Path $full) {
                try {
                    Get-ChildItem -Path $full -Force -Recurse -ErrorAction SilentlyContinue |
                        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    Write-Log "Cleared contents of: $full" "INFO"
                }
                catch {
                    Write-Log "Failed to fully clear $full : $($_.Exception.Message)" "WARN"
                    $script:HadFailure = $true
                }
            }
        }

        foreach ($sub in $browserCacheTargets) {
            $full = Join-Path $profilePath $sub
            if (Test-Path $full) {
                try {
                    # Firefox Profiles folder contains a randomly-named subfolder; wipe cache/places
                    # inside it rather than deleting the profile folder name itself.
                    if ($sub -eq "AppData\Local\Mozilla\Firefox\Profiles") {
                        Get-ChildItem -Path $full -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                            $ffProfile = $_.FullName
                            @("cache2", "startupCache", "places.sqlite", "cookies.sqlite", "webappsstore.sqlite") | ForEach-Object {
                                $target = Join-Path $ffProfile $_
                                Remove-Item -Path $target -Force -Recurse -ErrorAction SilentlyContinue
                            }
                        }
                        Write-Log "Cleared Firefox cache/history data." "INFO"
                    }
                    else {
                        Remove-Item -Path $full -Force -Recurse -ErrorAction SilentlyContinue
                        Write-Log "Cleared: $full" "INFO"
                    }
                }
                catch {
                    Write-Log "Failed to clear $full : $($_.Exception.Message)" "WARN"
                    $script:HadFailure = $true
                }
            }
        }

        # Recycle bin (per-profile $Recycle.Bin entries are cleared machine-wide below)
    }

    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Log "Cleared recycle bin." "INFO"
    }
    catch {
        Write-Log "Failed to clear recycle bin: $($_.Exception.Message)" "WARN"
    }

    Write-Log "Cleanup mode complete." "INFO"

    if ($script:HadFailure) {
        exit 1
    } else {
        exit 0
    }
}

# ----------------------------------------------------------------------------------
# Entry point
# ----------------------------------------------------------------------------------
switch ($Mode) {
    "Setup"   { Invoke-Setup }
    "Cleanup" { Invoke-Cleanup }
    default   {
        Write-Log "Unknown mode specified: $Mode" "ERROR"
        exit 2
    }
}
