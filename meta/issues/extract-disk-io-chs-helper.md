# Extract Disk I/O CHS Helper

## Summary

`read_sector` and `write_sector` duplicate partition offset application, LBA-to-CHS conversion, geometry checks, retry setup, and post-sector pointer advancement. This makes disk I/O hardening changes easy to apply to one path and miss in the other.

## Requirements

- Extract the common LBA-to-CHS conversion and geometry validation into a shared helper or macro.
- Keep read/write retry behavior and register effects compatible with current callers.
- Preserve partitioned FAT16 hidden-sector handling and high-LBA directory behavior.
- Keep the refactor small and mechanical.

## Acceptance Criteria

- Existing boot, FAT16, partitioned FAT16, high-directory, write, save-write, and directory mutation tests pass.
- `make test` passes.
- The remaining difference between read and write paths is limited to the BIOS operation and necessary call-specific state.

## Notes

- Review references: `src/kernel.asm:6832` and `src/kernel.asm:6899` contain the duplicated sector I/O paths.
