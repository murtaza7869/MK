param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$Password
)

# Check if the account already exists
$existingUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
if ($existingUser) {
    Write-Host "User '$Username' already exists." -ForegroundColor Yellow
    exit
}

try {
    # Create the local user
    $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    New-LocalUser -Name $Username -Password $securePassword -FullName $Username -Description "Local Admin Account" -PasswordNeverExpires -AccountNeverExpires

    # Add the user to the Administrators group
    Add-LocalGroupMember -Group "Administrators" -Member $Username

    Write-Host "Local admin account '$Username' has been created and added to the Administrators group." -ForegroundColor Green
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
