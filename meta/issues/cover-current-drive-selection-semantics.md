# Cover Current Drive Selection Semantics

## Summary

Lock `INT 21h AH=0Eh` and `AH=19h` current-drive behavior for supported and invalid logical drives.

## Requirements

- `AH=19h` returns the current zero-based default drive.
- `AH=0Eh` returns the supported logical drive count for valid and invalid requests.
- Invalid `AH=0Eh` requests preserve the previous current drive.
- Existing directory and disk-free drive behavior remains consistent with the selected drive policy.

## Acceptance Criteria

- A focused 16-bit regression exercises valid and invalid current-drive selection under QEMU.
- The regression covers boundary and high-invalid drive numbers.
- `make test` passes.
- The Phase 19 matrix records the covered current-drive semantics.
