# *** TBD **** Add code to logoff all the logged in users
$lgauurl = "https://github.com/murtaza7869/MK/raw/main/LogOffAllUsers.exe"
$outputDir = "C:\Windows\Temp\"
$logofferFilePath = $outputDir + "LogOffAllUsers.exe"
Invoke-WebRequest -Uri $lgauurl -OutFile $logofferFilePath

Start-Process -FilePath $logofferFilePath  -Wait
