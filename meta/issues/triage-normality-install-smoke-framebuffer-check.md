# Triage Normality Install Smoke Framebuffer Check

## Summary

`make test-normality-install` drove the Normality installer from the Sam & Max CD image and launched `NORM.EXE`, but the final framebuffer activity check failed because installed files were corrupted by the hard-disk write-back cache.

## Requirements

- Determine whether Normality actually fails to start, starts too slowly for the harness, or displays a valid scene that the current framebuffer threshold misclassifies.
- Preserve the installer-flow coverage through CDReader, `COMSPEC /C` copy, and `C:\NORMINC\NORMINC.BAT` launch.
- Keep the Sam & Max/Normality vendor media and generated CD/hard-disk artifacts untracked.

## Acceptance Criteria

- `make test-normality-install` passes with a stable post-launch signal, or the failure is converted into a clearer product-bug repro.
- The harness records enough screen/serial context to distinguish a real game crash from a screenshot-threshold failure.
- Existing Sam & Max CD smokes continue to pass.

## Notes

- Observed 2026-06-14 at `866b448` with `make -k test-game-smokes`.
- Installer flow completed and printed `PASS: NORM.EXE launched`.
- Failure: `Normality framebuffer inactive (4 colors, 269491 nonblack pixels)` after the current post-launch wait.
- 2026-06-15 root cause: `NORMINC/NORM.EXE` contained `GFX/TWEEN.DAT` bytes from offset `172032`, and `NORMINC/GFX/TWEEN.DAT` had a short FAT chain. Dirty staged data sectors were allowed to remain live while the next FAT chain walk/extension crossed FAT16 sector boundaries.
- Added `scripts/test_cd_shellcopy_large.py` / `tests/programs/cdshcopy.asm`, a generated child-shell CD copy replay that failed pre-fix with the same `NORM.EXE` offset and GFX chain truncation pattern.
- The fix flushes staged write data before sparse gap allocation, first-cluster allocation, and uncached FAT chain walks/extensions while preserving same-sector write coalescing.
- `make test-normality-install` now passes and installed `NORM.EXE` / `GFX/TWEEN.DAT` match the CD source bytes.
