$ScriptRoot = $PSScriptRoot
if([string]::IsNullOrEmpty($ScriptRoot)){
    $ScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

$LogFile = "$ScriptRoot\CheckStorageSpacePath_$env:COMPUTERNAME.Log"
$ERROR_SUCCESS = 0
$ERROR_FAILED = 1
$ERROR_EXCEPTION_OCCURED = -1

$ERROR_PS_VER_LOWER = 20008
$versionMinimum = [Version]'3.0.99999.999'

Function ExitIfPSVersionLower {

    Log -logstring ("Info: PowerShell version is: " + $PSVersionTable.PSVersion)

    if ($versionMinimum -gt $PSVersionTable.PSVersion){
        Log -logstring "Error: This script requires minimun PowerShell version: $versionMinimum"
        Exit $ERROR_PS_VER_LOWER
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
    Log -logstring "Exception occured in CheckStorageSpacePath Script"
    $message = $Error[0].Exception.Message
    if ($message) 
    {
        Log -logstring "EXCEPTION: $message"
    }

    Log -logstring "Exit from CheckStorageSpacePath Script With Exitcode=$ERROR_EXCEPTION_OCCURED `r`n`r`n"
    exit $ERROR_EXCEPTION_OCCURED
}

function GetFWAStorageSpacePath{

	$productId="FWA"
	$path=""
	$ReturnValue=0

	Invoke-WmiMethod -Namespace "root\Faronics" -Class "StorageSpace" -Name "GetPath" -ArgumentList $productId, [ref]$path, [ref]$ReturnValue -ErrorAction Stop
    return $ERROR_SUCCESS
}

try {
    Push-Location $ScriptRoot
    # Create Log directory
    Log -logstring "Inside CheckStorageSpacePath Script"
    ExitIfPSVersionLower
    
    $ReturnValue = $ERROR_FAILED
   
    $ReturnValue = GetFWAStorageSpacePath
    
    Log -logstring "Exit from CheckStorageSpacePath Script with Exitcode = $ReturnValue `r`n`r`n"
	
	$file = Get-Item "$LogFile"  ### Put any file name of your choice here
	$url = "http://dev.deepfreeze.com/fileupload"

	$boundary = [System.Guid]::NewGuid().ToString()
	$LF = "`r`n"
	$bytes = [System.Text.Encoding]::UTF8.GetBytes("--$boundary$LF")
	$bytes += [System.Text.Encoding]::UTF8.GetBytes("Content-Disposition: form-data; name=`"file`"; filename=`"$($file.Name)`"$LF")
	$bytes += [System.Text.Encoding]::UTF8.GetBytes("Content-Type: `"application/octet-stream`"$LF$LF")
	$bytes += [System.IO.File]::ReadAllBytes($file.FullName)
	$bytes += [System.Text.Encoding]::UTF8.GetBytes("$LF--$boundary--$LF")

	$request = [System.Net.WebRequest]::Create($url)
	$request.Method = "POST"
	$request.ContentType = "multipart/form-data; boundary=$boundary"
	$request.ContentLength = $bytes.Length
	$request.Timeout = [System.Int32]::MaxValue

	$requestStream = $request.GetRequestStream()
	$requestStream.Write($bytes, 0, $bytes.Length)
	$requestStream.Close()

	$response = $request.GetResponse()
	$responseStream = $response.GetResponseStream()
	$responseReader = new-object System.IO.StreamReader($responseStream)
	$responseText = $responseReader.ReadToEnd()
	$response.Close()

	Write-Output $responseText

    Exit $ReturnValue
}
finally {
    Pop-Location
}
