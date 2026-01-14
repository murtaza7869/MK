#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Removes user-created files from specific folders in the 'library' user profile
.DESCRIPTION
    Runs in SYSTEM context via RMM to clean up Desktop, Downloads, Documents, and Pictures folders
    for the local user account named 'library'. Provides detailed summary of files found and deleted.
.NOTES
    Author: RMM Cleanup Script
    Version: 1.0
    Designed for: Faronics RMM deployment in SYSTEM context
#>

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
        Write-Host "`n[+] Processing $FolderName folder: $FolderPath" -ForegroundColor Cyan
        
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
                    
                    Write-Host "  [✓] Deleted: $($file.Name) ($(Format-FileSize $file.Length))" -ForegroundColor Green
                }
                catch {
                    $fileInfo.Error = $_.Exception.Message
                    $script:errors += "$($file.FullName): $_"
                    Write-Host "  [✗] Failed: $($file.Name) - $_" -ForegroundColor Red
                }
                
                $folderStats.Files += $fileInfo
                $script:deletedFiles += $fileInfo
            }
            
            # Clean up empty subdirectories
            Get-ChildItem -Path $FolderPath -Recurse -Directory -ErrorAction SilentlyContinue | 
                Sort-Object -Property FullName -Descending | 
                ForEach-Object {
                    if ((Get-ChildItem $_.FullName -Force | Measure-Object).Count -eq 0) {
                        try {
                            Remove-Item $_.FullName -Force -ErrorAction Stop
                            Write-Host "  [✓] Removed empty folder: $($_.Name)" -ForegroundColor DarkGray
                        }
                        catch {
                            # Silently continue if folder cannot be deleted
                        }
                    }
                }
        }
        catch {
            Write-Host "  [!] Error accessing folder: $_" -ForegroundColor Yellow
            $script:errors += "Folder access error for $FolderPath: $_"
        }
        
        # Folder summary
        if ($folderStats.Found -gt 0) {
            Write-Host "  Summary: Found $($folderStats.Found) files, Deleted $($folderStats.Deleted), Freed $(Format-FileSize $folderStats.SizeFreed)" -ForegroundColor White
        } else {
            Write-Host "  No files found in this folder" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "`n[-] $FolderName folder not found: $FolderPath" -ForegroundColor Yellow
    }
    
    return $folderStats
}

# Main execution
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host " LIBRARY USER PROFILE CLEANUP SCRIPT" -ForegroundColor Magenta
Write-Host " Running as: $env:USERNAME ($(whoami))" -ForegroundColor Magenta
Write-Host " Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta

# Determine library user profile path
$libraryProfilePath = $null

# Check common profile locations
$possiblePaths = @(
    "C:\Users\library",
    "$env:SystemDrive\Users\library"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $libraryProfilePath = $path
        break
    }
}

if (-not $libraryProfilePath) {
    # Try to find via registry if user exists but profile is elsewhere
    try {
        $userSID = (New-Object System.Security.Principal.NTAccount("library")).Translate([System.Security.Principal.SecurityIdentifier]).Value
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$userSID"
        if (Test-Path $regPath) {
            $libraryProfilePath = (Get-ItemProperty -Path $regPath -Name ProfileImagePath).ProfileImagePath
        }
    }
    catch {
        # User might not exist
    }
}

if (-not $libraryProfilePath -or -not (Test-Path $libraryProfilePath)) {
    Write-Host "`n[ERROR] Library user profile not found!" -ForegroundColor Red
    Write-Host "Checked locations:" -ForegroundColor Yellow
    $possiblePaths | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    exit 1
}

Write-Host "`n[✓] Found library profile at: $libraryProfilePath" -ForegroundColor Green

# Define folders to clean
$foldersToClean = @(
    @{ Name = "Desktop"; Path = Join-Path $libraryProfilePath "Desktop" },
    @{ Name = "Downloads"; Path = Join-Path $libraryProfilePath "Downloads" },
    @{ Name = "Documents"; Path = Join-Path $libraryProfilePath "Documents" },
    @{ Name = "Pictures"; Path = Join-Path $libraryProfilePath "Pictures" }
)

# Process each folder
$folderResults = @{}
foreach ($folder in $foldersToClean) {
    $result = Remove-UserFiles -FolderPath $folder.Path -FolderName $folder.Name
    $folderResults[$folder.Name] = $result
}

# Generate detailed report
Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host " CLEANUP SUMMARY REPORT" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta

Write-Host "`nOVERALL STATISTICS:" -ForegroundColor Cyan
Write-Host "  Total Files Found:    $script:totalFilesFound" -ForegroundColor White
Write-Host "  Total Files Deleted:  $script:totalFilesDeleted" -ForegroundColor $(if ($script:totalFilesDeleted -eq $script:totalFilesFound) { "Green" } else { "Yellow" })
Write-Host "  Total Space Freed:    $(Format-FileSize $script:totalSizeFreed)" -ForegroundColor Green
Write-Host "  Success Rate:         $(if ($script:totalFilesFound -gt 0) { '{0:P0}' -f ($script:totalFilesDeleted / $script:totalFilesFound) } else { 'N/A' })" -ForegroundColor White

if ($script:errors.Count -gt 0) {
    Write-Host "`nERRORS ENCOUNTERED ($($script:errors.Count)):" -ForegroundColor Red
    $script:errors | Select-Object -First 10 | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Red
    }
    if ($script:errors.Count -gt 10) {
        Write-Host "  ... and $($script:errors.Count - 10) more errors" -ForegroundColor Red
    }
}

# Top 10 largest files deleted
if ($script:deletedFiles | Where-Object { $_.Deleted }) {
    Write-Host "`nTOP 10 LARGEST FILES DELETED:" -ForegroundColor Cyan
    $script:deletedFiles | 
        Where-Object { $_.Deleted } | 
        Sort-Object Size -Descending | 
        Select-Object -First 10 | 
        ForEach-Object {
            $fileName = Split-Path $_.Path -Leaf
            Write-Host "  - $fileName ($(Format-FileSize $_.Size))" -ForegroundColor White
        }
}

# Files that couldn't be deleted
$failedFiles = $script:deletedFiles | Where-Object { -not $_.Deleted }
if ($failedFiles) {
    Write-Host "`nFILES THAT COULD NOT BE DELETED ($($failedFiles.Count)):" -ForegroundColor Yellow
    $failedFiles | Select-Object -First 5 | ForEach-Object {
        $fileName = Split-Path $_.Path -Leaf
        Write-Host "  - $fileName" -ForegroundColor Yellow
    }
    if ($failedFiles.Count -gt 5) {
        Write-Host "  ... and $($failedFiles.Count - 5) more files" -ForegroundColor Yellow
    }
}

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host " CLEANUP COMPLETED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta

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
