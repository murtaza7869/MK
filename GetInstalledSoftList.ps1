# PowerShell Script to list all installed software with details and sorted by install date

$softwareList = @()

# Paths to search for installed software
$registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($path in $registryPaths) {
    Get-ItemProperty -Path $path | ForEach-Object {
        $installDate = $_.InstallDate
        if ($installDate) {
            $installDate = [datetime]::ParseExact($installDate, "yyyyMMdd", $null) -as [datetime]
        }

        # Populate software details
        $softwareList += [PSCustomObject]@{
            Name        = $_.DisplayName
            Publisher   = $_.Publisher
            InstalledOn = $installDate
            SizeMB      = if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize / 1024, 2) } else { "N/A" }
            Version     = $_.DisplayVersion
        }
    }
}

# Display the software list sorted by InstalledOn date (latest first)
$softwareList | Sort-Object InstalledOn -Descending | Format-Table -AutoSize -Property Name, Publisher, InstalledOn, SizeMB, Version
