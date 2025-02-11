# PowerShell script to get asset tag
# Method 1: Using Win32_SystemEnclosure
Write-Host "Method 1: Checking Win32_SystemEnclosure"
$assetTag1 = Get-WmiObject -Class Win32_SystemEnclosure | Select-Object -ExpandProperty SMBIOSAssetTag
if ($assetTag1 -and $assetTag1.Trim() -ne "") {
    Write-Host "Asset Tag found: $assetTag1"
} else {
    Write-Host "No asset tag found in Win32_SystemEnclosure"
}

# Method 2: Using SMBIOS directly (alternative method)
Write-Host "`nMethod 2: Checking SMBIOS directly"
$assetTag2 = Get-CimInstance -ClassName Win32_SystemEnclosure | Select-Object -ExpandProperty SMBIOSAssetTag
if ($assetTag2 -and $assetTag2.Trim() -ne "") {
    Write-Host "Asset Tag found: $assetTag2"
} else {
    Write-Host "No asset tag found in SMBIOS"
}
