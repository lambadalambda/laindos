# Triage Normality Install Smoke Framebuffer Check

## Summary

`make test-normality-install` drives the Normality installer from the Sam & Max CD image and launches `NORM.EXE`, but the final framebuffer activity check fails.

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
