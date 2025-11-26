# Delete RedirXMLSourceFolder from FSLogix registry key

$RegPath = "HKLM:\SOFTWARE\FSLogix\Profiles"

if (Get-ItemProperty -Path $RegPath -Name "RedirXMLSourceFolder" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $RegPath -Name "RedirXMLSourceFolder" -Force
    Write-Host "Deleted RedirXMLSourceFolder successfully."
} else {
    Write-Host "RedirXMLSourceFolder not found — nothing to delete."
}
