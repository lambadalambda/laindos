# Preserve DI In CD Sector Fetch

## Summary

`cd_fetch_sectors_drive` saves most general registers around BIOS/ATAPI CD sector I/O, but not `DI`. Current callers appear safe, but BIOS `INT 13h AH=42h` should not be assumed to preserve `DI` on all implementations.

## Requirements

- Add a focused regression or register-preservation probe covering CD sector fetch through a public DOS/CD path.
- Preserve `DI` across `cd_fetch_sectors_drive` for both BIOS and ATAPI-backed reads.
- Avoid changing CD read behavior or cache semantics.

## Acceptance Criteria

- The new regression fails before the fix if `DI` is clobbered and passes after the fix.
- `cd_fetch_sectors_drive` preserves `DI` on all return paths.
- Existing CD and game smoke tests still pass.

## Notes

- Found during the 2026-06-15 review of recent CD-ROM performance work.
- This is a future-proofing compatibility issue rather than a currently observed game failure.

## Resolution

- Added `scripts/test_cd_fetch_di.py` and `tests/programs/cdfetchd.asm`.
- `cd_fetch_sectors_drive` now saves and restores `DI`.
- The regression uses a test-only clobber hook to prove the helper preserves `DI` on return.
