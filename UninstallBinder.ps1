# Uninstall script for MSI package
# This script runs the MsiExec command to uninstall a specific program

# Set the product code from the MSI package
$ProductCode = "{884D3EFF-5207-454F-8EC9-C54FC86F7594}"

# Display information about what the script is doing
Write-Host "Starting uninstallation of product with code: $ProductCode"

try {
    # Run the MsiExec command to uninstall the program
    $process = Start-Process -FilePath "MsiExec.exe" -ArgumentList "/X$ProductCode" -Wait -PassThru -NoNewWindow
    
    # Check the exit code
    if ($process.ExitCode -eq 0) {
        Write-Host "Uninstallation completed successfully." -ForegroundColor Green
    } 
    else {
        Write-Host "Uninstallation completed with exit code: $($process.ExitCode)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "An error occurred during uninstallation: $_" -ForegroundColor Red
}

Write-Host "Uninstallation process finished."
