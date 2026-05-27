# Harden Boot FAT Chain Loading

## Summary

The boot sectors walk `KERNEL.SYS` cluster chains before the kernel's FAT bounds checks are available. Corrupted FAT entries can make the boot loaders read invalid clusters or arbitrary sectors while loading the kernel.

## Requirements

- Add boot-sector bounds checks for cluster numbers before computing LBAs.
- Sanitize or reject FAT entries that point below cluster 2, beyond the data region, or into non-EOC reserved ranges.
- Apply equivalent hardening to FAT12 floppy boot and FAT16 hard-disk boot loaders within boot-sector size constraints.
- Fail safely with the existing boot error path rather than jumping into partially loaded garbage.

## Acceptance Criteria

- Focused boot-image regressions corrupt the kernel FAT chain to cluster 0/1 and to an out-of-range value and verify safe boot failure.
- Normal FAT12 and FAT16 boot tests pass.
- `make test` passes.

## Notes

- Review references: `src/boot.asm:120`, `src/boot.asm:142`, `src/boot16.asm:90`, and `src/boot16.asm:113` implement pre-kernel chain loading.
