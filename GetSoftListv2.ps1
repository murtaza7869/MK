# Simple version - just combine both registry locations
$software = Get-ItemProperty -Path @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
) | Where-Object { $_.DisplayName } |
Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
Sort-Object DisplayName

# Display and save
$software | Format-Table -AutoSize
$software | Format-Table -AutoSize | Out-File -FilePath "C:\windows\temp\InstalledSoftware.log"
