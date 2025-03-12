# PowerShell script to shrink C: drive and create a new D: drive of 1 GB
# This script requires administrative privileges to run

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator."
    exit
}

# Size in MB (1 GB = 1024 MB)
$sizeToShrinkMB = 1024

try {
    # Get the C: drive
    $CDrive = Get-Partition -DriveLetter C
    
    # Get the disk containing C: drive
    $DiskNumber = $CDrive.DiskNumber
    
    # Shrink the C: drive by the specified amount
    Write-Host "Shrinking C: drive by $sizeToShrinkMB MB..."
    $ShrinkSize = $sizeToShrinkMB * 1MB
    Resize-Partition -DriveLetter C -Size ((Get-PartitionSupportedSize -DriveLetter C).SizeMax - $ShrinkSize)
    
    # Get available unallocated space
    $MaxSize = (Get-Disk -Number $DiskNumber | Get-PartitionSupportedSize -AsJob | Wait-Job | Receive-Job).SizeMax
    
    # Create the new partition
    Write-Host "Creating new partition D: with size $sizeToShrinkMB MB..."
    New-Partition -DiskNumber $DiskNumber -UseMaximumSize -DriveLetter D | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
    
    Write-Host "Operation completed successfully."
    Write-Host "Drive D: has been created with a size of 1 GB."
} 
catch {
    Write-Error "An error occurred: $_"
}
