# Please specify the Destination Folder for the new redirected user profiles in the command line
#Download the IGC tool
$url = "https://github.com/murtaza7869/EvertZ/raw/main/IGC.exe"
$outputDir = "C:\Windows\Temp\"
$downloadedFilePath = $outputDir + "IGC.exe"
Invoke-WebRequest -Uri $url -OutFile $downloadedFilePath

# *** TBD **** Add code to logoff all the logged in users
$lgauurl = "https://github.com/murtaza7869/EvertZ/raw/main/LogOffAllUsers.exe"
$outputDir = "C:\Windows\Temp\"
$logofferFilePath = $outputDir + "LogOffAllUsers.exe"
Invoke-WebRequest -Uri $lgauurl -OutFile $logofferFilePath

Start-Process -FilePath $logofferFilePath  -Wait

#Get the List of User Profiles 
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = $downloadedFilePath
$pinfo.Arguments = "/RedirectUP"
$pinfo.RedirectStandardError = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.UseShellExecute = $false
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null
$p.WaitForExit()
$output = @($p.StandardOutput.ReadToEnd())

$profsData = $output.Split("`n")

$profileList = @()

Foreach ( $line IN $profsData)
{

 if ($line) { 
    $pf = $line.Split(",")
    $profileList += $pf[0].Trim()
    }
}

#Call IGC RedirectUp for all 

Foreach ( $user IN $profileList)
{
# Get the destination folder path and create the command line argumentlist
$CmdLineArgList = "/RedirectUP " + $user +" /loc:"+$args[0]


 Start-Process -FilePath $downloadedFilePath  -ArgumentList $CmdLineArgList -Wait
}
