$computer = $env:COMPUTERNAME
$file = "C:\Windows\temp\$computer-installed-software.txt"
Get-WmiObject -Class Win32_Product | Select-Object -Property Name, InstallDate, version | Sort-Object -Property InstallDate | Format-Table -AutoSize | Out-File $file
$ufile = Get-Item "C:\Windows\temp\$computer-installed-software.txt"
$url = "http://dct.deepfreeze.com/uploaddct"

$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"
$bytes = [System.Text.Encoding]::UTF8.GetBytes("--$boundary$LF")
$bytes += [System.Text.Encoding]::UTF8.GetBytes("Content-Disposition: form-data; name=`"file`"; filename=`"$($ufile.Name)`"$LF")
$bytes += [System.Text.Encoding]::UTF8.GetBytes("Content-Type: `"application/octet-stream`"$LF$LF")
$bytes += [System.IO.File]::ReadAllBytes($ufile.FullName)
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
