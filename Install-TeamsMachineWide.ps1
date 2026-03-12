#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Downloads and installs Microsoft Teams Machine-Wide Bootstrapper.
.DESCRIPTION
    Downloads the Teams Machine-Wide Installer bootstrapper and executes it
    with the -p flag for machine-wide provisioning. Designed to run under
    SYSTEM context via RMM.
#>

$ErrorActionPreference = 'Stop'

# --- Configuration ---
$DownloadURL  = 'https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409'
$InstallerPath = Join-Path $env:TEMP 'TeamsBootstrapper.exe'
$LogPath       = Join-Path $env:TEMP 'TeamsBootstrapper_Install.log'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $Entry = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $Entry | Tee-Object -FilePath $LogPath -Append | Out-Null
    Write-Output $Entry
}

try {
    Write-Log "Starting Teams Machine-Wide Bootstrapper installation."
    Write-Log "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"

    # --- Download ---
    Write-Log "Downloading bootstrapper from: $DownloadURL"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($DownloadURL, $InstallerPath)

    if (-not (Test-Path $InstallerPath)) {
        throw "Download failed - installer not found at: $InstallerPath"
    }

    $FileSize = (Get-Item $InstallerPath).Length
    Write-Log "Download complete. File size: $FileSize bytes."

    # --- Execute ---
    Write-Log "Executing bootstrapper with -p flag..."
    $ProcArgs = @{
        FilePath               = $InstallerPath
        ArgumentList           = '-p'
        Wait                   = $true
        PassThru               = $true
        NoNewWindow            = $true
    }
    $Process = Start-Process @ProcArgs
    $ExitCode = $Process.ExitCode
    Write-Log "Installer exited with code: $ExitCode"

    # --- Evaluate exit code ---
    # 0 = success, 1641/3010 = success + reboot pending
    switch ($ExitCode) {
        0    { Write-Log "Installation completed successfully." }
        1641 { Write-Log "Installation succeeded. Reboot initiated by installer." }
        3010 { Write-Log "Installation succeeded. Reboot required to complete setup." }
        default {
            throw "Installer returned unexpected exit code: $ExitCode"
        }
    }

    exit $ExitCode

} catch {
    Write-Log "ERROR: $_" -Level 'ERROR'
    exit 1

} finally {
    # --- Cleanup ---
    if (Test-Path $InstallerPath) {
        Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
        Write-Log "Cleaned up installer from temp."
    }
    Write-Log "Log saved to: $LogPath"
}
