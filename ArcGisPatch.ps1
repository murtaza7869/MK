# ArcGIS Pro Patch Installation Script
# This script downloads and installs the ArcGIS Pro 3.5.3 patch (195507)

# Define variables
$downloadUrl = "https://biblsysaiddvst.blob.core.windows.net/dfcloud/ArcGIS_Pro_353_195507.msp"
$tempFolder = "C:\temp"
$mspFileName = "ArcGIS_Pro_353_195507.msp"
$localFilePath = Join-Path $tempFolder $mspFileName

try {
    # Create temp folder if it doesn't exist
    Write-Host "Checking for temp folder..." -ForegroundColor Yellow
    if (!(Test-Path $tempFolder)) {
        Write-Host "Creating folder: $tempFolder" -ForegroundColor Green
        New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
    } else {
        Write-Host "Folder already exists: $tempFolder" -ForegroundColor Green
    }

    # Download the MSP file
    Write-Host "`nDownloading MSP file..." -ForegroundColor Yellow
    Write-Host "Source: $downloadUrl" -ForegroundColor Cyan
    Write-Host "Destination: $localFilePath" -ForegroundColor Cyan
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $localFilePath -UseBasicParsing
        Write-Host "Download completed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Error downloading file: $_" -ForegroundColor Red
        exit 1
    }

    # Verify the file was downloaded
    if (Test-Path $localFilePath) {
        $fileSize = (Get-Item $localFilePath).Length / 1MB
        Write-Host "`nFile downloaded successfully. Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
    } else {
        Write-Host "Error: File was not downloaded properly!" -ForegroundColor Red
        exit 1
    }

    # Execute the MSP file with msiexec
    Write-Host "`nInstalling ArcGIS Pro patch..." -ForegroundColor Yellow
    $msiArguments = "/p `"$localFilePath`" REINSTALLMODE=omus REINSTALL=ALL /qn"
    Write-Host "Executing: msiexec.exe $msiArguments" -ForegroundColor Cyan
    
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArguments -Wait -PassThru
    
    # Check the exit code
    if ($process.ExitCode -eq 0) {
        Write-Host "`nPatch installation completed successfully!" -ForegroundColor Green
    } elseif ($process.ExitCode -eq 3010) {
        Write-Host "`nPatch installation completed successfully but requires a restart." -ForegroundColor Yellow
        Write-Host "Please restart your computer to complete the installation." -ForegroundColor Yellow
    } else {
        Write-Host "`nPatch installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
        Write-Host "Common exit codes:" -ForegroundColor Yellow
        Write-Host "  1603 - Fatal error during installation" -ForegroundColor Yellow
        Write-Host "  1618 - Another installation is in progress" -ForegroundColor Yellow
        Write-Host "  1619 - Installation package could not be opened" -ForegroundColor Yellow
        Write-Host "  1638 - Another version of the product is already installed" -ForegroundColor Yellow
    }

    # Optional: Ask if user wants to delete the downloaded file
    $response = Read-Host "`nDo you want to delete the downloaded MSP file? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        Remove-Item -Path $localFilePath -Force
        Write-Host "MSP file deleted." -ForegroundColor Green
    } else {
        Write-Host "MSP file kept at: $localFilePath" -ForegroundColor Cyan
    }

} catch {
    Write-Host "`nAn error occurred: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`nScript execution completed." -ForegroundColor Green
