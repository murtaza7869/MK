If (Test-Path -Path C:\Windows\temp\PolarisClientsv74.zip){
Remove-Item 'C:\Windows\temp\PolarisClientsv74.zip' -Recurse | out-null
}
Invoke-WebRequest 'https://nlls.sharepoint.com/:u:/s/tsi/EeQ_QxZyc9xJq49DaulQfRgBFWzfi4P8fwhoWUs4_kYFcw?download=1' -OutFile 'C:\Windows\temp\PolarisClientsv74.zip'
If (Test-Path -Path C:\ProgramData\Faronics\PolarisClient ){
Remove-Item 'C:\ProgramData\Faronics\PolarisClient' -Recurse | out-null
}
md C:\ProgramData\Faronics\PolarisClient
Expand-Archive -LiteralPath C:\Windows\temp\PolarisClientsv74.zip -DestinationPath C:\ProgramData\Faronics\PolarisClient
ping localhost -n 9
Start-Process -FilePath 'C:\ProgramData\Faronics\PolarisClient\PolarisClients.exe' -ArgumentList '/s /v"/l*v C:\PolarisClientInstall.log TRANSFORMS="C:\ProgramData\Faronics\PolarisClient\TRAC-PROD.MST" /q"'
