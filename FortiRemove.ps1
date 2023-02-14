set-executionpolicy -ExecutionPolicy Unrestricted -Scope LocalMachine
Unblock-File -Path C:\FortiRemove.ps1
Get-WmiObject Win32_Product -Filter "name like 'FortiClient'" | Select-Object -ExpandProperty IdentifyingNumber | ForEach-Object { & 'MSIEXEC.exe' '/x' $_}