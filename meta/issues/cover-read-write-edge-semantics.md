# Cover Read Write Edge Semantics

## Summary

Lock `INT 21h AH=3Fh` and `AH=40h` read/write behavior for zero-length calls, EOF reads, returned counts, and error paths.

## Requirements

- Zero-length reads and writes return zero without moving the file position.
- Reads at EOF return zero and partial reads return the available byte count.
- File writes return the number of bytes written and persist through close/reopen.
- Invalid read/write handles fail with invalid-handle error.
- Writes through read-only handles fail with access-denied error.

## Acceptance Criteria

- A focused 16-bit regression exercises the read/write edge cases under QEMU.
- The regression is part of the default test suite.
- `make test` passes.
- The Phase 19 matrix records the covered read/write semantics.
