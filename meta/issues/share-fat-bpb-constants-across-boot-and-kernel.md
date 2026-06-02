# Share FAT BPB Constants Across Boot And Kernel

## Summary

The boot sectors and kernel duplicate FAT EOC/reserved-cluster values and BPB field offsets. These values are currently correct, but duplication makes future FAT or boot-path changes fragile.

## Requirements

- Move shared FAT constants and BPB offsets into a common NASM include where feasible.
- Keep boot-sector code size under the 512-byte limit.
- Avoid making the boot sectors depend on large kernel-only data or macros.
- Preserve current FAT12 and FAT16 semantics.

## Acceptance Criteria

- Boot-sector FAT EOC/reserved thresholds and kernel FAT constants come from one shared source or have explicit comments explaining any necessary duplication.
- FAT12 and FAT16 boot images still build and boot.
- `make test` passes.

## Notes

- Current kernel constants are set in `src/kernel.asm:469-478`.
- FAT12 boot thresholds are in `src/boot.asm:101-106`.
- FAT16 boot thresholds are in `src/boot16.asm:98-103`.
- `src/memory.inc` already demonstrates a shared include pattern for low-memory constants.
