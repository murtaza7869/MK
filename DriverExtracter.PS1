<# 
.SYNOPSIS
  Export only networking and storage drivers (from the Driver Store) for WinPE.

.PARAMETER Destination
  Where to export the drivers (a new folder is fine).

.PARAMETER IncludeMsInBox
  Include Microsoft in-box drivers (default: $false). Usually you only need 3rd-party.

.EXAMPLE
  .\Export-BootCriticalDrivers.ps1 -Destination "D:\BootCriticalDrivers"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Destination,
    [switch]$IncludeMsInBox
)

# Must be admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Run this script in an elevated PowerShell session."
    exit 1
}

# Create destination
New-Item -Path $Destination -ItemType Directory -Force | Out-Null

# Driver classes we care about
$classes = @('Net','SCSIAdapter','HDC')   # NICs, RAID/HBA/NVMe, IDE/AHCI

# Get driver packages known to DISM (Get-WindowsDriver shows packages, not just live devices)
$drivers = Get-WindowsDriver -Online -All | Where-Object {
    $_.ClassName -in $classes -and $_.Driver -match '^oem\d+\.inf$'
}

if (-not $IncludeMsInBox) {
    # Filter out in-box Microsoft drivers (typically ProviderName "Microsoft" and ClassName still matches)
    $drivers = $drivers | Where-Object { $_.ProviderName -ne 'Microsoft' }
}

if (-not $drivers) {
    Write-Warning "No matching driver packages found with the current filters."
    return
}

# Export each package via pnputil (most robust way to get full package with catalog + binaries)
$infRoot = Join-Path $env:windir 'INF'
$exported = @()

foreach ($d in $drivers | Sort-Object Driver -Unique) {
    $infPath = Join-Path $infRoot $d.Driver
    $classDir = Join-Path $Destination $d.ClassName
    New-Item -Path $classDir -ItemType Directory -Force | Out-Null

    Write-Host "Exporting $($d.Driver) [$($d.ClassName)] from $($d.ProviderName)..." -ForegroundColor Cyan
    $p = Start-Process -FilePath pnputil.exe -ArgumentList @('/export-driver', $infPath, $classDir) -NoNewWindow -PassThru -Wait
    if ($p.ExitCode -eq 0) {
        $exported += [pscustomobject]@{
            INF          = $d.Driver
            Class        = $d.ClassName
            Provider     = $d.ProviderName
            Version      = $d.Version
            Date         = $d.Date
            ExportFolder = $classDir
        }
    } else {
        Write-Warning "Failed exporting $($d.Driver) (exit $($p.ExitCode))."
    }
}

# Summary
$exported | Format-Table -AutoSize
Write-Host "`nDone. Exported to: $Destination"
