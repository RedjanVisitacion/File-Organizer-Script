FILE ORGANIZER

Place your files in this folder, then double-click Organize-Files.bat.
The BAT file is standalone: copy ONLY Organize-Files.bat into any folder
you want to organize, then double-click it. No separate PS1 file is needed.
Files are sorted into Images, Music, Videos, PDFs, Documents, Excel,
Presentations, Apps, Photoshop, Archives, and Other.
Photoshop files (.psd/.psb) go into Photoshop. ZIP files and other common
compressed archives (.zip/.7z/.rar and related formats) go into Archives.
PowerPoint files (.ppt/.pptx) go into Presentations. Executables, installers,
and app shortcuts (.exe/.msi/.lnk and related formats) go into Apps.
Word files (.docx/.doc) go into Documents. Unrecognized files go into Other.

The organizer only moves files directly inside the folder. It leaves existing
subfolders and hidden files alone. It keeps its own script and instructions
in place. Existing files are never overwritten; duplicates receive a number.
Close any files open in other apps before organizing them.

Preview first (run in PowerShell from this folder):
  .\Organize-Files.bat -WhatIf

To organize a different folder, copy the BAT file there and run it.
The PS1 file is an optional separate version; the BAT file includes its code.
