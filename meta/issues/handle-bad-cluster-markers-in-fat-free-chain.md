# Handle bad-cluster markers in fat_free_chain

## Summary

Freeing a chain whose next-pointer is a bad-cluster marker (0xFF7/0xFFF7 — above `kfat_reserved` but below `kfat_eoc`, surviving `fat_next_sanitize` and the EOC test) loops once more with the marker in SI (`src/kernel/fat.inc:255-268`); `fat_set` then takes `.invalid` and latches `fat_io_error` (fat.inc:133-135). The next `flush_fat` returns CF set, so e.g. `delete_file` reports error 5 (`src/kernel/int21.inc:3501-3503`) after a delete that actually succeeded, and on FAT12 the `.fat_err` path discards the pending FAT image (`fat_dirty` cleared without writing), losing the legitimately freed entries.

## Requirements

- Treat values >= `kfat_reserved` (including bad-cluster markers) as chain terminators in `fat_free_chain` without touching the marker entry or latching an error.

## Acceptance Criteria

- Test image with a file chain ending in a 0xFF7 marker: delete succeeds, the FAT flush persists the freed entries, and the bad-cluster mark is preserved; `PASS:` markers.
- Existing delete/FAT tests pass.

## Notes

- Coordinate with [Add cycle guard and shared FAT chain walker](add-fat-chain-cycle-guard.md), which centralizes the guard values.
