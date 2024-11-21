# Function to retrieve Office installation details
function Get-MSOfficeDetails {
    Write-Output "Checking installed Microsoft Office products..."

    # Query via WMI for Office installations
    $officeDetails = Get-CimInstance -Namespace "Root\cimv2" -ClassName Win32_Product |
        Where-Object { $_.Name -match "Microsoft Office" }

    if ($officeDetails) {
        foreach ($office in $officeDetails) {
            Write-Output "Product Name: $($office.Name)"
            Write-Output "Version: $($office.Version)"
            Write-Output "Install Location: $($office.InstallLocation)"
            Write-Output "Install Date: $([datetime]::ParseExact($office.InstallDate, 'yyyyMMdd', $null))"
            Write-Output "Vendor: $($office.Vendor)"
            Write-Output "----------------------------------------"
        }
    } else {
        Write-Output "No Microsoft Office products found via WMI query."
    }

    # Query Office Click-to-Run installations using the registry
    $ctrPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
    if (Test-Path $ctrPath) {
        $ctrConfig = Get-ItemProperty -Path $ctrPath
        Write-Output "Product Name: $($ctrConfig.ProductName)"
        Write-Output "Version: $($ctrConfig.ClientVersionToReport)"
        Write-Output "Install Source: $($ctrConfig.UpdateUrl)"
        Write-Output "----------------------------------------"
    } else {
        Write-Output "No Click-to-Run Office installations found."
    }
}

# Call the function
Get-MSOfficeDetails
