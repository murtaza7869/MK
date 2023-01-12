$filename = $args[0]
# Search for the file
$file = Get-ChildItem -Path "C:\" -recurse -Filter $filename -ErrorAction  SilentlyContinue

# If the file was found, delete it
if ($file) {
  Remove-Item $file.FullName
  Write-Output "Deleted $filename"
} else {
  Write-Output "File not found"
}
