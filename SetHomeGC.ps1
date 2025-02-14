# Define the homepage URL
$HomePage = "https://microsoft.com"

# Registry path for Chrome policies (applies machine-wide)
$RegPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"

# Ensure the registry path exists
if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}

# Set the homepage policy
Set-ItemProperty -Path $RegPath -Name "HomepageLocation" -Value $HomePage -Type String
Set-ItemProperty -Path $RegPath -Name "HomepageIsNewTabPage" -Value 0 -Type DWord
Set-ItemProperty -Path $RegPath -Name "RestoreOnStartup" -Value 1 -Type DWord
Set-ItemProperty -Path $RegPath -Name "RestoreOnStartupURLs" -Value $HomePage -Type MultiString

# Force Chrome to always start in Incognito mode
Set-ItemProperty -Path $RegPath -Name "IncognitoModeAvailability" -Value 2 -Type DWord

# Path to Chrome executable
$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"

# Ensure Chrome is installed
if (-Not (Test-Path $ChromePath)) {
    $ChromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}

if (Test-Path $ChromePath) {
    # Command-line arguments to force Incognito mode and open homepage
    $ChromeArgs = "--incognito --new-window $HomePage"

    # Modify shortcuts for all users (Desktop and Start Menu)
    $Shortcuts = @(
        "C:\Users\Public\Desktop\Google Chrome.lnk",
        "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk"
    )

    foreach ($Shortcut in $Shortcuts) {
        if (Test-Path $Shortcut) {
            # Use WScript Shell to modify the shortcut
            $WScriptShell = New-Object -ComObject WScript.Shell
            $ShortcutObject = $WScriptShell.CreateShortcut($Shortcut)
            $ShortcutObject.TargetPath = $ChromePath
            $ShortcutObject.Arguments = $ChromeArgs
            $ShortcutObject.Save()
        }
    }

    Write-Output "Chrome shortcuts updated to launch with homepage in Incognito mode."
} else {
    Write-Output "Google Chrome not found! Ensure it's installed."
}

# Apply changes immediately
gpupdate /force
Write-Output "Google Chrome homepage and Incognito mode policy have been set."
