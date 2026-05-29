# Cover Dup Handle Edge Semantics

## Summary

Strengthen `INT 21h AH=45h` and `AH=46h` duplicate-handle coverage around close lifetime and invalid force-dup requests.

## Requirements

- Duplicated file handles share file position and survive closing the original handle.
- Closed original and replacement handles fail subsequent I/O with invalid-handle error.
- `AH=46h` rejects invalid source and destination handles.
- Force-dup replacement preserves unrelated aliases and keeps replacement handles sharing the source state.

## Acceptance Criteria

- The existing `DUPTEST` 16-bit regression exercises the added edge cases under QEMU.
- `make test` passes.
- The Phase 19 matrix records the covered duplicate-handle semantics.
