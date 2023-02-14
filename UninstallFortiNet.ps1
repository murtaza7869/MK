Get-WmiObject Win32_Product -Filter "name like 'FortiClient'" | Select-Object -ExpandProperty IdentifyingNumber | ForEach-Object { & 'MSIEXEC.exe' '/x' $_}
