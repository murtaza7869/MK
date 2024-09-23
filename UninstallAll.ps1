# PowerShell script to uninstall products in sequence and reboot after completion

function Uninstall-Product {
    param (
        [string]$ProductGuid,
        [string]$ProductName
    )

    Write-Host "Uninstalling product $ProductName..."
    $process = Start-Process msiexec.exe -ArgumentList "/X$ProductGuid /quiet /norestart" -PassThru -Wait
    if ($process.ExitCode -eq 0) {
        Write-Host "Uninstallation of $ProductName completed successfully."
    } elseif ($process.ExitCode -eq 3010) {
        Write-Host "Uninstallation of $ProductName completed successfully, a reboot is required."
    } else {
        Write-Host "Uninstallation of $ProductName failed with error code $($process.ExitCode)."
    }
    Start-Sleep -Seconds 5
}

Uninstall-Product "{74B5307B-2002-4823-A5D0-DF067F46FE91}" "Faronics Software Updater"
Uninstall-Product "{F6BAFFE7-D8EF-493A-8E06-864836A41078}" "Faronics UsageStats"
Uninstall-Product "{EEA10E7D-C7CF-4743-B002-00C5CFD95157}" "Faronics Imaging"
Uninstall-Product "{0D326B4C-1102-4C69-8266-7323C701B45C}" "Faronics Deploy Agent"

Write-Host "All products uninstalled. The system will reboot in 30 seconds."
Start-Sleep -Seconds 30

# Reboot the system
Restart-Computer -Force
