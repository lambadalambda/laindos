# Fix High-Allocation MCB Chain Split

## Summary

`alloc_mem_direct_high` can split a last free MCB while leaving the lower leftover block marked `Z`, which terminates later MCB walks before the newly allocated high block.

## Requirements

- Mark the lower leftover block as `MCB_SIG_M` when splitting a `Z` block for high allocation.
- Keep the allocated high block as the original terminal `Z` block.
- Add a regression that boots a COM target through the high-allocation path and proves later memory allocation still sees the high block after the COM program exits.

## Acceptance Criteria

- The regression fails before the fix and passes after it.
- Existing memory/EXEC/shell tests still pass.
- `make test` passes.

## Notes

- Review identified the missing `MCB_SIG_M` write near `alloc_mem_direct_high` as structurally similar to the already-correct `.am_use_last` path.
