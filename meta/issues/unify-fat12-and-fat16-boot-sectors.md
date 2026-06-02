# Unify FAT12 And FAT16 Boot Sectors

## Summary

`src/boot.asm` and `src/boot16.asm` duplicate most of the boot flow with FAT12/FAT16-specific differences. Keeping two near-identical boot sectors increases the chance of fixing boot loading, CHS, retry, or FAT-chain logic in one file but not the other.

## Requirements

- Evaluate whether a single NASM source with `%if`-selected FAT12/FAT16 paths can still fit in 512 bytes for both formats.
- Keep boot-sector size and signature constraints intact.
- Preserve FAT12 floppy boot and FAT16 hard-disk boot behavior.
- Keep generated image builders and Makefile targets working.

## Acceptance Criteria

- A single source file or clearly shared include owns the duplicated boot flow.
- FAT12 and FAT16 boot binaries remain exactly 512 bytes with `0xAA55` signatures.
- FAT12 and FAT16 boot smoke tests pass.
- `make test` passes.

## Notes

- Relevant files: `src/boot.asm` and `src/boot16.asm`.
- If size pressure makes full unification impractical, capture the decision and still share small constants/helpers where safe.
