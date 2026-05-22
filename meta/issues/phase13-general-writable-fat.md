# Phase 13: General Writable FAT Filesystem

## Summary

Generalize FAT writes beyond minimal std-handle support so shell commands and game saves can create, write, delete, and rename files.

## Requirements

- Implement `INT 21h AH=3Ch` create/truncate file.
- Extend `INT 21h AH=40h` to write regular file handles.
- Implement `INT 21h AH=41h` delete file.
- Implement `INT 21h AH=56h` rename file.
- Implement `INT 21h AH=57h` get/set file date and time.
- Allocate and free FAT12 cluster chains correctly.
- Flush FAT and directory updates to the disk image.

## Acceptance Criteria

- A create/write/close/read cycle preserves exact file contents.
- Delete removes a file and frees its cluster chain.
- Rename updates directory entries without corrupting data.
- Monkey Island save/load works against a writable image.
- Shell commands can use the write APIs without special kernel shortcuts.

## Notes

- This overlaps with Phase 9 save-game writes; Phase 13 is the broader shell/filesystem version.
- Root create/write/delete/rename/date support is implemented and covered by `SAVEWR.COM`.
- Bare-filename create/write/delete/rename now also works in the current subdirectory, covered by `CD MIDEMO` regression coverage in `SAVEWR.COM`.
- Subdirectory lookup and free-entry scanning now cover every sector in each directory cluster, covered by a 2.88 MB `SAVEWR.COM` image that forces entries into the second directory sector.
- Full subdirectories now extend by allocating, zeroing, linking, and flushing a new directory cluster; covered by forcing `MIDEMO/SUBUSED.DAT` into an extended directory cluster.
- Seek-past-EOF writes now zero-fill gaps before writing caller data, covered by `GAP.DAT` reusing a stale freed cluster.
- Remaining gaps include actual Monkey load validation and multi-component write paths such as `DIR\FILE.DAT`.
