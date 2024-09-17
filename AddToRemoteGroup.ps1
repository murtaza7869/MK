# Variables
$user = "evertz_microsys\hdsuper"  # Replace DOMAIN\UserName with the domain\username for a domain user
                           # For a local user, just use the username (e.g., 'LocalUserName')

# Add the user to "Remote Desktop Users" group
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $user
