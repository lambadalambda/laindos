# Centralize Directory Slot Writeback

## Summary

Directory mutation code repeatedly decides whether a directory entry lives in the fixed root buffer or in a subdirectory sector, then computes offsets and flushes the correct backing sector. The repeated root-vs-subdirectory logic is a correctness risk for future directory changes.

## Requirements

- Centralize root-directory LBA detection and root-buffer offset calculation.
- Provide a shared helper or macro for loading, updating, and flushing a directory slot by saved LBA/high-LBA/offset metadata.
- Preserve high-LBA directory metadata and existing root directory behavior.
- Keep the refactor incremental and covered by directory mutation tests.

## Acceptance Criteria

- Existing mkdir/rmdir/delete/rename/create/write directory mutation tests pass.
- Existing high-directory and partitioned FAT16 tests pass.
- `make test` passes.

## Notes

- Review references: `src/kernel.asm:6992` and `src/kernel.asm:7022` contain representative duplicated writeback logic.
