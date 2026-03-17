# Define the list of services to target
$services = @("FAVEService", "FAVECore")

foreach ($serviceName in $services) {
    # Check if the service exists on the system first
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($service) {
        Write-Host "Processing service: $serviceName" -ForegroundColor Cyan

        # Stop the service if it is running
        if ($service.Status -eq 'Running') {
            Write-Host "  Stopping $serviceName..." -NoNewline
            Stop-Service -Name $serviceName -Force
            Write-Host " Done." -ForegroundColor Green
        } else {
            Write-Host "  $serviceName is already stopped." -ForegroundColor Gray
        }

        # Disable the service
        Write-Host "  Disabling $serviceName..." -NoNewline
        Set-Service -Name $serviceName -StartupType Disabled
        Write-Host " Done." -ForegroundColor Green
    } else {
        Write-Warning "Service '$serviceName' was not found on this machine."
    }
}

Write-Host "`nAll specified services have been processed." -ForegroundColor Yellow
