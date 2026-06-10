# Bound volume buffers against BPB geometry

## Summary

Mount-time geometry from the BPB is trusted past the resident buffer sizes. `parse_bpb_geometry` accepts root directory sizes up to 2032 entries (`src/kernel.asm:496`) but `ROOT_BUF_PARAS` is sized for `ROOT_MAX_ENTRIES equ 512`; `load_active_volume_buffers` reads all `krsc` sectors (up to 63.5 KiB) into `ROOT_SEG` unconditionally, overrunning into the kernel stack and the MCB arena. Similarly `kfat_secs` is not bounded against the FAT buffer for the FAT12 path.

## Requirements

- Reject (or cleanly fail to mount) volumes whose root directory entry count exceeds `ROOT_MAX_ENTRIES` or whose FAT sector count exceeds the resident FAT buffer for the detected bitness.
- Failure must be a clean mount error, not silent truncation or memory corruption.

## Acceptance Criteria

- Mounting an image with >512 root entries or an oversized FAT returns an error and leaves kernel memory intact (verified by a test that continues running the shell afterwards).
- Test program plus QEMU script with `PASS:`/`FAIL:` markers added; existing ladder passes.

## Notes

- Found during the 2026-06-10 whole-repo review alongside [Detect FAT bitness from cluster count](detect-fat-bitness-from-cluster-count.md).
