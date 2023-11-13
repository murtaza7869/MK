$filepath = "C:\Windows\temp\RunInUC.exe"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile("http://faronics.org/proservices/DeployPowerShellAssistantv2.exe", $filepath)

$args = @('https://github.com/murtaza7869/MK/raw/main/SetWallpaper.exe')

Start-Process -Filepath "C:\Windows\temp\RunInUC.exe" -ArgumentList $args
