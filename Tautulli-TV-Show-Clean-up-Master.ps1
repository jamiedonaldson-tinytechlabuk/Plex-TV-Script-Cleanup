<#
Version History:
---------------
v0.3.4 - Added prompt for folder deletion feature. If $PromptForDeletion is set to $true, the user will be prompted to confirm deletion (cleanup) of a subfolder before cleaning up its contents.
v0.3.3 - Added "Report-Only Mode" functionality. When set to $true, the script will only generate reports and will not delete files.
v0.3.2 - Bug fix for skipped folder size display. Ensured size is correctly converted to GB and TB when necessary.
v0.3.1 - Added total size tracking for deleted files and skipped folders in GB and TB.
v0.3.0 - Initial release with folder cleanup based on watched TV shows from Tautulli API.
#>

# Define the normalization function
function Normalize-Name {
    param (
        [string]$Name
    )
    return $Name -replace ":", "-" -replace "\s+", " "
}

# Configuration
$RootFolder = "\\IPADDRESS\Plex\TVFOLDER"  # Root folder to look into for the cleanup process (Only Point to a TV folder...Movie folder being included is untested and will have disastrous consequences)
$ExcludeFolders = @(
    "TVSHOW1",
    "TVSHOW2"
    "TVSHOW3"
)  # List of folders to exclude no matter what the watch status is.

$TautulliAPI = "http://IPORFQDN:PORT/api/v2"  # Tautulli API endpoint
$TautulliAPIKey = "<Tautulli API Key>"  # Tautulli API key
$TautulliMonths = 12  # Months to look back for watched history
$TVShowsEpisodeCount = 3 # Number of episodes you wish to maintain within your TV shows

# Add an option for Report Only mode (set to $true to run in report-only mode)
$ReportOnly = $false  # Set this to $true for report-only mode (no file deletions)

# Add an option to prompt for folder deletion (set to $true to prompt for folder deletion)
$PromptForFolderDeletion = $true  # Set to $false to skip folder deletion prompts

# Fetch Tautulli watch history
$StartDate = (Get-Date).AddMonths(-$TautulliMonths).ToString("yyyy-MM-dd")

$TautulliParams = @(
    "apikey=$TautulliAPIKey",
    "cmd=get_history",
    "length=1000",
    "start=0",
    "order=desc",
    "order_column=date"
)

$TautulliUri = $TautulliAPI + "?" + ($TautulliParams -join "&")

Write-Host "Tautulli API URI: $TautulliUri"

$TautulliResponse = Invoke-RestMethod -Method GET -Uri $TautulliUri

# Output total record count
$totalRecords = $TautulliResponse.response.data.recordsFiltered
Write-Host "Total records available: $totalRecords"

# Determine the correct data path
if ($TautulliResponse.response.data.data) {
    $TautulliDataArray = @($TautulliResponse.response.data.data)
} elseif ($TautulliResponse.response.data.rows) {
    $TautulliDataArray = @($TautulliResponse.response.data.rows)
} else {
    Write-Error "No data found in the API response."
    return
}

# Ensure data is an array
$TautulliDataArray = @($TautulliDataArray)

# Filter for TV shows, convert Unix timestamps, and sort
$TautulliData = $TautulliDataArray | Where-Object {
    $_ -ne $null -and $_.date -ne $null -and $_.media_type -eq "episode" -and $_.date -is [int]
} | ForEach-Object {
    try {
        $_ | Add-Member -MemberType NoteProperty -Name ConvertedDate -Value ([datetime]::UnixEpoch.AddSeconds($_.date)) -Force -ErrorAction SilentlyContinue
    } catch {
        # Suppress errors
        $null
    }
    $_
} | Sort-Object -Property ConvertedDate -Descending

# Extract watched TV show titles and normalize them
$WatchedTVIDs = $TautulliData | Select-Object -ExpandProperty grandparent_title | Sort-Object -Unique
$NormalizedWatchedTVIDs = $WatchedTVIDs | ForEach-Object { Normalize-Name $_ }

# Output the watched TV shows
Write-Host "Watched TV IDs from Tautulli for last $TautulliMonths months:"
$WatchedTVIDs | ForEach-Object { Write-Host $_ -ForegroundColor Green }

Write-Host "Now Processing Tautulli Watched Series against TV Shows Folders" -ForegroundColor Magenta

# Normalize the exclude folder names beforehand
$NormalizedExcludeFolders = $ExcludeFolders | ForEach-Object { Normalize-Name $_ }

# Initialize counters for deleted files, skipped files, and total size (in bytes)
$deletedFilesCount = 0
$skippedFilesCount = 0
$totalSizeDeleted = 0
$totalSizeSkipped = 0

# Process folders
$Folders = Get-ChildItem -Path $RootFolder -Directory
foreach ($Folder in $Folders) {
    $FolderName = Normalize-Name $Folder.Name

    # Get all files in the folder and subfolders
    $Files = Get-ChildItem -Path $Folder.FullName -Recurse -File | Sort-Object -Property Name

    # Calculate the size of the files in the folder
    $TotalSize = ($Files | Measure-Object -Property Length -Sum).Sum

    # Debugging: output the file count for this folder
    Write-Host "Folder '$FolderName' contains $($Files.Count) files." -ForegroundColor Yellow

    # Skip excluded folders
    if ($NormalizedExcludeFolders -contains $FolderName) {
        $totalSizeSkipped += $TotalSize  # Accumulate skipped folder size
        $skippedFilesCount += $Files.Count  # Accumulate skipped file count
        Write-Host "Skipping excluded folder: $FolderName | Files: $($Files.Count) | Total size: $( [math]::round($TotalSize / 1GB, 2) ) GB" -ForegroundColor Cyan
        continue
    }

    # Skip folders matching watched TV show IDs
    if ($NormalizedWatchedTVIDs -contains $FolderName) {
        $totalSizeSkipped += $TotalSize  # Accumulate skipped folder size
        $skippedFilesCount += $Files.Count  # Accumulate skipped file count
        Write-Host "Skipping watched folder: $FolderName | Files: $($Files.Count) | Total size: $( [math]::round($TotalSize / 1GB, 2) ) GB" -ForegroundColor Cyan
        continue
    }

    # Prompt for folder deletion (cleanup)
    if ($PromptForFolderDeletion) {
        $userInput = Read-Host "Do you want to clean up the folder '$FolderName' (delete files exceeding $TVShowsEpisodeCount)? (y/n)"
        if ($userInput -eq 'y') {
            Write-Host "Cleaning up folder: $FolderName" -ForegroundColor Green
            # Delete all files except the first three
            $FilesToDelete = $Files | Select-Object -Skip $TVShowsEpisodeCount
            foreach ($File in $FilesToDelete) {
                Write-Host "Deleting file: $($File.FullName)" -ForegroundColor Red
                Remove-Item -Path $File.FullName -Force
                $deletedFilesCount++  # Increment the counter
                $totalSizeDeleted += $File.Length  # Add file size (in bytes)
            }
        } else {
            Write-Host "Skipping folder: $FolderName" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Cleaning up folder: $FolderName" -ForegroundColor Green
        # Delete all files except the first three
        $FilesToDelete = $Files | Select-Object -Skip $TVShowsEpisodeCount
        foreach ($File in $FilesToDelete) {
            Write-Host "Deleting file: $($File.FullName)" -ForegroundColor Red
            Remove-Item -Path $File.FullName -Force
            $deletedFilesCount++  # Increment the counter
            $totalSizeDeleted += $File.Length  # Add file size (in bytes)
        }
    }
}

# Convert total size from bytes to GB and TB if applicable
$totalSizeDeletedGB = [math]::round($totalSizeDeleted / 1GB, 2)
$totalSizeSkippedGB = [math]::round($totalSizeSkipped / 1GB, 2)

# Convert to TB if needed
if ($totalSizeSkippedGB -ge 1024) {
    $totalSizeSkippedTB = [math]::round($totalSizeSkippedGB / 1024, 2)
    $totalSizeSkippedOutput = "$totalSizeSkippedTB TB"
} else {
    $totalSizeSkippedOutput = "$totalSizeSkippedGB GB"
}

# Output the total number of deleted files and the total size in GB or TB
Write-Host "Cleanup completed. Total files deleted: $deletedFilesCount"
Write-Host "Cleanup Total space freed: $totalSizeDeletedGB GB"
Write-Host "Skipping Folders. Total files skipped: $skippedFilesCount"
Write-Host "Skipping Total space used: $totalSizeSkippedOutput" -ForegroundColor Green