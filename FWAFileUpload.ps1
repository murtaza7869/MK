$outputDir = "C:\Windows\Temp\Faronics\"
$FWA_SS_ZipFilePath = $outputDir + "FWA_SS.zip"

If (Test-Path $outputDir) {
    rm -r "$outputDir" | out-null
}

mkdir "$outputDir" | out-null
#stopping CLoud agent
stop-service -name "fwasvc"

# Create ZIP file from FWA's storage space folder
Compress-Archive -Path C:\ProgramData\Faronics\StorageSpace\FWA "$FWA_SS_ZipFilePath"
start-service -name "fwasvc"

$FileToUpload = "$FWA_SS_ZipFilePath"

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

