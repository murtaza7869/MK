<#
    Configure-PowerPlan.ps1
    Creates a custom power plan "Never Hibernate/sleep" and configures
    power button / lid / fast startup settings per IT request.
    Run this script as Administrator.
#>

#Requires -RunAsAdministrator

# ---- 1. Create the custom power plan (based on Balanced) ----
$balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
$planName     = "Never Hibernate/sleep"

# Check if a plan with this name already exists; if so, reuse its GUID
$existing = powercfg /list | Select-String $planName
if ($existing) {
    $newGuid = ($existing -split '\s+')[3]
    Write-Host "Plan '$planName' already exists. Using existing GUID $newGuid"
} else {
    $dupOutput = powercfg -duplicatescheme $balancedGuid
    $newGuid = ($dupOutput -split '\s+')[3]
    powercfg -changename $newGuid $planName "Custom plan: display and sleep never time out"
    Write-Host "Created plan '$planName' with GUID $newGuid"
}

# ---- 2. Set it as the active plan ----
powercfg -setactive $newGuid

# ---- 3. Display & sleep timeouts: Never (0) on AC and DC ----
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
# Also disable hibernate timeout to be consistent with "never sleep/hibernate"
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0

# ---- 4. Power button / sleep button / lid close actions (apply to ALL plans) ----
# Sub-group GUID: SUB_BUTTONS = 4f971e89-eebd-4455-a8de-9e59040e7347
$subButtons     = "4f971e89-eebd-4455-a8de-9e59040e7347"
$powerButtonSetting = "7648efa3-dd9c-4e3e-b566-50f929386280"  # PBUTTONACTION
$sleepButtonSetting = "96996bc0-ad50-47ec-923b-6f41874dd9eb"  # SBUTTONACTION
$lidSetting         = "5ca83367-6e45-459f-a27b-476b1d01c936"  # LIDACTION

# Action values: 0 = Do nothing, 1 = Sleep, 2 = Hibernate, 3 = Shut down
$allSchemes = (powercfg /list | Select-String "GUID:\s+([0-9a-f\-]{36})" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }

foreach ($scheme in $allSchemes) {
    # Power button -> Shut down (AC & DC)
    powercfg -setacvalueindex $scheme $subButtons $powerButtonSetting 3
    powercfg -setdcvalueindex $scheme $subButtons $powerButtonSetting 3

    # Sleep button -> Do nothing (AC & DC)
    powercfg -setacvalueindex $scheme $subButtons $sleepButtonSetting 0
    powercfg -setdcvalueindex $scheme $subButtons $sleepButtonSetting 0

    # Lid close -> Do nothing (AC & DC)
    powercfg -setacvalueindex $scheme $subButtons $lidSetting 0
    powercfg -setdcvalueindex $scheme $subButtons $lidSetting 0
}

# Re-apply the active scheme so changes take effect immediately
powercfg -setactive $newGuid

# ---- 5. Enable Fast Startup ----
# Fast startup requires hibernation to be enabled under the hood
#powercfg /hibernate on

#$powerRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
#Set-ItemProperty -Path $powerRegPath -Name "HiberbootEnabled" -Value 1 -Type DWord -Force

# ---- 6. Hide Sleep, Hibernate, and Lock from the power/account menu ----
$flyoutPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings"
if (-not (Test-Path $flyoutPath)) {
    New-Item -Path $flyoutPath -Force | Out-Null
}
New-ItemProperty -Path $flyoutPath -Name "ShowSleepOption"     -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $flyoutPath -Name "ShowHibernateOption" -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $flyoutPath -Name "ShowLockOption"      -Value 0 -PropertyType DWord -Force | Out-Null

Write-Host "Power plan '$planName' configured and activated successfully."
