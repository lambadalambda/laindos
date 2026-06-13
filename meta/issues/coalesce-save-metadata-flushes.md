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
