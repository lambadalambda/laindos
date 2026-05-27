# Prevent Create Truncation Of Open Files

## Summary

`INT 21h AH=3Ch` truncates an existing file by freeing its FAT chain without first checking whether another open handle already references the same directory entry. `INT 21h AH=41h` already protects deletes with `entry_has_open_handle`; create/truncate should not invalidate live handles either.

## Requirements

- Before truncating an existing file, detect whether the target directory entry has an open handle.
- Return a DOS-compatible error, likely access denied, without changing the directory entry or FAT chain when the file is open.
- Preserve normal create-new and create-over-closed-file behavior.
- Cover both root and subdirectory entries where practical.

## Acceptance Criteria

- A focused regression opens a file, attempts to create/truncate the same path through another handle, verifies the create fails, and verifies the original handle still reads the original data.
- Existing create, delete, write, save-write, and directory mutation tests pass.
- `make test` passes.

## Notes

- Review reference: `src/kernel.asm:2977` frees the existing chain in `.create_file`; `src/kernel.asm:3933` shows the delete-side open-handle guard.
