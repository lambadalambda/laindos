# Cover Directory Current Edge Semantics

## Summary

Strengthen `INT 21h AH=39h`, `AH=3Ah`, `AH=3Bh`, and `AH=47h` coverage around invalid paths, invalid drives, and current-directory preservation.

## Requirements

- `AH=3Bh` rejects empty, file, and invalid-drive paths without changing the current directory.
- `AH=39h` and `AH=3Ah` reject empty and invalid-drive paths with DOS error codes.
- `AH=47h` reports the current directory for valid drive requests and rejects invalid drive requests.

## Acceptance Criteria

- A focused 16-bit regression exercises the added directory/current-directory edge cases under QEMU.
- Any exposed kernel compatibility bug is fixed generically.
- `make test` passes.
- The Phase 19 matrix records the covered directory/current-directory edge semantics.
