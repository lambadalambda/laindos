# Expand CD-ROM Read Caching for MIX-Archive Access

## Summary

The current CD-ROM file-read cache holds one 2 KiB sector. This fixed Red
Alert's repeated tiny reads from a single MIX sector, but archive workloads may
still bounce between nearby sectors and lose most of the benefit. Extend CD-ROM
caching only where measurement shows it helps.

## Requirements

- Measure synthetic MIX-like reads first, then Red Alert mission loads/save-time CD access if local media is present.
- Generate ISO images with large archive-like files and benchmark access patterns that read repeated same-sector, nearby-sector, and alternating-sector chunks.
- Add a small multi-sector or LRU cache if the access pattern warrants it.
- Keep cache invalidation correct for raw CD sector users, directory scans, media changes, and CD audio/device requests that reuse `CD_BUF`.
- Avoid excessive conventional-memory cost.

## Acceptance Criteria

- A generated CD-ROM benchmark demonstrates improved same-sector, nearby-sector, and alternating-sector reads without vendor media.
- Existing CD-ROM file, subdirectory, FindFirst/FindNext, MSCDEX, audio, chunk-read, share, exec, cache, and mutation tests still pass.
- Red Alert load/save instrumentation shows fewer ATAPI or EDD CD reads if CD access remains a bottleneck.

## Notes

- Relevant code today: `src/kernel/cdrom.inc` `cd_read_handle`, `cd_read_sector_drive`, `CD_BUF`, and `cd_rd_cache_valid`.
- The one-sector cache should remain the minimum fallback if memory pressure argues against a larger cache.
- Depends on `fix-cdrom-media-swap-cache-invalidation.md` so larger caches do not preserve stale disc data.
- Depends on measurement from `measure-disk-cdrom-io-hot-paths.md`.
- 2026-06-13: Added `make bench-cd-cache`, `scripts/bench_cd_cache.py`, and `tests/programs/perfcd.asm` with generated ISO phases `CDSAME64`, `CDSEQ64`, `CDALT2_64`, and `CDALT4_64`.
- Baseline one-sector cache result: same-sector and sequential reads were already bounded (`CDSAME64 CD=1`, `CDSEQ64 CD=3`), but alternating sectors missed badly (`CDALT2_64 CD=64`, `CDALT4_64 CD=64`).
- Implemented a four-slot CD file-read cache backed by dedicated buffers rather than `CD_BUF`; raw sector users still invalidate the file cache before PVD, directory, audio, and media-refresh reads.
- Review follow-up: a victim slot is now marked invalid before refilling, so a failed CD sector fetch cannot leave stale LBA metadata attached to partially replaced data; `CD_CACHE_SLOTS` is also compile-time guarded as a power of two for the round-robin mask.
- Current generated result: `make bench-cd-cache` reports `CDSAME64 CD=1`, `CDSEQ64 CD=3`, `CDALT2_64 CD=2`, and `CDALT4_64 CD=4`.
- Focused generated CD regressions and full `make test` (`152/152`) passed. Covered file, subdir, FindFirst/FindNext, MSCDEX, audio, chunk-read, share, exec, media-swap, volume-label, cache-coherence, mutation guard, and dot/large-directory paths.
- User-confirmed Red Alert boot/load behavior on the refreshed media is good after the four-slot cache, so no additional Red Alert-specific instrumentation is required for this slice.
