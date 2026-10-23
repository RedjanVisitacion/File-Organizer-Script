@echo off
setlocal
set "FILE_ORGANIZER_SELF=%~f0"
set "FILE_ORGANIZER_HOME=%~dp0"
set "FILE_ORGANIZER_PREVIEW=%~1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { $body = [IO.File]::ReadAllText($env:FILE_ORGANIZER_SELF); $marker = '# POWERSHELL_' + 'PAYLOAD'; $code = $body.Substring($body.IndexOf($marker) + $marker.Length); & ([scriptblock]::Create($code)) -WhatIf:($env:FILE_ORGANIZER_PREVIEW -eq '-WhatIf') } catch { Write-Host $_ -ForegroundColor Red; exit 1 }"
set "organizer_result=%errorlevel%"
echo.
if not defined FILE_ORGANIZER_NO_PAUSE pause
exit /b %organizer_result%
# POWERSHELL_PAYLOAD
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$Folder
)

$ErrorActionPreference = 'Stop'
Write-Host 'Created by Redjan Phil S. Visitacion'
Write-Host ''
if ([string]::IsNullOrWhiteSpace($Folder)) { $Folder = $env:FILE_ORGANIZER_HOME }

# Only files directly inside the selected folder are moved. Subfolders stay intact.
$root = Get-Item -LiteralPath $Folder
if (-not $root.PSIsContainer) {
    throw "Not a folder: $Folder"
}

$categories = [ordered]@{
    Images    = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.ico', '.tif', '.tiff', '.heic', '.heif', '.avif', '.raw')
    Music     = @('.mp3', '.wav', '.flac', '.aac', '.m4a', '.ogg', '.wma', '.aiff', '.aif', '.opus', '.mid', '.midi')
    Videos    = @('.mp4', '.mkv', '.avi', '.mov', '.wmv', '.webm', '.m4v', '.mpeg', '.mpg', '.3gp', '.ts', '.mts')
    Presentations = @('.ppt', '.pptx', '.pptm', '.pps', '.ppsx', '.ppsm', '.pot', '.potx', '.potm', '.odp')
    Apps      = @('.exe', '.msi', '.msix', '.msixbundle', '.appx', '.appxbundle', '.appinstaller', '.apk', '.lnk', '.appref-ms')
    Photoshop = @('.psd', '.psb')
    Archives  = @('.zip', '.zipx', '.7z', '.rar', '.tar', '.gz', '.tgz', '.bz2', '.xz')
    PDFs      = @('.pdf')
    Documents = @('.docx', '.doc', '.odt', '.rtf')
    Excel     = @('.xlsx', '.xls', '.xlsm', '.xlsb', '.csv', '.tsv', '.ods', '.xltx', '.xltm')
}

$extensionMap = @{}
foreach ($category in $categories.Keys) {
    foreach ($extension in $categories[$category]) {
        $extensionMap[$extension] = $category
    }
}

# Keep the organizer and its instructions in place when organizing their folder.
$protectedNames = @('Organize-Files.ps1', 'Organize-Files.bat', 'README.txt', [IO.Path]::GetFileName($env:FILE_ORGANIZER_SELF))
$scriptFolder = [IO.Path]::GetFullPath($env:FILE_ORGANIZER_HOME).TrimEnd('\', '/')
$targetFolder = [IO.Path]::GetFullPath($root.FullName).TrimEnd('\', '/')
$files = @(Get-ChildItem -LiteralPath $root.FullName -File | Where-Object {
    -not ($targetFolder -eq $scriptFolder -and $_.Name -in $protectedNames)
})

$moved = 0
$failed = 0
foreach ($file in $files) {
    $category = $extensionMap[$file.Extension.ToLowerInvariant()]
    if (-not $category) { $category = 'Other' }
    $destinationFolder = Join-Path $root.FullName $category
    $destination = Join-Path $destinationFolder $file.Name

    # Never replace an existing file: use "filename (1).ext", etc.
    $number = 1
    while (Test-Path -LiteralPath $destination) {
        $newName = '{0} ({1}){2}' -f $file.BaseName, $number, $file.Extension
        $destination = Join-Path $destinationFolder $newName
        $number++
    }

    if ($PSCmdlet.ShouldProcess($file.FullName, "Move to $destination")) {
        try {
            if (-not (Test-Path -LiteralPath $destinationFolder -PathType Container)) {
                New-Item -ItemType Directory -Path $destinationFolder | Out-Null
            }
            Move-Item -LiteralPath $file.FullName -Destination $destination -ErrorAction Stop
            Write-Host ('Moved: {0} -> {1}' -f $file.Name, $category)
            $moved++
        }
        catch {
            Write-Warning ('Could not move "{0}": {1}' -f $file.Name, $_.Exception.Message)
            $failed++
        }
    }
}

Write-Host "`nFinished. Moved: $moved. Failed: $failed."
if ($WhatIfPreference) { Write-Host 'Preview only: no files were moved.' }
if ($failed -gt 0) { exit 1 }
