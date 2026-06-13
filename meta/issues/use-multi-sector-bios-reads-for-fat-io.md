# Use Multi-Sector BIOS Reads for FAT I/O

## Summary

The FAT disk path currently issues one BIOS read per 512-byte sector. Teach the
BIOS/CHS disk path to transfer multiple contiguous sectors per call where it is
safe, reducing interrupt and CHS setup overhead for sequential reads.

## Requirements

- Compute safe transfer counts from the current LBA, request size, track boundary, and destination 64 KiB boundary.
- Preserve floppy and hard-disk correctness, including media-change and write-cache flush behavior.
- Keep single-sector fallback behavior for unsafe boundaries or failed multi-sector reads.
- Add or extend generated benchmarks to show reduced BIOS call counts for sequential reads.

## Acceptance Criteria

- Sequential FAT reads transfer multiple sectors per BIOS call without crossing track or 64 KiB DMA boundaries.
- Existing FAT read/write, floppy media-change, save/load, and shell tests pass.
- A generated read benchmark shows fewer physical BIOS read calls for sequential reads, while random 512-byte reads do not regress.

## Notes

- Relevant code: `src/kernel/disk.inc` `setup_sector_io`, `sector_io_loop`, `finish_sector_io`, and CHS setup.
- Cap conservatively, likely to the current track and destination boundary rather than chasing maximum BIOS transfer sizes.

## Implementation Notes

- Added `read_sectors` and a multi-sector CHS transfer count capped by request length, current track, and destination 64 KiB DMA boundary.
- Multi-sector read failures force one-sector retry behavior for the remaining operation without refreshing the retry budget; floppy media-change remount preserves in-flight I/O state.
- DMA capping uses the low 16 bits of the physical `ES:BX` address, not just the offset. The direct handle-read path falls back to the cache path when a caller buffer starts too close to a DMA page boundary for one sector.
- Added a full-sector `AH=3Fh` direct-read path for at least two sectors inside the current FAT cluster.
- `finish_sector_io` advances `ES:BX` using the high word of `512 * sector_count`, keeping the helper safe for future larger transfer counts.
- The CHS overflow error path returns without popping the already-restored quotient; only the pre-pop DMA no-fit path uses the pop-before-error exit.
- The direct read path rejects `rf_direct_count >= 128` before BIOS I/O so its 16-bit byte-count updates remain bounded.
- `make bench-read-paths` now reports `RS` transferred FAT sectors and validates reduced `RD` BIOS calls for 1 KiB/4 KiB sequential reads while keeping random 512-byte `FATSEEK` at `RD=32`.
