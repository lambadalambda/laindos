# Triage Shortlines Hang

## Summary

Shortlines reportedly hangs under LainDOS.

## Requirements

- Identify the exact Shortlines build/version from the reporter or local game set.
- Build or document a local repro image without committing external game files.
- Capture serial output, framebuffer state, and the exact point where the hang occurs.
- Determine whether the hang is due to DOS API, file I/O, memory, input, timer, VGA/BIOS, or emulator-specific behavior.
- Add focused regression coverage for any DOS behavior that explains the hang.

## Acceptance Criteria

- The Shortlines hang is reproducible with a documented version and launch path.
- Shortlines reaches interactive gameplay, or the remaining blocker is isolated into a separate issue.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: "Shortlines (hangs)".
