# Detect FAT bitness from cluster count

## Summary

`parse_bpb_geometry` decides FAT12 vs FAT16 from the BPB FS-type label string (`src/kernel.asm:517-526`): it defaults to FAT12 and upgrades only when `BPB_FS_TYPE+4 == '6'`. A legal FAT16 volume whose label is not exactly "FAT16" (the MBR mount path accepts partition types 01/04/06/0E regardless of label) is misclassified as FAT12, and `load_active_volume_buffers` then streams the entire FAT (potentially 64-256 sectors) into the 12-sector FAT12 buffer at `FAT_SEG` (0x0060), overwriting `CD_BUF` and the relocated kernel image.

## Requirements

- Determine FAT bitness from the data-area cluster count (< 4085 clusters = FAT12, otherwise FAT16), per the standard algorithm, ignoring the FS-type label.
- Keep `kfat_eoc`/`kfat_eoc_value`/`kfat_reserved` selection in sync with the computed bitness.

## Acceptance Criteria

- A FAT16 image whose BPB label is blank or non-"FAT16" mounts as FAT16 and passes existing FAT16 tests.
- A new test program plus QEMU script exercises a mislabeled FAT16 volume and prints `PASS:` markers.
- Existing test ladder passes.

## Notes

- Compile-time buffer asserts (`src/kernel.asm:3497-3527`) do not cover this runtime path.
- Sibling issue: [Bound volume buffers against BPB geometry](bound-volume-buffers-against-bpb-geometry.md).
