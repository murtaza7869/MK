# Must be run as administrator
# This script disables Delivery Optimization and forces direct downloads from Microsoft

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires administrator privileges. Please run as administrator."
    exit
}

Write-Host "Disabling Windows Update Delivery Optimization..." -ForegroundColor Green

# Set Delivery Optimization download mode to 0 (HTTP Only - No peering)
# 0 = HTTP Only (no peering)
# 1 = HTTP with peering behind same NAT
# 2 = HTTP with peering across private group
# 3 = HTTP with Internet peering
# 99 = Simple download mode with no peering
# 100 = Bypass mode

# Method 1: Using registry
try {
    # Set the download mode to HTTP Only (0)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0 -Type DWord -Force
    
    # Disable all peering options
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DownloadModeProvider" -Value 8 -Type DWord -Force
    
    # If the above registry key doesn't exist, create it
    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Force | Out-Null
    }
    
    # Set policy to HTTP only
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0 -Type DWord -Force
    
    Write-Host "Delivery Optimization settings changed via registry." -ForegroundColor Yellow
} catch {
    Write-Host "Error changing registry settings: $_" -ForegroundColor Red
}

# Method 2: Using Group Policy cmdlets (if available)
try {
    if (Get-Command Set-DeliveryOptimizationConfig -ErrorAction SilentlyContinue) {
        Set-DeliveryOptimizationConfig -DownloadMode 0
        Write-Host "Delivery Optimization settings changed via cmdlet." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Delivery Optimization cmdlet not available. Registry method was used instead." -ForegroundColor Yellow
}

# Restart the Delivery Optimization service to apply changes
try {
    Stop-Service -Name "DoSvc" -Force
    Start-Service -Name "DoSvc"
    Write-Host "Delivery Optimization service restarted." -ForegroundColor Green
} catch {
    Write-Host "Error restarting Delivery Optimization service: $_" -ForegroundColor Red
}

Write-Host "Script completed. Windows updates will now download directly from Microsoft servers." -ForegroundColor Cyan
Write-Host "You may need to restart your computer for all changes to take effect." -ForegroundColor Cyan
