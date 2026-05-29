# Cover DOS Version Identity Semantics

## Summary

Lock LainDOS's reported DOS identity to a conservative MS-DOS 3.30-compatible version across version query APIs.

## Requirements

- `INT 21h AH=30h` reports DOS major 3 and minor 30.
- `INT 21h AX=3306h` reports the same true version using DOS-compatible register ordering.
- Existing state API coverage remains consistent with the chosen identity.
- Update the Phase 19 compatibility matrix notes for `AH=30h`.

## Acceptance Criteria

- A focused 16-bit regression exercises the implemented version behavior under QEMU.
- The regression is part of the default test suite.
- `make test` passes.
- The Phase 19 matrix records the explicit 3.30 version policy.
