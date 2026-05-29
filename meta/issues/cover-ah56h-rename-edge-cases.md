# Cover AH=56h Rename Edge Cases

## Summary

Add focused default-suite coverage for `INT 21h AH=56h` rename behavior around existing destination names and cross-directory targets.

## Requirements

- Same-directory rename to an existing destination fails with access denied and preserves both source and destination files.
- Cross-directory rename attempts fail with access denied and leave the source file in place.
- Existing open-handle, read-only, and successful rename behavior remains covered.
- Update the Phase 19 compatibility matrix status for `AH=56h`.

## Acceptance Criteria

- A focused regression covers overwrite and cross-directory rename failures.
- The focused rename regression runs in the default `make test` suite.
- Existing save/write and directory mutation coverage still passes.
- `make test` passes.
