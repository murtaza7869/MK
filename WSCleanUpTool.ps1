# Define the URL and the destination path for the download
$downloadUrl = "https://github.com/murtaza7869/MK/blob/main/WINSelectCleanUpTool.exe"
$destinationPath = "C:\WINSelectCleanUpTool.exe"

# Download the file
Invoke-WebRequest -Uri $downloadUrl -OutFile $destinationPath

# Create the scheduled task
schtasks /Create /RU System /SC MONTHLY /tn LaunchWINSelectCleanUpTool /tr $destinationPath

# Run the scheduled task immediately
schtasks /run /tn LaunchWINSelectCleanUpTool

# Wait for 240 seconds
Start-Sleep -Seconds 120

# Delete the scheduled task
schtasks /delete /tn LaunchWINSelectCleanUpTool /f
