# Split Kernel Into Subsystem Includes

## Summary

`src/kernel.asm` has grown into a single large file containing boot handoff, interrupt dispatch, FAT, disk I/O, paths, directory mutation, MCB allocation, EXEC/overlay loading, console, mouse, data, and trace code. This makes focused review and safe growth harder.

## Requirements

- Split the kernel into NASM `%include`d subsystem files without changing runtime behavior.
- Keep include order, shared labels, and memory layout explicit.
- Prefer small, mechanical moves grouped by concern: interrupt handlers, FAT, disk I/O, paths/directories, MCBs, loader/EXEC, console/serial, mouse, and data.
- Preserve existing build flags and test entry points.

## Acceptance Criteria

- `make` produces a bootable kernel after each staged split.
- `make test` passes after each staged split.
- File boundaries make subsystem ownership clear without introducing broad rewrites.

## Notes

- This is an architecture-management issue, not an invitation for a large semantic rewrite.
