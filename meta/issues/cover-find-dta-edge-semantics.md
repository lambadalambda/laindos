# Cover Find DTA Edge Semantics

## Summary

Strengthen `INT 21h AH=4Eh` and `AH=4Fh` FindFirst/FindNext coverage around error codes, invalid drives, and drive-qualified root searches.

## Requirements

- `AH=4Fh` without an active match state fails with file-not-found.
- `AH=4Eh` distinguishes no-match, invalid-path, and invalid-drive failures.
- `AH=4Eh` handles valid drive-qualified root wildcard searches.
- Exhausted `AH=4Fh` returns file-not-found.

## Acceptance Criteria

- A focused 16-bit regression exercises the added FindFirst/FindNext edge cases under QEMU.
- Any exposed kernel compatibility bug is fixed generically.
- `make test` passes.
- The Phase 19 matrix records the covered FindFirst/FindNext edge semantics.
