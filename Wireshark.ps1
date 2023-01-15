Set-ExecutionPolicy Unrestricted -Force
Start-Process winget -ArgumentList 'install wireshark -h --accept-package-agreements --force --scope machine'
