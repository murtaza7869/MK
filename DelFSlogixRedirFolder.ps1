# Delete RedirXMLSourceFolder from FSLogix registry key (safe ASCII version)

$RegPath = "HKLM:\SOFTWARE\FSLogix\Profiles"

if (Get-ItemProperty -Path $RegPath -Name "RedirXMLSourceFolder" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $RegPath -Name "RedirXMLSourceFolder" -Force
    Write-Output "Deleted RedirXMLSourceFolder successfully."
} else {
    Write-Output "RedirXMLSourceFolder not found - nothing to delete."
}
