# This script queries the Uninstall reg key for installed software and prints in on scree.
# Uncomment the Out-File line if you need it saved to a log file
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table –AutoSize
#| Out-File -FilePath "C:\applist\InstalledProgram.log"
# cat "C:\applist\InstalledProgram.log"
Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table –AutoSize
#| Out-File -FilePath "C:\applist\Wow6432_InstalledProgram.log"
# cat "C:\applist\Wow6432_InstalledProgram.log"
