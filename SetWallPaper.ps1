$filepath = "C:\Windows\temp\RunInUC.exe"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile("http://faronics.org/proservices/DeployPowerShellAssistantv2.exe", $filepath)

$args = @('https://raw.githubusercontent.com/murtaza7869/MK/main/SetWallPaperHabibiIS.ps1')

Start-Process -Filepath "C:\Windows\temp\RunInUC.exe" -ArgumentList $args
