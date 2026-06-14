# Add Sequential Read-Ahead for Handle Reads

## Summary

`INT 21h AH=3Fh` handle reads currently benefit from only a one-sector read
cache. Sequential small reads still miss at every sector boundary. Add bounded
read-ahead for sequential handle reads, ideally limited to the current FAT
cluster and measured before implementation.

## Requirements

- Benchmark sequential handle reads using small, 512-byte, 1 KiB, and 4 KiB chunks.
- Prefetch only safe contiguous sectors, such as the remainder of the current cluster.
- Keep cache invalidation correct for writes, seeks, truncates, drive switches, and disk resets.
- Avoid excessive conventional-memory cost.

## Acceptance Criteria

- Generated sequential-read benchmark shows fewer physical reads or BIOS calls for small sequential chunks.
- Random reads do not fetch excessive unused data.
- Existing read-cache, save/write, seek, truncate, FAT16, and floppy media-change tests pass.

## Notes

- This may share transfer-count logic with multi-sector BIOS reads.
- If memory pressure is high, prefer a small two- or four-sector read-ahead buffer over a full cluster cache.
- 2026-06-14 implementation: `READ_CACHE_BUF` is now four sectors and tagged by active logical drive. Sequential continuation misses prefetch up to four sectors, capped by the current FAT cluster and EOF; non-sequential misses and dirty write-cache fills stay one sector. `bench_read_paths.py` now enforces reduced `READ64`/`READ512` BIOS calls and no extra sectors for random `FATSEEK` reads.
