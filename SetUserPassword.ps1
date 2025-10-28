<#
.SYNOPSIS
    Reset local Windows user account password
.DESCRIPTION
    Resets the password for a specified local user account on Windows 10/11
    Designed to run under SYSTEM account via RMM tools
.PARAMETER Username
    The local username to reset password for
.PARAMETER NewPassword
    The new password to set for the account
.EXAMPLE
    .\Reset-LocalUserPassword.ps1 -Username "john.doe" -NewPassword "NewP@ssw0rd123"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,
    
    [Parameter(Mandatory=$true)]
    [string]$NewPassword
)

# Function to write output with timestamp
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] [$Level] $Message"
}

try {
    Write-Log "Starting password reset for user: $Username"
    
    # Verify script is running with elevated privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Log "ERROR: Script is not running with administrative privileges" "ERROR"
        exit 1
    }
    
    Write-Log "Running with administrative privileges"
    
    # Check if user exists
    try {
        $user = Get-LocalUser -Name $Username -ErrorAction Stop
        Write-Log "User account found: $Username"
    }
    catch {
        Write-Log "ERROR: User '$Username' does not exist on this system" "ERROR"
        exit 1
    }
    
    # Check if account is enabled
    if (-not $user.Enabled) {
        Write-Log "WARNING: User account '$Username' is currently disabled" "WARNING"
    }
    
    # Convert password to secure string
    $securePassword = ConvertTo-SecureString $NewPassword -AsPlainText -Force
    
    # Reset the password
    Set-LocalUser -Name $Username -Password $securePassword -ErrorAction Stop
    Write-Log "Password successfully reset for user: $Username" "SUCCESS"
    
    # Optional: Set password to never expire (uncomment if needed)
    # Set-LocalUser -Name $Username -PasswordNeverExpires $true
    # Write-Log "Password set to never expire for user: $Username"
    
    # Optional: Force user to change password at next logon (uncomment if needed)
    # Note: This doesn't work well with the modern Set-LocalUser cmdlet
    # You would need to use net user command for this:
    # net user $Username /logonpasswordchg:yes
    
    Write-Log "Password reset operation completed successfully"
    exit 0
}
catch {
    Write-Log "ERROR: Failed to reset password - $($_.Exception.Message)" "ERROR"
    Write-Log "ERROR: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}
