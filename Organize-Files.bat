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
if not "%~1"=="" if not defined FILE_ORGANIZER_NO_PAUSE pause
exit /b %organizer_result%
# POWERSHELL_PAYLOAD
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$Folder,
    [ValidateSet('Menu', 'Organize', 'Undo', 'Preview')]
    [string]$Action = 'Menu'
)

$runOrganizer = {
[CmdletBinding(SupportsShouldProcess = $true)]
param([string]$Folder, [string]$Action, [hashtable]$Session)

$ErrorActionPreference = 'Stop'
function Write-PanelLine([string]$Text = '', [ConsoleColor]$Color = 'Green') {
    # ASCII borders work in classic Command Prompt, including from a USB drive.
    $width = 68
    try { $width = [Math]::Max(20, [Math]::Min(68, $Host.UI.RawUI.WindowSize.Width - 8)) } catch { }
    do {
        $count = [Math]::Min($width, $Text.Length)
        $line = $Text.Substring(0, $count)
        Write-Host '  | ' -NoNewline -ForegroundColor DarkGreen
        Write-Host $line.PadRight($width) -NoNewline -ForegroundColor $Color
        Write-Host ' |' -ForegroundColor DarkGreen
        $Text = $Text.Substring($count)
    } while ($Text.Length -gt 0)
}
function Write-PanelBorder {
    $width = 68
    try { $width = [Math]::Max(20, [Math]::Min(68, $Host.UI.RawUI.WindowSize.Width - 8)) } catch { }
    Write-Host ('  +-' + ('-' * $width) + '-+') -ForegroundColor DarkGreen
}
function Write-ResultPanel([string]$Title, [string]$Message, [ConsoleColor]$Color = 'Green') {
    Write-Host ''
    Write-PanelBorder
    Write-PanelLine $Title $Color
    Write-PanelLine $Message 'White'
    Write-PanelLine
    Write-PanelLine 'Created by Redjan Phil S. Visitacion' 'DarkGreen'
    Write-PanelBorder
    Write-Host ''
}

Write-Host ''
Write-PanelBorder
Write-PanelLine
Write-PanelLine '   _____ ___ _     _____' 'Green'
Write-PanelLine '  |  ___|_ _| |   | ____|' 'Green'
Write-PanelLine '  | |_   | || |   |  _|' 'Green'
Write-PanelLine '  |  _|  | || |___| |___' 'Green'
Write-PanelLine '  |_|   |___|_____|_____|  O R G A N I Z E R' 'Green'
Write-PanelLine
Write-PanelLine '  LOCAL FILE CONTROL                       [ OFFLINE ]' 'Cyan'
Write-PanelLine '  Created by Redjan Phil S. Visitacion' 'White'
Write-PanelLine
Write-PanelBorder
Write-Host ''
if ([string]::IsNullOrWhiteSpace($Folder)) { $Folder = $env:FILE_ORGANIZER_HOME }

# Only files directly inside the selected folder are moved. Subfolders stay intact.
$root = Get-Item -LiteralPath $Folder
if (-not $root.PSIsContainer) {
    throw "Not a folder: $Folder"
}
Write-PanelBorder
Write-PanelLine 'TARGET FOLDER' 'Cyan'
Write-PanelLine $root.FullName 'White'
Write-PanelBorder
Write-Host ''

if ($WhatIfPreference -and $Action -eq 'Menu') { $Action = 'Organize' }
if ($Action -eq 'Menu') {
    Write-PanelBorder
    Write-PanelLine 'CONTROL MENU' 'Cyan'
    Write-PanelLine
    Write-PanelLine '  [1]  ORGANIZE FILES' 'Green'
    Write-PanelLine '       Sort files into folders by type.' 'Gray'
    Write-PanelLine
    Write-PanelLine '  [2]  UNDO LAST ORGANIZATION' 'Green'
    Write-PanelLine '       Restore original locations using saved history.' 'Gray'
    Write-PanelLine
    Write-PanelLine '  [3]  PREVIEW ONLY' 'Cyan'
    Write-PanelLine '       See planned moves before changing anything.' 'Gray'
    Write-PanelLine
    Write-PanelLine '  [0]  EXIT' 'Gray'
    Write-PanelLine
    Write-PanelBorder
    Write-Host ''
    Write-Host '  >> Select an option [0-3]' -ForegroundColor Cyan
    switch (Read-Host '  command') {
        '1' { $Action = 'Organize' }
        '2' { $Action = 'Undo' }
        '3' { $Action = 'Preview' }
        '0' { $Session.Exit = $true; Write-Host '  [EXIT] Session closed.' -ForegroundColor DarkGreen; return }
        default { Write-Host '  Invalid choice. Choose 0, 1, 2, or 3 from the menu.' -ForegroundColor Yellow; return }
    }
}
$previewOnly = $Action -eq 'Preview' -or [bool]$WhatIfPreference
if ($Action -eq 'Preview') { $Action = 'Organize' }

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
        Write-ResultPanel 'UNDO // NO HISTORY' 'No saved organization to undo in this folder.' 'Yellow'
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
    Write-ResultPanel 'UNDO // COMPLETE' ("Restored: {0}   |   Remaining: {1}" -f $restored, $remaining.Count) 'Cyan'
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

Write-Host ('  [SCAN] {0} file(s) ready for sorting' -f $files.Count) -ForegroundColor Cyan
if ($previewOnly) { Write-Host '  [MODE] PREVIEW - no files will be moved' -ForegroundColor Yellow }
else { Write-Host '  [MODE] ORGANIZE - undo history enabled' -ForegroundColor DarkGreen }
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

    # Preview never enters the code that creates folders, writes history, or moves files.
    if ($previewOnly) {
        Write-Host ('  [WOULD MOVE] {0} -> {1}' -f $file.Name, $destination) -ForegroundColor Cyan
        continue
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

if ($previewOnly) {
    Write-ResultPanel 'PREVIEW // COMPLETE' ("Files checked: {0}   |   No changes made" -f $files.Count) 'Cyan'
} else {
    $resultColor = 'Green'
    if ($failed -gt 0) { $resultColor = 'Yellow' }
    Write-ResultPanel 'ORGANIZE // COMPLETE' ("Moved: {0}   |   Failed: {1}" -f $moved, $failed) $resultColor
    if ($moved -gt 0) { Write-Host '  [TIP] Choose option 2 next time to undo this run.' -ForegroundColor DarkGreen }
}
if ($failed -gt 0) { throw "$failed file(s) could not be organized. Review the warnings above." }
}

$session = @{ Exit = $false }
$interactiveMenu = $Action -eq 'Menu' -and -not $WhatIfPreference
do {
    if ($interactiveMenu -and -not $env:FILE_ORGANIZER_NO_PAUSE) { Clear-Host }
    try {
        & $runOrganizer -Folder $Folder -Action $Action -Session $session -WhatIf:$WhatIfPreference
    }
    catch {
        Write-Host ('  [ERROR] {0}' -f $_.Exception.Message) -ForegroundColor Red
        if (-not $interactiveMenu) { throw }
    }
    if ($interactiveMenu -and -not $session.Exit -and -not $env:FILE_ORGANIZER_NO_PAUSE) {
        Write-Host ''
        Write-Host '  Press any key to return to the menu . . .' -ForegroundColor Cyan
        try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') }
        catch { $null = Read-Host '  Press Enter to return to the menu' }
    }
} while ($interactiveMenu -and -not $session.Exit)
