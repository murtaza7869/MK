# PowerShell Script to Download, Extract and Run an Executable
# Set your download URL and executable name directly in these variables
$DownloadURL = "https://aejvancouver-my.sharepoint.com/:u:/g/personal/murtaza_kanchwala_vancouverjamaat_ca/Ecqv6vxay3hLuQMpOwqP8XQB3X-XIQdcH3Wj0VjUVJB6vw?download=1" # Replace with your actual download URL
$ExeName = "TBS_INSTALLER_7.0.0.45.exe"                                # Replace with your actual executable name

# Set the download location and file name
$tempFolder = "C:\Windows\Temp"
$zipFile = Join-Path -Path $tempFolder -ChildPath "download.zip"
$extractFolder = Join-Path -Path $tempFolder -ChildPath "extracted"

# Create the extraction folder if it doesn't exist
if (-not (Test-Path -Path $extractFolder)) {
    New-Item -Path $extractFolder -ItemType Directory -Force
}

try {
    # Download the file
    Write-Host "Downloading file from $DownloadURL..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $DownloadURL -OutFile $zipFile
    
    # Check if download was successful
    if (Test-Path -Path $zipFile) {
        Write-Host "Download completed successfully."
        
        # Extract the ZIP file
        Write-Host "Extracting ZIP file to $extractFolder..."
        Expand-Archive -Path $zipFile -DestinationPath $extractFolder -Force
        
        # Check if extraction was successful
        if (Test-Path -Path $extractFolder) {
            Write-Host "Extraction completed successfully."
            
            # Find the executable
            $exePath = Get-ChildItem -Path $extractFolder -Filter $ExeName -Recurse | Select-Object -First 1 -ExpandProperty FullName
            
            if ($exePath -and (Test-Path -Path $exePath)) {
                Write-Host "Executing $exePath..."
                # Run the executable
                Start-Process -FilePath $exePath -Wait
                Write-Host "Execution completed."
            } else {
                Write-Host "Error: Could not find $ExeName in the extracted files." -ForegroundColor Red
            }
        } else {
            Write-Host "Error: Failed to extract ZIP file." -ForegroundColor Red
        }
    } else {
        Write-Host "Error: Download failed." -ForegroundColor Red
    }
} catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
} finally {
    # Optional: Clean up temporary files
    # Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
    # Remove-Item -Path $extractFolder -Recurse -Force -ErrorAction SilentlyContinue
}
