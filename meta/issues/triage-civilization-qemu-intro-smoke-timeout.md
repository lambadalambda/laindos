# Triage Civilization QEMU Intro Smoke Timeout

## Summary

`make test-civ-smoke` currently reaches Civilization's graphics menu under QEMU, but the smoke does not observe the expected active intro framebuffer before timing out.

## Requirements

- Determine whether this is the known QEMU PIT/input-progress limitation, a changed game-start sequence, or a LainDOS regression before the intro.
- Preserve the check that bare `CIV` reaches the graphics menu with the current child-load placement.
- Keep the 86Box cross-check and QEMU smoke expectations consistent once the root cause is known.

## Acceptance Criteria

- `make test-civ-smoke` passes with a deterministic QEMU-visible milestone, or the QEMU smoke is re-scoped to the stable milestone it can actually validate.
- If QEMU can no longer reach the intro, documentation and status files stop claiming that this exact smoke passes to the intro.
- Any product-side fix keeps existing Civilization and game-smoke coverage intact.

## Notes

- Observed 2026-06-14 at `866b448` with `make -k test-game-smokes`.
- The smoke passed `bare CIV reaches the graphics menu (children load above 64K)`.
- Failure: `no active intro framebuffer within 120s; last stats: (2, 5218)`.

## Resolution

- Resolved 2026-06-15 at `04823ad` with `make -k test-game-smokes`.
- The smoke now passes with `bare CIV reaches the graphics menu (children load above 64K)`, `intro framebuffer active`, and BIOS tick advancement.
