# Keep CD Refresh Read Method Consistent

## Summary

`cd_refresh_media` can validate a refreshed PVD through the BIOS fallback path after ATAPI retries fail, but it does not set `cd_read_method` back to BIOS. Later directory and file reads may still try ATAPI, making refresh metadata and data reads inconsistent.

## Requirements

- Add a focused regression or test-mode probe that forces CD refresh through the BIOS fallback while the previous read method is ATAPI.
- Ensure a BIOS-validated refresh records `CD_READ_METHOD_BIOS` before subsequent directory or file reads.
- Preserve the ATAPI-preferred path when ATAPI successfully validates the PVD.
- Keep media-swap invalidation behavior intact.

## Acceptance Criteria

- The new regression fails before the fix and passes after it.
- After BIOS fallback validation, subsequent CD data reads use BIOS unless ATAPI later revalidates successfully.
- Existing CD media-swap, CD file, Sam & Max CD, and game smoke tests still pass.

## Notes

- Found during the 2026-06-15 review of recent CD-ROM performance work.
- QEMU normally does not hit this branch because ATAPI remains healthy after monitor media changes.

## Resolution

- Added `scripts/test_cd_refresh_method.py` and `tests/programs/cdrefmet.asm`.
- `cd_refresh_media` now switches to BIOS before BIOS fallback PVD reads and records BIOS as the active method after BIOS validation succeeds.
- The regression forces ATAPI failures after boot and verifies CD file reads still succeed through BIOS fallback.
