# Support DOS-Compatible Partitioned FAT16 HD Images

## Summary

LainDOS hard-disk images are currently raw FAT volumes. Real MS-DOS expects a partitioned hard disk with an MBR, an active FAT partition, and BPB hidden-sector offsets. LainDOS should be able to boot from and read a standard partitioned FAT16 hard-disk image, including images prepared by normal FAT/disk tools.

## Requirements

- Support a simple MBR with one active FAT16 partition that chainloads the LainDOS FAT16 boot sector.
- Honor the FAT boot sector BPB hidden-sector field when translating filesystem-relative LBAs to BIOS disk LBAs.
- Keep existing raw FAT12/FAT16 image support working when hidden sectors are zero.
- Prefer validation with normal FAT/disk tooling where available; use deterministic generated fixtures only for focused regression coverage.
- Document the supported image layout and tool workflow.

## Acceptance Criteria

- A partitioned FAT16 hard-disk image boots LainDOS in QEMU and runs a small file-read test from the FAT16 partition.
- The same partitioned image exposes a readable FAT16 partition to MS-DOS or host FAT tooling.
- Existing FAT12 and raw FAT16 tests continue to pass.
- The compatibility matrix or relevant docs mention partitioned FAT16 support and remaining limits.

## Notes

- The current `hd32m`/`hd96m` formats are raw FAT volumes, not DOS-compatible partitioned disks.
- The initial implementation adds BPB hidden-sector offsets in the FAT16 boot sector and common kernel sector I/O path.
- The first target can be one primary partition below the CHS 1024-cylinder limit, using existing CHS INT 13h paths.
- Follow-up after the initial boot/read path: audit older filesystem call sites that still pass only 16-bit sector LBAs before relying on partitioned images with high subdirectories or large mutable directory trees.
