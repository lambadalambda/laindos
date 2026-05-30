# Triage Micro Machines 2 Hang

## Summary

Micro Machines 2 reportedly hangs under LainDOS.

## Requirements

- Build or document a local Micro Machines 2 repro image without committing proprietary game files.
- Capture serial output, framebuffer state, and exact launch steps.
- Identify whether the hang occurs in an installer/configurator, copy-protection check, loader, or main game runtime.
- Determine whether the blocker is DOS API, file I/O, memory, input, timer, VGA/BIOS, or emulator-specific.
- Add focused regression coverage for any DOS behavior that explains the hang.

## Acceptance Criteria

- The hang has a repeatable repro and recorded failure signature.
- Micro Machines 2 reaches gameplay, or the remaining blocker is isolated into a documented follow-up.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: "Micro Machines 2 (hangs)".
