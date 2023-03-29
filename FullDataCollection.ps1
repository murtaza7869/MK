$url = "https://s3-us-west-2.amazonaws.com/faronics-techsupport-utilities/Download/FaronicsDataCollectionTools.exe"
$outputDir = "C:\Windows\Temp\Faronics\DCT\"
$downloadedFilePath = $outputDir + "FaronicsDCT.exe"
$DCTFolderPath = $outputDir + "FaronicsDataCollectionTools\"
$AgentDataCollectorPath = $outputDir + "FaronicsDataCollectionTools\FaronicsAgentDataCollection.exe"
$MaximumRuntimeSeconds = 5

If (Test-Path $outputDir) {
    rm -r "$outputDir" | out-null
}

If (Test-Path $DCTFolderPath) {
	rm -r "$DCTFolderPath" | out-null
}

mkdir "$outputDir" | out-null

Invoke-WebRequest -Uri $url -OutFile $downloadedFilePath

$process = Start-Process -FilePath "$downloadedFilePath" -PassThru
try
{
    $process | Wait-Process -Timeout $MaximumRuntimeSeconds -ErrorAction Stop
    # Write-Warning -Message 'Process successfully completed within timeout.'
}
catch
{
    # Write-Warning -Message 'Process exceeded timeout, will be killed now.'
    $process | Stop-Process -Force
}

# Write-Warning -Message "Tool path is '$AgentDataCollectorPath'"
Start-Process -FilePath "$AgentDataCollectorPath" -ArgumentList "/dbg:n" -WorkingDirectory "$DCTFolderPath" -Wait

$zipFileName = Get-ChildItem -Path "$DCTFolderPath" -Filter *.zip |Select -First 1
$FileToUpload = $DCTFolderPath + $zipFileName

$file = Get-Item $FileToUpload
$url = "http://dev.deepfreeze.com:80/fileupload"

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

Write-Output $responseText
