# Cover State API Edge Semantics

## Summary

Broaden `INT 21h` Ctrl-C/break and verify-flag state coverage around normalization and unsupported calls.

## Requirements

- `AX=3301h` normalizes break state to bit 0.
- Unsupported `AX=33xxh` subfunctions fail with function-number error `AX=0001h`.
- Failed break-state calls do not corrupt the stored break flag.
- `AH=2Eh` normalizes verify state from `AL` and ignores `DL`.

## Acceptance Criteria

- The existing `STATEAPI` 16-bit regression exercises the added state edge cases under QEMU.
- Existing boot-drive, true-version, date, and time state coverage remains intact.
- `make test` passes.
- The Phase 19 matrix records the covered state edge semantics.
