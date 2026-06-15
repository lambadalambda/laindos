# Flush Dirty FAT16 Window Despite Pending FAT Error

## Summary

`flush_fat` returns through the pending `fat_io_error` path before trying to flush a dirty FAT16 write-back window. In retry or termination paths, this can leave dirty FAT16 state unpersisted.

## Requirements

- Add a regression that creates both a pending FAT error and a dirty FAT16 window, then verifies `flush_fat` still attempts to persist the dirty window.
- Make `flush_fat` drain a dirty FAT16 window even when `fat_io_error` is already set.
- Preserve the existing consumed-on-flush error contract: callers still see carry set when a pending FAT error existed.
- Avoid changing FAT12 flush behavior except where explicitly covered by tests.

## Acceptance Criteria

- The new regression fails before the fix and passes after it.
- Dirty FAT16 window data is persisted even when `fat_io_error` was set before `flush_fat`.
- `flush_fat` still reports the pending error to callers.
- Existing FAT16 mutation tests and full generated test suite still pass.

## Notes

- Found during the 2026-06-15 review of recent performance work.
- This is distinct from a write failure during the FAT16 window flush itself; that case is tracked separately.

## Resolution

- Added `scripts/test_fat16_pending_error_flush.py` and `tests/programs/f16perr.asm`.
- The FAT16 `flush_fat` branch now drains a dirty write-back window before consuming/reporting a pending `fat_io_error`.
- The regression halts without termination cleanup retry and verifies the full `F16PERR.DAT` chain host-side.
