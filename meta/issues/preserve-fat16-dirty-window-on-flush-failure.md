# Preserve FAT16 Dirty Window On Flush Failure

## Summary

`fat16_window_flush` clears `fat16_cache_dirty` even when writing the cached FAT16 window to disk fails. A later window load can overwrite `FAT_SEG`, permanently losing unflushed FAT updates.

## Requirements

- Add a focused regression that injects a FAT16 window write failure and proves the dirty window remains retryable.
- Keep the dirty FAT16 window intact if any FAT copy write fails.
- Prevent `fat16_window_load` from overwriting a dirty window after a failed eviction flush.
- Preserve existing successful-path FAT16 write-back behavior and benchmark counters where possible.

## Acceptance Criteria

- The new regression fails before the fix and passes after it.
- A failed FAT16 window flush does not clear `fat16_cache_dirty` or overwrite the dirty window on the next window load.
- Retrying the flush after the injected failure persists the FAT updates.
- Existing FAT16, write, and game smoke regressions still pass.

## Notes

- Found during the 2026-06-15 review of recent performance work.
- Risk is silent FAT data loss or mirror desync on real disk write failures, which QEMU game smokes normally do not exercise.

## Resolution

- Added `scripts/test_fat16_flush_fail.py` and `tests/programs/f16ferr.asm`.
- `fat16_window_flush` now preserves the dirty window on failure and `fat16_window_load` refuses to evict it after a failed flush.
- The regression verifies the full `F16FERR.DAT` chain and data after the internal eviction retry and close-level stale-error retry.
