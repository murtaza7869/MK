# Script to reset Windows Update components by deleting SoftwareDistribution folder
# Run this script as Administrator

# Create a backup of the SoftwareDistribution folder with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "C:\SoftwareDistribution_Backup_$timestamp"

Write-Host "Starting Windows Update reset process..." -ForegroundColor Green
Write-Host "This script will stop Windows Update services, rename the SoftwareDistribution folder, and restart services." -ForegroundColor Yellow

try {
    # Stop dependent services first
    Write-Host "Stopping dependent services..." -ForegroundColor Cyan
    Stop-Service -Name BITS -Force -ErrorAction SilentlyContinue
    Stop-Service -Name DoSvc -Force -ErrorAction SilentlyContinue
    Stop-Service -Name CryptSvc -Force -ErrorAction SilentlyContinue
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    
    # Wait a moment for services to fully stop
    Start-Sleep -Seconds 5
    
    # Check if services are stopped
    $services = @("BITS", "DoSvc", "CryptSvc", "wuauserv")
    foreach ($service in $services) {
        $status = (Get-Service -Name $service).Status
        if ($status -ne "Stopped") {
            Write-Host "Waiting for $service to stop completely..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    }
    
    # Create backup of SoftwareDistribution folder
    Write-Host "Creating backup of SoftwareDistribution folder to $backupPath..." -ForegroundColor Cyan
    if (Test-Path "C:\Windows\SoftwareDistribution") {
        Copy-Item -Path "C:\Windows\SoftwareDistribution" -Destination $backupPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Delete SoftwareDistribution folder
    Write-Host "Deleting SoftwareDistribution folder..." -ForegroundColor Cyan
    if (Test-Path "C:\Windows\SoftwareDistribution") {
        Remove-Item -Path "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clear Windows Update cache in registry
    Write-Host "Clearing Windows Update registry keys..." -ForegroundColor Cyan
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RequestedAppCategoriesForWindowsUpdate") {
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RequestedAppCategoriesForWindowsUpdate" -Force -ErrorAction SilentlyContinue
    }
    
    # Reset Winsock catalog
    Write-Host "Resetting Winsock catalog..." -ForegroundColor Cyan
    netsh winsock reset
    
    # Start services again
    Write-Host "Starting services again..." -ForegroundColor Cyan
    Start-Service -Name CryptSvc
    Start-Service -Name BITS
    Start-Service -Name DoSvc
    Start-Service -Name wuauserv
    
    Write-Host "Windows Update components have been reset successfully!" -ForegroundColor Green
    Write-Host "Please restart your computer and then try the Windows 11 24H2 upgrade again." -ForegroundColor Green
    Write-Host "A backup of your original SoftwareDistribution folder was created at: $backupPath" -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    Write-Host "Please try running this script as Administrator or restart and try again." -ForegroundColor Red
}
