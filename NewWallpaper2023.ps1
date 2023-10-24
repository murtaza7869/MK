# Define the URL of the wallpaper image you want to download
$wallpaperURL = "https://link.storjshare.io/s/jwn4ckhh5lgf7ojzz253w3ayymga/deploy-1/Wallpaper.png?download=1"

# Define the path where you want to save the downloaded image
$downloadPath = "C:\wallpaper\background.png"

# Download the wallpaper image
Invoke-WebRequest -Uri $wallpaperURL -OutFile $downloadPath

# Set the wallpaper for the current user
Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public class Wallpaper {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
"@

[Wallpaper]::SystemParametersInfo(0x0014, 0, $downloadPath, 0x0001)  # 0x0014 corresponds to setting the desktop wallpaper

# Define the WallpaperStyle value (6 for "Fit")
$wallpaperStyle = 6

# Create a scheduled task to set the wallpaper for all user profiles
$action = New-ScheduledTaskAction -Execute 'powershell' -Argument "Set-ItemProperty -Path 'HKU:\*\Control Panel\Desktop' -Name WallpaperStyle -Value $wallpaperStyle; Set-ItemProperty -Path 'HKU:\*\Control Panel\Desktop' -Name Wallpaper -Value '$downloadPath'; RUNDLL32.EXE user32.dll, UpdatePerUserSystemParameters"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "SetWallpaperTask" -User "NT AUTHORITY\SYSTEM"
