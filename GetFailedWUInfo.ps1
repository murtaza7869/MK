# Define the output file path
$outputFile = "C:\FailedWindowsUpdates.txt"

# Get the failed Windows updates
$failedUpdates = Get-WindowsUpdateLog | Select-String "Installation Failure" | ForEach-Object {
    $parts = $_.Line -split "\s+"
    [PSCustomObject]@{
        Date      = $parts[0]
        Time      = $parts[1]
        UpdateID  = $parts[3]
        ErrorCode = $parts[-1]
    }
}

# Function to get the reason for failure based on the error code
function Get-FailureReason($errorCode) {
    switch ($errorCode) {
        '0x800705b4' { "Timeout error." }
        '0x80070005' { "Access denied. This may be due to insufficient permissions." }
        '0x80070643' { "Installation failed. This could be due to a corrupt .NET framework or an issue with Windows Update components." }
        '0x80242016' { "Temporary connection-related failure." }
        '0x800f081f' { "Missing or corrupt update files." }
        '0x80240017' { "Generic error. Potential issue with the Windows Update components." }
        default      { "Unknown error code. Further investigation required." }
    }
}

# Collect the output data
$outputData = $failedUpdates | ForEach-Object {
    [PSCustomObject]@{
        Date        = $_.Date
        Time        = $_.Time
        UpdateID    = $_.UpdateID
        ErrorCode   = $_.ErrorCode
        Reason      = Get-FailureReason $_.ErrorCode
    }
} | Format-Table -AutoSize | Out-String

# Write the output data to the text file
$outputData | Out-File -FilePath $outputFile -Force

# Confirm completion
Write-Host "Failed Windows Updates have been logged to $outputFile"
