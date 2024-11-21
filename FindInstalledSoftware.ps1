param (
    [Parameter(Mandatory = $true)]
    [string]$ProductName
)

# Function to check installed software in both registry locations
function Get-InstalledSoftware {
    param (
        [string]$Name
    )

    # Registry paths to search
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $paths) {
        # Get software details
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$Name*" }
    }
}

# Search for the product
$software = Get-InstalledSoftware -Name $ProductName

if ($software) {
    foreach ($item in $software) {
        Write-Output "Product Name: $($item.DisplayName)"
        Write-Output "Version: $($item.DisplayVersion)"
        Write-Output "Install Date: $($item.InstallDate)"
        Write-Output "Publisher: $($item.Publisher)"
        Write-Output "----------------------------------------"
    }
} else {
    Write-Output "Did not find the product '$ProductName' installed on this system."
}
