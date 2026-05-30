# Triage Civilization 1 Configuration And Startup Hang

## Summary

Civilization 1 reportedly does not work: its configuration menu renders or behaves incorrectly, and the game hangs on start.

## Requirements

- Build or document a local Civilization 1 repro image without committing proprietary game files.
- Capture serial output, framebuffer state, and the exact launch/configuration steps that reproduce the issue.
- Determine whether the configuration-menu corruption is console, keyboard, VGA/BIOS, filesystem, or program-loader related.
- Determine whether the startup hang shares a root cause with the configuration issue or is a separate runtime blocker.
- Add a focused regression or smoke script if a small DOS/API behavior explains the failure.

## Acceptance Criteria

- The issue has a repeatable launch/configuration repro and recorded failure signature.
- Civilization 1 reaches gameplay, or the remaining blocker is isolated with enough detail for a follow-up issue.
- Relevant regressions and `make test` pass after any implementation change.

## Notes

- Reported symptoms: "configuration menu is all weird" and "hangs on start".
