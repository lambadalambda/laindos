# Measure Hard-Disk and CD-ROM I/O Hot Paths

## Summary

Add low-overhead diagnostics that count hard-disk and CD-ROM I/O during known
slow workloads. The first target is Red Alert save-game time under 86Box, where
user reports show saves taking around a minute after load-time CD caching
improved.

## Requirements

- Count sector reads, sector writes, CD sector reads, FAT flushes, directory-entry flushes, hard-disk/CD-ROM drive switches, and INT 21h write sizes.
- Build synthetic benchmark runners first: small-write save pattern, alternating C:/D: access pattern, FAT16 allocation pattern, metadata churn pattern, and MIX-like CD read pattern.
- Make diagnostics opt-in at build time or runtime so normal tests remain quiet.
- Distinguish hard-disk data writes from FAT writes and directory writes where practical.
- Preserve serial output parsing for existing tests.

## Acceptance Criteria

- Focused probes report I/O counts for synthetic save-like, drive-switch, FAT16 allocation, metadata, and CD-ROM archive workloads.
- A Red Alert manual or vendor-gated run can report counts around a save operation as a secondary confirmation.
- The diagnostics identify whether the current bottleneck is small writes, C:/D: switches, FAT flushing, directory metadata, CD reads, or a combination.

## Notes

- Likely hook points are `src/kernel/disk.inc`, `src/kernel/cdrom.inc`, `src/kernel/fat.inc`, `src/kernel/fs.inc`, and the INT 21h read/write/commit handlers.
- This issue should usually be handled before cache changes so later commits can prove improvement quantitatively.
