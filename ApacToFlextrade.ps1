$url = "https://github.com/murtaza7869/MK/raw/main/SwitchApacToFlextradeSite.exe"
$output = "C:\Windows\temp\SwitchApacToFlextradeSite.exe"
$wc = new-object System.Net.WebClient
$wc.DownloadFile($url, $output)
Start-Process -FilePath "C:\Windows\temp\SwitchApacToFlextradeSite.exe"
