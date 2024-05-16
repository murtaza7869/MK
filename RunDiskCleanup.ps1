# Define the URL for the registry file
$regFileUrl = "https://raw.githubusercontent.com/murtaza7869/MK/main/CleanUpSageSet.reg"
$regFilePath = "C:\temp\CleanUpSageSet.reg"
md C:\temp

# Download the registry file
Invoke-WebRequest -Uri $regFileUrl -OutFile $regFilePath

# Apply Disk Cleanup settings from the downloaded registry file
Start-Process -FilePath "regedit.exe" -ArgumentList "/s $regFilePath" -Wait

# Run Disk Cleanup with the specified SAGESET
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -NoNewWindow -Wait
