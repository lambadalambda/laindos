# Prefer ATAPI CD-ROM Data Path

## Summary

LainDOS currently probes BIOS EDD CD-ROM reads before native ATAPI reads. QEMU supports the BIOS route, while the 86Box example machine needs ATAPI. Since the native ATAPI path now has benchmark coverage and is required for broader CD behavior, prefer ATAPI for CD data reads and keep BIOS EDD only as fallback.

## Requirements

- Try native ATAPI CD-ROM mounting before BIOS EDD CD-ROM probing.
- Preserve BIOS EDD fallback for environments that expose a CD only through INT 13h extensions.
- Preserve CD media-swap refresh, MSCDEX/audio paths, raw-sector reads, and file-read cache behavior.
- Keep the forced-ATAPI benchmark path available for regression coverage.

## Acceptance Criteria

- Normal QEMU CD read-path benchmark still passes and uses the sequential CD multiread path.
- Existing forced-ATAPI benchmark pass still verifies the native ATAPI multiread path.
- Focused CD file, cache, media-swap, MSCDEX/audio, chunks, exec, mutation, and dot/large-directory tests pass.
- Full default regression ladder passes.

## Notes

- Relevant code: `src/kernel/cdrom.inc` `mount_bios_cdrom_d`, `mount_atapi_cdrom_d`, `cd_refresh_media`, and CD read helpers.
- The first step should be ATAPI-first with BIOS fallback, not deleting the BIOS path.
- The normal and forced-ATAPI read-path benchmark runs both report `CDSTRM CD=8`; `CDSEQ` stays `CD=16`.
