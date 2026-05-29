# Cover Seek Edge Semantics

## Summary

Lock `INT 21h AH=42h` seek behavior for origin modes, EOF positions, and failed calls.

## Requirements

- `AH=42h` supports origin 0, 1, and 2 with correct returned 32-bit file position.
- Seeking past EOF succeeds and subsequent reads report EOF.
- Unsupported origin modes fail with function-number error and preserve file position.
- Invalid seek handles fail with invalid-handle error.

## Acceptance Criteria

- A focused 16-bit regression exercises the seek edge cases under QEMU.
- The regression is part of the default test suite.
- `make test` passes.
- The Phase 19 matrix records the covered seek semantics.
