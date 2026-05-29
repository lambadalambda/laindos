# Document Mouse Input And INT 33h Behavior

## Summary

Add documentation for the built-in mouse driver path, from PS/2 packets through `INT 33h` services and game callbacks.

## Requirements

- Explain PS/2 mouse initialization, packet decoding, button/movement state, scaling, edge clamping, and callback invocation.
- Document the implemented `INT 33h` functions and register contracts.
- Describe how emulator mouse capture affects manual testing.
- Link to relevant tests and emulator workflow docs.

## Acceptance Criteria

- Mouse behavior is documented in the interactive site or in a linked docs page.
- The docs identify what is implemented, what is stubbed, and what target games rely on.
- The docs link to mouse callback, hardware, ratio, and setter preservation tests.
- Local site smoke confirms any new site content renders without console errors.

## Notes

- Include practical notes for v86, QEMU display modes, VNC, and 86Box where behavior differs.
