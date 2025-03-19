# PowerShell Script to move C:\Windows\CCM to T:\CCM and create a junction link
# This script must be run as Administrator

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges. Please restart PowerShell as Administrator."
    exit
}

# Define source and destination paths
$sourcePath = "C:\Windows\CCM"
$destinationPath = "E:\sccm_data"
$backupPath = "C:\Windows\CCM_Backup"

# Ensure the destination drive exists
if (-NOT (Test-Path "T:\" -PathType Container)) {
    Write-Error "The T: drive does not exist. Please ensure the drive is connected and try again."
    exit
}

# Check if source folder exists
if (-NOT (Test-Path $sourcePath -PathType Container)) {
    Write-Error "The CCM folder does not exist at $sourcePath"
    exit
}

# Create the destination directory if it doesn't exist
if (-NOT (Test-Path $destinationPath -PathType Container)) {
    Write-Host "Creating destination directory $destinationPath"
    New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null
}

# Stop SMS related services
Write-Host "Stopping SMS related services..."
$smsServices = Get-Service | Where-Object { $_.Name -like "SMS*" -or $_.Name -like "CcmExec" -or $_.DisplayName -like "*Configuration Manager*" }
foreach ($service in $smsServices) {
    Write-Host "Stopping service: $($service.DisplayName) [$($service.Name)]"
    try {
        Stop-Service -Name $service.Name -Force -ErrorAction Stop
        Write-Host "Service stopped successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to stop service $($service.Name): $_"
    }
}

# Wait a moment for services to fully stop
Start-Sleep -Seconds 5

# Rename the original folder as backup
Write-Host "Creating backup of original CCM folder..."
try {
    Rename-Item -Path $sourcePath -NewName $backupPath -ErrorAction Stop
    Write-Host "Backup created successfully at $backupPath" -ForegroundColor Green
} catch {
    Write-Error "Failed to create backup: $_"
    
    # Try to restart services if backup fails
    Write-Host "Attempting to restart services..."
    foreach ($service in $smsServices) {
        try {
            Start-Service -Name $service.Name -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to restart service $($service.Name): $_"
        }
    }
    exit
}

# Create the junction link
Write-Host "Creating junction link..."
try {
    $null = [System.IO.Directory]::CreateSymbolicLink($sourcePath, $destinationPath, 1) # 1 means directory symbolic link
    Write-Host "Junction link created successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to create junction link: $_"
    
    # Try to restore from backup if junction creation fails
    Write-Host "Restoring from backup..."
    Remove-Item -Path $sourcePath -Force -ErrorAction SilentlyContinue
    Rename-Item -Path $backupPath -NewName $sourcePath
    
    # Try to restart services
    Write-Host "Attempting to restart services..."
    foreach ($service in $smsServices) {
        try {
            Start-Service -Name $service.Name -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to restart service $($service.Name): $_"
        }
    }
    exit
}

# Copy all files from backup to the new location
Write-Host "Copying files from backup to new location. This may take some time..."
try {
    Copy-Item -Path "$backupPath\*" -Destination $destinationPath -Recurse -Force -ErrorAction Stop
    Write-Host "Files copied successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to copy files: $_"
    
    # Try to restore from backup if copy fails
    Write-Host "Restoring from backup..."
    Remove-Item -Path $sourcePath -Force -ErrorAction SilentlyContinue
    Rename-Item -Path $backupPath -NewName $sourcePath
    
    # Try to restart services
    Write-Host "Attempting to restart services..."
    foreach ($service in $smsServices) {
        try {
            Start-Service -Name $service.Name -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to restart service $($service.Name): $_"
        }
    }
    exit
}

# Start SMS related services
Write-Host "Starting SMS related services..."
foreach ($service in $smsServices) {
    Write-Host "Starting service: $($service.DisplayName) [$($service.Name)]"
    try {
        Start-Service -Name $service.Name -ErrorAction Stop
        Write-Host "Service started successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to start service $($service.Name): $_"
    }
}

# Verify the junction link works
if (Test-Path $sourcePath) {
    Write-Host "Verification: Junction link at $sourcePath exists and points to $destinationPath" -ForegroundColor Green
} else {
    Write-Warning "Verification failed: Junction link does not exist."
}

# Ask if user wants to delete the backup
$deleteBackup = Read-Host "Do you want to delete the backup folder at $backupPath? (Y/N)"
if ($deleteBackup -eq "Y" -or $deleteBackup -eq "y") {
    try {
        Remove-Item -Path $backupPath -Recurse -Force -ErrorAction Stop
        Write-Host "Backup folder deleted successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to delete backup folder: $_"
    }
} else {
    Write-Host "Backup folder preserved at $backupPath" -ForegroundColor Yellow
}

Write-Host "Operation completed. CCM folder has been moved to $destinationPath and a junction link has been created at $sourcePath."
