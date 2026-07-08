<#
.SYNOPSIS
    Cleans profile data folders for a specified local Windows user.

.NOTES
    - Run this in an elevated (Administrator) PowerShell session.
    - This performs PERMANENT deletion (bypasses Recycle Bin). Back up anything
      important first, and test with -WhatIf before running for real.
#>

param(
    [string]$UserName = "studentuser",
    [switch]$WhatIf   # Run with -WhatIf to preview what would be deleted, no actual deletion
)

# Resolve the profile path (works even if profile isn't on C: or has a nonstandard path)
$profile = Get-CimInstance Win32_UserProfile | Where-Object {
    (Split-Path $_.LocalPath -Leaf) -eq $UserName
} | Select-Object -First 1

if (-not $profile) {
    Write-Error "Could not find a profile for user '$UserName'. Verify the username and that the profile has logged in at least once."
    return
}

$profilePath = $profile.LocalPath
Write-Host "Found profile for '$UserName' at: $profilePath" -ForegroundColor Cyan

# Folders whose CONTENTS should be wiped (folder itself stays)
$foldersToClean = @(
    "Downloads",
    "Documents",
    "Pictures",
    "Videos",
    "Music",
    "Desktop",
    "Favorites",
    "AppData\Local\Temp",
    "AppData\Roaming\Microsoft\Windows\Recent",
    "AppData\Local\Microsoft\Windows\INetCache",
    "AppData\Local\Microsoft\Windows\WebCache",
    "AppData\Local\CrashDumps"
)

foreach ($rel in $foldersToClean) {
    $target = Join-Path $profilePath $rel

    if (Test-Path $target) {
        Write-Host "Cleaning: $target" -ForegroundColor Yellow
        try {
            Get-ChildItem -Path $target -Force -ErrorAction SilentlyContinue | ForEach-Object {
                if ($WhatIf) {
                    Write-Host "  Would delete: $($_.FullName)"
                } else {
                    Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-Warning "  Failed to fully clean $target : $_"
        }
    }
    else {
        Write-Host "Skipping (not found): $target" -ForegroundColor DarkGray
    }
}

Write-Host "`nCleanup complete for profile: $UserName" -ForegroundColor Green
