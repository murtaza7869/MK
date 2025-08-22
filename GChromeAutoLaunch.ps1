# Chrome Auto-Launch Setup Script for Windows 11
# This script sets Google Chrome to auto-launch at startup for all users
# Run this script as Administrator

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Function to find Chrome installation path
function Get-ChromePath {
    $chromePaths = @(
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "${env:LocalAppData}\Google\Chrome\Application\chrome.exe"
    )
    
    foreach ($path in $chromePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Try to find Chrome via registry
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
    )
    
    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            $chromePath = (Get-ItemProperty -Path $regPath -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)"
            if ($chromePath -and (Test-Path $chromePath)) {
                return $chromePath
            }
        }
    }
    
    return $null
}

# Main script
Write-Host "Chrome Auto-Launch Setup Script" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Find Chrome installation
$chromePath = Get-ChromePath

if (-not $chromePath) {
    Write-Host "Google Chrome installation not found. Please install Chrome first." -ForegroundColor Red
    exit 1
}

Write-Host "Chrome found at: $chromePath" -ForegroundColor Green
Write-Host ""

# Method selection
Write-Host "Select setup method:" -ForegroundColor Yellow
Write-Host "1. Registry Run key (Recommended - applies to all users)"
Write-Host "2. Startup folder (All Users)"
Write-Host "3. Both methods (Maximum reliability)"
Write-Host "4. Group Policy (Domain environments)"
Write-Host ""

$method = Read-Host "Enter your choice (1-4)"

# Method 1: Registry Run key for all users
if ($method -eq "1" -or $method -eq "3") {
    Write-Host ""
    Write-Host "Setting up Registry Run key..." -ForegroundColor Yellow
    
    try {
        # Add to HKLM Run key (applies to all users)
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        Set-ItemProperty -Path $regPath -Name "GoogleChrome" -Value "`"$chromePath`"" -Type String
        Write-Host "✓ Registry Run key added successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to add Registry Run key: $_" -ForegroundColor Red
    }
}

# Method 2: Startup folder for all users
if ($method -eq "2" -or $method -eq "3") {
    Write-Host ""
    Write-Host "Setting up Startup folder shortcut..." -ForegroundColor Yellow
    
    try {
        # Create shortcut in All Users startup folder
        $startupPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
        $shortcutPath = Join-Path $startupPath "Google Chrome.lnk"
        
        # Create shortcut
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = $chromePath
        $Shortcut.WorkingDirectory = Split-Path $chromePath
        $Shortcut.IconLocation = "$chromePath,0"
        $Shortcut.Description = "Google Chrome Web Browser"
        $Shortcut.Save()
        
        # Release COM object
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
        
        Write-Host "✓ Startup folder shortcut created successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to create startup shortcut: $_" -ForegroundColor Red
    }
}

# Method 4: Group Policy (for domain environments)
if ($method -eq "4") {
    Write-Host ""
    Write-Host "Group Policy Setup Instructions:" -ForegroundColor Yellow
    Write-Host "1. Open Group Policy Editor (gpedit.msc)"
    Write-Host "2. Navigate to: User Configuration > Windows Settings > Scripts (Logon/Logoff)"
    Write-Host "3. Double-click 'Logon'"
    Write-Host "4. Click 'Add' and browse to: $chromePath"
    Write-Host "5. Click OK to save"
    Write-Host ""
    Write-Host "Note: This method requires Group Policy Editor access" -ForegroundColor Cyan
    
    # Optionally create a logon script
    $createScript = Read-Host "Would you like to create a logon script file? (Y/N)"
    if ($createScript -eq "Y" -or $createScript -eq "y") {
        $scriptPath = "$env:SystemRoot\System32\GroupPolicy\User\Scripts\Logon\chrome_launch.bat"
        $scriptDir = Split-Path $scriptPath
        
        if (-not (Test-Path $scriptDir)) {
            New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
        }
        
        @"
@echo off
start "" "$chromePath"
"@ | Out-File -FilePath $scriptPath -Encoding ASCII
        
        Write-Host "✓ Logon script created at: $scriptPath" -ForegroundColor Green
        Write-Host "Add this script in Group Policy Editor" -ForegroundColor Yellow
    }
}

# Verification
Write-Host ""
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Verification Steps:" -ForegroundColor Cyan
Write-Host "1. Restart the computer"
Write-Host "2. Log in with any user account"
Write-Host "3. Chrome should launch automatically"
Write-Host ""

# Option to remove auto-launch
Write-Host "To remove auto-launch later, run this script with -Remove parameter" -ForegroundColor Yellow
Write-Host ""

# Remove functionality
if ($args[0] -eq "-Remove") {
    Write-Host "Removing Chrome auto-launch..." -ForegroundColor Yellow
    
    # Remove registry entry
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "GoogleChrome" -ErrorAction SilentlyContinue
        Write-Host "✓ Registry entry removed" -ForegroundColor Green
    }
    catch {
        Write-Host "Registry entry not found or already removed" -ForegroundColor Yellow
    }
    
    # Remove startup shortcut
    $shortcutPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Google Chrome.lnk"
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
        Write-Host "✓ Startup shortcut removed" -ForegroundColor Green
    }
    else {
        Write-Host "Startup shortcut not found or already removed" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Chrome auto-launch has been disabled" -ForegroundColor Green
}
