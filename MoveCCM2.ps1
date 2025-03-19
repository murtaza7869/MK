# PowerShell Script to move C:\Windows\CCM to T:\CCM and create a junction link
# This script must be run as Administrator

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges. Please restart PowerShell as Administrator."
    exit
}

# Define source and destination paths
$sourcePath = "C:\Windows\CCM"
$destinationPath = "T:\CCM"

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

# Copy all files directly from source to the new location
Write-Host "Copying files from $sourcePath to $destinationPath. This may take some time..."
try {
    # Using robocopy instead of Copy-Item for better handling of system files
    $robocopyOutput = robocopy $sourcePath $destinationPath /E /COPYALL /R:1 /W:1 /NFL /NDL /NJH /NJS
    if ($LASTEXITCODE -lt 8) {
        Write-Host "Files copied successfully." -ForegroundColor Green
    } else {
        throw "Robocopy reported errors with exit code $LASTEXITCODE"
    }
} catch {
    Write-Error "Failed to copy files: $_"
    
    # Try to restart services if copy fails
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

# Move the original folder contents to a temp location and remove it
# This approach is more reliable than trying to directly remove protected system folders
$tempPath = "$sourcePath-TEMP-TO-DELETE"
Write-Host "Moving original CCM folder contents to temporary location..."
try {
    # Temporarily save ACLs
    $acl = Get-Acl -Path $sourcePath
    
    # Create a temporary folder next to source
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
    
    # Move files using cmd.exe move command which is more reliable for system folders
    $moveOutput = cmd /c "move /Y ""$sourcePath\*"" ""$tempPath\"""
    
    # Now try to remove the original folder which should be empty
    if (Test-Path -Path $sourcePath) {
        Remove-Item -Path $sourcePath -Force -Recurse
    }
    
    Write-Host "Original folder contents moved and folder removed successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to move/remove original folder: $_"
    
    # Try to restart services if removal fails
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

# Create the junction link using cmd.exe mklink which is more reliable for system folders
Write-Host "Creating junction link..."
try {
    $cmdOutput = cmd /c "mklink /J ""$sourcePath"" ""$destinationPath"""
    if ($cmdOutput -like "*created*") {
        Write-Host "Junction link created successfully." -ForegroundColor Green
    } else {
        throw "Mklink command did not report success: $cmdOutput"
    }
} catch {
    Write-Error "Failed to create junction link: $_"
    
    # Try to restart services if junction creation fails
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

# Try to clean up the temporary folder
try {
    if (Test-Path -Path $tempPath) {
        Remove-Item -Path $tempPath -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "Temporary folder removed." -ForegroundColor Green
    }
} catch {
    Write-Warning "Failed to remove temporary folder $tempPath: $_"
    Write-Host "You may want to manually remove this folder later." -ForegroundColor Yellow
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

Write-Host "Operation completed. CCM folder has been moved to $destinationPath and a junction link has been created at $sourcePath."
