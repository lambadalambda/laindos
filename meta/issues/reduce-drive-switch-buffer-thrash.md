# Reduce Drive-Switch Buffer Thrash Between C: and D:

## Summary

LainDOS keeps one active FAT/CD volume context. Switching between C: and D:
flushes FAT state, invalidates caches, and reloads active volume buffers. A
game that alternates CD reads with hard-disk save writes can accidentally pay
dozens of root-directory reads and FAT-window reloads during one save.

## Requirements

- Measure synthetic C:/D: alternation first; use manual Red Alert confirmation when local media is present.
- Add a generated benchmark that alternates hard-disk writes with CD-ROM reads and records root-buffer reloads, FAT flushes, and elapsed ticks.
- Avoid reloading unchanged FAT16 root buffers on every C:/D: transition.
- Keep per-drive current directory and media-change behavior correct.
- Preserve floppy media-change handling and CD-ROM mount behavior.

## Acceptance Criteria

- A synthetic regression proves alternating C: and D: operations do not reload unchanged C: root buffers unnecessarily.
- The benchmark runs with generated hard-disk and ISO images, not vendor media.
- Drive-switch correctness tests still pass for hard disk, floppy, and CD-ROM combinations.
- Manual Red Alert testing confirms the optimized drive-switch path improves save/load feel.

## Notes

- Relevant code today: `src/kernel.asm` `activate_drive`, `load_active_volume_buffers`, and cache invalidation around drive switches.
- Potential designs include per-drive buffer-valid flags, lazy root reloads, or preserving root/FAT window state per drive when memory permits.
- Depends on measurement from `measure-disk-cdrom-io-hot-paths.md`.
- 2026-06-13: Added a generated benchmark guard requiring `DRIVESW` hard-disk sector reads to stay at or below 128. The pre-fix baseline failed with `RD=1065`, matching repeated C: FAT16 root reloads across 65 drive switches.
- 2026-06-13: `ROOT_SEG` now has a conservative owner byte. `load_active_volume_buffers` skips the root reload only when returning to the same hard-disk FAT16 drive; floppy and failed reload paths remain conservative. The generated benchmark now reports `DRIVESW RD=9 DSW=65 CD=1`.
- 2026-06-13: Manual Red Alert testing on the patched 86Box image confirmed the change sped things up enough; no additional Red Alert-specific instrumentation is required for this issue.
