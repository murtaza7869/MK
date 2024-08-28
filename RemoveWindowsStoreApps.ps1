# Define the list of apps to be removed
$appsToRemove = @(
    "Microsoft.OneDrive",
    "Microsoft.SkypeApp",
    "Microsoft.MicrosoftTeams",
    "Microsoft.ZuneMusic",  # Groove Music
    "Microsoft.ZuneVideo",  # Movies & TV
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.Messaging",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.Office.OneNote",
    "Microsoft.People",
    "Microsoft.Print3D",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCamera",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MSPaint"
)

# Remove apps for the current user
foreach ($app in $appsToRemove) {
    Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage
}

# Prevent apps from being provisioned for new users
foreach ($app in $appsToRemove) {
    Get-AppxProvisionedPackage -Online | where DisplayName -EQ $app | Remove-AppxProvisionedPackage -Online
}

# Optional: Remove OneDrive completely from the system
# Uninstall OneDrive
$onedrivePath = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
if (Test-Path $onedrivePath) {
    Start-Process $onedrivePath "/uninstall" -NoNewWindow -Wait
}

# Clean up residual OneDrive files and folders
Remove-Item -Path "$env:UserProfile\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LocalAppData\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:ProgramData\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemDrive\OneDriveTemp" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Bloatware apps removed and provisioning prevented for new users."
