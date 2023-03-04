$filepath = $args[0]
if ($filepath) {
  Get-ChildItem $filepath -Recurse | Remove-Item -Force -Recurse
  Write-Output "Deleted files in $filepath" > C:\Windows\temp\delfile.log
} else {
  Write-Output "File path not found"
}
