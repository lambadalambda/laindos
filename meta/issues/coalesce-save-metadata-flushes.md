# Coalesce Save-Time Directory and FAT Metadata Flushes

## Summary

Create, close, commit, rename, delete, and file-time calls eagerly write
directory sectors and flush FAT state. Save systems often use temp files,
commits, renames, and timestamp updates, so metadata writes may dominate even
when data writes are small.

## Requirements

- Measure directory-entry flushes, FAT flushes, commits, closes, renames, deletes, and file-time updates during save-like workloads.
- Use generated DOS programs to model common save strategies: temp-file write + commit + rename, overwrite existing save, update timestamp, delete old backup, and repeated close/reopen.
- Add per-handle or per-directory dirty tracking where it safely avoids redundant flushes.
- Preserve DOS-visible commit semantics: `AH=68h`, close, and process termination must still make data durable enough for the emulator-backed disk image and subsequent opens.
- Keep error propagation and rollback behavior correct.

## Acceptance Criteria

- A focused synthetic benchmark proves redundant close/commit/time-update sequences do not cause unnecessary sector writes while still persisting correct metadata.
- The benchmark reports metadata sector read/write counts before/after without vendor media.
- Existing file-time, commit, rename/delete, truncate, and save-write tests still pass.
- Red Alert save instrumentation shows fewer metadata sector writes if metadata churn was part of the slowdown.

## Notes

- Relevant code today: `src/kernel/fs.inc` `flush_handle_dir_entry`, `flush_dir_slot`, and INT 21h handlers for create, close, commit, rename, delete, attributes, and file time.
- See also: `improve-fat-write-durability-and-rollback.md` for durability and rollback expectations.
- Depends on measurement from `measure-disk-cdrom-io-hot-paths.md`.

## Completion Notes

- Added `make bench-metadata`, `scripts/bench_metadata.py`, and `tests/programs/perfmeta.asm` to cover timestamp+commit churn, clean commit, clean close, same-size overwrite, temp-file commit/rename, delete-old-save, subdirectory timestamp, FAT16, and FAT12 patterns.
- Added per-handle metadata dirty tracking in the spare byte after `H_DRIVE`; metadata-changing write/truncate/time paths mark it dirty, and successful directory-entry flush clears it.
- Added `scripts/test_metafail.py` and `tests/programs/metafail.asm` to force a directory-slot flush failure after a write/file-time update and verify a later commit persists dirty size, first cluster, data, and timestamp.
- Current focused FAT16 benchmark result: `TIMECOMMIT WR=35 DIR=32`, `CLEANCOMMIT WR=0 DIR=0`, `CLEANCLOSE WR=0 DIR=0`, `OVERWRITE WR=1 DIR=0`, `TEMPRENAME WR=6 DIR=3`, `DELETEOLD WR=3 DIR=1`, `SUBDIRTIME WR=35 DIR=32`.
- Current focused FAT12 benchmark result: `TIMECOMMIT WR=49 DIR=32`, `CLEANCOMMIT WR=0 DIR=0`, `CLEANCLOSE WR=0 DIR=0`, `OVERWRITE WR=1 DIR=0`, `TEMPRENAME WR=20 DIR=3`, `DELETEOLD WR=17 DIR=1`, `SUBDIRTIME WR=49 DIR=32`.
- Verification passed: `make`, `make check-docs-sync`, `git diff --check`, `make bench-metadata`, `make bench-disk-write`, `make bench-io-hot-paths`, focused metadata regressions, Norton Commander rename/delete, `python3 scripts/test_metafail.py`, and full `make test` (`151/151`).
