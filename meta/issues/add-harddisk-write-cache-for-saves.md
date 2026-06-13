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
- Red Alert save-time instrumentation shows a substantial reduction in data-sector read/write calls if small writes were the bottleneck.

## Notes

- Relevant code today: `src/kernel/int21.inc` `AH=40h`, `src/kernel/disk.inc` `write_sector`, and the existing read cache in `AH=3Fh`.
- This should stay generic: no Red Alert-specific file names or save paths.
- See also: `separate-sector-buffers-from-read-cache.md` and `invalidate-read-cache-on-secbuf-overwrites.md` for existing sector-buffer invalidation hazards.
- Depends on measurement from `measure-disk-cdrom-io-hot-paths.md`.
