# PowerShell Script to Rename DLL Files and Restart the Machine

# Define file paths
$files = @(
    "C:\Program Files\Faronics\WINSelect\Win32\WSAPI.dll",
    "C:\Program Files\Faronics\WINSelect\WSAPI.dll"
)

# Timestamp for backup
$timestamp = (Get-Date -Format "yyyyMMddHHmmss")

# Rename each file
foreach ($file in $files) {
    if (Test-Path $file) {
        try {
            $newName = "$file.$timestamp.bak"
            Rename-Item -Path $file -NewName $newName -ErrorAction Stop
            Write-Host "Renamed $file to $newName"
        } catch {
            Write-Host "Failed to rename $file. Error: $_"
            exit 1
        }
    } else {
        Write-Host "File not found: $file"
    }
}

# Initiate a restart
Write-Host "Restarting the machine in 1 minute..."
Restart-Computer -Force -Delay 60
