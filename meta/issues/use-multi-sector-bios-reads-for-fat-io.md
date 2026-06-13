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
