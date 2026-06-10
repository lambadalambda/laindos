# Harden boot sector disk reads

## Summary

Three boot.asm robustness gaps: (a) the disk-retry counter `ret_` is a global decremented across the entire load and never reset on success (`src/boot.asm:263-270`) — three cumulative transient errors anywhere abort the boot, and at 0 the next error wraps to 255 retries; (b) the carry returned by `rs` is ignored for the FAT and root-directory reads (boot.asm:115 and 123), so a failed read silently continues with garbage buffers; (c) only the low cylinder byte is stored (`mov [cy], al`, boot.asm:244-249) and cylinder bits 8-9 are never OR'd into CL bits 6-7 — harmless at shipped geometries, latent for >255-cylinder layouts.

## Requirements

- Reset the retry counter on each successful sector read.
- Check CF after every `rs` call and fail the boot loudly on error.
- Encode cylinder bits 8-9 into CL per the INT 13h CHS convention (or document the geometry ceiling).

## Acceptance Criteria

- Boot still fits in 512 bytes minus BPB and signature (build assert).
- `make test` boot tests pass; a fault-injection check (Bochs or QEMU blkdebug) showing a transient error no longer aborts the whole load is a plus, otherwise reasoning documented in the commit.

## Resolution

All three fixes applied: the retry counter resets after every successful sector read, the FAT (FAT12 builds) and root directory reads now `jc nf` instead of continuing with garbage buffers, and the FAT16 boot path stores the full 16-bit cylinder and ORs bits 8-9 into CL per the INT 13h CHS convention. Both variants still fit 512 bytes (2 bytes spare on FAT16 after compensating size reductions: shorter fat_next encoding, fused AX=0x0201 load, and removal of a redundant ROOT_SEG reload).

Fault-injection testing was attempted and abandoned: QEMU's FDC ignores blkdebug read errors entirely, and on IDE a hang-on-retry probe proved injected errors never surface as INT 13h carry to the boot code (the failure manifests through data paths instead), so neither transient-retry nor read-error behavior can be exercised deterministically on this emulator stack. Verified instead by inspection plus the standard boot ladder (test_boot, test_fat16, test_partitioned_fat16, test_boot_chain_bounds).
