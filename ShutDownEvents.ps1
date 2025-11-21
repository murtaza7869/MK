# Get-ShutdownEvents.ps1
# Retrieves all shutdown events from the Windows Event Log

param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [int]$Days = 7,
    [switch]$ExportToCSV,
    [string]$OutputPath = ".\ShutdownEvents_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Write-Host "Retrieving shutdown events for: $ComputerName" -ForegroundColor Cyan
Write-Host "Looking back $Days days..." -ForegroundColor Cyan
Write-Host ""

# Calculate the date range
$StartDate = (Get-Date).AddDays(-$Days)

# Define shutdown-related event IDs
$ShutdownEventIDs = @(
    1074,  # System shutdown/restart (user initiated)
    1076,  # Unexpected shutdown (dirty shutdown)
    6005,  # Event Log service started (system startup)
    6006,  # Event Log service stopped (clean shutdown)
    6008,  # Unexpected shutdown (system crash)
    6009,  # System information at boot
    41     # Kernel-Power (system rebooted without cleanly shutting down)
)

# Build the filter hashtable
$FilterHashtable = @{
    LogName = 'System'
    ID = $ShutdownEventIDs
    StartTime = $StartDate
}

try {
    # Get the events
    if ($ComputerName -ne $env:COMPUTERNAME) {
        $FilterHashtable.Add('ComputerName', $ComputerName)
    }
    
    $Events = Get-WinEvent -FilterHashtable $FilterHashtable -ErrorAction Stop
    
    # Process and format the events
    $FormattedEvents = $Events | ForEach-Object {
        $EventID = $_.Id
        $TimeCreated = $_.TimeCreated
        $Message = $_.Message
        $User = $_.UserId
        
        # Determine event type
        $EventType = switch ($EventID) {
            1074 { "User-Initiated Shutdown/Restart" }
            1076 { "Unexpected Shutdown" }
            6005 { "System Startup (Event Log Started)" }
            6006 { "Clean Shutdown (Event Log Stopped)" }
            6008 { "Unexpected Shutdown (System Crash)" }
            6009 { "System Boot Information" }
            41   { "Critical Shutdown (Kernel-Power)" }
            default { "Unknown" }
        }
        
        # Extract shutdown reason if available (for Event ID 1074)
        $Reason = "N/A"
        $Process = "N/A"
        if ($EventID -eq 1074) {
            if ($Message -match "Process\s+(.+?)\s+has") {
                $Process = $Matches[1]
            }
            if ($Message -match "Reason Code:\s+(.+)") {
                $Reason = $Matches[1].Trim()
            }
        }
        
        # Create custom object
        [PSCustomObject]@{
            TimeCreated = $TimeCreated
            EventID = $EventID
            EventType = $EventType
            Computer = $ComputerName
            User = if ($User) { 
                try {
                    $sid = New-Object System.Security.Principal.SecurityIdentifier($User)
                    $sid.Translate([System.Security.Principal.NTAccount]).Value
                } catch {
                    $User
                }
            } else { "N/A" }
            Process = $Process
            Reason = $Reason
            Message = ($Message -replace '\r\n', ' ' -replace '\s+', ' ').Trim()
        }
    }
    
    # Display results
    if ($FormattedEvents) {
        Write-Host "Found $($FormattedEvents.Count) shutdown events:" -ForegroundColor Green
        Write-Host ""
        
        # Group by event type for summary
        $Summary = $FormattedEvents | Group-Object EventType | Select-Object Count, Name
        Write-Host "Summary by Event Type:" -ForegroundColor Yellow
        $Summary | Format-Table -AutoSize
        
        Write-Host "Detailed Events (Most Recent First):" -ForegroundColor Yellow
        $FormattedEvents | Sort-Object TimeCreated -Descending | Format-Table TimeCreated, EventID, EventType, User, Process -AutoSize
        
        # Export to CSV if requested
        if ($ExportToCSV) {
            $FormattedEvents | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Host ""
            Write-Host "Results exported to: $OutputPath" -ForegroundColor Green
        }
        
        # Show last clean shutdown and unexpected shutdown
        $LastCleanShutdown = $FormattedEvents | Where-Object { $_.EventID -eq 6006 } | Sort-Object TimeCreated -Descending | Select-Object -First 1
        $LastUnexpectedShutdown = $FormattedEvents | Where-Object { $_.EventID -in @(1076, 6008, 41) } | Sort-Object TimeCreated -Descending | Select-Object -First 1
        
        Write-Host ""
        Write-Host "Notable Events:" -ForegroundColor Cyan
        if ($LastCleanShutdown) {
            Write-Host "  Last Clean Shutdown: $($LastCleanShutdown.TimeCreated)" -ForegroundColor Green
        }
        if ($LastUnexpectedShutdown) {
            Write-Host "  Last Unexpected Shutdown: $($LastUnexpectedShutdown.TimeCreated) (Event ID: $($LastUnexpectedShutdown.EventID))" -ForegroundColor Red
        }
        
    } else {
        Write-Host "No shutdown events found in the specified time range." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error retrieving events: $_" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*elevated*") {
        Write-Host "Note: You may need to run this script as Administrator to access certain event logs." -ForegroundColor Yellow
    }
}

# Optional: Return the formatted events for further processing
return $FormattedEvents
