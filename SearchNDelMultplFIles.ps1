$files = "EVERTZ_c.dll", "EVERTZ_c.exe", "EVERTZx64_c.exe", "EVERTZx64_c.dll","Nccsp.exe", "xctsb.exe", "Ppp.ps1", "PC.csv", "IOC", "controlledtest.txt"
#"$makeitso", "108[.]62.118.131", "146[.]70.86.61", "193[.]23.244.244"
# declaring a variable and the ipaddress files are causing errors

foreach($file in $files)
{
    Get-ChildItem -Path "C:\" -Include $file -ErrorVariable FailedItems -ErrorAction SilentlyContinue -Recurse | Remove-Item -Force -Verbose
}

#-ErrorVariable FailedItems -ErrorAction SilentlyContinue is required to suppress locations where elevated privledges dont have permission.
