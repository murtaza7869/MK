<#
.SYNOPSIS
    Downloads and executes an EXE, then outputs its log file contents.
.DESCRIPTION
    This script downloads an executable from a provided URL, runs it under SYSTEM context,
    waits for the log file to be created, and outputs its contents.
.PARAMETER DownloadUrl
    The direct download URL for the executable file.
.EXAMPLE
    .\Execute-AndReadLog.ps1 -DownloadUrl "https://example.com/IntWebServerChanger.exe"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$DownloadUrl
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Define paths
$TempPath = "$env:TEMP\IntWebServerChanger"
$ExePath = "$TempPath\IntWebServerChanger.exe"
$LogPath = "$TempPath\IntWebServerChanger.exe-STUB.LOG"

try {
    # Create temp directory if it doesn't exist
    if (-not (Test-Path -Path $TempPath)) {
        New-Item -Path $TempPath -ItemType Directory -Force | Out-Null
        Write-Output "Created temporary directory: $TempPath"
    }

    # Download the executable
    Write-Output "Downloading executable from: $DownloadUrl"
    Write-Output "Download location: $ExePath"
    
    # Use .NET WebClient for reliable download under SYSTEM account
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($DownloadUrl, $ExePath)
    
    if (Test-Path -Path $ExePath) {
        Write-Output "Download completed successfully"
        $FileSize = (Get-Item $ExePath).Length
        Write-Output "File size: $FileSize bytes"
    } else {
        throw "Download failed - file not found at $ExePath"
    }

    # Execute the downloaded file
    Write-Output "`nExecuting: $ExePath"
    $Process = Start-Process -FilePath $ExePath -WorkingDirectory $TempPath -PassThru -Wait
    
    Write-Output "Process completed with exit code: $($Process.ExitCode)"

    # Wait for log file to be created (with timeout)
    Write-Output "`nWaiting for log file to be created..."
    $Timeout = 30 # seconds
    $Timer = 0
    $Interval = 1 # second
    
    while (-not (Test-Path -Path $LogPath) -and ($Timer -lt $Timeout)) {
        Start-Sleep -Seconds $Interval
        $Timer += $Interval
    }

    # Check if log file exists and read it
    if (Test-Path -Path $LogPath) {
        Write-Output "Log file found at: $LogPath"
        Write-Output "`n==================== LOG FILE CONTENTS ===================="
        
        # Read and output the log file contents
        Get-Content -Path $LogPath | ForEach-Object { Write-Output $_ }
        
        Write-Output "==================== END OF LOG FILE ===================="
    } else {
        Write-Warning "Log file was not created within $Timeout seconds"
        Write-Warning "Expected location: $LogPath"
    }

} catch {
    Write-Error "An error occurred: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
} finally {
    # Optional: Cleanup (comment out if you want to preserve files for troubleshooting)
    # Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
}

exit 0
