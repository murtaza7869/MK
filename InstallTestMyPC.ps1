
If (Test-Path -Path C:\Windows\temp\TBSMyPC_7.0.0.9.zip){
Remove-Item 'C:\Windows\temp\PolarisClientsv74.zip' -Recurse | out-null
}
Invoke-WebRequest 'https://cuyahogalibrary.sharepoint.com/:u:/g/publicfolders/Eamn7u3eTDtPoJLSBXtcedgBi6wFdcgER8kZxI5V8YQ8kg?download=1' -OutFile 'C:\Windows\temp\TBSMyPC_7.0.0.9.zip'
If (Test-Path -Path C:\ProgramData\Faronics\TBSMyPC ){
Remove-Item 'C:\ProgramData\Faronics\TBSMyPC' -Recurse | out-null
}
md C:\ProgramData\Faronics\TBSMyPC
Expand-Archive -LiteralPath C:\Windows\temp\TBSMyPC_7.0.0.9.zip -DestinationPath C:\ProgramData\Faronics\TBSMyPC
ping localhost -n 9
Start-Process -FilePath 'C:\ProgramData\Faronics\TBSMyPC\TBSMyPC_7.0.0.9\TBS_INSTALLER_7.0.0.9.exe'
