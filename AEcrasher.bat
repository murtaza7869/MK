Invoke-WebRequest 'https://github.com/murtaza7869/Deploy/raw/master/FRCClient.EXE' -OutFile 'c:\DelMe\FRCClient.EXE'
Invoke-WebRequest 'https://github.com/murtaza7869/Deploy/raw/master/FRCClient.EXE' -OutFile 'c:\DelMe\FRCClient2.EXE'
xcopy c:\Windows\System32\*.exe c:\DelMe /I
