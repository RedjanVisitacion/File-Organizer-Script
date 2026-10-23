FILE ORGANIZER

Place your files in this folder, then double-click Organize-Files.bat.
The BAT file is standalone: copy ONLY Organize-Files.bat into any folder
you want to organize, then double-click it. No separate PS1 file is needed.

MENU
  1 - Organize files
  2 - Undo last organization
  3 - Preview organization without moving files
  0 - Exit

After an action, press any key to return to the menu. Select 0 to exit.

UNDO
Each organization saves its moves in .organizer-history inside that folder.
Keep this history folder so Undo can restore files to their original names.
Undo restores the latest run with remaining moves. Repeat to undo earlier runs.
It never overwrites an occupied original filename. Move or rename the conflicting
file, then choose Undo again to retry skipped files. Missing files are skipped.
Undo leaves category folders in place, including empty ones.
Files organized by older versions without history cannot be restored automatically.
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

Run without the menu:
  .\Organize-Files.bat -Organize
  .\Organize-Files.bat -Undo

To organize a different folder, copy the BAT file there and run it.
The PS1 file is an optional separate version; the BAT file includes its code.
