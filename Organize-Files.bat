@echo off
setlocal
title File Organizer - Created by Redjan Phil S. Visitacion
color 0A
set "FILE_ORGANIZER_SELF=%~f0"
set "FILE_ORGANIZER_HOME=%~dp0"
set "FILE_ORGANIZER_PREVIEW=%~1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { $body = [IO.File]::ReadAllText($env:FILE_ORGANIZER_SELF); $marker = '# POWERSHELL_' + 'PAYLOAD'; $code = $body.Substring($body.IndexOf($marker) + $marker.Length); $action = 'Menu'; if ($env:FILE_ORGANIZER_PREVIEW -eq '-Undo') { $action = 'Undo' }; if ($env:FILE_ORGANIZER_PREVIEW -eq '-Organize') { $action = 'Organize' }; & ([scriptblock]::Create($code)) -Action $action -WhatIf:($env:FILE_ORGANIZER_PREVIEW -eq '-WhatIf') } catch { Write-Host $_ -ForegroundColor Red; exit 1 }"
set "organizer_result=%errorlevel%"
echo.
if not defined FILE_ORGANIZER_NO_PAUSE pause
exit /b %organizer_result%
# POWERSHELL_PAYLOAD
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$Folder,
    [ValidateSet('Menu', 'Organize', 'Undo', 'Preview')]
    [string]$Action = 'Menu'
)

$ErrorActionPreference = 'Stop'
Write-Host ''
Write-Host '  +==========================================================+' -ForegroundColor DarkGreen -BackgroundColor Black
Write-Host '  |                  FILE ORGANIZER // ONLINE                |' -ForegroundColor Green -BackgroundColor Black
Write-Host '  |          Created by Redjan Phil S. Visitacion             |' -ForegroundColor Green -BackgroundColor Black
Write-Host '  +==========================================================+' -ForegroundColor DarkGreen -BackgroundColor Black
Write-Host ''
if ([string]::IsNullOrWhiteSpace($Folder)) { $Folder = $env:FILE_ORGANIZER_HOME }

# Only files directly inside the selected folder are moved. Subfolders stay intact.
$root = Get-Item -LiteralPath $Folder
if (-not $root.PSIsContainer) {
    throw "Not a folder: $Folder"
}

if ($WhatIfPreference -and $Action -eq 'Menu') { $Action = 'Organize' }
if ($Action -eq 'Menu') {
    Write-Host '  [1] Organize files' -ForegroundColor Green
    Write-Host '  [2] Undo last organization' -ForegroundColor Green
    Write-Host '  [3] Preview organization (no changes)' -ForegroundColor Cyan
    Write-Host '  [0] Exit' -ForegroundColor Green
    switch (Read-Host '  Choose an option') {
        '1' { $Action = 'Organize' }
        '2' { $Action = 'Undo' }
        '3' { $Action = 'Preview' }
        '0' { return }
        default { Write-Host '  Invalid choice. Run again and choose 0, 1, 2, or 3.' -ForegroundColor Yellow; return }
    }
}
if ($Action -eq 'Preview') { $WhatIfPreference = $true; $Action = 'Organize' }

# Keep a separate journal for every run. Write it before moving any file so
# an interrupted run can still be undone. JSON paths are relative to this folder.
$historyFolder = Join-Path $root.FullName '.organizer-history'
function Save-Journal($Journal, [string]$Path) {
    $temporary = $Path + '.tmp'
    $Journal | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporary -Encoding UTF8 -WhatIf:$false
    Move-Item -LiteralPath $temporary -Destination $Path -Force -WhatIf:$false
}

if ($Action -eq 'Undo') {
    $latest = $null
    if (Test-Path -LiteralPath $historyFolder -PathType Container) {
        foreach ($candidate in (Get-ChildItem -LiteralPath $historyFolder -Filter '*.json' -File | Sort-Object Name -Descending)) {
            $journal = Get-Content -LiteralPath $candidate.FullName -Raw | ConvertFrom-Json
            if (@($journal.Entries).Count -gt 0) { $latest = $candidate; break }
        }
    }
    if (-not $latest) {
        Write-Host '  [UNDO] No saved organization to undo in this folder.' -ForegroundColor Yellow
        return
    }
    $restored = 0
    $remaining = @($journal.Entries)
    foreach ($entry in @($journal.Entries)) {
        try {
            # Only permit a root filename and a file one category folder below it.
            $parts = @($entry.Destination -split '[\\/]')
            if ($entry.Source -ne [IO.Path]::GetFileName($entry.Source) -or $entry.Source -in @('', '.', '..') -or
                $parts.Count -ne 2 -or $parts[0] -notin @('Images','Music','Videos','Presentations','Apps','Photoshop','Archives','PDFs','Documents','Excel','Other') -or
                $parts[1] -in @('', '.', '..')) { throw 'Invalid path in undo history.' }
            $original = Join-Path $root.FullName $entry.Source
            $organized = Join-Path $root.FullName $entry.Destination
            $parent = Get-Item -LiteralPath (Split-Path $organized -Parent) -ErrorAction SilentlyContinue
            if ($parent -and ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Category folder is a link; restore skipped.' }
            if (-not (Test-Path -LiteralPath $organized)) {
                if (-not (Test-Path -LiteralPath $original -PathType Leaf)) { throw 'File is missing from both locations.' }
                # Already restored, or a journal entry from an interrupted move.
                $remaining = @($remaining | Where-Object { $_ -ne $entry })
                if (-not $WhatIfPreference) { $journal.Entries = $remaining; Save-Journal $journal $latest.FullName }
                continue
            }
            if (Test-Path -LiteralPath $original) { throw 'Original filename is occupied; nothing was overwritten.' }
            if ($PSCmdlet.ShouldProcess($organized, "Restore to $original")) {
                # File.Move fails if the original name appears concurrently.
                [IO.File]::Move($organized, $original)
                $remaining = @($remaining | Where-Object { $_ -ne $entry })
                $journal.Entries = $remaining
                Save-Journal $journal $latest.FullName
                $restored++
                Write-Host ('  [RESTORED] {0}' -f $entry.Source) -ForegroundColor Green
            }
        }
        catch { Write-Warning ('Undo skipped "{0}": {1}' -f $entry.Source, $_.Exception.Message) }
    }
    Write-Host ("  [UNDO] Restored: {0} | Remaining: {1}" -f $restored, $remaining.Count) -ForegroundColor Cyan
    Write-Host '  Created by Redjan Phil S. Visitacion' -ForegroundColor Green
    return
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
$protectedNames = @('Organize-Files.ps1', 'Organize-Files.bat', 'README.txt', 'README.md', [IO.Path]::GetFileName($env:FILE_ORGANIZER_SELF))
$scriptFolder = [IO.Path]::GetFullPath($env:FILE_ORGANIZER_HOME).TrimEnd('\', '/')
$targetFolder = [IO.Path]::GetFullPath($root.FullName).TrimEnd('\', '/')
$files = @(Get-ChildItem -LiteralPath $root.FullName -File | Where-Object {
    -not ($targetFolder -eq $scriptFolder -and $_.Name -in $protectedNames)
})

Write-Host ('  [SCAN] {0} file(s) found in {1}' -f $files.Count, $root.FullName) -ForegroundColor Cyan -BackgroundColor Black
Write-Host ''
$moved = 0
$failed = 0
$journal = [pscustomobject]@{ Version = 1; Entries = @() }
$journalPath = Join-Path $historyFolder ((Get-Date -Format 'yyyyMMdd-HHmmss-fffffff') + '-' + [guid]::NewGuid().ToString('N') + '.json')
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
        $entry = $null
        try {
            if (-not (Test-Path -LiteralPath $destinationFolder -PathType Container)) {
                New-Item -ItemType Directory -Path $destinationFolder | Out-Null
            }
            if (-not (Test-Path -LiteralPath $historyFolder -PathType Container)) {
                New-Item -ItemType Directory -Path $historyFolder | Out-Null
            }
            $entry = [pscustomobject]@{ Source = $file.Name; Destination = (Join-Path $category ([IO.Path]::GetFileName($destination))) }
            $journal.Entries = @($journal.Entries) + @($entry)
            Save-Journal $journal $journalPath
            [IO.File]::Move($file.FullName, $destination)
            Write-Host ('  [SORTED] {0} -> {1}' -f $file.Name, $category) -ForegroundColor Green -BackgroundColor Black
            $moved++
        }
        catch {
            # Keep the journal entry if a move may have completed; undo can
            # reconcile an interrupted move without overwriting either path.
            Write-Warning ('Could not move "{0}": {1}' -f $file.Name, $_.Exception.Message)
            $failed++
        }
    }
}

Write-Host ''
Write-Host '  +-------------------- SCAN COMPLETE -----------------------+' -ForegroundColor DarkGreen -BackgroundColor Black
Write-Host ("  [RESULT] Moved: {0} | Failed: {1}" -f $moved, $failed) -ForegroundColor Green -BackgroundColor Black
Write-Host '  Created by Redjan Phil S. Visitacion' -ForegroundColor Green -BackgroundColor Black
Write-Host '  +----------------------------------------------------------+' -ForegroundColor DarkGreen -BackgroundColor Black
if ($WhatIfPreference) { Write-Host '  [PREVIEW] No files were moved.' -ForegroundColor Yellow -BackgroundColor Black }
if ($failed -gt 0) { exit 1 }
