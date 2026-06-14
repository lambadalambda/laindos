# Triage Full Monkey Island Framebuffer Inactive Smoke

## Summary

`make test-monkey-full` currently launches the full VGA Monkey Island image and reaches `EXE loaded`, but the smoke fails because the captured framebuffer remains inactive.

## Requirements

- Determine whether the failure is a real Monkey Island startup regression, a QEMU/emulator timing issue, or an overly strict harness timeout/framebuffer threshold.
- Preserve the shell Monkey demo smoke while investigating the full-game image.
- Keep proprietary `vendor/monkey_full.zip` and generated images untracked.

## Acceptance Criteria

- `make test-monkey-full` passes, or the issue is split into a concrete product bug plus a documented harness limitation.
- The smoke fails with a clear diagnostic if the game never reaches an expected startup state.
- Relevant game-smoke documentation is updated if the expected full Monkey status changed.

## Notes

- Observed 2026-06-14 at `866b448` with `make -k test-game-smokes`.
- Serial markers passed: `LainDOS booted`, `EXE loaded`.
- Failure: `framebuffer inactive (2 colors, 4108 nonblack pixels)` after the current 25 second wait in `scripts/test_monkey_full.py`.
- Triage found `2a484f8 perf: batch FAT handle reads` as the first bad commit. The game performs large reads into unaligned buffers; routing those away from direct BIOS reads restores the smoke.
- Resolved 2026-06-14. `make test-monkey-full` passes after requiring sector-aligned caller buffers for direct FAT multi-sector reads.
