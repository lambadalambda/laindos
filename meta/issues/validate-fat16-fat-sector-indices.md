# Validate FAT16 FAT Sector Indices

## Summary

FAT16 helpers compute the FAT sector index from the cluster number, but they do not explicitly check that the resulting index is below `kfat_secs` before reading or writing a FAT sector. Normal images should satisfy this through `kmax_cluster`, but malformed BPBs can make those invariants inconsistent.

## Requirements

- In FAT16 read and write helpers, reject any computed FAT sector index at or beyond `kfat_secs` before disk I/O.
- Treat out-of-range `fat16_next` lookups as end-of-chain or a safe chain termination.
- Treat out-of-range `fat16_set` writes as FAT I/O errors without touching disk sectors outside the FAT.
- Preserve existing FAT12 behavior and valid FAT16 image behavior.

## Acceptance Criteria

- A focused malformed FAT16 geometry or chain regression proves the kernel does not read/write outside the FAT area when the cluster-to-FAT-sector invariant is broken.
- Existing FAT16, high-directory, partitioned FAT16, and bad-FAT tests pass.
- `make test` passes.

## Notes

- Review references: `src/kernel.asm:6520` computes the FAT16 read sector; `src/kernel.asm:6613` computes the FAT16 write sector.
