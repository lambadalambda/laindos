# Guard AH=56h Rename Against Open Handles And Read-Only Files

## Summary

`INT 21h AH=56h` (rename) overwrites the source directory entry name without checking `ATTR_RDONLY` or whether another open handle references it. The delete path (AH=41h) and the create path (AH=3Ch) both guard against these conditions; rename should too.

## Requirements

- Before renaming a file, check `ATTR_RDONLY` on the source entry and return error 5 (access denied) if set.
- Before renaming a file, call `entry_has_open_handle` and return error 5 if another handle references the same directory entry.
- Preserve normal rename behavior for non-read-only, non-open files.

## Acceptance Criteria

- A focused regression renames a read-only file and verifies it fails with error 5.
- A focused regression opens a file, attempts to rename it, verifies the rename fails, and verifies the original handle still reads the original data.
- Existing rename, create, delete, write, save-write, and directory mutation tests pass.
- `make test` passes.

## Notes

- Identified during review of the create-truncation guard (commit for AH=3Ch open-handle + ATTR_RDONLY guards).
- Pattern to follow: see `.cr_existing` in `src/kernel/int21.inc` and the delete path at `.df_access`.
