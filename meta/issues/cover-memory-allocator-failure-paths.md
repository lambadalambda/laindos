# Cover Memory Allocator Failure Paths

## Summary

Add focused coverage for `INT 21h AH=48h/49h/4Ah` failure paths so allocation, free, and resize errors return stable DOS error codes and largest-available sizes without corrupting existing MCBs.

## Requirements

- Oversized allocation requests fail with out-of-memory and return the largest available block in `BX`.
- Invalid free and resize segments fail with invalid-block errors.
- Failed resize growth returns the largest size available for that block and preserves the block size.
- Existing PSP-top resize and register-preservation behavior remains covered by existing tests.
- Update the Phase 19 compatibility matrix status for `AH=48h/49h/4Ah`.

## Acceptance Criteria

- A focused regression covers allocation, free, and resize failure paths.
- Existing memory, shell, EXEC, and game smoke tests relevant to allocation still pass.
- `make test` passes.
