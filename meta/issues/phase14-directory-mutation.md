# Phase 14: Directory Mutation

## Summary

Add directory creation and removal so the shell can manage a writable DOS filesystem.

## Requirements

- Implement `INT 21h AH=39h` create directory.
- Implement `INT 21h AH=3Ah` remove directory.
- Create valid `.` and `..` entries for subdirectories.
- Reject removing non-empty directories.
- Update FAT and parent directory entries correctly.

## Acceptance Criteria

- `MD` creates a directory visible to `DIR` and `FindFirst`.
- `RD` removes an empty directory and frees its cluster.
- `RD` rejects non-empty directories.
- Existing path resolution, `CD`, and file opens continue to work.

## Notes

- Root directory capacity and FAT12 cluster allocation edge cases should be covered by tests.
