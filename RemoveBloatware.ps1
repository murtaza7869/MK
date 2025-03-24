# Windows 11 Bloatware Removal Script
# Run as administrator in PowerShell
# CAUTION: Review the list before running to ensure you don't remove apps you want to keep

# Elevate to admin if not already
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script needs to be run as Administrator. Attempting to restart with elevated privileges..."
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Starting Windows 11 bloatware removal..." -ForegroundColor Green

# Define apps to remove - add or remove from this list as needed
$AppsToRemove = @(
    # Common Bloatware
    "Microsoft.549981C3F5F10"    # Cortana
    "Microsoft.BingNews"
    "Microsoft.BingWeather"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.People"
    "Microsoft.Todos"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    
    # Games
    "Microsoft.MixedReality.Portal"
    "Microsoft.SkypeApp"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.GamingApp"
    "Microsoft.XboxGameCallableUI"
    
    # Potentially Unwanted (review carefully)
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCamera"
    "microsoft.windowscommunicationsapps"    # Mail & Calendar
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.PowerAutomateDesktop"
    
    # Third-party bloatware
    "SpotifyAB.SpotifyMusic"
    "king.com.CandyCrushSaga"
    "king.com.CandyCrushFriends"
    "XINGAG.XING"
    "Facebook.Facebook"
    "Fitbit.FitbitCoach"
    "BytedancePte.Ltd.TikTok"
    "Disney.37853FC22B2CE"     # Disney+
    "AmazonVideo.PrimeVideo"
    "4DF9E0F8.Netflix"
)

$SuccessCount = 0
$FailCount = 0
$SkipCount = 0

Write-Host "`nRemoving apps...`n" -ForegroundColor Cyan

# Get all provisioned app packages
$AllProvisionedPackages = Get-AppxProvisionedPackage -Online

# Loop through each app to remove
foreach ($App in $AppsToRemove) {
    try {
        # Check if the app exists before trying to remove it
        $PackageFullName = (Get-AppxPackage $App -ErrorAction SilentlyContinue).PackageFamilyName
        $ProPackageFullName = ($AllProvisionedPackages | Where-Object { $_.DisplayName -eq $App }).PackageName

        if ($PackageFullName -or $ProPackageFullName) {
            # Remove installed package
            Write-Host "Removing $App..." -NoNewline
            
            if ($PackageFullName) {
                Get-AppxPackage -Name $App -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                Get-AppxPackage -Name $App | Remove-AppxPackage -ErrorAction SilentlyContinue
            }

            # Remove provisioned package
            if ($ProPackageFullName) {
                Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $App } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            }
            
            $SuccessCount++
            Write-Host " Done" -ForegroundColor Green
        }
        else {
            Write-Host "Skipping $App (not found)" -ForegroundColor Yellow
            $SkipCount++
        }
    }
    catch {
        Write-Host " Failed" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        $FailCount++
    }
}

# Remove capabilities (optional)
Write-Host "`nRemoving optional features..." -ForegroundColor Cyan
$CapabilitiesToRemove = @(
    "App.StepsRecorder~~~~0.0.1.0"
    "Browser.InternetExplorer~~~~0.0.11.0"
    "MathRecognizer~~~~0.0.1.0"
    "Media.WindowsMediaPlayer~~~~0.0.12.0"
    "Microsoft.Windows.WordPad~~~~0.0.1.0"
    "Print.Fax.Scan~~~~0.0.1.0"
    "Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0"
)

foreach ($Capability in $CapabilitiesToRemove) {
    try {
        Write-Host "Removing $Capability..." -NoNewline
        Remove-WindowsCapability -Online -Name $Capability -ErrorAction SilentlyContinue | Out-Null
        Write-Host " Done" -ForegroundColor Green
    }
    catch {
        Write-Host " Failed" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Successfully removed: $SuccessCount apps" -ForegroundColor Green
Write-Host "Skipped (not found): $SkipCount apps" -ForegroundColor Yellow
Write-Host "Failed to remove: $FailCount apps" -ForegroundColor Red

Write-Host "`nBloatware removal completed. Some changes may require a system restart to take effect." -ForegroundColor Green
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
