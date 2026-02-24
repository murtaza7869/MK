#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Removes user-created files from specific folders in a specified user profile
.DESCRIPTION
    Runs in SYSTEM context via RMM to clean up Desktop, Downloads, Documents, and Pictures folders
    for any specified user account (domain or local). Provides detailed summary of files found and deleted.
.PARAMETER Username
    The username to clean up. Can be local (e.g., "john") or domain (e.g., "DOMAIN\john" or "john@domain.com")
.EXAMPLE
    .\cleanup-user-profile.ps1 -Username "library"
    .\cleanup-user-profile.ps1 -Username "CONTOSO\jdoe"
    .\cleanup-user-profile.ps1 -Username "jane@company.com"
.NOTES
    Author: RMM Cleanup Script
    Version: 3.0
    Designed for: Faronics RMM deployment in SYSTEM context
    Supports: Domain and local user accounts
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Username to clean up (e.g., 'john', 'DOMAIN\john', 'john@domain.com')")]
    [ValidateNotNullOrEmpty()]
    [string]$Username
)

# Initialize counters and collections
$script:totalFilesFound = 0
$script:totalFilesDeleted = 0
$script:totalSizeFreed = 0
$script:errors = @()
$script:deletedFiles = @()

# Function to format file size
function Format-FileSize {
    param([long]$Size)
    
    if ($Size -gt 1TB) { return "{0:N2} TB" -f ($Size / 1TB) }
    elseif ($Size -gt 1GB) { return "{0:N2} GB" -f ($Size / 1GB) }
    elseif ($Size -gt 1MB) { return "{0:N2} MB" -f ($Size / 1MB) }
    elseif ($Size -gt 1KB) { return "{0:N2} KB" -f ($Size / 1KB) }
    else { return "{0} Bytes" -f $Size }
}

# Function to resolve user profile path
function Get-UserProfilePath {
    param([string]$Username)
    
    Write-Host ("[INFO] Looking up profile path for user: " + $Username) -ForegroundColor Cyan
    
    # First, try to normalize the username for different formats
    $normalizedUser = $Username
    
    # Handle domain\user format
    if ($Username -like "*\*") {
        $parts = $Username -split '\\'
        if ($parts.Count -eq 2) {
            $domain = $parts[0]
            $user = $parts[1]
            $normalizedUser = $user
            Write-Host ("[INFO] Detected domain user: Domain=$domain, User=$user") -ForegroundColor Gray
        }
    }
    # Handle user@domain format
    elseif ($Username -like "*@*") {
        $parts = $Username -split '@'
        if ($parts.Count -eq 2) {
            $user = $parts[0]
            $domain = $parts[1]
            $normalizedUser = $user
            Write-Host ("[INFO] Detected UPN format: User=$user, Domain=$domain") -ForegroundColor Gray
        }
    }
    
    # Try common profile path patterns
    $possiblePaths = @(
        "C:\Users\$normalizedUser",
        "C:\Users\$Username",
        ($env:SystemDrive + "\Users\$normalizedUser"),
        ($env:SystemDrive + "\Users\$Username")
    )
    
    # Check if any of the common paths exist
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-Host ("[SUCCESS] Found profile path: " + $path) -ForegroundColor Green
            return $path
        }
    }
    
    # Try to find via registry using different username formats
    $usernamesToTry = @($Username, $normalizedUser)
    
    foreach ($userToTry in $usernamesToTry) {
        try {
            Write-Host ("[INFO] Attempting registry lookup for: " + $userToTry) -ForegroundColor Gray
            
            # Try to get SID for the user
            $ntAccount = New-Object System.Security.Principal.NTAccount($userToTry)
            $userSID = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
            
            Write-Host ("[INFO] Found SID: " + $userSID) -ForegroundColor Gray
            
            # Look up profile path in registry
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$userSID"
            if (Test-Path $regPath) {
                $profilePath = (Get-ItemProperty -Path $regPath -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
                if (Test-Path $profilePath) {
                    Write-Host ("[SUCCESS] Found profile via registry: " + $profilePath) -ForegroundColor Green
                    return $profilePath
                }
            }
        }
        catch {
            Write-Host ("[WARNING] Registry lookup failed for '$userToTry': " + $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    
    # Try WMI as last resort
    try {
        Write-Host "[INFO] Trying WMI lookup..." -ForegroundColor Gray
        $wmiUser = Get-WmiObject -Class Win32_UserProfile -ErrorAction Stop | Where-Object { 
            $_.LocalPath -like "*\$normalizedUser" -or $_.LocalPath -like "*\$Username" 
        }
        
        if ($wmiUser -and (Test-Path $wmiUser.LocalPath)) {
            Write-Host ("[SUCCESS] Found profile via WMI: " + $wmiUser.LocalPath) -ForegroundColor Green
            return $wmiUser.LocalPath
        }
    }
    catch {
        Write-Host ("[WARNING] WMI lookup failed: " + $_.Exception.Message) -ForegroundColor Yellow
    }
    
    return $null
}

# Function to safely delete files and track results
function Remove-UserFiles {
    param(
        [string]$FolderPath,
        [string]$FolderName
    )
    
    $folderStats = @{
        Found = 0
        Deleted = 0
        SizeFreed = 0
        Files = @()
    }
    
    if (Test-Path $FolderPath) {
        Write-Host ("`n[+] Processing " + $FolderName + " folder: " + $FolderPath) -ForegroundColor Cyan
        
        try {
            # Get all files recursively (excluding folders)
            $files = Get-ChildItem -Path $FolderPath -Recurse -File -ErrorAction SilentlyContinue
            
            foreach ($file in $files) {
                $folderStats.Found++
                $script:totalFilesFound++
                
                $fileInfo = @{
                    Path = $file.FullName
                    Size = $file.Length
                    LastModified = $file.LastWriteTime
                    Deleted = $false
                    Error = ""
                }
                
                try {
                    # Attempt to remove the file
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    
                    $fileInfo.Deleted = $true
                    $folderStats.Deleted++
                    $folderStats.SizeFreed += $file.Length
                    $script:totalFilesDeleted++
                    $script:totalSizeFreed += $file.Length
                    
                    $sizeFormatted = Format-FileSize $file.Length
                    Write-Host ("  [OK] Deleted: " + $file.Name + " (" + $sizeFormatted + ")") -ForegroundColor Green
                }
                catch {
                    $errorMsg = $_.Exception.Message
                    $fileInfo.Error = $errorMsg
                    $script:errors += ($file.FullName + ": " + $errorMsg)
                    Write-Host ("  [X] Failed: " + $file.Name + " - " + $errorMsg) -ForegroundColor Red
                }
                
                $folderStats.Files += $fileInfo
                $script:deletedFiles += $fileInfo
            }
            
            # Clean up empty subdirectories
            $directories = Get-ChildItem -Path $FolderPath -Recurse -Directory -ErrorAction SilentlyContinue
            if ($directories) {
                $directories | Sort-Object -Property FullName -Descending | ForEach-Object {
                    $dirPath = $_.FullName
                    $dirName = $_.Name
                    try {
                        $itemCount = (Get-ChildItem $dirPath -Force -ErrorAction SilentlyContinue | Measure-Object).Count
                        if ($itemCount -eq 0) {
                            Remove-Item $dirPath -Force -ErrorAction Stop
                            Write-Host ("  [OK] Removed empty folder: " + $dirName) -ForegroundColor DarkGray
                        }
                    }
                    catch {
                        # Silently continue if folder cannot be deleted
                    }
                }
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Host ("  [!] Error accessing folder: " + $errorMsg) -ForegroundColor Yellow
            $script:errors += ("Folder access error for " + $FolderPath + ": " + $errorMsg)
        }
        
        # Folder summary
        if ($folderStats.Found -gt 0) {
            $sizeFreedFormatted = Format-FileSize $folderStats.SizeFreed
            Write-Host ("  Summary: Found " + $folderStats.Found + " files, Deleted " + $folderStats.Deleted + ", Freed " + $sizeFreedFormatted) -ForegroundColor White
        } else {
            Write-Host "  No files found in this folder" -ForegroundColor Gray
        }
    }
    else {
        Write-Host ("`n[-] " + $FolderName + " folder not found: " + $FolderPath) -ForegroundColor Yellow
    }
    
    return $folderStats
}

# Main execution
Write-Host "====================================================================" -ForegroundColor Magenta
Write-Host " USER PROFILE CLEANUP SCRIPT" -ForegroundColor Magenta
Write-Host (" Target User: " + $Username) -ForegroundColor Magenta
Write-Host (" Running as: " + $env:USERNAME + " (" + (whoami) + ")") -ForegroundColor Magenta
Write-Host (" Timestamp: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Magenta
Write-Host "====================================================================" -ForegroundColor Magenta

# Validate and get user profile path
$userProfilePath = Get-UserProfilePath -Username $Username

if (-not $userProfilePath) {
    Write-Host "`n[ERROR] User profile not found!" -ForegroundColor Red
    Write-Host ("Searched for user: " + $Username) -ForegroundColor Yellow
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  - User account does not exist" -ForegroundColor Yellow
    Write-Host "  - User has never logged in (no profile created)" -ForegroundColor Yellow
    Write-Host "  - Profile path is in a non-standard location" -ForegroundColor Yellow
    Write-Host "  - Insufficient permissions to access profile information" -ForegroundColor Yellow
    exit 1
}

Write-Host ("`n[OK] Found user profile at: " + $userProfilePath) -ForegroundColor Green

# Validate profile path accessibility
try {
    $testAccess = Get-ChildItem -Path $userProfilePath -Force -ErrorAction Stop | Select-Object -First 1
    Write-Host "[OK] Profile directory is accessible" -ForegroundColor Green
}
catch {
    Write-Host ("[ERROR] Cannot access profile directory: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

# Define folders to clean
$foldersToClean = @(
    @{ Name = "Desktop"; Path = Join-Path $userProfilePath "Desktop" },
    @{ Name = "Downloads"; Path = Join-Path $userProfilePath "Downloads" },
    @{ Name = "Documents"; Path = Join-Path $userProfilePath "Documents" },
    @{ Name = "Pictures"; Path = Join-Path $userProfilePath "Pictures" }
)

Write-Host "`nFolders to be cleaned:" -ForegroundColor Cyan
foreach ($folder in $foldersToClean) {
    $exists = if (Test-Path $folder.Path) { "[EXISTS]" } else { "[MISSING]" }
    $color = if (Test-Path $folder.Path) { "White" } else { "DarkGray" }
    Write-Host ("  " + $exists + " " + $folder.Path) -ForegroundColor $color
}

# Process each folder
$folderResults = @{}
foreach ($folder in $foldersToClean) {
    $result = Remove-UserFiles -FolderPath $folder.Path -FolderName $folder.Name
    $folderResults[$folder.Name] = $result
}

# Generate detailed report
Write-Host "`n====================================================================" -ForegroundColor Magenta
Write-Host " CLEANUP SUMMARY REPORT" -ForegroundColor Magenta
Write-Host ("   User: " + $Username) -ForegroundColor Magenta
Write-Host "====================================================================" -ForegroundColor Magenta

Write-Host "`nOVERALL STATISTICS:" -ForegroundColor Cyan
Write-Host ("  Total Files Found:    " + $script:totalFilesFound) -ForegroundColor White

if ($script:totalFilesDeleted -eq $script:totalFilesFound) {
    Write-Host ("  Total Files Deleted:  " + $script:totalFilesDeleted) -ForegroundColor Green
} else {
    Write-Host ("  Total Files Deleted:  " + $script:totalFilesDeleted) -ForegroundColor Yellow
}

$totalSizeFreedFormatted = Format-FileSize $script:totalSizeFreed
Write-Host ("  Total Space Freed:    " + $totalSizeFreedFormatted) -ForegroundColor Green

if ($script:totalFilesFound -gt 0) {
    $successRate = [math]::Round(($script:totalFilesDeleted / $script:totalFilesFound) * 100, 0)
    Write-Host ("  Success Rate:         " + $successRate + "%") -ForegroundColor White
} else {
    Write-Host "  Success Rate:         N/A" -ForegroundColor White
}

# Per-folder breakdown
Write-Host "`nPER-FOLDER BREAKDOWN:" -ForegroundColor Cyan
foreach ($folderName in $folderResults.Keys) {
    $stats = $folderResults[$folderName]
    $sizeFormatted = Format-FileSize $stats.SizeFreed
    Write-Host ("  " + $folderName + ": " + $stats.Deleted + "/" + $stats.Found + " files deleted, " + $sizeFormatted + " freed") -ForegroundColor White
}

if ($script:errors.Count -gt 0) {
    Write-Host ("`nERRORS ENCOUNTERED (" + $script:errors.Count + "):") -ForegroundColor Red
    $errorCount = 0
    foreach ($error in $script:errors) {
        if ($errorCount -lt 10) {
            Write-Host ("  - " + $error) -ForegroundColor Red
            $errorCount++
        } else {
            $remainingErrors = $script:errors.Count - 10
            Write-Host ("  ... and " + $remainingErrors + " more errors") -ForegroundColor Red
            break
        }
    }
}

# Top 10 largest files deleted
$deletedFilesSuccessful = @()
foreach ($file in $script:deletedFiles) {
    if ($file.Deleted) {
        $deletedFilesSuccessful += $file
    }
}

if ($deletedFilesSuccessful.Count -gt 0) {
    Write-Host "`nTOP 10 LARGEST FILES DELETED:" -ForegroundColor Cyan
    $sortedFiles = $deletedFilesSuccessful | Sort-Object -Property Size -Descending | Select-Object -First 10
    foreach ($file in $sortedFiles) {
        $fileName = Split-Path $file.Path -Leaf
        $fileSizeFormatted = Format-FileSize $file.Size
        Write-Host ("  - " + $fileName + " (" + $fileSizeFormatted + ")") -ForegroundColor White
    }
}

# Files that couldn't be deleted
$failedFiles = @()
foreach ($file in $script:deletedFiles) {
    if (-not $file.Deleted) {
        $failedFiles += $file
    }
}

if ($failedFiles.Count -gt 0) {
    Write-Host ("`nFILES THAT COULD NOT BE DELETED (" + $failedFiles.Count + "):") -ForegroundColor Yellow
    $failedCount = 0
    foreach ($file in $failedFiles) {
        if ($failedCount -lt 5) {
            $fileName = Split-Path $file.Path -Leaf
            Write-Host ("  - " + $fileName) -ForegroundColor Yellow
            $failedCount++
        } else {
            $remainingFailed = $failedFiles.Count - 5
            Write-Host ("  ... and " + $remainingFailed + " more files") -ForegroundColor Yellow
            break
        }
    }
}

Write-Host "`n====================================================================" -ForegroundColor Magenta
Write-Host (" CLEANUP COMPLETED: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Magenta
Write-Host "====================================================================" -ForegroundColor Magenta

# Exit with appropriate code
if ($script:totalFilesFound -eq 0) {
    Write-Host "`n[INFO] No files found to clean up" -ForegroundColor Cyan
    exit 0
} elseif ($script:totalFilesDeleted -eq $script:totalFilesFound) {
    Write-Host "`n[SUCCESS] All files successfully deleted" -ForegroundColor Green
    exit 0
} elseif ($script:totalFilesDeleted -gt 0) {
    Write-Host "`n[PARTIAL] Some files were deleted, but errors occurred" -ForegroundColor Yellow
    exit 2
} else {
    Write-Host "`n[FAILED] No files could be deleted" -ForegroundColor Red
    exit 1
}