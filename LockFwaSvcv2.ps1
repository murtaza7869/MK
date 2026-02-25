# 1. Configuration
$ServiceName = "FWASvc"
$AdminDenySDDL = "(D;;RPWP;;;BA)" # D=Deny, RP=Stop, WP=Write Config, BA=Built-in Admins

# 2. Check if Service exists
if (!(Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
    Write-Error "Service '$ServiceName' not found on this machine."
    return
}

Write-Host "Checking status for $ServiceName..." -ForegroundColor Cyan

# 3. Handle Disabled/Stopped State
$ServiceObj = Get-Service -Name $ServiceName

# If Disabled, set to Automatic
if ($ServiceObj.StartType -eq 'Disabled') {
    Write-Host "Service is Disabled. Enabling..." -ForegroundColor Yellow
    Set-Service -Name $ServiceName -StartupType Automatic
}

# If Stopped, Start it
if ($ServiceObj.Status -ne 'Running') {
    Write-Host "Service is $($ServiceObj.Status). Starting..." -ForegroundColor Yellow
    Start-Service -Name $ServiceName
    # Wait a moment for the service to initialize
    Start-Sleep -Seconds 2
}

# 4. Final verification of Startup Type (Ensure it is Automatic)
Set-Service -Name $ServiceName -StartupType Automatic

# 5. Apply SDDL Security Restrictions
Write-Host "Applying Admin restrictions..." -ForegroundColor Cyan

$currentSDDL = sc.exe sdshow $ServiceName

if ($currentSDDL -notlike "*$AdminDenySDDL*") {
    # Insert the Deny rule right after the DACL header (D:)
    $newSDDL = $currentSDDL -replace "D:", "D:$AdminDenySDDL"
    
    $result = sc.exe sdset $ServiceName $newSDDL
    
    if ($result -match "SUCCESS") {
        Write-Host "SUCCESS: $ServiceName is now Running, Automatic, and locked against Admins." -ForegroundColor Green
    } else {
        Write-Warning "Failed to set SDDL. Ensure you are running PowerShell as Administrator."
    }
} else {
    Write-Host "Restrictions already in place. No changes needed." -ForegroundColor Green
}
