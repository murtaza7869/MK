# Windows 11 - Disable Sleep and Hibernate Script
# This script sets sleep and hibernate to Never for all power states
# Run as Administrator

#Requires -RunAsAdministrator

Write-Host "Windows 11 - Disable Sleep and Hibernate Configuration" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Set sleep timeout to 0 (never) for both AC and DC
    Write-Host "Disabling automatic sleep..." -ForegroundColor Yellow
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
    Write-Host "  Sleep disabled when plugged in (AC)" -ForegroundColor Green
    Write-Host "  Sleep disabled when on battery (DC)" -ForegroundColor Green
    Write-Host ""
    
    # Set hibernate timeout to 0 (never) for both AC and DC
    Write-Host "Disabling automatic hibernate..." -ForegroundColor Yellow
    powercfg /change hibernate-timeout-ac 0
    powercfg /change hibernate-timeout-dc 0
    Write-Host "  Hibernate disabled when plugged in (AC)" -ForegroundColor Green
    Write-Host "  Hibernate disabled when on battery (DC)" -ForegroundColor Green
    Write-Host ""
    
    # Keep hibernate feature enabled (manual hibernate still available)
    Write-Host "  Hibernate feature kept enabled (manual hibernate still available)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Configuration completed successfully!" -ForegroundColor Green
    Write-Host "Your computer will no longer automatically sleep or hibernate." -ForegroundColor Green
    Write-Host ""
    
    # Show current sleep/hibernate settings to confirm
    Write-Host "Current Settings Verification:" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    $currentPlan = powercfg /getactivescheme
    Write-Host "Active Power Plan: $($currentPlan.Split('(')[1].Split(')')[0])" -ForegroundColor Yellow
    
    # Query and display sleep settings
    $sleepAC = (powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String "Current AC Power Setting Index:" | Out-String).Split(":")[1].Trim()
    $sleepDC = (powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String "Current DC Power Setting Index:" | Out-String).Split(":")[1].Trim()
    
    $sleepACMin = [int]("0x" + $sleepAC) / 60
    $sleepDCMin = [int]("0x" + $sleepDC) / 60
    
    Write-Host "Sleep when plugged in: $(if($sleepACMin -eq 0){'Never'}else{$sleepACMin + ' minutes'})" -ForegroundColor Gray
    Write-Host "Sleep on battery: $(if($sleepDCMin -eq 0){'Never'}else{$sleepDCMin + ' minutes'})" -ForegroundColor Gray
    
    # Check hibernate status
    $hibernateStatus = powercfg /availablesleepstates | Select-String "Hibernate"
    if ($hibernateStatus) {
        Write-Host "Hibernate: Available (manual only, auto-hibernate disabled)" -ForegroundColor Gray
    } else {
        Write-Host "Hibernate: Completely disabled" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "Error occurred: $_" -ForegroundColor Red
    Write-Host "Make sure you're running PowerShell as Administrator" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
# Script completed - will exit automatically
