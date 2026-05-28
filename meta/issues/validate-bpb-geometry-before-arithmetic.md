# Validate BPB Geometry Before Arithmetic

## Summary

BPB fields are trusted before arithmetic in kernel initialization. A corrupted BPB can make `init_bpb_geometry` divide by zero or compute inconsistent filesystem geometry before normal disk I/O guards are reached.

## Requirements

- Validate sectors per cluster, sectors per track, head count, number of FATs, FAT size, root entry count, bytes per sector, and total sector fields before division or derived geometry writes.
- Reject unsupported or inconsistent BPBs with a clear halt/error path instead of taking a CPU exception.
- Keep raw FAT12, raw FAT16, and partitioned FAT16 boot paths working.

## Acceptance Criteria

- A focused boot regression corrupts at least `BPB_SecPerClus` to zero and verifies the kernel fails safely rather than raising divide error.
- Existing boot, FAT12, FAT16, and partitioned FAT16 tests pass.
- `make test` passes.

## Notes

- Review reference: `src/kernel.asm:429` divides by `kspc` during `init_bpb_geometry`.
- Outcome: `init_bpb_geometry` now validates BPB fields and geometry bounds before divisions; `test_bpb_invalid.py` corrupts `BPB_SecPerClus` to zero and verifies an `Invalid BPB` halt.
