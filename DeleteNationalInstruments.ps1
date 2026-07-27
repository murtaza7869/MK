# Delete National Instruments Vision Examples folder
# Target: C:\Users\Public\Documents\National Instruments
# Run context: SYSTEM via RMM

$TargetPath = "C:\Users\Public\Documents\National Instruments"

try {
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        Write-Output "INFO: Path not found, nothing to delete: $TargetPath"
        exit 0
    }

    # Clear read-only/hidden/system attributes recursively first,
    # in case permission errors were caused by attribute flags
    Get-ChildItem -LiteralPath $TargetPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $_.Attributes = 'Normal'
        } catch {
            # ignore attribute reset failures, continue to delete attempt
        }
    }

    Remove-Item -LiteralPath $TargetPath -Recurse -Force -ErrorAction Stop

    if (Test-Path -LiteralPath $TargetPath) {
        Write-Output "ERROR: Deletion attempted but path still exists: $TargetPath"
        exit 1
    }

    Write-Output "SUCCESS: Deleted $TargetPath"
    exit 0
}
catch {
    Write-Output "ERROR: Failed to delete $TargetPath - $($_.Exception.Message)"
    exit 1
}
