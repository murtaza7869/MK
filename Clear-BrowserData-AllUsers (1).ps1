#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Clears browser cache, cookies, and stored data for Chrome and Edge across all user profiles
.DESCRIPTION
    This script removes browser cache, cookies, stored passwords, and other browsing data for 
    Google Chrome and Microsoft Edge browsers across all user profiles on the system.
    Designed to run under SYSTEM account through RMM tools.
.NOTES
    Author: System Administrator
    Date: January 2025
    Version: 1.0
#>

# Set error action preference
$ErrorActionPreference = 'SilentlyContinue'
$ConfirmPreference = 'None'  # Suppress all confirmation prompts for unattended execution

# Initialize counters and arrays for reporting
$script:TotalFilesDeleted = 0
$script:TotalSizeFreed = 0
$script:ProcessedUsers = @()
$script:FailedUsers = @()
$script:RunningBrowsers = @()

# Function to check if browsers are running
function Test-BrowserRunning {
    $chromeRunning = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    $edgeRunning = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
    
    if ($chromeRunning) {
        $script:RunningBrowsers += "Chrome"
        Write-Host "WARNING: Chrome is currently running. Some files may be locked." -ForegroundColor Yellow
    }
    if ($edgeRunning) {
        $script:RunningBrowsers += "Edge"
        Write-Host "WARNING: Edge is currently running. Some files may be locked." -ForegroundColor Yellow
    }
}

# Function to get size of folder
function Get-FolderSize {
    param([string]$Path)
    
    if (Test-Path $Path) {
        $size = (Get-ChildItem -Path $Path -Recurse -Force | 
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Round($size / 1MB, 2)
    }
    return 0
}

# Function to remove folder contents with retry logic
function Remove-FolderContents {
    param(
        [string]$Path,
        [string]$Description,
        [int]$MaxRetries = 2
    )
    
    if (Test-Path $Path) {
        $sizeBefore = Get-FolderSize -Path $Path
        Write-Host "  Cleaning $Description..." -ForegroundColor Gray
        
        $attempt = 0
        $success = $false
        
        while ($attempt -lt $MaxRetries -and -not $success) {
            try {
                # First try to remove all files with -Confirm:$false to suppress prompts
                Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        Remove-Item -Path $_.FullName -Force -Confirm:$false -ErrorAction Stop
                        $script:TotalFilesDeleted++
                    } catch {
                        # File is locked, skip it
                    }
                }
                
                # Then try to remove empty directories with -Confirm:$false
                Get-ChildItem -Path $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue | 
                    Sort-Object -Property FullName -Descending | ForEach-Object {
                    try {
                        Remove-Item -Path $_.FullName -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
                    } catch {
                        # Directory not empty or locked, skip it
                    }
                }
                
                # Alternative method: Try to remove entire folder contents at once
                try {
                    Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | 
                        Remove-Item -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
                } catch {
                    # Ignore errors
                }
                
                $success = $true
            } catch {
                $attempt++
                if ($attempt -lt $MaxRetries) {
                    Start-Sleep -Seconds 1
                }
            }
        }
        
        $sizeAfter = Get-FolderSize -Path $Path
        $sizeFreed = $sizeBefore - $sizeAfter
        $script:TotalSizeFreed += $sizeFreed
        
        if ($sizeFreed -gt 0) {
            Write-Host "    Freed: $sizeFreed MB" -ForegroundColor Green
        }
    }
}

# Function to clear Chrome data for a user
function Clear-ChromeData {
    param([string]$UserProfile, [string]$Username)
    
    Write-Host "`n  [Chrome] Processing..." -ForegroundColor Cyan
    
    $chromePaths = @(
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\Cache"; Desc = "Cache"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\Code Cache"; Desc = "Code Cache"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\GPUCache"; Desc = "GPU Cache"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\Service Worker"; Desc = "Service Worker Cache"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\IndexedDB"; Desc = "IndexedDB"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\Local Storage"; Desc = "Local Storage"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\Session Storage"; Desc = "Session Storage"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\Cookies"; Desc = "Cookies (file)"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\Cookies-journal"; Desc = "Cookies Journal"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\Web Data"; Desc = "Web Data (autofill)"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\Login Data"; Desc = "Login Data (passwords)"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\Default\History"; Desc = "History"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\ShaderCache"; Desc = "Shader Cache"},
        @{Path = "$UserProfile\AppData\Local\Google\Chrome\User Data\GrShaderCache"; Desc = "Graphics Shader Cache"}
    )
    
    foreach ($item in $chromePaths) {
        if ($item.Path -match "\.(db|sqlite|cookies|data)$" -or $item.Path -notmatch "\\$") {
            # It's a file
            if (Test-Path $item.Path) {
                try {
                    Remove-Item -Path $item.Path -Force -Confirm:$false -ErrorAction Stop
                    Write-Host "    Deleted: $($item.Desc)" -ForegroundColor Green
                    $script:TotalFilesDeleted++
                } catch {
                    Write-Host "    Locked: $($item.Desc)" -ForegroundColor Yellow
                }
            }
        } else {
            # It's a directory
            Remove-FolderContents -Path $item.Path -Description $item.Desc
        }
    }
    
    # Also check for additional profiles (Profile 1, Profile 2, etc.)
    $chromeUserData = "$UserProfile\AppData\Local\Google\Chrome\User Data"
    if (Test-Path $chromeUserData) {
        Get-ChildItem -Path $chromeUserData -Directory | Where-Object { $_.Name -match '^Profile \d+$' } | ForEach-Object {
            $profilePath = $_.FullName
            Write-Host "  [Chrome - $($_.Name)]" -ForegroundColor Cyan
            
            Remove-FolderContents -Path "$profilePath\Cache" -Description "Cache"
            Remove-FolderContents -Path "$profilePath\Code Cache" -Description "Code Cache"
            Remove-FolderContents -Path "$profilePath\Service Worker" -Description "Service Worker"
            
            # Remove cookie and password files
            @("Cookies", "Cookies-journal", "Login Data", "Web Data", "History") | ForEach-Object {
                $filePath = "$profilePath\$_"
                if (Test-Path $filePath) {
                    try {
                        Remove-Item -Path $filePath -Force -Confirm:$false -ErrorAction Stop
                        Write-Host "    Deleted: $_" -ForegroundColor Green
                    } catch {
                        Write-Host "    Locked: $_" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
}

# Function to clear Edge data for a user
function Clear-EdgeData {
    param([string]$UserProfile, [string]$Username)
    
    Write-Host "`n  [Edge] Processing..." -ForegroundColor Cyan
    
    $edgePaths = @(
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\Cache"; Desc = "Cache"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache"; Desc = "Code Cache"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\GPUCache"; Desc = "GPU Cache"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\Service Worker"; Desc = "Service Worker Cache"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\IndexedDB"; Desc = "IndexedDB"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\Local Storage"; Desc = "Local Storage"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\Session Storage"; Desc = "Session Storage"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\Cookies"; Desc = "Cookies (file)"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\Cookies-journal"; Desc = "Cookies Journal"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\Web Data"; Desc = "Web Data (autofill)"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\Login Data"; Desc = "Login Data (passwords)"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\History"; Desc = "History"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\ShaderCache"; Desc = "Shader Cache"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\GrShaderCache"; Desc = "Graphics Shader Cache"},
        @{Path = "$UserProfile\AppData\Local\Microsoft\Edge\User Data\Default\Collections"; Desc = "Collections"}
    )
    
    foreach ($item in $edgePaths) {
        if ($item.Path -match "\.(db|sqlite|cookies|data)$" -or $item.Path -notmatch "\\$") {
            # It's a file
            if (Test-Path $item.Path) {
                try {
                    Remove-Item -Path $item.Path -Force -Confirm:$false -ErrorAction Stop
                    Write-Host "    Deleted: $($item.Desc)" -ForegroundColor Green
                    $script:TotalFilesDeleted++
                } catch {
                    Write-Host "    Locked: $($item.Desc)" -ForegroundColor Yellow
                }
            }
        } else {
            # It's a directory
            Remove-FolderContents -Path $item.Path -Description $item.Desc
        }
    }
    
    # Also check for additional profiles
    $edgeUserData = "$UserProfile\AppData\Local\Microsoft\Edge\User Data"
    if (Test-Path $edgeUserData) {
        Get-ChildItem -Path $edgeUserData -Directory | Where-Object { $_.Name -match '^Profile \d+$' } | ForEach-Object {
            $profilePath = $_.FullName
            Write-Host "  [Edge - $($_.Name)]" -ForegroundColor Cyan
            
            Remove-FolderContents -Path "$profilePath\Cache" -Description "Cache"
            Remove-FolderContents -Path "$profilePath\Code Cache" -Description "Code Cache"
            Remove-FolderContents -Path "$profilePath\Service Worker" -Description "Service Worker"
            
            # Remove cookie and password files
            @("Cookies", "Cookies-journal", "Login Data", "Web Data", "History") | ForEach-Object {
                $filePath = "$profilePath\$_"
                if (Test-Path $filePath) {
                    try {
                        Remove-Item -Path $filePath -Force -Confirm:$false -ErrorAction Stop
                        Write-Host "    Deleted: $_" -ForegroundColor Green
                    } catch {
                        Write-Host "    Locked: $_" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
}

# Main script execution
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Browser Data Cleanup Script" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host ""

# Check for running browsers
Test-BrowserRunning

# Get all user profiles
$userProfiles = Get-WmiObject Win32_UserProfile | Where-Object { 
    $_.Special -eq $false -and 
    $_.LocalPath -ne $null -and 
    $_.LocalPath -notmatch 'Windows\\ServiceProfiles'
}

$totalUsers = ($userProfiles | Measure-Object).Count
Write-Host "`nFound $totalUsers user profile(s) to process" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Gray

foreach ($profile in $userProfiles) {
    $userPath = $profile.LocalPath
    $username = Split-Path $userPath -Leaf
    
    Write-Host "`nProcessing User: $username" -ForegroundColor Yellow
    Write-Host "Profile Path: $userPath" -ForegroundColor Gray
    
    try {
        # Clear Chrome data
        Clear-ChromeData -UserProfile $userPath -Username $username
        
        # Clear Edge data  
        Clear-EdgeData -UserProfile $userPath -Username $username
        
        $script:ProcessedUsers += $username
    } catch {
        Write-Host "  ERROR: Failed to process user $username - $_" -ForegroundColor Red
        $script:FailedUsers += $username
    }
}

# Clear any system-level caches
Write-Host "`n========================================" -ForegroundColor Gray
Write-Host "Processing System-Level Caches..." -ForegroundColor Yellow

# Chrome system temp
$chromeSysTemp = "$env:windir\Temp\Chrome_*"
if (Test-Path $chromeSysTemp) {
    Get-ChildItem -Path $env:windir\Temp -Filter "Chrome_*" | ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Host "  Cleared Chrome system temp files" -ForegroundColor Green
}

# Edge system temp
$edgeSysTemp = "$env:windir\Temp\Edge_*"
if (Test-Path $edgeSysTemp) {
    Get-ChildItem -Path $env:windir\Temp -Filter "Edge_*" | ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Host "  Cleared Edge system temp files" -ForegroundColor Green
}

# Final Summary
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "CLEANUP SUMMARY" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Completion Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host ""
Write-Host "Users Processed: $($script:ProcessedUsers.Count)" -ForegroundColor Green
if ($script:ProcessedUsers.Count -gt 0) {
    Write-Host "  $($script:ProcessedUsers -join ', ')" -ForegroundColor Gray
}

if ($script:FailedUsers.Count -gt 0) {
    Write-Host "Users Failed: $($script:FailedUsers.Count)" -ForegroundColor Red
    Write-Host "  $($script:FailedUsers -join ', ')" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Total Files Deleted: $($script:TotalFilesDeleted)" -ForegroundColor Cyan
Write-Host "Total Space Freed: $([math]::Round($script:TotalSizeFreed, 2)) MB" -ForegroundColor Cyan

if ($script:RunningBrowsers.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNING: The following browsers were running during cleanup:" -ForegroundColor Yellow
    Write-Host "  $($script:RunningBrowsers -join ', ')" -ForegroundColor Yellow
    Write-Host "  Some files may have been locked and not deleted." -ForegroundColor Yellow
    Write-Host "  Consider running this script when browsers are closed for best results." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Browser cleanup completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Magenta

# Exit with appropriate code for RMM
if ($script:FailedUsers.Count -eq 0) {
    exit 0
} else {
    exit 1
}
