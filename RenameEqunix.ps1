<#
.SYNOPSIS
    Renames a computer by replacing "LP" at positions 3-4 with "SH".

.DESCRIPTION
    Checks if the current computer name has "LP" as the 3rd and 4th characters.
    If found, renames the computer replacing "LP" with "SH".
    No reboot is forced — intended for use within a task sequence.
#>

$currentName = $env:COMPUTERNAME

Write-Host "Current computer name: $currentName"

# Validate name is at least 4 characters
if ($currentName.Length -lt 4) {
    Write-Host "Computer name is fewer than 4 characters. Exiting without changes."
    Exit 0
}

# Check if 3rd and 4th characters (index 2 and 3) are "LP"
$chars34 = $currentName.Substring(2, 2)

if ($chars34 -ne "LP") {
    Write-Host "Characters at positions 3-4 are '$chars34', not 'LP'. Exiting without changes."
    Exit 0
}

# Build the new name: keep first 2 chars, insert "SH", append remainder
$newName = $currentName.Substring(0, 2) + "SH" + $currentName.Substring(4)

Write-Host "Renaming computer from '$currentName' to '$newName'..."

try {
    Rename-Computer -NewName $newName -Force -ErrorAction Stop
    Write-Host "Computer successfully renamed to '$newName'. A reboot is required for the change to take effect."
    Exit 0
}
catch {
    Write-Error "Failed to rename computer: $_"
    Exit 1
}
