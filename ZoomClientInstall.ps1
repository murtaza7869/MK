# Define the download URL and the installer path
$zoomInstallerUrl = "https://cdn.zoom.us/prod/6.2.5.48876/x64/ZoomInstallerFull.msi"
$zoomInstallerPath = "$env:TEMP\ZoomInstallerFull.msi"
$currentVersion = "6.2.48876"
$appDisplayName = "Zoom Workplace (64-bit)"

# Function to check if Zoom is installed
function Get-ZoomInstallInfo {
    $uninstallKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $zoomInfo = Get-ItemProperty -Path $uninstallKey | Where-Object { $_.DisplayName -eq $appDisplayName }
    return $zoomInfo
}

# Download the Zoom installer if needed
function Download-ZoomInstaller {
    Write-Host "Downloading Zoom installer..."
    Invoke-WebRequest -Uri $zoomInstallerUrl -OutFile $zoomInstallerPath
}

# Install or upgrade Zoom
function Install-Zoom {
    Write-Host "Installing Zoom Workspace client..."
    Start-Process msiexec.exe -ArgumentList "/i `"$zoomInstallerPath`" /quiet /norestart" -Wait
}

# Main logic
$zoomInstallInfo = Get-ZoomInstallInfo

if ($null -eq $zoomInstallInfo) {
    Write-Host "Zoom Workspace is not installed. Proceeding with installation."
    Download-ZoomInstaller
    Install-Zoom
} elseif ($zoomInstallInfo.DisplayVersion -eq $currentVersion) {
    Write-Host "Zoom Workspace version $currentVersion is already installed. Skipping installation."
} else {
    Write-Host "An older version of Zoom Workspace is installed. Upgrading to version $currentVersion."
    Download-ZoomInstaller
    Install-Zoom
}

# Cleanup the downloaded installer
if (Test-Path $zoomInstallerPath) {
    Remove-Item $zoomInstallerPath -Force
    Write-Host "Installer removed."
}

Write-Host "Zoom Workspace client installation script completed."
