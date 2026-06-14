# Fix Civilization 86Box Smoke Title Menu Timeout

## Summary

`make test-civ-86box` currently boots LainDOS under headless 86Box and launches `LOADFIX CIV`, but the harness never observes the expected Civilization title-menu screenshot.

## Requirements

- Determine whether Civilization is failing under 86Box, the RPC screenshot pipeline is not producing valid frames, or the automated input sequence no longer advances the game.
- Preserve the 86Box cross-check as the discriminator for QEMU's Civilization PIT/input limitation.
- Keep 86Box ROMs, profiles, screenshots, and generated images untracked.

## Acceptance Criteria

- `make test-civ-86box` passes by reaching the title menu, or the issue is narrowed to a missing/unstable local 86Box harness dependency with a clear skip/failure message.
- The smoke captures enough serial or screenshot context to distinguish black-screen capture failure from game-progress failure.
- Documentation remains accurate about whether the headless 86Box Civilization cross-check is expected to pass locally.

## Notes

- Observed 2026-06-14 at `866b448` with `make -k test-game-smokes`.
- The smoke passed `LainDOS shell prompt over 86Box serial` and typed `cd civ`, `loadfix civ`.
- Failure: `no title-menu screen within 240s; last stats: (1, 0)`.
