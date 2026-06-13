# Add a Hard-Disk Write Cache for Save-Game Workloads

## Summary

The hard-disk read path has a sector cache, but the write path stages every
write through `SEC_BUF` and calls BIOS synchronously for each affected sector.
Save-game writers that emit many small records pay a read-modify-write cycle
for each partial sector. Add an appropriate hard-disk write cache or dirty
sector coalescing path to reduce physical sector I/O.

## Requirements

- Coalesce repeated writes to the same sector before issuing INT 13h writes.
- Benchmark with generated DOS programs that issue representative write patterns: byte/word records, 64-byte records, 512-byte aligned writes, and mixed seek/write updates.
- Preserve correct behavior for partial-sector writes, reads after writes, seek/write patterns, close, commit, process termination, and critical errors.
- Keep FAT/directory metadata coherent with data writes.
- Flush dirty write-cache state on close, commit, drive switch, media change, program termination, and before any operation that must observe on-disk data.

## Acceptance Criteria

- A generated benchmark proves repeated small writes to one sector produce correct data and fewer physical writes under instrumentation.
- The benchmark reports before/after sector I/O counts for several write chunk sizes without requiring Red Alert media.
- Existing save/write tests still pass.
- Manual Red Alert testing confirms the write-cache optimization improves the save/load workload.

## Notes

- Relevant code today: `src/kernel/int21.inc` `AH=40h`, `src/kernel/disk.inc` `write_sector`, and the existing read cache in `AH=3Fh`.
- This should stay generic: no Red Alert-specific file names or save paths.
- See also: `separate-sector-buffers-from-read-cache.md` and `invalidate-read-cache-on-secbuf-overwrites.md` for existing sector-buffer invalidation hazards.
- Depends on measurement from `measure-disk-cdrom-io-hot-paths.md`.
- First optimization step kept the cache non-dirty and only skipped repeated prereads for consecutive writes to the same sector. `make bench-disk-write` improved the 128-byte record pattern from `RD=512 WFP=512` to `RD=128 WFP=128`; physical writes remained `WR=516`.
- Current hard-disk-only write-back step uses a dedicated one-sector `WRITE_CACHE_BUF` and flushes dirty data before drive switches, reads, disk reset, close/commit/time metadata writes, and before reusing the cache for another sector. Same-LBA reads fill `READ_CACHE_BUF` from the flushed write cache so read-before-close observes dirty data immediately. Floppy writes stay write-through after `test_savewrite.py` caught a floppy read-after-write regression; `make bench-disk-write` also includes a hard-disk read-before-close dirty-cache check. Verified QEMU benchmark: `WRITE512 WR=132 WD=128`, `WRITE128 WR=132 WD=128`, `WRITE64 WR=132 WD=128`; the 128-byte case dropped from `WR=516` to `WR=132`, and the 64-byte case reports the same one-data-write-per-sector behavior. Manual Red Alert testing confirmed the patched image is faster.
- Verification after the read-before-close fix: `make`, `make check-docs-sync`, `make bench-disk-write`, `make bench-io-hot-paths`, focused write/read/flush tests, and `python3 scripts/run_tests.py -j 4` (`150/150`) passed.
