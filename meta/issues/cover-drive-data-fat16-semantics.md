# Cover Drive Data FAT16 Semantics

## Summary

Extend `INT 21h AH=1Bh` and `AH=1Ch` drive allocation-data coverage across floppy FAT12 and hard-disk FAT16 boot images.

## Requirements

- `AH=1Bh` reports allocation data for the default drive.
- `AH=1Ch` accepts default and supported explicit drive numbers.
- Invalid `AH=1Ch` drive requests return `AL=FFh`.
- FAT12 and FAT16 boot-image BPB values are reflected consistently.

## Acceptance Criteria

- A focused 16-bit regression exercises FAT12 floppy and FAT16 hard-disk drive data under QEMU.
- The regression checks sectors per cluster, bytes per sector, available cluster count, and media descriptor pointers.
- The regression checks boundary and high-invalid drive requests.
- `make test` passes.
- The Phase 19 matrix records the covered drive-data semantics.
