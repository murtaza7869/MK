$PackageName = "Wallpaper"
$Version = 4

# URL to download the lock screen image from
$LockscreenSourceURL = "https://aejvancouver-my.sharepoint.com/:i:/g/personal/murtaza_kanchwala_vancouverjamaat_ca/IQCyTT7gziPxRZ-pMsvMT3DiAUtIPd3w1-RR4x3yT6e5uY0?download=1"

# Local staging path for the downloaded image
$LockscreenTempIMG = "$env:TEMP\PCC-Lockscreen.jpg"

# Log path - generic ProgramData location instead of Intune's IME log folder
$LogFolder = "$env:ProgramData\RMM\Logs"
if (!(Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$LogFolder\$PackageName-install.log" -Force
$ErrorActionPreference = "Stop"

# Registry key path and value names to be modified
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
$LockScreenPath = "LockScreenImagePath"
$LockScreenStatus = "LockScreenImageStatus"
$LockScreenUrl = "LockScreenImageUrl"
$StatusValue = "1"

# Final local path for the lockscreen image
$LockscreenLocalIMG = "C:\Windows\System32\Lockscreen.jpg"

# Check whether the URL variable has a value
if (!$LockscreenSourceURL) {
    Write-Warning "LockscreenURL must have a value."
}
else {
    try {
        Write-Host "Downloading lockscreen image from $LockscreenSourceURL"
        Invoke-WebRequest -Uri $LockscreenSourceURL -OutFile $LockscreenTempIMG -UseBasicParsing
    }
    catch {
        Write-Error "Failed to download lockscreen image: $_"
        throw
    }

    # Check whether registry key path exists, create it if it does not
    if (!(Test-Path $RegKeyPath)) {
        Write-Host "Creating registry path: $($RegKeyPath)."
        New-Item -Path $RegKeyPath -Force | Out-Null
    }

    Write-Host "Copy lockscreen ""$($LockscreenTempIMG)"" to ""$($LockscreenLocalIMG)"""
    Copy-Item $LockscreenTempIMG $LockscreenLocalIMG -Force

    Write-Host "Creating regkeys for lockscreen"
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenPath -Value $LockscreenLocalIMG -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenUrl -Value $LockscreenLocalIMG -PropertyType STRING -Force | Out-Null

    # Clean up temp download
    Remove-Item $LockscreenTempIMG -Force -ErrorAction SilentlyContinue
}

# Validation marker - keep or remove depending on how your RMM tracks success
New-Item -Path "C:\ProgramData\scloud\Validation\$PackageName" -ItemType "file" -Force -Value $Version | Out-Null

Stop-Transcript
