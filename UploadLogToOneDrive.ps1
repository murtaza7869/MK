# Upload-LogToOneDrive.ps1
# This script uploads a log file (or zip file) to OneDrive using Microsoft Graph API
# It runs silently without user intervention using app authentication

param(
    [Parameter(Mandatory=$true)]
    [string]$LogFilePath,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$false)]
    [string]$UploadFolderPath = "LogUploads",
    
    [Parameter(Mandatory=$false)]
    [switch]$AppendTimestamp = $true
)

# Function to write to log file
function Write-Log {
    param(
        [string]$Message,
        [string]$LogFile = "$env:TEMP\LogUpload.log"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append
}

# Error handling
$ErrorActionPreference = "Stop"
try {
    # Check if the log file exists
    if (-not (Test-Path -Path $LogFilePath)) {
        throw "Log file does not exist at path: $LogFilePath"
    }
    
    Write-Log "Starting upload process for: $LogFilePath"
    
    # Get file name from path
    $fileName = Split-Path -Path $LogFilePath -Leaf
    
    # Append timestamp to filename if requested
    if ($AppendTimestamp) {
        $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extension = [System.IO.Path]::GetExtension($fileName)
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $fileName = "$fileNameWithoutExt-$timestamp$extension"
    }
    
    # Acquire an access token for Microsoft Graph API
    Write-Log "Acquiring access token"
    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $tokenBody = @{
        client_id     = $ClientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
    }
    
    $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
    $accessToken = $tokenResponse.access_token
    
    Write-Log "Access token acquired successfully"
    
    # Check if upload folder exists, create if it doesn't
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }
    
    # Try to get the folder, if it doesn't exist, create it
    try {
        $checkFolderUrl = "https://graph.microsoft.com/v1.0/me/drive/root:/$UploadFolderPath"
        $folderResponse = Invoke-RestMethod -Uri $checkFolderUrl -Headers $headers -Method Get
        Write-Log "Upload folder exists: $UploadFolderPath"
    }
    catch {
        Write-Log "Upload folder doesn't exist, creating it: $UploadFolderPath"
        $createFolderUrl = "https://graph.microsoft.com/v1.0/me/drive/root/children"
        $folderBody = @{
            name = $UploadFolderPath
            folder = @{}
            "@microsoft.graph.conflictBehavior" = "rename"
        } | ConvertTo-Json
        
        $folderResponse = Invoke-RestMethod -Uri $createFolderUrl -Headers $headers -Method Post -Body $folderBody
    }
    
    # Upload the file using an upload session (for files larger than 4MB)
    Write-Log "Creating upload session for file: $fileName"
    $createUploadSessionUrl = "https://graph.microsoft.com/v1.0/me/drive/root:/$UploadFolderPath/$fileName`:/createUploadSession"
    $createSessionBody = @{
        item = @{
            "@microsoft.graph.conflictBehavior" = "rename"
        }
    } | ConvertTo-Json
    
    $uploadSession = Invoke-RestMethod -Uri $createUploadSessionUrl -Headers $headers -Method Post -Body $createSessionBody
    $uploadUrl = $uploadSession.uploadUrl
    
    # Get file content and size
    $fileContent = [System.IO.File]::ReadAllBytes($LogFilePath)
    $fileSize = $fileContent.Length
    
    # Upload the file in chunks
    $maxChunkSize = 4MB
    $chunks = [Math]::Ceiling($fileSize / $maxChunkSize)
    
    Write-Log "Uploading file in $chunks chunks"
    
    for ($i = 0; $i -lt $chunks; $i++) {
        $chunkStart = $i * $maxChunkSize
        $chunkEnd = [Math]::Min($chunkStart + $maxChunkSize - 1, $fileSize - 1)
        $chunkSize = $chunkEnd - $chunkStart + 1
        $contentRange = "bytes $chunkStart-$chunkEnd/$fileSize"
        
        $chunkContent = New-Object byte[] $chunkSize
        [Array]::Copy($fileContent, $chunkStart, $chunkContent, 0, $chunkSize)
        
        $uploadHeaders = @{
            "Content-Range" = $contentRange
        }
        
        Write-Log "Uploading chunk $($i+1)/$chunks ($contentRange)"
        
        $uploadResponse = Invoke-RestMethod -Uri $uploadUrl -Method Put -Headers $uploadHeaders -Body $chunkContent
        
        # Last chunk will contain the complete file metadata
        if ($chunkEnd -eq $fileSize - 1) {
            Write-Log "Upload completed successfully. File ID: $($uploadResponse.id)"
        }
    }
    
    Write-Log "File upload process completed for: $fileName"
    Write-Output "File uploaded successfully to OneDrive folder: $UploadFolderPath"
    
} catch {
    $errorMessage = $_.Exception.Message
    Write-Log "ERROR: $errorMessage"
    Write-Error $errorMessage
    exit 1
}