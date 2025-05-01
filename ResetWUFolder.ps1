# Run as Administrator

Write-Host "Stopping Windows Update services..." -ForegroundColor Yellow
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue

# Rename SoftwareDistribution and Catroot2
$sdPath = "$env:SystemRoot\SoftwareDistribution"
$catroot2Path = "$env:SystemRoot\System32\catroot2"

$timestamp = Get-Date -Format "yyyyMMddHHmmss"

if (Test-Path $sdPath) {
    Rename-Item -Path $sdPath -NewName ("SoftwareDistribution.old." + $timestamp) -Force
    Write-Host "Renamed SoftwareDistribution folder." -ForegroundColor Green
}

if (Test-Path $catroot2Path) {
    Rename-Item -Path $catroot2Path -NewName ("catroot2.old." + $timestamp) -Force
    Write-Host "Renamed catroot2 folder." -ForegroundColor Green
}

# Restart services
Write-Host "Restarting Windows Update services..." -ForegroundColor Yellow
Start-Service -Name wuauserv
Start-Service -Name bits
Start-Service -Name cryptsvc

Write-Host "`nWindows Update components reset. Please restart the computer and try checking for updates again." -ForegroundColor Cyan
