# Script to remove all UWP app packages for all users
Write-Host "Starting UWP app cleanup..." -ForegroundColor Green

# Function to remove Appx packages for all users
function Remove-AppxPackages {
    $appPackages = Get-AppxPackage -AllUsers
    foreach ($app in $appPackages) {
        try {
            Write-Host "Removing AppxPackage: $($app.Name)" -ForegroundColor Yellow
            Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction Stop
        } catch {
            Write-Host "Failed to remove $($app.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Function to remove provisioned Appx packages
function Remove-ProvisionedAppxPackages {
    $provisionedPackages = Get-AppxProvisionedPackage -Online
    foreach ($package in $provisionedPackages) {
        try {
            Write-Host "Removing Provisioned AppxPackage: $($package.PackageName)" -ForegroundColor Yellow
            Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop
        } catch {
            Write-Host "Failed to remove provisioned package $($package.PackageName): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Disable development mode for UWP apps
Write-Host "Resetting all UWP apps to default state..." -ForegroundColor Cyan
Get-AppxPackage -AllUsers | ForEach-Object {
    try {
        Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppxManifest.xml" -ErrorAction Stop
    } catch {
        Write-Host "Failed to reset $($_.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Remove all UWP apps for all users
Write-Host "Removing all installed Appx packages for all users..." -ForegroundColor Cyan
Remove-AppxPackages

# Remove all provisioned packages
Write-Host "Removing all provisioned Appx packages..." -ForegroundColor Cyan
Remove-ProvisionedAppxPackages

# Final cleanup
Write-Host "Cleaning up UWP remnants from the registry..." -ForegroundColor Cyan
Start-Process regedit.exe -ArgumentList "/e, HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore"

Write-Host "UWP app cleanup completed. Reboot the system before running Sysprep." -ForegroundColor Green
