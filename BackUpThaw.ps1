$source = "O:\"
md C:\ThawBackup
$destination = "C:\ThawBackup"

Get-ChildItem -Path $source -Recurse | ForEach-Object {
    $dest = $_.FullName -Replace [regex]::Escape($source), $destination
    if ($_.PSIsContainer) {
        if (!(Test-Path -Path $dest)) {
            New-Item -ItemType Directory -Path $dest
        }
    }
    else {
        Copy-Item -Path $_.FullName -Destination $dest
    }
}
