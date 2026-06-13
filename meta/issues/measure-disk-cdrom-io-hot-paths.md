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
- Manual Red Alert testing confirms the synthetic bottleneck findings transfer to the real workload.
- The diagnostics identify whether the current bottleneck is small writes, C:/D: switches, FAT flushing, directory metadata, CD reads, or a combination.

## Notes

- Likely hook points are `src/kernel/disk.inc`, `src/kernel/cdrom.inc`, `src/kernel/fat.inc`, `src/kernel/fs.inc`, and the INT 21h read/write/commit handlers.
- This issue should usually be handled before cache changes so later commits can prove improvement quantitatively.
- Initial hard-disk write probe: `make bench-disk-write` builds a non-default FAT16 hard-disk image with `-DPERF_IO_COUNTS=1`, runs `tests/programs/perfwrite.asm`, verifies written contents, and reports 512-byte sequential writes plus 128-byte and 64-byte save-style writes. It prints BIOS ticks plus `RD`, `WR`, `WD`, `CD`, `DSW`, `FF`, `F16`, `FA`, `DIR`, `WFC`, and `WFP` counters from the opt-in `INT 21h AH=F0h` benchmark API.
- Synthetic hot-path suite: `make bench-io-hot-paths` builds generated FAT16 and ISO media with `-DPERF_IO_COUNTS=1`, runs `tests/programs/perfio.asm`, and reports `WRITE512`, `WRITE128`, `DRIVESW`, `FAT16ALLOC`, `METADATA`, and `CDMIX64`. The counter line now also includes `FA` for FAT allocation events. First QEMU run: `WRITE512 rd=1 wr=132 fa=16`, `WRITE128 rd=128 wr=516 fa=16`, `DRIVESW dsw=65 cd=1`, `FAT16ALLOC wr=260 fa=32`, `METADATA wr=67 ff=33 dir=65`, `CDMIX64 cd=3`. The primary current bottleneck remains synchronous save-style hard-disk writes; metadata churn is the secondary obvious write source. Red Alert vendor/media confirmation has not been run in this slice.
- 2026-06-13: Completed by the generated benchmark suite and manual Red Alert confirmation. No Red Alert-specific counter instrumentation is required for this issue.
