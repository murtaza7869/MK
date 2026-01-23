# Set error action preference
$ErrorActionPreference = "Stop"

# Define registry path - HKCR maps to HKEY_CLASSES_ROOT
$RegistryPath = "Registry::HKEY_CLASSES_ROOT\{359C24F1-51B5-44CE-8F2D-2FBB1A0FE4EA}\FWA_GUI_Agent"
$ValueName = "server"

try {
    Write-Output "==================== FWA GUI AGENT SERVER CHECK ===================="
    Write-Output "Registry Path: $RegistryPath"
    Write-Output "Value Name: $ValueName"
    Write-Output ""

    # Check if the registry key exists
    if (Test-Path -Path $RegistryPath) {
        Write-Output "Registry key exists"
        
        # Try to get the registry value
        $RegValue = Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue
        
        if ($null -ne $RegValue) {
            $ServerValue = $RegValue.$ValueName
            $ValueType = (Get-Item -Path $RegistryPath).GetValueKind($ValueName)
            
            Write-Output "Registry value exists"
            Write-Output ""
            Write-Output "==================== SERVER VALUE ===================="
            Write-Output "Server: $ServerValue"
            Write-Output "Value Type: $ValueType"
            Write-Output "====================================================="
            Write-Output ""
            Write-Output "SUCCESS: Server value retrieved successfully"
            
            # Return success
            exit 0
        } else {
            Write-Output "ERROR: Registry value 'server' not found in key"
            Write-Output ""
            Write-Output "Available values in FWA_GUI_Agent key:"
            Get-ItemProperty -Path $RegistryPath | Format-List
            exit 1
        }
        
    } else {
        Write-Output "ERROR: Registry key does not exist"
        Write-Output "Expected path: $RegistryPath"
        Write-Output ""
        
        # Check if parent GUID key exists
        $ParentPath = "Registry::HKEY_CLASSES_ROOT\{359C24F1-51B5-44CE-8F2D-2FBB1A0FE4EA}"
        if (Test-Path -Path $ParentPath) {
            Write-Output "Parent GUID key exists. Available subkeys:"
            Get-ChildItem -Path $ParentPath | Select-Object Name | Format-Table -AutoSize
        } else {
            Write-Output "Parent GUID key also does not exist"
        }
        exit 1
    }

} catch {
    Write-Output "ERROR: An error occurred while reading registry"
    Write-Output "Error Message: $_"
    Write-Output $_.Exception.Message
    exit 1
}
