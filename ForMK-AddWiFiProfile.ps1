# How to use this script
# AddWiFiProfile.ps1 SSIDName, SecurityType ( like WPA2PSK), EncryptionType (Like AES TKIP etc ), Password

param(
	$SSIDName,
	$SecurityType,
	$EncryptionType,
	$Password
)

$ScriptRoot = "C:\Windows\Temp"

$LogDir = "$ScriptRoot\logs"
$LogFile = "$LogDir\ManageConfiguration.Log"
$ERROR_SUCCESS = 0
$ERROR_FAILED = 1
$ERROR_EXCEPTION_OCCURED = -1
$ProfileXmlPath = "$($Env:SystemDrive)\ProgramData\Faronics\Profile.xml"

$WiFiProfile = @'
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
<name>{0}</name>
<SSIDConfig>
<SSID>
<name>{0}</name>
</SSID>
</SSIDConfig>
<connectionType>ESS</connectionType>
<connectionMode>auto</connectionMode>
<autoSwitch>false</autoSwitch>
<MSM>
<security>
<authEncryption>
<authentication>{1}</authentication>
<encryption>{2}</encryption>
<useOneX>false</useOneX>
</authEncryption>
<sharedKey>
<keyType>passPhrase</keyType>
<protected>false</protected>
<keyMaterial>{3}</keyMaterial>
</sharedKey>
</security>
</MSM>
</WLANProfile>
'@  -f $SSIDName, $SecurityType, $EncryptionType, $Password


$ERROR_PS_VER_LOWER = 20008
$versionMinimum = [Version]'3.0.99999.999'

Function ExitIfPSVersionLower {

    Log -logstring ("Info: PowerShell version is: " + $PSVersionTable.PSVersion)

    if ($versionMinimum -gt $PSVersionTable.PSVersion){
        Log -logstring "Error: This script requires minimun PowerShell version: $versionMinimum"
        Exit $ERROR_PS_VER_LOWER
    }
}

Function CreateLogDir {
    If (!(Test-Path $LogDir)) {
        mkdir $LogDir | out-null
    }
}

Function Log {
    param(
        [Parameter(Mandatory=$true)][string]$logstring
    )

    $Logtime = Get-Date -Format "dd/MM/yyyy HH:mm:ss:fff"
    $logToWrite = "{$Logtime[PID:$PID]} : $logstring"
    Write-Host($logToWrite)
    Add-content $LogFile -value ($logToWrite)            
}

trap 
{
    #Log -logstring "Exception occured in AddWiFiProfile Script"
    $message = $Error[0].Exception.Message
    if ($message) 
    {
       # Log -logstring "EXCEPTION: $message"
    }

    #Log -logstring "Exit from AddWiFiProfile Script With Exitcode=$ERROR_EXCEPTION_OCCURED `r`n`r`n"
    exit $ERROR_EXCEPTION_OCCURED
}

function AddWiFiProfile{

    $ReturnValue = $ERROR_FAILED
    $WiFiProfile | Out-File $ProfileXmlPath

    if(Test-Path $ProfileXmlPath){
        Log -logstring "WiFi profile xml created."
    }
    else{
        Log -logstring "Error: Failed to create WiFi profile xml."
        return $ReturnValue
    }
       
    $netshOutput = netsh wlan show interfaces | Select-String "Name"

    $wifiInterfaces = $netshOutput -split ":"

    $Wirelessinterface = $wifiInterfaces[1].Trim()

    $ReturnCode = netsh.exe wlan add profile filename=$ProfileXmlPath user=all interface=$Wirelessinterface
    
    Log -logstring "WiFi Profile: netsh.exe wlan add profile: ReturnCode= $ReturnCode"

    return $ERROR_SUCCESS
}

try {
    Push-Location $ScriptRoot
    # Create Log directory
    CreateLogDir
    Log -logstring "Inside AddWiFiProfile Script"
    ExitIfPSVersionLower
    
    $ReturnValue = $ERROR_FAILED
   
	$NonBroadcast = "false"
	$ConnectMode = "auto"
	$OverWrite = "Yes"
		
    $ReturnValue = AddWiFiProfile
    
		if(Test-Path $ProfileXmlPath){
        Remove-Item $ProfileXmlPath
    }

    Log -logstring "Exit from AddWiFiProfile Script with Exitcode = $ReturnValue `r`n`r`n"
    Exit $ReturnValue
}
finally {
    Pop-Location
}
