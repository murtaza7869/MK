# Path to the DLL file
$dllPath = "C:\Program Files\Faronics\WINSelect\WinSelectAdapter.dll"

# Check if the file exists
if (Test-Path $dllPath) {
    try {
        # Execute regsvr32 command to register the DLL
        Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s", $dllPath -Wait -NoNewWindow

        # Check if registration was successful
        if ($LASTEXITCODE -eq 0) {
            Write-Host "DLL registered successfully."
        } else {
            Write-Host "DLL registration failed with exit code: $LASTEXITCODE"
        }
    } catch {
        Write-Host "An error occurred while registering the DLL: $_"
    }
} else {
    Write-Host "DLL file not found at the specified path: $dllPath"
}
