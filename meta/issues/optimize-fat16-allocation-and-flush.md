# Optimize FAT16 Allocation and Flush Behavior

## Summary

FAT16 currently has a one-sector write-back window and a next-fit allocation
hint. That fixed the DOS/4GW write-past-EOF stall, but Red Alert save behavior
may still expose FAT-sector reads, dirty-window evictions, or long allocation
scans on large or fragmented volumes.

## Requirements

- Measure FAT16 allocation scan length, FAT-window hits/misses, and FAT mirror writes during save-like writes.
- Build synthetic FAT16 images that exercise contiguous, fragmented, high-cluster, and nearly-full allocation cases.
- Reduce unnecessary dirty-window evictions and long free-cluster scans.
- Preserve both FAT copies and existing rollback/error semantics.
- Keep memory usage appropriate for a tiny real-mode kernel.

## Acceptance Criteria

- A focused synthetic FAT16 benchmark covers fragmented, high-cluster, nearly-full, and sequential allocation cases.
- Instrumentation shows fewer FAT-sector reads/writes for multi-cluster save-like writes.
- FAT16 correctness tests still pass, including large-file, bounds, seek, gap-write, truncate, delete, and directory mutation tests.

## Notes

- Relevant code today: `src/kernel/fat.inc` `fat_alloc_cluster`, `fat16_window_load`, `fat16_window_flush`, and `fat16_set`.
- Possible approaches include a wider FAT16 window, stronger allocation hints, local free-run detection, or delayed mirror writes with explicit flush boundaries.
- See also: `improve-fat-write-durability-and-rollback.md` for FAT-copy consistency and rollback expectations.
- Depends on measurement from `measure-disk-cdrom-io-hot-paths.md`.
- 2026-06-13: Added `make bench-fat16-alloc`, which boots generated FAT16 images shaped into sequential, fragmented, high-cluster, and nearly-full allocation cases. New opt-in counters report FAT allocation scan steps (`FS`), FAT16 window hits/misses (`FH`/`FM`), and FAT mirror writes (`MW`).
- 2026-06-13 baseline before the allocation-hint change: sequential `FS=43`, fragmented `FS=75`, high-cluster `FS=8222`, nearly-full `FS=24533`; high-cluster and nearly-full spent the save/write phase scanning allocated FAT entries.
- 2026-06-13: FAT16 hard-disk mounts now scan once for the first free cluster and store the allocation hint per drive. After the change, `make bench-fat16-alloc` reports high-cluster `FS=32` and nearly-full `FS=32`, with mirror writes still `MW=2`.
