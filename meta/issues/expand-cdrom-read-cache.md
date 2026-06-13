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
