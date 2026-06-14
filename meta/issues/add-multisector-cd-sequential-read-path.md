# Add Multi-Sector CD Sequential Read Path

## Summary

The CD file cache now handles repeated archive-sector reads, but sequential CD
streaming still issues one ATAPI or EDD command per 2048-byte sector. Add a
measured multi-sector sequential CD read path for generated ISO workloads.

## Requirements

- Add a generated sequential-CD benchmark phase distinct from alternating MIX/archive reads.
- For BIOS EDD CD reads, use a sector count greater than one where safe.
- For ATAPI, investigate whether QEMU and 86Box handle multi-sector packet reads consistently; keep single-sector fallback.
- Preserve CD media-swap invalidation, raw-sector users, directory scans, audio requests, and cache coherency.

## Acceptance Criteria

- Generated sequential CD benchmark shows fewer CD commands/physical reads for streaming reads.
- Existing CD file, subdir, find, MSCDEX, audio, chunks, share, exec, media-swap, cache, mutation, and dot/large-directory tests pass.
- Multi-sector ATAPI failures degrade safely to single-sector reads rather than corrupting cached data.

## Notes

- Relevant code: `src/kernel/cdrom.inc` `cd_fetch_sector_drive`, ATAPI packet read code, EDD DAP setup, and `cd_read_handle`.
- Validate on QEMU first; 86Box should be treated as a separate discriminator when the local harness is useful.
- Added `CDSTRM` to `scripts/bench_read_paths.py`: 32768 bytes from `D:\CDSEQ.BIN` in 4096-byte chunks.
- Baseline before the direct path: `CDSTRM CD=16`; after the two-sector path: `CDSTRM CD=8` in both normal BIOS EDD and forced-ATAPI benchmark builds. Existing `CDSEQ` stays at `CD=16` for the 512-byte cache workload.
- The implementation only takes the direct path for aligned 4096-byte handle reads with at least two sectors left and a DMA-safe destination; failures fall back to the existing one-sector cache path without advancing the handle.
