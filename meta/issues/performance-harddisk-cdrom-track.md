# Performance Track: Hard-Disk and CD-ROM I/O

## Summary

Make hard-disk and CD-ROM I/O fast enough for late DOS games under real-speed
emulators, using Red Alert save/load behavior as the current representative
workload. The target is generic DOS performance: fewer one-sector BIOS/ATAPI
operations, better cache locality, and faithful write semantics without
per-title shortcuts.

## Requirements

- Start with synthetic benchmarks so improvements are tied to sector counts and wall time without needing vendor media.
- Keep Red Alert as a confirming workload, not the primary benchmark gate.
- Optimize the writable FAT hard-disk path for save-game workloads with many small writes.
- Reduce unnecessary volume-buffer reloads when programs alternate between C: and D:.
- Improve FAT16 allocation and flush behavior without weakening rollback or durability expectations.
- Extend CD-ROM read caching for MIX/archive-style small reads beyond a single sector when evidence supports it.
- Keep changes covered by focused generated-media tests, plus vendor-gated Red Alert checks when local media is present.

## Acceptance Criteria

- A documented synthetic benchmark suite captures hard-disk write, drive-switch, FAT16, metadata, and CD-ROM read counts before and after the track.
- Red Alert save time and disk/CD sector counts are captured as a secondary confirmation when local media is present.
- Red Alert save-game time under the same 86Box profile drops from roughly one minute to under 15 seconds, or a lower bound is documented if emulator/media latency makes that target unrealistic.
- Existing correctness tests continue to pass, including FAT mutation, CD-ROM, and save/load regressions.
- New cache behavior has invalidation tests for writes, directory updates, drive switches, and media changes.

## Notes

- Child issues:
- [Measure Hard-Disk and CD-ROM I/O Hot Paths](measure-disk-cdrom-io-hot-paths.md)
- [Add a Hard-Disk Write Cache for Save-Game Workloads](add-harddisk-write-cache-for-saves.md)
- [Reduce Drive-Switch Buffer Thrash Between C: and D:](reduce-drive-switch-buffer-thrash.md)
- [Optimize FAT16 Allocation and Flush Behavior](optimize-fat16-allocation-and-flush.md)
- [Coalesce Save-Time Directory and FAT Metadata Flushes](coalesce-save-metadata-flushes.md)
- [Expand CD-ROM Read Caching for MIX-Archive Access](expand-cdrom-read-cache.md)
- [Fix CD-ROM Media-Swap Cache Invalidation](fix-cdrom-media-swap-cache-invalidation.md)
- Current suspects from code review: synchronous one-sector writes, partial-write prereads, active-drive C:/D: churn, eager commit/close metadata flushing, FAT16 window/allocation behavior, and a too-small CD-ROM read cache.
- Current CD media-swap symptom: after changing CDs, `DIR` often works only on a second try and can briefly show stale or wrong data. Treat this as a correctness prerequisite before expanding CD caches.
- Prefer small generated DOS benchmark programs under `tests/programs/` plus Python runners in `scripts/` that print or collect stable counters. Vendor-gated Red Alert runs should only validate that synthetic wins transfer to the real game.
- 2026-06-13 CD cache expansion: `make bench-cd-cache` now covers generated archive-style same-sector, sequential, and two-/four-sector alternating 64-byte reads. The four-slot CD file-read cache reduced alternating CD sector fetches from 64 to 2 and 4 respectively while same-sector/sequential phases stayed at 1 and 3. User-confirmed Red Alert boots and feels good on refreshed media after this change.

## Closed State

- Final benchmark ladder passed: `make bench-disk-write bench-fat16-alloc bench-metadata bench-io-hot-paths bench-cd-cache`.
- Final write-cache counters: `WRITE512 WR=132 WD=128`, `WRITE128 WR=132 WD=128`, `WRITE64 WR=132 WD=128`; the 128-byte save-style case is coalesced to one data-sector write per sector.
- Final FAT16 allocation counters: sequential `FS=32`, fragmented `FS=63`, high-cluster `FS=32`, nearly-full `FS=32`.
- Final metadata counters: FAT16 `CLEANCOMMIT WR=0 DIR=0`, `CLEANCLOSE WR=0 DIR=0`, `OVERWRITE WR=1 DIR=0`, `TIMECOMMIT WR=35 DIR=32`; FAT12 shows the same clean zero-write behavior with expected FAT12 FAT-sector write counts.
- Final hot-path counters: `DRIVESW RD=9 WR=35 CD=1 DSW=65`, `FAT16ALLOC WR=260 FS=32`, `METADATA WR=35 DIR=32`, `CDMIX64 CD=3`.
- Final CD archive-cache counters: `CDSAME64 CD=1`, `CDSEQ64 CD=3`, `CDALT2_64 CD=2`, `CDALT4_64 CD=4`.
- Correctness coverage passed during the track, including focused generated-media tests and full `make test` (`152/152`) after the final CD cache implementation.
- User-confirmed Red Alert boots and feels good on refreshed media; no further Red Alert-specific instrumentation or bring-up work is required for the current project state.
- The original Red Alert under-15-second save/load target is waived in favor of this user confirmation because the game is now acceptable on the refreshed media and the remaining measurements are covered by generated benchmarks.
