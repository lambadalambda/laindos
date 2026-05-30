# Triage Boom And SMMU FreeDoom Hangs

## Summary

FreeDoom with Boom and SMMU reportedly hangs under LainDOS.

## Requirements

- Build or document local Boom and SMMU FreeDoom repro images without committing external game data.
- Capture serial output, framebuffer state, and the last known progress point for each executable.
- Determine whether the hangs are DOS API, file I/O, memory/XMS, DPMI/protected-mode, timer, keyboard, or emulator-behavior related.
- Compare with real DOS under the same QEMU/86Box setup when the failure looks emulator-specific.
- Add focused regression coverage for any DOS behavior that explains either hang.

## Acceptance Criteria

- Boom and SMMU each have a recorded reproducible failure signature.
- Both launch far enough to run FreeDoom content, or each remaining blocker is isolated into a documented follow-up.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: "FreeDoom (Boom and SMMU, hangs)".
