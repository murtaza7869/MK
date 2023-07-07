Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table –AutoSize | Out-File -FilePath "C:\applist\InstalledProgram.log"
#cat "C:\applist\InstalledProgram.log"
Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table –AutoSize | Out-File -FilePath "C:\applist\Wow6432_InstalledProgram.log"
#cat "C:\applist\Wow6432_InstalledProgram.log"
