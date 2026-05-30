# Triage Sokoban Hang

## Summary

Sokoban reportedly hangs under LainDOS.

## Requirements

- Identify the exact Sokoban build/version from the reporter or local game set.
- Build or document a local repro image without committing external game files.
- Capture serial output, framebuffer state, keyboard state, and the last DOS call or CPU location where practical.
- Determine whether the hang is due to console I/O, keyboard input, timer behavior, file I/O, memory, or program loading.
- Add focused regression coverage for any DOS behavior that explains the hang.

## Acceptance Criteria

- The Sokoban hang is reproducible with a documented version and launch path.
- Sokoban reaches interactive gameplay, or the remaining blocker is isolated into a separate issue.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: "Sokoban (hangs)".
