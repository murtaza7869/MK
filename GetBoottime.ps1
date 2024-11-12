# Define the time period (last 3 days)
$startTime = (Get-Date).AddDays(-3)

# Retrieve events for both startup (ID 6005) and shutdown (ID 6006)
$events = Get-WinEvent -FilterHashtable @{LogName='System'; ID=@(506,6005,6006); StartTime=$startTime}

if ($events) {
    $events | Select-Object -Property TimeCreated, ID, Message |
    Sort-Object TimeCreated -Descending |
    ForEach-Object {
        if ($_.ID -eq 6005) {
            "Boot Time: $($_.TimeCreated)"
        } elseif ($_.ID -eq 6006) {
            "Shutdown Time: $($_.TimeCreated)"
        }
    }
} else {
    Write-Output "No relevant startup or shutdown events found in the last 3 days."
}
