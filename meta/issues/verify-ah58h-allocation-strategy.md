# Verify AH=58h Allocation Strategy

## Summary

`INT 21h AH=58h` exposes DOS memory allocation strategy state. Verify first-fit, best-fit, last-fit, and unsupported subfunction handling so runtimes see predictable allocator behavior.

## Requirements

- `AX=5800h` returns the current allocation strategy.
- `AX=5801h` accepts supported strategies `0`, `1`, and `2` only.
- Unsupported strategies or subfunctions fail with an error instead of silently succeeding.
- Memory allocation observes first-fit, best-fit, and last-fit strategy selection.
- Update the Phase 19 compatibility matrix status for `AH=58h`.

## Acceptance Criteria

- A focused regression distinguishes first, best, and last allocation choices and covers unsupported `AH=58h` requests.
- Existing memory, shell, EXEC, and game smoke tests relevant to allocation still pass.
- `make test` passes.
