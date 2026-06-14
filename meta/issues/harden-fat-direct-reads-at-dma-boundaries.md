# Harden FAT Direct Reads at DMA Boundaries

## Summary

The FAT handle-read direct multi-sector path now rejects unaligned caller offsets, but it can still request more direct sectors than fit before the next 64K BIOS DMA boundary when the caller buffer is offset-aligned but physically misaligned.

## Requirements

- Preserve the direct multi-sector read optimization for safe aligned reads.
- Limit direct reads so one BIOS request never advances into a region where fewer than one whole 512-byte sector fits before a 64K DMA boundary.
- Route unsafe boundary-tail sectors through the existing staged read-cache/copy path instead of adding a new bounce-buffer path.
- Add a focused regression that performs a near-64K read into an offset-aligned but physically misaligned buffer and verifies all bytes.

## Acceptance Criteria

- The focused hard-disk multi-sector read regression passes for unaligned buffers, aligned near-boundary buffers, and a near-64K physically misaligned aligned-offset buffer.
- Monkey Island 1 and Monkey Island 2 save smokes still pass.
- The read-path benchmark still shows the aligned `READ4K` direct path and unchanged CD streaming counters.
- Default QEMU regression tests pass.

## Notes

- Advisors recommended hardening now instead of reverting the read optimization.
- The expected fix is to cap the FAT direct-read sector count by `floor(bytes_to_64K_dma_boundary / 512)` and let the existing read loop fall back to staged reads when the next sector starts in the boundary tail.
- Resolved 2026-06-14. `READMULTI` now reproduces the near-64K physically misaligned aligned-offset case, and the FAT direct-read gate caps direct sector count before the DMA boundary.
