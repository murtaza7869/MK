#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Updates Windows ProfileList registry keys to redirect user profiles to T:\Profiles\Users
.DESCRIPTION
    This script modifies the ProfileList registry keys to change the default profile locations
    to T:\Profiles\Users while preserving system and service account profiles.
.NOTES
    Author: Windows Systems Administrator
    Purpose: Profile path redirection for Windows deployment
    Requires: Administrative privileges
#>

# Define the new profile paths
$NewProfilesDirectory = "T:\Profiles\Users"
$NewDefaultProfile = "T:\Profiles\Users\Default"
$NewPublicProfile = "T:\Profiles\Users\Public"

# Registry path for ProfileList
$ProfileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

# System SIDs that should NOT be modified
$SystemSIDs = @(
    "S-1-5-18",  # SYSTEM
    "S-1-5-19",  # LOCAL SERVICE
    "S-1-5-20"   # NETWORK SERVICE
)

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage -ForegroundColor $(if($Level -eq "ERROR"){"Red"}elseif($Level -eq "WARNING"){"Yellow"}else{"Green"})
}

function Test-RegistryValue {
    param(
        [string]$Path,
        [string]$Name
    )
    try {
        $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Backup-RegistryKey {
    param(
        [string]$KeyPath,
        [string]$BackupPath
    )
    try {
        $BackupFile = Join-Path $BackupPath "ProfileList_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
        Write-Log "Creating registry backup at: $BackupFile"
        
        # Export the registry key
        $RegPath = $KeyPath.Replace("HKLM:\", "HKEY_LOCAL_MACHINE\")
        $ExportCmd = "reg export `"$RegPath`" `"$BackupFile`" /y"
        $Result = Invoke-Expression $ExportCmd 2>&1
        
        if (Test-Path $BackupFile) {
            Write-Log "Registry backup created successfully"
            return $BackupFile
        }
        else {
            Write-Log "Failed to create registry backup" "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Error creating backup: $_" "ERROR"
        return $null
    }
}

# Main script execution
try {
    Write-Log "Starting ProfileList Registry Update Script"
    Write-Log "================================================"
    
    # Check if running as administrator
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Log "This script must be run as Administrator!" "ERROR"
        exit 1
    }
    
    # Create backup directory
    $BackupDir = "C:\Windows\Temp\ProfileListBackups"
    if (!(Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        Write-Log "Created backup directory: $BackupDir"
    }
    
    # Backup the registry before making changes
    $BackupFile = Backup-RegistryKey -KeyPath $ProfileListPath -BackupPath $BackupDir
    if (!$BackupFile) {
        Write-Log "Failed to create backup. Proceeding without backup." "WARNING"
    }
    
    # Update the main ProfileList keys
    Write-Log "Updating main ProfileList registry keys..."
    
    try {
        # Update Default profile path
        Set-ItemProperty -Path $ProfileListPath -Name "Default" -Value $NewDefaultProfile
        Write-Log "Updated Default profile path to: $NewDefaultProfile"
        
        # Update ProfilesDirectory
        Set-ItemProperty -Path $ProfileListPath -Name "ProfilesDirectory" -Value $NewProfilesDirectory
        Write-Log "Updated ProfilesDirectory to: $NewProfilesDirectory"
        
        # Update Public profile path
        Set-ItemProperty -Path $ProfileListPath -Name "Public" -Value $NewPublicProfile
        Write-Log "Updated Public profile path to: $NewPublicProfile"
    }
    catch {
        Write-Log "Error updating main ProfileList keys: $_" "ERROR"
        throw
    }
    
    # Get all profile SID subkeys
    Write-Log "Processing individual user profiles..."
    $ProfileSIDs = Get-ChildItem -Path $ProfileListPath | Where-Object { $_.PSChildName -match "^S-\d-\d+-(\d+-){1,14}\d+$" }
    
    $UpdatedProfiles = 0
    $SkippedProfiles = 0
    
    foreach ($SID in $ProfileSIDs) {
        $SIDPath = Join-Path $ProfileListPath $SID.PSChildName
        
        # Check if this is a system SID
        $IsSystemSID = $false
        foreach ($SystemSID in $SystemSIDs) {
            if ($SID.PSChildName.StartsWith($SystemSID)) {
                $IsSystemSID = $true
                break
            }
        }
        
        if ($IsSystemSID) {
            Write-Log "Skipping system profile: $($SID.PSChildName)" "WARNING"
            $SkippedProfiles++
            continue
        }
        
        # Get the current ProfileImagePath
        if (Test-RegistryValue -Path $SIDPath -Name "ProfileImagePath") {
            $CurrentPath = (Get-ItemProperty -Path $SIDPath -Name "ProfileImagePath").ProfileImagePath
            
            # Skip if it's a system profile path
            if ($CurrentPath -match "\\(systemprofile|LocalService|NetworkService)$") {
                Write-Log "Skipping service profile: $CurrentPath" "WARNING"
                $SkippedProfiles++
                continue
            }
            
            # Extract the username from the current path
            $Username = Split-Path $CurrentPath -Leaf
            
            # Build the new profile path
            $NewProfilePath = Join-Path $NewProfilesDirectory $Username
            
            # Update the ProfileImagePath
            try {
                Set-ItemProperty -Path $SIDPath -Name "ProfileImagePath" -Value $NewProfilePath
                Write-Log "Updated profile path for $Username from '$CurrentPath' to '$NewProfilePath'"
                $UpdatedProfiles++
            }
            catch {
                Write-Log "Failed to update profile path for $Username : $_" "ERROR"
            }
        }
    }
    
    Write-Log "================================================"
    Write-Log "Profile path update completed successfully!"
    Write-Log "Updated profiles: $UpdatedProfiles"
    Write-Log "Skipped profiles (system/service): $SkippedProfiles"
    Write-Log "Backup saved to: $BackupFile"
    
    # Verify the changes
    Write-Log ""
    Write-Log "Verifying changes..."
    $CurrentDefault = (Get-ItemProperty -Path $ProfileListPath -Name "Default").Default
    $CurrentProfilesDir = (Get-ItemProperty -Path $ProfileListPath -Name "ProfilesDirectory").ProfilesDirectory
    $CurrentPublic = (Get-ItemProperty -Path $ProfileListPath -Name "Public").Public
    
    Write-Log "Current Default: $CurrentDefault"
    Write-Log "Current ProfilesDirectory: $CurrentProfilesDir"
    Write-Log "Current Public: $CurrentPublic"
    
    Write-Log ""
    Write-Log "Script execution completed. Please restart the computer for changes to take effect."
    Write-Log "To restore original settings, import the backup file: $BackupFile"
}
catch {
    Write-Log "Critical error occurred: $_" "ERROR"
    Write-Log "Script execution failed. Please review the error and restore from backup if needed." "ERROR"
    exit 1
}
