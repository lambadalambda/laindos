# Widen Directory Sector Metadata For High FAT16 LBAs

## Summary

Some filesystem paths still store directory-entry sector LBAs in 16-bit variables or handle fields. This is safe for current generated images that keep directories low, but it can target the wrong sector for high directories or large mutable FAT16 images.

## Requirements

- Audit directory-entry LBA storage and call sites that pass sectors into `read_sector`, `write_sector`, `flush_dir_sector`, and `flush_handle_dir_entry`.
- Widen directory-sector metadata where needed, including handle directory-entry locations and find/create/rename temporary fields.
- Preserve raw FAT12 and existing low-directory FAT16 behavior.
- Add a focused regression with a FAT16 directory or mutable directory entry above the 65535-sector boundary.

## Acceptance Criteria

- High-LBA subdirectory create/read/write/rename or close-time directory-entry updates target the correct sectors.
- Focused high-directory FAT16 regression passes.
- Existing `make test` passes.

## Notes

- This was identified while adding DOS-compatible partitioned FAT16 boot images.
- The initial partitioned-image support covers low directories and boot-critical files; this issue tracks the broader high-LBA audit.
- Fixed by adding 32-bit directory-sector bookkeeping for find/create/rename/delete/attribute/mkdir/rmdir/close-time update paths and a high-subdirectory FAT16 regression.
