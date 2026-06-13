# Fix CD-ROM Media-Swap Cache Invalidation

## Summary

Changing the CD-ROM media can leave stale CD state visible to DOS programs: a
`DIR` after a swap sometimes works only on the second try and can temporarily
show wrong data. Fix CD media-change detection and cache invalidation before
expanding CD read caches for performance.

## Requirements

- Reproduce the stale/wrong directory behavior with generated ISO images and an automated QEMU monitor media swap.
- Invalidate all CD-derived state when media changes: file-read cache, directory scan state, volume label/id data, PVD/root-directory metadata, and any future multi-sector CD cache.
- Ensure the first DOS directory or file operation after a CD swap observes the new disc or returns a clear transient error that a retry can handle correctly.
- Preserve existing MSCDEX, CD file, CD directory, CD exec, and CD audio behavior.

## Acceptance Criteria

- A generated regression swaps between two ISO images with different root directories and proves the first `DIR`/FindFirst after the swap cannot show stale entries from the previous disc.
- The same regression proves opening a file unique to the new disc succeeds without requiring a second manual attempt when the emulator reports the media change cleanly.
- Existing CD-ROM tests still pass, including `test_cd_file`, `test_cd_subdir`, `test_cd_find`, `test_cd_mscdex`, `test_cd_chunks`, `test_cd_cache`, `test_cd_exec`, and vendor-gated CD smokes where applicable.

## Notes

- Current suspect areas include `src/kernel/cdrom.inc` CD sector caches and PVD/root metadata, `src/kernel.asm` drive activation and CD mount state, and any assumptions that CD media does not change after boot.
- The regression should use synthetic ISO images, not Red Alert media, so it can run in the default or focused generated-media ladder.
- This is both a correctness issue and a prerequisite for larger CD-ROM caches: stale cache invalidation must be proven before adding more cached CD state.
- See also: `guard-cdrom-drive-against-fat-mutations.md` for CD-ROM safeguards around FAT mutation calls.

## Completion Notes

- Added `scripts/test_cd_media_swap.py` and `tests/programs/cdswap.asm`, which swap generated `OLDCD`/`NEWCD` ISOs through the QEMU monitor and prove the first post-swap volume-label FindFirst, root FindFirst, and new-file open/read cannot use stale old-disc state.
- CD path and directory opens now refresh PVD/root/volume metadata through direct ATAPI when available, SRST+retry on post-swap unit attention, and commit the CD read method to ATAPI after a valid PVD so subsequent directory scans and file reads avoid stale BIOS EDD sectors.
- Verification passed: `make`, five consecutive `python3 scripts/test_cd_media_swap.py` runs, focused generated CD ladder including `test_cd_cache`, `test_cd_exec`, `test_cd_audio`, mutation and dot-directory CD tests, `make check-docs-sync`, and full `make test` (`152/152`).
- Attempted `make test-cd-86box`, but the local 86Box harness also failed `python3 scripts/test_cd_86box.py --boot-only` with empty serial output, so 86Box did not provide a useful CD regression signal for this slice.
